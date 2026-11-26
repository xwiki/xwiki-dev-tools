#!/bin/bash
SCRIPT_NAME=`basename "$0"`

VERSION=$1

## Location of the revapi ignores to clean.
declare -A PROJECTS=( ["xwiki-commons"]="xwiki-commons-core/pom.xml" ["xwiki-rendering"]="pom.xml" ["xwiki-platform"]="xwiki-platform-core/pom.xml")

## Project location of compatibility version (we assume it's in the root pom)
COMPATIBILITY_VERSION_PROJECT="xwiki-commons"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $SCRIPT_NAME released_version"
  echo "Example: $SCRIPT_NAME 10.9"
  exit 1
fi

if ! [[ $VERSION =~ ^([0-9]+.){1,2}[0-9]+$ ]]; then
  echo "ERROR: Only run this operation on final or bugfix versions, not release candidates or milestones."
  exit 2;
fi

VERSION_COMPONENTS=(${VERSION//./ })

POM_NAMESPACE=(-N m="http://maven.apache.org/POM/4.0.0")
REVAPI_GROUPS="/m:project/m:build/m:plugins/m:plugin/m:configuration/m:analysisConfiguration/m:revapi.differences"

## Is the version $1 strictly lower than the version $2? Only handles versions made of numbers separated by dots.
function version_lt ()
{
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}

## Prints the versions of the comma-separated list $1 which are greater than the released version $2 and lower than or
## equal to the current version $3 of the branch, i.e. the versions for which the ignore is still needed on the branch.
## The released version being a final or bugfix version, the qualifier of a version (e.g. "-rc-1") doesn't matter in
## the comparison: 19.0.0-rc-1 is greater than 18.10.1 like 19.0.0, and 18.10.0-rc-1 isn't greater than 18.10.0.
function filter_unreleased_versions ()
{
  local version base kept=()
  for version in ${1//,/ }; do
    base=${version%%-*}
    if version_lt "$2" "$base" && ! version_lt "$3" "$base"; then
      kept+=("$version")
    fi
  done
  (IFS=,; echo "${kept[*]}")
}

## Prints the value of the XPath $2 in the file $1, or nothing if it doesn't match.
function xml_value ()
{
  xmlstarlet sel "${POM_NAMESPACE[@]}" -t -v "$2" "$1" || true
}

function xml_delete ()
{
  xmlstarlet ed -P --inplace "${POM_NAMESPACE[@]}" -d "$2" "$1"
}

## Keeps in the [versions] attachment of the element $2 of the file $1 only the versions $3, or removes the attachment
## (and the attachments element if it's then empty) when $3 is empty.
function update_versions_attachment ()
{
  local file=$1 element=$2 kept=$3
  if [[ -n "$kept" ]]; then
    xmlstarlet ed -P --inplace "${POM_NAMESPACE[@]}" -u "$element/m:attachments/m:versions" -v "$kept" "$file"
  else
    xml_delete "$file" "$element/m:attachments/m:versions"
    if [[ $(xml_value "$file" "count($element/m:attachments/*)") == 0 ]]; then
      xml_delete "$file" "$element/m:attachments"
    fi
  fi
}

## Removes from the revapi ignores of the pom $1 the versions which are not needed anymore once the version $2 is
## released, on a branch whose current version is $3 (without -SNAPSHOT). See filter_unreleased_versions.
## The versions are given as a comma-separated list in a [versions] attachment of each difference, or of its
## revapi.differences group for the differences without their own. A difference whose versions are all removed is
## removed, and so is a group whose differences are all removed. A difference without any [versions] attachment is
## removed with a warning.
function cleanup_revapi_ignores ()
{
  local file=$1 released=$2 current=$3
  local group_count group group_versions group_kept item_count item item_versions kept i g

  group_count=$(xml_value "$file" "count($REVAPI_GROUPS)")
  ## Iterate backwards so that deleting a node doesn't shift the indexes of the nodes still to visit.
  for ((g = group_count; g >= 1; g--)); do
    group="($REVAPI_GROUPS)[$g]"
    group_versions=$(xml_value "$file" "$group/m:attachments/m:versions")
    group_kept=$(filter_unreleased_versions "$group_versions" "$released" "$current")

    item_count=$(xml_value "$file" "count($group/m:differences/m:item)")
    for ((i = item_count; i >= 1; i--)); do
      item="$group/m:differences/m:item[$i]"
      item_versions=$(xml_value "$file" "$item/m:attachments/m:versions")
      if [[ -n "$item_versions" ]]; then
        kept=$(filter_unreleased_versions "$item_versions" "$released" "$current")
        if [[ -n "$kept" ]]; then
          [[ "$kept" == "$item_versions" ]] || update_versions_attachment "$file" "$item" "$kept"
          continue
        fi
      elif [[ -n "$group_kept" ]]; then
        continue
      elif [[ -z "$group_versions" ]]; then
        echo "WARNING: removing the revapi ignore without [versions] attachment [$(xml_value "$file" "$item/m:code")]" \
          "[$(xml_value "$file" "$item/m:old")] [$(xml_value "$file" "$item/m:new")]"
      fi
      xml_delete "$file" "$item"
    done

    if [[ $(xml_value "$file" "count($group/m:differences/m:item)") == 0 ]]; then
      ## A revapi.differences group cannot be empty.
      xml_delete "$file" "$group"
    elif [[ -n "$group_versions" && "$group_kept" != "$group_versions" ]]; then
      update_versions_attachment "$file" "$group" "$group_kept"
    fi
  done
}

function update_compatibility_version ()
{
  local branch=$1
  echo "## Running update compatibility version on branch [$branch] for version [$VERSION]..."
  echo "## Updating [xwiki.compatibility.previous.version] in $COMPATIBILITY_VERSION_PROJECT root pom."

  cd $COMPATIBILITY_VERSION_PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$COMPATIBILITY_VERSION_PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 3; }

  git checkout $branch || exit 4
  git pull --rebase origin $branch || exit 4
  sed -i "s/<xwiki.compatibility.previous.version>.*</<xwiki.compatibility.previous.version>$VERSION</" pom.xml

  git --no-pager diff || exit 4
  git commit -a -m "[release] Updated compatibility previous version to the one just released." || exit 4

  cd ..
}

function backward_compatibility_cleanup ()
{
  local branch=$1

  echo "## Running backward compatibility cleanup on branch [$branch] for version [$VERSION]..."

  for PROJECT in ${!PROJECTS[@]}; do
    echo "## Checking [$PROJECT]..."

    cd $PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 3; }

    git checkout $branch || exit 4
    git pull --rebase origin $branch || exit 4

    IGNORES_FILE="${PROJECTS[$PROJECT]}"

    local current_version=$(xmlstarlet sel "${POM_NAMESPACE[@]}" -t -v "/m:project/m:version" pom.xml)
    current_version=${current_version%-SNAPSHOT}

    echo "## Removing the revapi ignores not needed anymore from [$IGNORES_FILE]..."

    cleanup_revapi_ignores "$IGNORES_FILE" "$VERSION" "$current_version"

    DIFF=`git --no-pager -c color.ui=always diff`
    [[ $? == 0 ]] || exit 4

    if ! [[ -z $DIFF ]]; then
      echo $DIFF
      git commit -a -m "[release] Removed revapi ignores from the previous version" || exit 4
    else
      echo "## No ignores to remove."
    fi

    echo "## Pushing changes..."
    git push origin $branch || exit 4

    cd ..
  done
}

## Stop here when the script is sourced (e.g. by its tests) instead of executed.
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

## Update the stable branch (either final release or bugfix release, they both use a stable branch, unlike a RC/milestone that releases from master).
BRANCH_NAME="stable-${VERSION_COMPONENTS[0]}.${VERSION_COMPONENTS[1]}.x"
update_compatibility_version $BRANCH_NAME
backward_compatibility_cleanup $BRANCH_NAME

echo "Also update the [master] branch? (Only if new release version is 'bigger' than the existing one. Y for final, N for most bugfixes except bugfix of a very recent final) :"
read -p "[y/N] " UPDATE_MASTER

if [[ "$UPDATE_MASTER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  ## Also update master. Useful when releasing a final version (right after a RC) or a bugfix of a previously released final (before the new final has a chance to be released).
  update_compatibility_version master
  backward_compatibility_cleanup master
fi
