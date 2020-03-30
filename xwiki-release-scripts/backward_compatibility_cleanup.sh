#!/bin/bash
SCRIPT_NAME=`basename "$0"`

VERSION=$1

declare -A PROJECTS=( ["xwiki-commons"]="pom.xml" ["xwiki-rendering"]="pom.xml" ["xwiki-platform"]="xwiki-platform-core/pom.xml")

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

function backward_compatibility_cleanup ()
{
  local branch=$1

  echo "## Running on branch [$branch] for version [$VERSION]..."

  for PROJECT in ${!PROJECTS[@]}; do
    echo "## Checking [$PROJECT]..."

    cd $PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 3; }

    git checkout $branch || exit 4
    git pull --rebase origin $branch || exit 4

    if [[ "$PROJECT" == "xwiki-commons" ]]; then
      echo "## Updating [xwiki.compatibility.previous.version]..."

      sed -i "s/<xwiki.compatibility.previous.version>.*</<xwiki.compatibility.previous.version>$VERSION</" pom.xml

      git --no-pager diff || exit 4
      git commit -a -m "[release] Updated compatibility previous version to the one just released." || exit 4
    fi

    IGNORES_FILE="${PROJECTS[$PROJECT]}"

    echo "## Removing any existing revapi ignores from [$IGNORES_FILE]..."

    perl -0pi -e 's/(\"ignore\" : \[$)\s*({.*?}(,\s*|\s*$))+/$1/gms' "$IGNORES_FILE"

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
backward_compatibility_cleanup "stable-${VERSION_COMPONENTS[0]}.${VERSION_COMPONENTS[1]}.x"

echo "Also update the [master] branch? (Only if new release version is 'bigger' than the existing one. Y for final, N for most bugfixes except bugfix of a very recent final) :"
read -p "[y/N] " UPDATE_MASTER

if [[ "$UPDATE_MASTER" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  ## Also update master. Useful when releasing a final version (right after a RC) or a bugfix of a previously released final (before the new final has a chance to be released).
  backward_compatibility_cleanup master
fi
