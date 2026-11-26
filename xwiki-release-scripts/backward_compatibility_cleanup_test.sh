#!/bin/bash
## ---------------------------------------------------------------------------
## See the NOTICE file distributed with this work for additional
## information regarding copyright ownership.
##
## This is free software; you can redistribute it and/or modify it
## under the terms of the GNU Lesser General Public License as
## published by the Free Software Foundation; either version 2.1 of
## the License, or (at your option) any later version.
##
## This software is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
## Lesser General Public License for more details.
##
## You should have received a copy of the GNU Lesser General Public
## License along with this software; if not, write to the Free
## Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
## 02110-1301 USA, or see the FSF site: http://www.fsf.org.
## ---------------------------------------------------------------------------

## Tests of the revapi ignores cleanup of backward_compatibility_cleanup.sh. Requires xmlstarlet.
## Usage: ./backward_compatibility_cleanup_test.sh

## Source the script for its functions only (a version is needed to pass its argument checks).
source "$(dirname "$0")/backward_compatibility_cleanup.sh" 1.0

FAILURES=0
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

function assert_equals ()
{
  if [[ "$2" != "$3" ]]; then
    echo "FAIL: $1: expected [$2] but got [$3]"
    FAILURES=$((FAILURES + 1))
  fi
}

## Writes a pom holding the given revapi.differences groups and prints its path.
function pom ()
{
  local file="$WORK_DIR/pom-$RANDOM.xml"
  cat > "$file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <build>
    <plugins>
      <plugin>
        <groupId>org.revapi</groupId>
        <artifactId>revapi-maven-plugin</artifactId>
        <configuration>
          <analysisConfiguration>
            <revapi.filter>
              <archives/>
            </revapi.filter>
            <!-- Add ignores here. -->
$1
          </analysisConfiguration>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
EOF
  echo "$file"
}

## A revapi.differences group with the attachments $1 (may be empty) and the items $2.
function group ()
{
  echo "<revapi.differences><justification>Some reason</justification>$1<differences>$2</differences></revapi.differences>"
}

## An item identified by the code $1, with the attachments $2 (may be empty).
function item ()
{
  echo "<item><ignore>true</ignore><code>$1</code><old>method void org.xwiki.Foo::bar()</old>$2</item>"
}

function versions ()
{
  echo "<attachments><versions>$1</versions></attachments>"
}

## Prints the [versions] of the item with the code $2 in the file $1, or "removed" if there's no such item anymore.
function item_versions ()
{
  if [[ $(xml_value "$1" "count(//m:item[m:code='$2'])") == 0 ]]; then
    echo "removed"
  else
    xml_value "$1" "//m:item[m:code='$2']/m:attachments/m:versions"
  fi
}

function test_master_after_bugfix ()
{
  local file=$(pom "$(group "" "$(item rc "$(versions 18.10.0-rc-1)")$(item next "$(versions 19.0.0-rc-1)")$(item backported "$(versions 18.10.1,19.0.0-rc-1)")")")

  cleanup_revapi_ignores "$file" 18.10.1 19.0.0 > /dev/null

  assert_equals "master: released RC" "removed" "$(item_versions "$file" rc)"
  assert_equals "master: next release" "19.0.0-rc-1" "$(item_versions "$file" next)"
  assert_equals "master: backported to the released version" "19.0.0-rc-1" "$(item_versions "$file" backported)"
}

function test_stable_after_bugfix ()
{
  local file=$(pom "$(group "" "$(item released "$(versions 18.10.1,19.0.0-rc-1)")$(item next "$(versions 18.10.2)")$(item older "$(versions 18.4.10,18.10.2,19.0.0-rc-1)")")")

  cleanup_revapi_ignores "$file" 18.10.1 18.10.2 > /dev/null

  ## 19.0.0-rc-1 belongs to master, which has its own copy of the ignore.
  assert_equals "stable: released" "removed" "$(item_versions "$file" released)"
  assert_equals "stable: next release" "18.10.2" "$(item_versions "$file" next)"
  assert_equals "stable: backported from an older branch" "18.10.2" "$(item_versions "$file" older)"
}

function test_group_versions ()
{
  local file=$(pom "$(group "$(versions 18.10.1)" "$(item released "")")$(group "$(versions 18.10.1,19.0.0)" "$(item kept "")")$(group "$(versions 18.10.1)" "$(item inherited "")$(item own "$(versions 19.0.0)")")")

  cleanup_revapi_ignores "$file" 18.10.1 19.0.0 > /dev/null

  assert_equals "group: released" "removed" "$(item_versions "$file" released)"
  assert_equals "group: inherited released versions" "removed" "$(item_versions "$file" inherited)"
  assert_equals "group: own versions" "19.0.0" "$(item_versions "$file" own)"
  ## Empty groups are removed: only the 2 groups with a remaining item are left.
  assert_equals "group: remaining groups" "2" "$(xml_value "$file" "count($REVAPI_GROUPS)")"
  assert_equals "group: filtered versions" "19.0.0" \
    "$(xml_value "$file" "$REVAPI_GROUPS[m:differences/m:item/m:code='kept']/m:attachments/m:versions")"
  ## The group whose versions are all released doesn't keep an empty attachments element.
  assert_equals "group: removed attachments" "0" \
    "$(xml_value "$file" "count($REVAPI_GROUPS[m:differences/m:item/m:code='own']/m:attachments)")"
}

function test_without_versions ()
{
  local file=$(pom "$(group "" "$(item legacy "")")")

  local output=$(cleanup_revapi_ignores "$file" 18.10.1 19.0.0)

  assert_equals "no versions: removed" "removed" "$(item_versions "$file" legacy)"
  assert_equals "no versions: warning" \
    "WARNING: removing the revapi ignore without [versions] attachment [legacy] [method void org.xwiki.Foo::bar()] []" \
    "$output"
  assert_equals "no versions: groups" "0" "$(xml_value "$file" "count($REVAPI_GROUPS)")"
}

function test_rest_of_the_pom_unchanged ()
{
  local file=$(pom "$(group "" "$(item next "$(versions 19.0.0-rc-1)")")")
  local before=$(cat "$file")

  cleanup_revapi_ignores "$file" 18.10.1 19.0.0 > /dev/null

  assert_equals "unchanged" "$before" "$(cat "$file")"
}

test_master_after_bugfix
test_stable_after_bugfix
test_group_versions
test_without_versions
test_rest_of_the_pom_unchanged

if [[ $FAILURES == 0 ]]; then
  echo "All tests passed."
else
  echo "$FAILURES failure(s)."
  exit 1
fi
