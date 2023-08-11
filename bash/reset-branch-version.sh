#!/bin/bash

CURRENT_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Current version: $CURRENT_VERSION"
BASE_VERSION=${CURRENT_VERSION%%-*}
echo "Base version: $BASE_VERSION"
BRANCH_VERSION=$BASE_VERSION-SNAPSHOT
echo "Branch version: $BRANCH_VERSION"

mvn -f pom.xml versions:set -DnewVersion=${BRANCH_VERSION} -DallowSnapshots=true -DgenerateBackupPoms=false -Plegacy,integration-tests,snapshot,docker
mvn versions:update-parent -DallowSnapshots=true -DparentVersion=15.7-feature-deploy-jakarta-SNAPSHOT -DgenerateBackupPoms=false -N
