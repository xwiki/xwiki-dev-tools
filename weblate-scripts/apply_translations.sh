#!/bin/bash
## Following options  are needed to avoid the subshell issue because of using a while read loop with a pipe.
## See: https://mywiki.wooledge.org/BashFAQ/024
set +m
shopt -s lastpipe

CURRENT_DIRECTORY=`pwd`
SCRIPT_DIRECTORY=`dirname "$0"`
SCRIPT_NAME=`basename "$0"`
PROJECTS=("xwiki-commons" "xwiki-rendering" "xwiki-platform")
COMPONENTS_SCRIPT="retrieve_components.py"
BRANCH=$2

function usage {
  echo "Usage: $SCRIPT_NAME [target] branchname"
  echo "Target:"
  echo "  update  Update translations"
  echo "  push    Push the updated translations"
  echo "  clean   Rollback the update (before pushing)"
  echo "Example:"
  echo "  $SCRIPT_NAME update stable-X"
  exit 1
}

function checkout() {
    git checkout $BRANCH
    if [[ $? != 0 ]]; then
      echo "Branch $BRANCH not found."
      return -1
    fi
    return 0
}

function update() {
  N=0
  for project in ${PROJECTS[@]}; do
      echo "Updating $project translations..."
      cd $project
      # Ensure that all commits from master are retrieved, since we'll update from it.
      git checkout master
      git pull --rebase origin master
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git pull --rebase origin $BRANCH
      if [[ $? != 0 ]]; then
        echo "Couldn't pull new changes."
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      N=$((N+1))
      # Iterate on all paths from the list of components and checkout the changes from master on the translation
      # and on the source file translation
      $SCRIPT_DIRECTORY/$COMPONENTS_SCRIPT $project | while read -r component; do
        if [[ -f $component ]]; then
          git checkout master -- $component

          p_prop="${component/.properties/_*.properties}"
          p_xml="${component/.xml/.*.xml}"

          # we don't want the checkout to fail if the pattern does not exist in master
          # (could be the case if the component does not have any translation yet on master)
          # Note that some not nice error logs might still occur, such as:
          # error: pathspec 'xwiki-platform-core/xwiki-platform-captcha/xwiki-platform-captcha-ui/src/main/resources/XWiki/Captcha/Translations.*.xml' did not match any file(s) known to git.
          # Those are not nice to have, but not harmful.
          if [[ $component != $p_prop ]]; then
            git checkout master -- $p_prop || true
          elif [[ $component != $p_xml ]]; then
            git checkout master -- $p_xml || true
          fi
        fi
      done
      cd $CURRENT_DIRECTORY
      echo
  done
  echo "$N project(s) updated."
  echo "After reviewing the changes, you can run '$SCRIPT_NAME push $BRANCH' "
  echo "to commit and push the changes."
}

function push() {
  for project in $PROJECTS; do
      echo "Pushing $project translations..."
      cd $project
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git add . && git commit -m "[release] Updated translations." && \
      git pull --rebase origin $BRANCH && git push origin $BRANCH
      if [[ $? != 0 ]]; then
        echo "Couldn't push to $BRANCH."
      fi
      cd $CURRENT_DIRECTORY
      echo
  done
}

function clean() {
  for project in $PROJECTS; do
      echo "Cleaning $project..."
      cd $project
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git reset --hard && git clean -dxf
      cd $CURRENT_DIRECTORY
      echo
  done
}

if [[ "$1" == 'update' ]] && [[ -n "$BRANCH" ]]; then
  update
elif [[ "$1" == 'push' ]] && [[ -n "$BRANCH" ]]; then
  push
elif [[ "$1" == 'clean' ]] && [[ -n "$BRANCH" ]]; then
  clean
else
  usage
fi
