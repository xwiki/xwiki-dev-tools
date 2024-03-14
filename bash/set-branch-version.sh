#!/bin/bash

if [ ! -d ".git" ]; then
  if [ ! -f ".git" ]; then
    >&2 echo "Should be executed at the root of the git workspace!"
    exit 1
  fi
fi

CURRENT_VERSION=$(mvn -N help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Current version: $CURRENT_VERSION"
BASE_VERSION=${CURRENT_VERSION%%-*}
echo "Base version: $BASE_VERSION"
NEW_VERSION=$BASE_VERSION-$(git branch --show-current)-SNAPSHOT
echo "New version: $NEW_VERSION"
STANDARD_VERSION=$BASE_VERSION-SNAPSHOT
echo "Standard version: $STANDARD_VERSION"
REPOSITORY=$(basename -s .git `git config --get remote.origin.url`)
echo "Repository: $REPOSITORY"

mvn versions:update-parent -DallowSnapshots=true -DparentVersion=[${STANDARD_VERSION}],[${NEW_VERSION}] -DgenerateBackupPoms=false -N
mvn -f pom.xml versions:set -DnewVersion=${NEW_VERSION} -DallowSnapshots=true -DgenerateBackupPoms=false -Plegacy,integration-tests,snapshot,docker
sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${NEW_VERSION}<\/commons.version>/" -i pom.xml

if [[ $REPOSITORY == 'xwiki-platform' ]]
then
  sed -e "s/<platform.version>.*<\/platform.version>/<platform.version>${NEW_VERSION}<\/platform.version>/" -i pom.xml
fi
