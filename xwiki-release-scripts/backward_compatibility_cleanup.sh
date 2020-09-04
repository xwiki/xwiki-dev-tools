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

    echo "## Removing any existing revapi ignores from [$IGNORES_FILE]..."

    xmlstarlet ed -P --inplace -N m="http://maven.apache.org/POM/4.0.0" -d "/m:project/m:build/m:plugins/m:plugin/m:configuration/m:analysisConfiguration/m:revapi.ignore" "$IGNORES_FILE"

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
