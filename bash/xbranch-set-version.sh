#!/bin/bash

if [ ! -d ".git" ]; then
  if [ ! -f ".git" ]; then
    >&2 echo "Should be executed at the root of the git workspace!"
    exit 1
  fi
fi

while getopts ahv: flag
do
    case "${flag}" in
        h) help=true;;
        a) all=true;;
        v) CURRENT_VERSION=${OPTARG};;
    esac
done

if [ $help ]
then
  echo "Usage: xbranch-set-version.sh [option]"
  echo "Set the version in the pom files to match the name of the git branch, to avoid colliding with the main branch on which the current feature branch is based."
  echo "For example if the current version is 16.5.0-SNAPSHOT and the feature branch name is feature-deploy-jakarta then new version will be 16.5.0-feature-deploy-jakarta-SNAPSHOT."
  echo ""
  echo "Options:"
  echo "-h: Display this help."
  echo "-a: Replace the version in all pom files without going though Maven (much faster, but cannot be used if you don't want to change the parent for example)."
  echo "-v <current version>: Indicate the current version to replace, faster and less fragile than asking Maven... For example, it's a good workaround when Maven fail to find the current version because of some pom customization."
  echo ""
  echo "Example: xbranch-set-version.sh -av 16.5.0-SNAPSHOT"

  exit 0
fi

if [[ -z $CURRENT_VERSION ]]; then
  CURRENT_VERSION=$(mvn -N help:evaluate -Dexpression=project.version -q -DforceStdout)
fi
echo "Current version: $CURRENT_VERSION"
BASE_VERSION=${CURRENT_VERSION%%-*}
echo "Base version: $BASE_VERSION"
NEW_VERSION=$BASE_VERSION-$(git branch --show-current)-SNAPSHOT
echo "New version: $NEW_VERSION"
STANDARD_VERSION=$BASE_VERSION-SNAPSHOT
echo "Standard version: $STANDARD_VERSION"
REPOSITORY=$(basename -s .git `git config --get remote.origin.url`)
echo "Repository: $REPOSITORY"

GREEN='\033[0;32m'
if [ ${all} ] || [ $REPOSITORY == 'xwiki-commons' ]
then
  find . -type f -name 'pom.xml' | xargs sed -i "s/$STANDARD_VERSION/$NEW_VERSION/g"
  echo -e "${GREEN}Replaced version ${STANDARD_VERSION} by ${NEW_VERSION} in all pom files"
else
  mvn versions:update-parent -DallowSnapshots=true -DparentVersion=[${STANDARD_VERSION}],[${NEW_VERSION}] -DgenerateBackupPoms=false -N
  echo -e "${GREEN}Updated parent version ${STANDARD_VERSION} by ${NEW_VERSION} if it exist"

  mvn -f pom.xml versions:set -DnewVersion=${NEW_VERSION} -DallowSnapshots=true -DgenerateBackupPoms=false -Plegacy,integration-tests,snapshot,docker
  echo -e "${GREEN}Updated version ${STANDARD_VERSION} by ${NEW_VERSION}"

  sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${NEW_VERSION}<\/commons.version>/" -i pom.xml
  echo -e "${GREEN}Forced <commons.version> (if it exist) to ${NEW_VERSION}"

  if [[ $REPOSITORY == 'xwiki-platform' ]]
  then
    sed -e "s/<platform.version>.*<\/platform.version>/<platform.version>${NEW_VERSION}<\/platform.version>/" -i pom.xml
    echo -e "${GREEN}Force the <platform.version> property to ${NEW_VERSION}"
  fi
fi