#!/bin/bash

# ---------------------------------------------------------------------------
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
# ---------------------------------------------------------------------------

## Computes the contributors of a release with list_contributors.sh and stores them in the "Contributors" entry of the
## corresponding release note, where the {{releasenotecontributors/}} macro renders them.
##
## list_contributors.sh is called from here rather than piped into this script because both need the same versions: the
## end version gives both the end of the git range and the release note to update. With a pipe, the versions would have
## to be passed to each script separately, and nothing would ensure that the list is the one of the release note.

SCRIPT_NAME=`basename "$0"`
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LIST_CONTRIBUTORS="$SCRIPT_DIR/../list_contributors.sh"

PRODUCT="XWiki"
ENTRY_CLASS="ReleaseNotes.Code.EntryClass"
CONTRIBUTORS_CLASS="ReleaseNotes.Code.ContributorsClass"
RELEASE_NOTE_CLASS="ReleaseNotes.Code.ReleaseNoteClass"

## Authors and co-authors that are not people (AI agents, dependency updaters, service accounts). Extended regular
## expressions, matched against whole contributor names.
BOT_PATTERNS=(
  '.*\[bot\]'
  'Claude( .*)?'
  'Copilot'
  'Kimi Code'
  'Mend Renovate'
  'anonymous'
  'XWiki'
)

usage() {
  echo "Usage: $SCRIPT_NAME [options] start_version end_version"
  echo "Example: $SCRIPT_NAME 18.7.0 18.8.0-rc-1"
  echo
  echo "Must be executed from the 'xwiki-trunks' parent folder, like list_contributors.sh."
  echo
  echo "Options:"
  echo "  -n, --dry-run             Only display what would be published; no credentials needed"
  echo "  -f, --force               Replace an existing contributors list"
  echo "  -w, --wiki-url URL        Base URL of the wiki (default: https://www.xwiki.org/xwiki)"
  echo "  -r, --release-note SPACE  Space of the release note, e.g. ReleaseNotes/Data/XWiki/18.8.0RC1"
  echo "                            (default: derived from end_version)"
  echo "  -h, --help                Display this help"
  echo
  echo "Credentials are read from XWIKI_USERNAME and XWIKI_PASSWORD, or asked for interactively."
}

fail() {
  echo "ERROR: $1" >&2
  exit ${2:-1}
}

DRY_RUN=false
FORCE=false
WIKI_URL="https://www.xwiki.org/xwiki"
RELEASE_NOTE_SPACE=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true; shift ;;
    -f|--force) FORCE=true; shift ;;
    -w|--wiki-url) WIKI_URL="${2%/}"; shift 2 ;;
    -r|--release-note) RELEASE_NOTE_SPACE="${2%/}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

START_VERSION=${POSITIONAL[0]}
END_VERSION=${POSITIONAL[1]}

if [[ -z "$START_VERSION" ]] || [[ -z "$END_VERSION" ]] || [[ ${#POSITIONAL[@]} -gt 2 ]]; then
  usage >&2
  exit 1
fi

## The release note page name uses the version without dashes (e.g. 18.8.0-rc-1 -> 18.8.0RC1).
if [[ -z "$RELEASE_NOTE_SPACE" ]]; then
  RELEASE_NOTE_SPACE="ReleaseNotes/Data/$PRODUCT/${END_VERSION/-rc-/RC}"
fi

## Convert a space path (A/B/C) to its REST path (spaces/A/spaces/B/spaces/C).
REST_SPACE_PATH="spaces/${RELEASE_NOTE_SPACE//\//\/spaces\/}"
REST_BASE="$WIKI_URL/rest/wikis/xwiki"
RELEASE_NOTE_URL="$REST_BASE/$REST_SPACE_PATH/pages/WebHome"
CONTRIBUTORS_URL="$REST_BASE/$REST_SPACE_PATH/spaces/Contributors/pages/WebHome"

CURL_AUTH_CONFIG=""

## Performs a REST request and prints the response body. Fails on HTTP errors, except for the accepted statuses given
## after the curl arguments with "--accept STATUS...".
rest() {
  local args=()
  local accepted=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--accept" ]]; then
      shift
      accepted=("$@")
      break
    fi
    args+=("$1")
    shift
  done

  local response
  if [[ -n "$CURL_AUTH_CONFIG" ]]; then
    response=$(curl -sS -w '\n%{http_code}' -K <(printf '%s\n' "$CURL_AUTH_CONFIG") -H 'Accept: application/xml' \
      "${args[@]}") || return 1
  else
    response=$(curl -sS -w '\n%{http_code}' -H 'Accept: application/xml' "${args[@]}") || return 1
  fi
  local status=${response##*$'\n'}
  local body=${response%$'\n'*}
  if [[ " ${accepted[*]} " == *" $status "* ]]; then
    printf '%s' "$body"
    return 0
  fi
  echo "ERROR: unexpected HTTP status [$status] for [${args[*]}]" >&2
  return 1
}

## Decodes the XML entities that XWiki's REST API produces in text content.
xml_unescape() {
  sed -e 's/&#13;//g' -e 's/&#xD;//g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&apos;/'/g" \
    -e 's/&amp;/\&/g'
}

## Prints the number of the first object of the given class on the page at the given REST URL, or nothing.
object_number() {
  local body
  body=$(rest "$1/objects/$2" --accept 200 404) || return 1
  if [[ "$body" =~ \<number\>([0-9]+)\</number\> ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

## Prints the value of a property of an object.
object_property() {
  local body
  body=$(rest "$1/objects/$2/$3/properties/$4" --accept 200) || return 1
  if [[ "$body" =~ \<value\>([^\<]*)\</value\> ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}" | xml_unescape
  fi
}

xml_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

## Prints the XML representation of an object: xml_object CLASS NAME VALUE [NAME VALUE]...
xml_object() {
  echo '<object xmlns="http://www.xwiki.org">'
  echo "<className>$1</className>"
  shift
  while [[ $# -gt 0 ]]; do
    echo "<property name=\"$1\"><value>$(printf '%s' "$2" | xml_escape)</value></property>"
    shift 2
  done
  echo '</object>'
}

ask_credentials() {
  local username=${XWIKI_USERNAME}
  local password=${XWIKI_PASSWORD}
  if [[ -z "$username" ]]; then
    read -p "Username on $WIKI_URL: " username
  fi
  if [[ -z "$password" ]]; then
    read -s -p "Password for [$username]: " password
    echo
  fi
  ## Passed through a curl config file so that the password does not appear in the process list.
  local credentials="$username:$password"
  credentials=${credentials//\\/\\\\}
  credentials=${credentials//\"/\\\"}
  CURL_AUTH_CONFIG="user = \"$credentials\""
}

## Check that the target is the release note of the end version.
echo "Checking release note [$RELEASE_NOTE_SPACE] on [$WIKI_URL]..." >&2
RELEASE_NOTE_NUMBER=$(object_number "$RELEASE_NOTE_URL" "$RELEASE_NOTE_CLASS")
if [[ -z "$RELEASE_NOTE_NUMBER" ]]; then
  fail "no release note found at [$RELEASE_NOTE_SPACE]. Create it first or use --release-note." 2
fi
RELEASE_NOTE_VERSION=$(object_property "$RELEASE_NOTE_URL" "$RELEASE_NOTE_CLASS" "$RELEASE_NOTE_NUMBER" version) \
  || exit 2
if [[ "$RELEASE_NOTE_VERSION" != "$END_VERSION" ]]; then
  fail "the release note at [$RELEASE_NOTE_SPACE] is for version [$RELEASE_NOTE_VERSION], not [$END_VERSION]." 2
fi

## Compute the contributors.
BOT_REGEX="^($(IFS='|'; echo "${BOT_PATTERNS[*]}"))$"
CONTRIBUTORS=$("$LIST_CONTRIBUTORS" "$START_VERSION" "$END_VERSION") || fail "unable to list the contributors." 3
CONTRIBUTORS=$(printf '%s\n' "$CONTRIBUTORS" | sed -e 's/[[:space:]]*$//' | awk 'NF' | grep -v -E "$BOT_REGEX" \
  | sort -u)
if [[ -z "$CONTRIBUTORS" ]]; then
  fail "no contributors found between [$START_VERSION] and [$END_VERSION]." 3
fi

echo >&2
echo "Contributors of [$END_VERSION] ($(printf '%s\n' "$CONTRIBUTORS" | wc -l)):" >&2
printf '%s\n' "$CONTRIBUTORS"
echo >&2

## Compare with the existing contributors list, if any.
CONTRIBUTORS_NUMBER=$(object_number "$CONTRIBUTORS_URL" "$CONTRIBUTORS_CLASS")
ENTRY_NUMBER=$(object_number "$CONTRIBUTORS_URL" "$ENTRY_CLASS")
if [[ -n "$CONTRIBUTORS_NUMBER" ]]; then
  ## Read before normalizing: in a pipeline only the status of the last command is checked, and an unreadable list
  ## must not be taken for an empty one, which --force would then overwrite.
  EXISTING=$(object_property "$CONTRIBUTORS_URL" "$CONTRIBUTORS_CLASS" "$CONTRIBUTORS_NUMBER" contributors) || exit 2
  EXISTING=$(printf '%s\n' "$EXISTING" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | awk 'NF' \
    | sort -u)
  if [[ "$EXISTING" == "$CONTRIBUTORS" ]]; then
    echo "The release note already lists these contributors, nothing to do." >&2
    exit 0
  fi
  echo "The release note already lists contributors (< existing, > computed):" >&2
  diff <(printf '%s\n' "$EXISTING") <(printf '%s\n' "$CONTRIBUTORS") >&2
  echo >&2
  if [[ $FORCE == false ]]; then
    if [[ $DRY_RUN == true ]]; then
      echo "Dry run: the existing list would be kept; use --force to replace it." >&2
      exit 0
    fi
    fail "not replacing the existing list; use --force to replace it."
  fi
fi

if [[ $DRY_RUN == true ]]; then
  echo "Dry run: the list would be published to [$RELEASE_NOTE_SPACE/Contributors]." >&2
  exit 0
fi

ask_credentials

CONTRIBUTORS_XML=$(xml_object "$CONTRIBUTORS_CLASS" contributors "$CONTRIBUTORS")
ENTRY_XML=$(xml_object "$ENTRY_CLASS" product "$PRODUCT" type Contributors version "$END_VERSION")

if [[ -z "$CONTRIBUTORS_NUMBER" ]] && [[ -z "$ENTRY_NUMBER" ]]; then
  echo "Creating [$RELEASE_NOTE_SPACE/Contributors]..." >&2
  rest -X PUT -H 'Content-Type: application/xml' --data-binary \
    '<page xmlns="http://www.xwiki.org"><title>Contributors</title><hidden>true</hidden><content></content></page>' \
    "$CONTRIBUTORS_URL" --accept 201 202 > /dev/null || exit 4
fi

if [[ -n "$ENTRY_NUMBER" ]]; then
  rest -X PUT -H 'Content-Type: application/xml' --data-binary "$ENTRY_XML" \
    "$CONTRIBUTORS_URL/objects/$ENTRY_CLASS/$ENTRY_NUMBER" --accept 202 > /dev/null || exit 4
else
  rest -X POST -H 'Content-Type: application/xml' --data-binary "$ENTRY_XML" \
    "$CONTRIBUTORS_URL/objects" --accept 201 > /dev/null || exit 4
fi

if [[ -n "$CONTRIBUTORS_NUMBER" ]]; then
  rest -X PUT -H 'Content-Type: application/xml' --data-binary "$CONTRIBUTORS_XML" \
    "$CONTRIBUTORS_URL/objects/$CONTRIBUTORS_CLASS/$CONTRIBUTORS_NUMBER" --accept 202 > /dev/null || exit 4
else
  rest -X POST -H 'Content-Type: application/xml' --data-binary "$CONTRIBUTORS_XML" \
    "$CONTRIBUTORS_URL/objects" --accept 201 > /dev/null || exit 4
fi

echo "Contributors published to [$RELEASE_NOTE_SPACE/Contributors]." >&2
