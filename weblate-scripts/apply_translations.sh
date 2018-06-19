#!/bin/bash
CURRENT_DIRECTORY=`pwd`
SCRIPT_DIRECTORY=`dirname "$0"`
SCRIPT_NAME=`basename "$0"`
FILES="$SCRIPT_DIRECTORY/translation_list_%s.txt"

function usage {
  echo "Usage: $SCRIPT_NAME [target] ..."
  echo "Target:"
  echo "  update BRANCH   Update translations of the branch BRANCH"
  echo "  push            Push the updated translations"
  echo "  clean           Rollback the update (before pushing)"
  exit 1
}

function update() {
  N=0
  for f in *; do
    FILE=`printf $FILES $f`
    if [ -f $FILE ]; then
      echo "Updating $f translations..."
      cd $f
      if [ -n "$1" ]; then
        git checkout $1 > /dev/null 2>&1 || {
          echo "Branch $1 not found"
          cd $CURRENT_DIRECTORY
          continue
        }
      fi
      N=$((N+1))
      PATHS=`awk -F';' 'NF && $0!~/^#/{print $2}' $FILE`
      for p in $PATHS; do
        if [ -f $p ]; then
          git checkout master -- "${p/.properties/_*.properties}" 2> /dev/null
          git checkout master -- "${p/.xml/.*.xml}" 2> /dev/null
        fi
      done
      cd $CURRENT_DIRECTORY
    fi
  done
  echo $'\n'"$N project(s) updated"
  echo "You can commit the changes and run '$SCRIPT_NAME push' when finished"
}

function push() {
  for f in *; do
    FILE=`printf $FILES $f`
    if [ -f $FILE ]; then
      echo "Pushing $f translations..."
      cd $f
      git push > /dev/null
      cd $CURRENT_DIRECTORY
    fi
  done
}

function clean() {
  for f in *; do
    FILE=`printf $FILES $f`
    if [ -f $FILE ]; then
      echo "Cleaning $f..."
      cd $f
      git reset --hard > /dev/null
      cd $CURRENT_DIRECTORY
    fi
  done
}

if [ "$1" == 'update' ]; then
  update $2
elif [ "$1" == 'push' ]; then
  push
elif [ "$1" == 'clean' ]; then
  clean
else
  usage
fi
