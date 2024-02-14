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
NEW_VERSION=$BASE_VERSION-SNAPSHOT
echo "New version: $NEW_VERSION"

find . -type f -name 'pom.xml' | xargs sed -i "s/$CURRENT_VERSION/$NEW_VERSION/g"