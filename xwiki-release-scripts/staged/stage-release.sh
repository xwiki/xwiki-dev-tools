#!/bin/bash

# ---------------------------------------------------------------------------
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLIRR_EXCLUDES_LOCATION="${SCRIPT_DIR}/../clirr-excludes.xslt"
WORKING_DIR=`pwd`

# Perform environment checks: git username, GPG key, right directory.
function check_env() {
  echo -e "\033[0;32m* Checking environment\033[0m"

  # Check that the proper username/email is configured in the global git configuration
  RELEASER_EMAIL=`git config --global --get user.email`
  if [[ $RELEASER_EMAIL == 'build.noreply@xwiki.org' ]]
  then
    echo -e "\033[1;31mPlease install the right .gitconfig file, with your name configured in it\033[0m"
    exit -1
  fi

  # Check that a GPG key for the above email is installed
  if [[ -z `gpg --list-secret-keys | grep $RELEASER_EMAIL` ]]
  then
    echo -e "\033[1;31mYour GPG key is not installed. Please do that first.\033[0m"
    echo "On your local computer run:"
    echo "gpg --list-secret-keys"
    echo "Copy your key ID (the 8 characters long hexadecimal string on the \"sec\" line)"
    echo "gpg --export-secret-keys «keyID» > secret.key"
    echo "Copy the secret key file over to the agent machine"
    echo "On the agent machine, run"
    echo "gpg --import secret.key"
    echo "After the release you can remove the secret key from the agent by running"
    echo "gpg --delete-secret-and-public-keys «keyID»"
    exit -1
  else
    echo "Using key: `gpg --list-secret-keys ${RELEASER_EMAIL}`"
    GPG_KEY_ID=`gpg -K ${RELEASER_EMAIL} | head -1 | sed -n 's/^.*\([A-F0-9]\{8\}\).*/\1/p'`
    echo "Enter GPG key passphrase:"
    read -e -s -p "> " GPG_PASSPHRASE
  fi

  # Check that we're in the right directory
  if [[ ! -d xwiki-commons || ! -d xwiki-rendering || ! -d xwiki-platform || ! -d xwiki-rendering || ! -d xwiki-enterprise || ! -d xwiki-manager ]]
  then
    echo -e "\033[1;31mPlease go to the xwiki-trunks directory where the XWiki sources are checked out\033[0m"
    exit -1
  fi
}

# Check that the VERSION variable is defined, and if not, ask for its value
function check_version() {
  if [[ -z $VERSION ]]
  then
    echo -e "Which version are you releasing?\033[0;32m"
    read -e -p "> " VERSION
    echo -n -e "\033[0m"
    export VERSION=$VERSION
  fi
}

# Clean up the sources, discarding any changes in the local workspace not found in the local git clone and switching back to the master branch.
function pre_cleanup() {
  echo -e "\033[0;32m* Cleaning up\033[0m"
  git reset --hard
  git checkout master
  git reset --hard
  git clean -dxf
}

# Fetch sources to synchronize the local git clone with the upstream repository.
function update_sources() {
  echo -e "\033[0;32m* Fetching latest sources\033[0m"
  git pull
  git clean -dxf
}

# Offer to create a stable branch and move the master to the next version.
# After the switch to the new version, also update the root module parent version and the value for the commons.version property, if any.
function stabilize_branch() {
  echo "Do you want to create the stable branch and move trunk to the next version?"
  unset CONFIRM
  read -e -p "[Y|n]> " CONFIRM
  if [[ $CONFIRM != 'n' ]]
  then
    let NEXT_TRUNK_VERSION=`echo ${VERSION_STUB} | cut -d. -f2`+1
    NEXT_TRUNK_VERSION=`echo ${VERSION_STUB} | cut -d. -f1`.${NEXT_TRUNK_VERSION}-SNAPSHOT
    echo "What is the next master version?"
    read -e -p "${NEXT_TRUNK_VERSION}> " tmp
    if [[ $tmp ]]
    then
      NEXT_TRUNK_VERSION=${tmp}
    fi
    # Let maven update the version for all the submodules
    mvn release:branch -DbranchName=stable-${VERSION_STUB}.x -DautoVersionSubmodules -DdevelopmentVersion=${NEXT_TRUNK_VERSION} -Pci,hsqldb,mysql,pgsql,derby,jetty,glassfish,integration-tests,legacy
    git pull
    # We must update the root parent and commons.version manually
    mvn versions:update-parent -DgenerateBackupPoms=false -DparentVersion=[$NEXT_TRUNK_VERSION] -N
    sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${NEXT_TRUNK_VERSION}<\/commons.version>/" -i pom.xml
    git add pom.xml
    git commit -m "[branch] Updating inter-project dependencies on master"
    CURRENT_VERSION=`echo $NEXT_TRUNK_VERSION | cut -d- -f1`
    RELEASE_FROM_BRANCH=stable-${VERSION_STUB}.x
  fi
}

# Check which branch should be the basis for the release.
# - If the released version corresponds to the master, then use master.
# - If the released version is a -rc-1 version and we're releasing from master, then offer to create a stable branch and move the master to the next version.
# - If the released version doesn't have an associated stable branch, then stop the process, since there's no valid source branch to release from.
# In the end, a variable called RELEASE_FROM_BRANCH will hold the name of the source branch to start the release from (master or stable-X.Y).
function check_branch() {
  CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
  VERSION_STUB=`echo $VERSION | cut -c1-3`

  if [ "${RELEASE_FROM_BRANCH}" == "" ]; then
    RELEASE_FROM_BRANCH=master
  fi
  if [[ $CURRENT_VERSION == $VERSION_STUB ]]
  then
    if [[ `echo $VERSION | grep 'rc-1'` ]]
    then
      stabilize_branch
    fi
  else
    RELEASE_FROM_BRANCH=stable-${VERSION_STUB}.x
    if [[ -z `git branch -r | grep ${RELEASE_FROM_BRANCH}` ]]
    then
      echo -e "\033[1;31mThe release must be performed from the ${RELEASE_FROM_BRANCH} branch, but it doesn't seem to exist yet.\033[0m"
      exit -2
    fi
  fi

  echo
  echo -e "\033[0;32mReleasing version \033[1;32m${VERSION}\033[0;32m from branch \033[1;32m${RELEASE_FROM_BRANCH}\033[0m"
  echo
}

# Create a temporary branch to be used for the release, starting from the branch detected by check_branch() and set in the RELEASE_FROM_BRANCH variable.
function create_release_branch() {
  echo -e "\033[0;32m* Creating release branch\033[0m"
  git branch --no-track release-${VERSION} origin/${RELEASE_FROM_BRANCH} || exit -2
  git checkout release-${VERSION}
  CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
}

# Update the root project's parent version and version variables, if needed.
# For xwiki-commons updates the value for the commons.version variable.
# For the other projects it changes the version of the parent in the current repository root pom.
# The changes will be committed as a new git version.
function update_parent_versions() {
  echo -e "\033[0;32m* Preparing project for release\033[0m"
  mvn versions:update-parent -DgenerateBackupPoms=false -DparentVersion=[$VERSION] -N
  sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${VERSION}<\/commons.version>/" -i pom.xml
  PROJECT_NAME=`mvn help:evaluate -Dexpression='project.artifactId' -N | grep -v '\[' | grep -v 'Download'`
  TAG_NAME=${PROJECT_NAME}-${VERSION}

  git add pom.xml
  git commit -m "[release] Preparing release ${TAG_NAME}"
}

# Perform the actual maven release.
# Invoke mvn release:prepare, followed by mvn release:perform, then create a GPG-signed git tag.
function release_maven() {
  TEST_SKIP=""
  DB_PROFILE=hsqldb
  if [[ $PROJECT_NAME == 'xwiki-manager' ]]
  then
    DB_PROFILE=mysql
    TEST_SKIP=-DskipTests
  elif [[ $PROJECT_NAME == 'xwiki-enterprise' ]]
  then
    TEST_SKIP=-DskipTests
  fi

  TEST_SKIP=-DskipTests

  echo -e "\033[0;32m* release:prepare\033[0m"
  mvn release:prepare -DpushChanges=false -DlocalCheckout=true -DreleaseVersion=${VERSION} -DdevelopmentVersion=${CURRENT_VERSION} -Dtag=${TAG_NAME} -DautoVersionSubmodules=true -Phsqldb,mysql,pgsql,derby,jetty,glassfish,legacy,integration-tests,ci -Darguments="-N ${TEST_SKIP}" ${TEST_SKIP} || exit -2

  echo -e "\033[0;32m* release:stage\033[0m"
  mvn release:stage -DstagingRepository=nexus.xwiki.org::default::http://nexus.xwiki.org/nexus/service/local/staging/deploy/maven2 -DpushChanges=false -DlocalCheckout=true -P${DB_PROFILE},jetty,legacy,integration-tests,ci ${TEST_SKIP} -Darguments="-P${DB_PROFILE},jetty,legacy,integration-tests ${TEST_SKIP} -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.name=${GPG_KEY_ID}" -Dgpg.passphrase=${GPG_PASSPHRASE} -Dgpg.name=${GPG_KEY_ID} || exit -2
  #mvn release:perform -DpushChanges=false -DlocalCheckout=true -P${DB_PROFILE},jetty,legacy,integration-tests,ci ${TEST_SKIP} -Darguments="-P${DB_PROFILE},jetty,legacy,integration-tests ${TEST_SKIP} -Dgpg.passphrase=${GPG_PASSPHRASE}" -Dgpg.passphrase=${GPG_PASSPHRASE} || exit -2

  echo -e "\033[0;32m* Creating GPG-signed tag\033[0m"
  git checkout ${TAG_NAME}
  git tag -u ${GPG_KEY_ID} -f -m "Tagging ${TAG_NAME}" ${TAG_NAME}
}

# Generate a clirr report. Requires xsltproc to work properly.
function clirr_report() {
  echo -e "\033[0;32m* Generating clirr report\033[0m"
  # Process the pom, so that all the specified excludes following the "to be removed after x.y is released" comment are removed.
  xsltproc -o pom.xml ${CLIRR_EXCLUDES_LOCATION} pom.xml
  # Excludes are also specified in two other poms for xwiki-commons and xwiki-platform
  if [[ -f xwiki-commons-core/pom.xml ]]
  then
    xsltproc -o xwiki-commons-core/pom.xml ${CLIRR_EXCLUDES_LOCATION} xwiki-commons-core/pom.xml
  elif [[ -f xwiki-platform-core/pom.xml ]]
  then
    xsltproc -o xwiki-platform-core/pom.xml ${CLIRR_EXCLUDES_LOCATION} xwiki-platform-core/pom.xml
  fi
  # Run clirr
  mvn clirr:check -DfailOnError=false -DtextOutputFile=clirr-result.txt -Pintegration-tests -DskipTests -Plegacy
  # Aggregate results in one file
  find . -name clirr-result.txt | xargs cat | grep ERROR >> ${WORKING_DIR}/clirr.txt ; sed -r -e 's/ERROR: [0-9]+: //g' -e 's/\s+$//g' -i ${WORKING_DIR}/clirr.txt
}

# Cleanup sources again, after the release.
function post_cleanup() {
  echo -e "\033[0;32m* Cleanup\033[0m"
  git reset --hard
  git checkout master
  # Delete the release branch
  git branch -D release-${VERSION}
  git reset --hard
  git clean -dxf
}

# Push the signed tag to the upstream repository.
function push_tag() {
  echo -e "\033[0;32m* Pushing tag\033[0m"
  git push --tags
}

# get the sha1sums of the distributed files.
# @param name of the project.
function get_hashes() {
  if [[ $1 == 'xwiki-enterprise' ]]; then
    find ./ -name "xwiki-enterprise-installer-generic-${VERSION}-standard.jar" -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name "xwiki-enterprise-installer-windows-${VERSION}.exe" -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name "xwiki-enterprise-jetty-hsqldb-${VERSION}.zip" -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name "xwiki-enterprise-web-${VERSION}.war" -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name 'xwiki-enterprise-ui-all.xar' -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name '*.deb' -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
  elif [[ $1 == 'xwiki-manager' ]]; then
    find ./ -name '*.war' -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name '*.xar' -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
    find ./ -name '*.zip' -exec sha1sum {} \; >> ${WORKING_DIR}/hashes.txt
  fi
}

# Wrapper function that calls all the other release steps, for one project only.
# The first (mandatory) parameter is the name of the subdirectory where the project sources are (xwiki-commons, xwiki-enterprise, etc).
function release_project() {
  cd $1
  pre_cleanup
  update_sources
  check_branch
  create_release_branch
  update_parent_versions
  release_maven
  clirr_report
  get_hashes ${PROJECT_NAME}
#  post_cleanup
#  push_tag
  cd ..
}

# Wrapper function that calls release_project for each XWiki project in order: commons, rendering, platform, enterprise, manager.
# This is the main function that is called when running the script.
function release_all() {
  check_env
  check_version
  echo              "*****************************"
  echo -e "\033[1;32m    Releasing xwiki-commons\033[0m"
  echo              "*****************************"
  release_project xwiki-commons
  echo              "*****************************"
  echo -e "\033[1;32m    Releasing xwiki-rendering\033[0m"
  echo              "*****************************"
  release_project xwiki-rendering
  echo              "*****************************"
  echo -e "\033[1;32m    Releasing xwiki-platform\033[0m"
  echo              "*****************************"
  release_project xwiki-platform
  echo              "*****************************"
  echo -e "\033[1;32m    Releasing xwiki-enterprise\033[0m"
  echo              "*****************************"
  release_project xwiki-enterprise
  echo              "*****************************"
  echo -e "\033[1;32m    Releasing xwiki-manager\033[0m"
  echo              "*****************************"
  release_project xwiki-manager
  echo -e "\033[1;32mAll done!\033[0m"
}

# Display a help message describing this script.
function display_help() {
  echo "XWiki Release script - Part 1"
  echo ""
  echo "This script performs the technical release:"
  echo "* Create a release branch"
  echo "* Update the root project's parent version and the commons.version variable, if needed"
  echo "* Invoke the maven release process (mvn release:prepare and mvn release:perform)"
  echo "* Generate a clirr report"
  echo "* Create GPG-signed tags and push them to the upstream repository"
  echo "* [Optional] Branch the current master into a stable release and update the master to the next version"
  echo ""
  echo "Prerequisite steps:"
  echo "* Configure a proper global .giconfig file holding the release manager's username/email address"
  echo "* Setup a GPG signing key corresponding to the email address above"
  echo "* Change to the xwiki-trunks directory, where the xwiki-commons, xwiki-rendering, xwiki-platform, xwiki-enterprise and xwiki-manager have been checked out"
  echo "* [Optional] Export a VERSION shell variable holding the name of the version being released, in the X.Y-milestone-Z format"
  echo "The release script will check and refuse to proceed if these steps haven't been performed."
}

# Main code that gets executed. Invoke either display_help or release_all.
if [[ $1 == '--help' || $1 == '-h' ]]
then
  display_help
  exit -1
elif  [[ $1 != '' ]]; then
  if [[ $2 == 'clirr' ]]; then
    cd $1
    clirr_report
    cd ..
  elif [[ $2 == 'hashes' ]]; then
    cd $1
    get_hashes $1
    cd ..
  else
    check_env
    check_version
    release_project $1
  fi
else
  release_all
fi
