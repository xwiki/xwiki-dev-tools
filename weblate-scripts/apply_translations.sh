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
TMP_TRANSLATIONS_FILES="/tmp/xwiki-translations-files.tmp"
TMP_TRANSLATIONS_AUTHORS_INFO="/tmp/xwiki-translations-authors_$BRANCH"

function usage {
  echo "Usage: $SCRIPT_NAME [target] branchname"
  echo "Target:"
  echo "  update  Update translations"
  echo "  push    Push the updated translations"
  echo "  commit  Commit the updated translations with computed co-authors"
  echo "  clean   Rollback the update (before pushing)"
  echo "Example:"
  echo "  $SCRIPT_NAME update stable-X"
  exit 1
}

function checkout() {
    git checkout $BRANCH
    if [[ $? != 0 ]]; then
      echo "Branch $BRANCH not found."
      return 1
    fi
    return 0
}

function computeAuthors() {
  limitDate=$1
  filePath=$2
  git log --pretty=format:"%an <%ae> %+(trailers:key=Co-authored-by,only=false,valueonly=true,unfold=true)" --since="$limitDate" "$filePath" | sort -u >> "${TMP_TRANSLATIONS_AUTHORS_INFO}_${project}.txt"
}

function updateCurrentProject() {
    # Ensure that all commits from master are retrieved, since we'll update from it.
    git checkout master
    git pull --rebase origin master
    # Find latest tag related to the branch
    versionPattern=$(echo "$BRANCH" | sed -e 's/x/*/' -e 's/stable-/*/')
    tag=$(git tag -l --sort=-refname "$versionPattern" |head -n 1)
    echo "Latest tag found: $tag"
    # Find date of this tag
    tagDate=$(git log -1 --format=%ai "$tag")

    declare -A RELEASE_WEBLATE
    # Ensure to not aggregate information to old data
    rm -f $TMP_TRANSLATIONS_FILES
    # Retrieve the list of components from weblate
    $SCRIPT_DIRECTORY/$COMPONENTS_SCRIPT $project | while read -r component; do
      ## We store values of translations file available in master, since it's those that we will commit back.
      if [[ -f $component ]]; then
        echo $component >> $TMP_TRANSLATIONS_FILES
        computeAuthors "$tagDate" "$component"
        p_prop="${component/.properties/_*.properties}"
        p_xml="${component/.xml/.*.xml}"
        if [[ $component != $p_prop ]]; then
          echo $p_prop >> $TMP_TRANSLATIONS_FILES
          computeAuthors "$tagDate" "$p_prop"
        elif [[ $component != $p_xml ]]; then
          echo $p_xml >> $TMP_TRANSLATIONS_FILES
          computeAuthors "$tagDate" "$p_xml"
        fi
      fi
    done
    checkout
    if [[ $? != 0 ]]; then
      return $?
    fi
    git pull --rebase origin $BRANCH
    if [[ $? != 0 ]]; then
      echo "Couldn't pull new changes."
      return $?
    fi
    # Iterate on all paths we stored and apply them to the current branch
    cat $TMP_TRANSLATIONS_FILES | while read -r translation_file; do
      git checkout master -- $translation_file
    done
}

function update() {
  N=0
  for project in ${PROJECTS[@]}; do
      echo "Updating $project translations..."
      cd $project
      updateCurrentProject
      cd $CURRENT_DIRECTORY
      echo
  done
  echo "$N project(s) updated."
  echo "After reviewing the changes, you can run '$SCRIPT_NAME push $BRANCH' "
  echo "to commit and push the changes."
}

function commit() {
  authorFile="${TMP_TRANSLATIONS_AUTHORS_INFO}_${project}.txt"
  coauthors=""
  if [[ -f $authorFile ]]; then
    coauthors=$(cat $authorFile | sort -u | sed -e 's/^\(.\)/Co-authored-by: \1/')
    rm $authorFile
  fi
  git commit -m "[Misc] Updated translations." -m "$coauthors"
}

function push() {
  for project in ${PROJECTS[@]}; do
      echo "Pushing $project translations..."
      cd $project
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      commit
      git pull --rebase origin $BRANCH && git push origin $BRANCH
      if [[ $? != 0 ]]; then
        echo "Couldn't push to $BRANCH."
      fi
      cd $CURRENT_DIRECTORY
      echo
  done
}

function clean() {
  for project in ${PROJECTS[@]}; do
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

function checkDirectories() {
  for project in ${PROJECTS[@]}; do
    if [[ ! -d $project ]]; then
      echo "Cannot find directory $project"
      return 1
    fi
  done
  return 0
}

function guessCurrentProject() {
  current_dir=`basename $CURRENT_DIRECTORY`
  for project in ${PROJECTS[@]}; do
    if [[ $project == $current_dir ]]; then
      return 0
    fi
  done
  echo "Cannot guess the current project"
  return 1
}

if [[ "$1" == 'update' ]] && [[ -n "$BRANCH" ]]; then
  checkDirectories
  if [[ $? != 0 ]]; then
    guessCurrentProject
    if [[ $? == 0 ]]; then
      echo "Performing update on $project."
      updateCurrentProject
    fi
  else
    echo "Performing update on all commons, rendering and platform."
    update
  fi
elif [[ "$1" == 'commit' ]] && [[ -n "$BRANCH" ]]; then
  checkDirectories
  if [[ $? != 0 ]]; then
    guessCurrentProject
    if [[ $? == 0 ]]; then
      echo "Performing commit on $project."
      commit
    fi
  else
    echo "Performing commit on all commons, rendering and platform. [NOT SUPPORTED YET]"
  fi
elif [[ "$1" == 'push' ]] && [[ -n "$BRANCH" ]]; then
  push
elif [[ "$1" == 'clean' ]] && [[ -n "$BRANCH" ]]; then
  clean
else
  usage
fi
