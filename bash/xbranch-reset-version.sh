#!/bin/bash

if [ ! -d ".git" ]; then
  if [ ! -f ".git" ]; then
    >&2 echo "Should be executed at the root of the git workspace!"
    exit 1
  fi
fi

while getopts hv: flag
do
    case "${flag}" in
        h) help=true;;
        v) CURRENT_VERSION=${OPTARG};;
    esac
done

if [ $help ]
then
  echo "Usage: xbranch-reset-version.sh [option]"
  echo "Reset the version in the pom files to what is expected for main branch on which the current feature branch is based."
  echo "For example if the current version is 16.5.0-feature-deploy-jakarta-SNAPSHOT and the feature branch name is feature-deploy-jakarta then new reset version will be 16.5.0-SNAPSHOT."
  echo ""
  echo "Options:"
  echo "-h: Display this help."
  echo "-v <current version>: Indicate the current version to replace, faster and less fragile than asking Maven... For example, it's a good workaround when Maven fail to find the current version because of some pom customization."
  echo ""
  echo "Example: xbranch-reset-version.sh -av 16.5.0-feature-deploy-jakarta-SNAPSHOT"

  exit 0
fi

if [[ -z $CURRENT_VERSION ]]; then
  CURRENT_VERSION=$(mvn -N help:evaluate -Dexpression=project.version -q -DforceStdout)
fi
echo "Current version: $CURRENT_VERSION"
BASE_VERSION=${CURRENT_VERSION%%-*}
echo "Base version: $BASE_VERSION"
NEW_VERSION=$BASE_VERSION-SNAPSHOT
echo "New version: $NEW_VERSION"
REPOSITORY=$(basename -s .git `git config --get remote.origin.url`)
echo "Repository: $REPOSITORY"

GREEN='\033[0;32m'
find . -type f -name 'pom.xml' | xargs sed -i "s/$CURRENT_VERSION/$NEW_VERSION/g"
echo -e "${GREEN}Replaced version ${CURRENT_VERSION} by ${NEW_VERSION} in all pom files"

if [[ $REPOSITORY == 'xwiki-platform' ]]
then
  sed -e "s/<platform.version>.*<\/platform.version>/<platform.version>\${commons.version}<\/platform.version>/" -i pom.xml
  echo -e "${GREEN}Reseted the <platform.version> property to \${commons.version}"
fi
