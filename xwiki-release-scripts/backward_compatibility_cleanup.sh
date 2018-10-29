#!/bin/bash
SCRIPT_NAME=`basename "$0"`

VERSION=$1

declare -A PROJECTS=( ["xwiki-commons"]="pom.xml" ["xwiki-rendering"]="pom.xml" ["xwiki-platform"]="xwiki-platform-core/pom.xml")

if [[ -z "$VERSION" ]]; then
  echo "Usage: $SCRIPT_NAME released_version"
  echo "Example: $SCRIPT_NAME 10.9"
  exit 1
fi

if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Only run this operation on final versions, not release candidates or bugfixes."
  exit 2;
fi

for PROJECT in ${!PROJECTS[@]}; do
  echo "Checking [$PROJECT]..."

  cd $PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 3; }

  git checkout master || exit 4
  git pull --rebase || exit 4

  if [[ "$PROJECT" == "xwiki-commons" ]]; then
    echo "Updating [xwiki.compatibility.previous.version]..."

    sed -i "s/<xwiki.compatibility.previous.version>.*</<xwiki.compatibility.previous.version>$VERSION</" pom.xml

    git --no-pager diff || exit 4
    git commit -a -m "[release] Updated compatibility previous version to the one just released." || exit 4
  fi

  IGNORES_FILE="${PROJECTS[$PROJECT]}"

  echo "Removing any existing revapi ignores from [$IGNORES_FILE]..."

  perl -0pi -e 's/\/\/ Add more ignores below\.\.\.\s*({.*?}(,\s*|\s*$))+/\/\/ Add more ignores below\.\.\./gms' "$IGNORES_FILE"

  git --no-pager diff || exit 4
  git commit -a -m "[release] Removed revapi ignores from the previous version" || exit 4

  git push origin master || exit 4

  cd ..
done
