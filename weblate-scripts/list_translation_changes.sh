#!/bin/bash

## Following options  are needed to avoid the subshell issue because of using a while read loop with a pipe.
## See: https://mywiki.wooledge.org/BashFAQ/024
set +m
shopt -s lastpipe

SCRIPT_NAME=`basename "$0"`
SCRIPT_DIRECTORY=`dirname "$0"`
COMPONENTS_SCRIPT="retrieve_components.py"

CURRENT_DIRECTORY=`pwd`
PROJECT=`basename "$CURRENT_DIRECTORY"`

BRANCH=$1
START_COMMIT=$2
END_COMMIT=$3
OPTIONAL1=$4
OPTIONAL2=$5
OPTIONAL3=$6

([ "$OPTIONAL1" == '--verbose' ] || [ "$OPTIONAL2" == '--verbose' ] || [ "$OPTIONAL3" == '--verbose' ]) && VERBOSE_ENABLED=true || VERBOSE_ENABLED=false
([ "$OPTIONAL1" == '--diff' ] || [ "$OPTIONAL2" == '--diff' ] || [ "$OPTIONAL3" == '--diff' ]) && DIFF_ENABLED=true || DIFF_ENABLED=false
([ "$OPTIONAL1" == '--diffAll' ] || [ "$OPTIONAL2" == '--diffAll' ] || [ "$OPTIONAL3" == '--diffAll' ]) && DIFFALL_ENABLED=true || DIFFALL_ENABLED=false

function usage() {
  echo "Usage: $SCRIPT_NAME branch start_commit end_commit [options]"
  echo "Parameters:"
  echo "  branch        The branch name defined by the component. Most of the time should be master, except for a LTS bug fix release, where it should be the name of the branch."
  echo "  start_commit  The git commit/tag ID to compare from"
  echo "  end_commit    The git commit/tag ID to compare to"
  echo "Options:"
  echo "  --diff        Include the diff on each translated file that was modified"
  echo "  --diffAll     Include the diff on each translated file that was modified, including formatting changes that are skipped by the report"
  echo "  --verbose     List each checked translation file, even if it is not modified"
  echo "Example:"
  echo "  $SCRIPT_NAME xwiki-platform-10.3 xwiki-platform-10.4-rc-1 --diff --verbose"
  exit 1
}

function showDiff {
  ## Use --no-pager to not block the execution.
  git --no-pager diff --color=always $START_COMMIT..$END_COMMIT -- $1
}

if [[ -z "$START_COMMIT" ]] || [[ -z "$END_COMMIT" ]] || [[ -z "$BRANCH" ]]; then
  usage
fi

git cat-file -e $START_COMMIT
if [[ $? != 0 ]]; then
  echo "ERROR: Invalid start commit. Check for typos or update the local git repository with upstream changes."
  exit 3
fi

git cat-file -e $END_COMMIT
if [[ $? != 0 ]]; then
  echo "ERROR: Invalid end commit. Check for typos or update the local git repository with upstream changes."
  exit 4
fi

UPDATED_TRANSLATIONS=()
UPDATED_LANGUAGES=()

echo "Listing [$PROJECT] translation changes between [$START_COMMIT] and [$END_COMMIT]..."

if [ "$VERBOSE_ENABLED" == true ]; then
    echo "Calling $SCRIPT_DIRECTORY/$COMPONENTS_SCRIPT $PROJECT $BRANCH"
fi

$SCRIPT_DIRECTORY/$COMPONENTS_SCRIPT $PROJECT $BRANCH | while read -r TRANSLATION_BASE_FILE; do
  if [ "$VERBOSE_ENABLED" == true ]; then
    echo "Checking file [$TRANSLATION_BASE_FILE]..."
  fi
  if [[ -f $TRANSLATION_BASE_FILE ]]; then
    TRANSLATION_BASE_FILE="${TRANSLATION_BASE_FILE/.properties/_*.properties}"
    TRANSLATION_BASE_FILE="${TRANSLATION_BASE_FILE/.xml/.*.xml}"
    for TRANSLATION_LANGUAGE_FILE in $TRANSLATION_BASE_FILE; do
      if [ "$VERBOSE_ENABLED" == true ]; then
        echo "  Checking translation [$TRANSLATION_LANGUAGE_FILE]..."
      fi

      ## Valid changes are of the format "+property=value" (i.e. additions or modifications) of a line.
      LINES_CHANGED=`git diff $START_COMMIT..$END_COMMIT -- $TRANSLATION_LANGUAGE_FILE | grep -E "^\+[^#+]+=" | wc -l`
      if [[ $LINES_CHANGED -gt 0 ]]; then
        ## Print the checked translation file only when it contains modifications and if verbose mode is not already enabled.
        if [ "$VERBOSE_ENABLED" == false ]; then
          echo
          echo "  Checking translation [$TRANSLATION_LANGUAGE_FILE]..."
        fi
        echo "    FOUND CHANGES: $LINES_CHANGED"
        UPDATED_TRANSLATIONS+=($TRANSLATION_LANGUAGE_FILE)
        if [[ $TRANSLATION_LANGUAGE_FILE == *.xml ]]; then
          LANGUAGE=`echo "$TRANSLATION_LANGUAGE_FILE" | cut -d. -f2`
        elif [[ $TRANSLATION_LANGUAGE_FILE == *.properties ]]; then
          LANGUAGE=`echo "$TRANSLATION_LANGUAGE_FILE" | sed -E 's_.*/[^_]+\_(.*)\.properties_\1_'`
        fi
        UPDATED_LANGUAGES+=($LANGUAGE)

        if [ "$DIFF_ENABLED" == true ] || [ "$DIFFALL_ENABLED" == true ]; then
          showDiff $TRANSLATION_LANGUAGE_FILE
        fi
      else
        if [ "$DIFFALL_ENABLED" == true ]; then
          showDiff $TRANSLATION_LANGUAGE_FILE
        fi
      fi
    done
  fi
done

echo
echo "[REPORT]"

echo
echo "Updated translation files (${#UPDATED_TRANSLATIONS[@]}):"
printf "%s\n" "${UPDATED_TRANSLATIONS[@]}"

echo
UNIQUE_UPDATED_LANGUAGES=`printf "%s\n" "${UPDATED_LANGUAGES[@]}" | sort -u`
echo "Updated languages (`printf "%s\n" "${UNIQUE_UPDATED_LANGUAGES[@]}" | wc -l`):"
printf "%s\n" "${UNIQUE_UPDATED_LANGUAGES[@]}"
