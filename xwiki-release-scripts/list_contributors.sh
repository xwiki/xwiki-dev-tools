#!/bin/bash
SCRIPT_NAME=`basename "$0"`

VERSION1=$1
VERSION2=$2

PROJECTS=("xwiki-commons" "xwiki-rendering" "xwiki-platform")

if [[ -z "$VERSION1" ]] || [[ -z "$VERSION2" ]]; then
  echo "Usage: $SCRIPT_NAME start_version end_version"
  echo "Example: $SCRIPT_NAME 10.4 10.5"
  exit 1
fi

TMP_FILE="/tmp/list_contributors_$VERSION1_$VERSION1.txt"
rm $TMP_FILE 2> /dev/null

for PROJECT in ${PROJECTS[@]}; do
  echo "Checking [$PROJECT]..."

  cd $PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 2; }

  FROM=${PROJECT}-${VERSION1}
  TO=${PROJECT}-${VERSION2}

  git fetch --tags

  git cat-file -e $FROM
  if [[ $? != 0 ]]; then
    echo "ERROR: Invalid start version."
    exit 3
  fi

  git cat-file -e $TO
  if [[ $? != 0 ]]; then
    echo "ERROR: Invalid end version."
    exit 4
  fi

  git log --pretty=format:"%an" $FROM..$TO | sort -u >> $TMP_FILE

  cd ..
done

echo
echo "Results:"
cat $TMP_FILE | sort -u
rm $TMP_FILE
