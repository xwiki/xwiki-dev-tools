#!/bin/bash
SCRIPT_NAME=`basename "$0"`

PROJECTS=("xwiki-commons" "xwiki-rendering" "xwiki-platform")

## TODO: accept an optional prefix (e.g. "* ") to put in front of each contributor name, as a "-p" option.
## Until then, callers can pipe the names through `sed '/./s/^/* /'`.
usage() {
  echo "Usage: $SCRIPT_NAME start_version end_version"
  echo "Example: $SCRIPT_NAME 10.4 10.5"
}

VERSION1=$1
VERSION2=$2

if [[ -z "$VERSION1" ]] || [[ -z "$VERSION2" ]]; then
  usage
  exit 1
fi

TMP_FILE="/tmp/list_contributors_$VERSION1_$VERSION1.txt"
rm $TMP_FILE 2> /dev/null

for PROJECT in ${PROJECTS[@]}; do
  echo "Checking [$PROJECT]..."

  cd $PROJECT 2> /dev/null || { echo "ERROR: unable to find project [$PROJECT]. Execute script from 'xwiki-trunks' parent folder."; exit 2; }

  if [[ $VERSION1 =~ ^[0-9] ]]
  then
    FROM=${PROJECT}-${VERSION1}
  else
    FROM=${VERSION1}
  fi

  if [[ $VERSION2 =~ ^[0-9] ]]
  then
    TO=${PROJECT}-${VERSION2}
  else
    TO=${VERSION2}
  fi

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

  ## We want to retrieve both the authors and the co-authors of commits, that's why we include the Co-authored-by trailer
  ## `only=true` means that we only take value for this trailers key (we ignore other possible trailers)
  ## `valueonly=true` means that we don't want to display the key
  ## `unfold=true` means that in case of multiple co-authors we display them all
  ## The sed command is there to remove email addresses
  ## The awk command drops the empty lines
  ## The sort command is there to filter out multiple entries
  git log --pretty=format:"%an %+(trailers:key=Co-authored-by,only=true,valueonly=true,unfold=true)" $FROM..$TO | sed -e 's#<.*>##' | awk 'NF' | sort -u >> $TMP_FILE
  cd ..
done

echo
echo "Results:"
cat $TMP_FILE | sort -u
rm $TMP_FILE
