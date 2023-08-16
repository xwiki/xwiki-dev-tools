#!/bin/bash

CURRENT_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Current version: $CURRENT_VERSION"
BASE_VERSION=${CURRENT_VERSION%%-*}
echo "Base version: $BASE_VERSION"
NEW_VERSION=$BASE_VERSION-$(git branch --show-current)-SNAPSHOT
echo "New version: $NEW_VERSION"
STANDARD_VERSION=$BASE_VERSION-SNAPSHOT
echo "Standard version: $STANDARD_VERSION"

mvn -f pom.xml versions:set -DnewVersion=${NEW_VERSION} -DallowSnapshots=true -DgenerateBackupPoms=false -Plegacy,integration-tests,snapshot,docker
mvn versions:update-parent -DallowSnapshots=true -DparentVersion=[${STANDARD_VERSION}],[${NEW_VERSION}] -DgenerateBackupPoms=false -N
sed -e  "s/<commons.version>.*<\/commons.version>/<commons.version>${NEW_VERSION}<\/commons.version>/" -i pom.xml || true
