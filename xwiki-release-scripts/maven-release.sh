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

# Initialize common variables
function init() {
  echo -e "\033[0;32m* Initialization\033[0m"
  PRG="$0"
  while [ -h "$PRG" ]; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
      PRG="$link"
    else
      PRG=`dirname "$PRG"`/"$link"
    fi
  done
  PRGDIR=`dirname "$PRG"`
}

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
    echo "Enter GPG key passphrase:"
    read -e -s -p "> " GPG_PASSPHRASE
  fi

  # Check that we're in the right directory
  if [[ ! -d xwiki-commons || ! -d xwiki-rendering || ! -d xwiki-platform || ! -d xwiki-enterprise ]]
  then
    echo -e "\033[1;31mPlease go to the xwiki-trunks directory where the XWiki sources are checked out\033[0m"
    exit -1
  fi

  # Restart gpg-agent
  echo -e "\033[0;32m* Setup gpg-agent\033[0m"
  killall gpg-agent || true
  eval $(gpg-agent --daemon) || true
  export GPG_TTY=$(tty)
}

function clean_env() {
  # Stop gpg-agent
  echo -e "\033[0;32m* Stop gpg-agent\033[0m"
  killall gpg-agent || true
}

# Check various version related variables
function check_versions() {
  # Check version to release
  if [[ -z $VERSION ]]
  then
    echo -e "Which version are you releasing?\033[0;32m"
    read -e -p "> " VERSION
    echo -n -e "\033[0m"
    export VERSION=$VERSION
  fi

  # Set the name of the release branch
  export RELEASE_BRANCH=release-${VERSION}

  # Check next SNAPSHOT version
  if [[ -z $NEXT_SNAPSHOT_VERSION ]]
  then
    VERSION_STUB=`echo $VERSION | cut -c1-3`
    let NEXT_SNAPSHOT_VERSION=`echo ${VERSION_STUB} | cut -d. -f2`+1
    NEXT_SNAPSHOT_VERSION=`echo ${VERSION_STUB} | cut -d. -f1`.${NEXT_SNAPSHOT_VERSION}-SNAPSHOT
    echo "What is the next SNAPSHOT version?"
    read -e -p "${NEXT_SNAPSHOT_VERSION}> " tmp
    if [[ $tmp ]]
    then
      NEXT_SNAPSHOT_VERSION=${tmp}
    fi
    export NEXT_SNAPSHOT_VERSION=$NEXT_SNAPSHOT_VERSION
  fi
}

# Clean up the sources, discarding any changes in the local workspace not found in the local git clone and switching back to the master branch.
function pre_cleanup() {
  echo -e "\033[0;32m* Cleaning up\033[0m"
  git reset --hard -q
  git co master -q
  git reset --hard -q
  git clean -dxfq
}

# Fetch sources to synchronize the local git clone with the upstream repository.
function update_sources() {
  echo -e "\033[0;32m* Fetching latest sources\033[0m"
  git pull --rebase -q
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
    mvn release:branch -DbranchName=stable-${VERSION_STUB}.x -DautoVersionSubmodules -DdevelopmentVersion=${NEXT_TRUNK_VERSION} -Pci,hsqldb,mysql,pgsql,derby,jetty,glassfish,integration-tests,office-tests,legacy,standalone
    git up
    # We must update the root parent and commons.version manually
    mvn versions:update-parent -DgenerateBackupPoms=false -DparentVersion=[$NEXT_TRUNK_VERSION] -N -q
    sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${NEXT_TRUNK_VERSION}<\/commons.version>/" -i pom.xml
    git add pom.xml
    git ci -m "[branch] Updating inter-project dependencies on master" -q
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

  RELEASE_FROM_BRANCH=master
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
  git branch ${RELEASE_BRANCH} origin/${RELEASE_FROM_BRANCH} || exit -2
  git co ${RELEASE_BRANCH} -q
  CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
}

# Update the root project's parent version and version variables, if needed.
# For xwiki-commons updates the value for the commons.version variable.
# For the other projects it changes the version of the parent in the current repository root pom.
# The changes will be committed as a new git version.
function pre_update_parent_versions() {
  echo -e "\033[0;32m* Preparing project for release\033[0m"
  mvn versions:update-parent -DgenerateBackupPoms=false -DparentVersion=[$VERSION] -N -q
  sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${VERSION}<\/commons.version>/" -i pom.xml
  PROJECT_NAME=`mvn help:evaluate -Dexpression='project.artifactId' -N | grep -v '\[' | grep -v 'Download'`
  TAG_NAME=${PROJECT_NAME}-${VERSION}

  git add pom.xml
  git ci -m "[release] Preparing release ${TAG_NAME}" -q
}

# Perform the actual maven release.
# Invoke mvn release:prepare, followed by mvn release:perform, then create a GPG-signed git tag.
function release_maven() {
  TEST_SKIP="-DskipTests"
  DB_PROFILE=hsqldb

  echo -e "\033[0;32m* release:prepare\033[0m"
  mvn release:prepare -DpushChanges=false -DlocalCheckout=true -DreleaseVersion=${VERSION} -DdevelopmentVersion=${NEXT_SNAPSHOT_VERSION} -Dtag=${TAG_NAME} -DautoVersionSubmodules=true -Phsqldb,mysql,pgsql,derby,jetty,glassfish,legacy,integration-tests,office-tests,standalone -Darguments="-N ${TEST_SKIP}" ${TEST_SKIP} || exit -2

  echo -e "\033[0;32m* release:perform\033[0m"
  mvn release:perform -DpushChanges=false -DlocalCheckout=true -P${DB_PROFILE},jetty,legacy,integration-tests,office-tests,standalone ${TEST_SKIP} -Darguments="-P${DB_PROFILE},jetty,legacy,integration-tests,office-tests ${TEST_SKIP} -Dgpg.passphrase='${GPG_PASSPHRASE}' -Dxwiki.checkstyle.skip=true" -Dgpg.passphrase="${GPG_PASSPHRASE}" || exit -2

  echo -e "\033[0;32m* Creating GPG-signed tag\033[0m"
  git co ${TAG_NAME} -q
  git tag -s -f -m "Tagging ${TAG_NAME}" ${TAG_NAME}
}

# Update the root project's parent version and version variables, if needed.
# For xwiki-commons updates the value for the commons.version variable.
# For the other projects it changes the version of the parent in the current repository root pom.
# The changes will be committed as a new git version.
function post_update_parent_versions() {
  echo -e "\033[0;32m* Go back to branch ${RELEASE_BRANCH}\033[0m"
  git co ${RELEASE_BRANCH}

  echo -e "\033[0;32m* Update parent to ${NEXT_SNAPSHOT_VERSION} after release\033[0m"
  xsltproc -o pom.xml --stringparam parentversion "${NEXT_SNAPSHOT_VERSION}" $PRGDIR/clirr-excludes.xslt pom.xml
  echo -e "\033[0;32m* Update commons.version to ${NEXT_SNAPSHOT_VERSION} after release\033[0m"
  sed -e "s/<commons.version>${VERSION}<\/commons.version>/<commons.version>${NEXT_SNAPSHOT_VERSION}<\/commons.version>/" -i pom.xml

  git add pom.xml
  git ci -m "[release] Update parent after release ${TAG_NAME}" -q
}

# Push changes made to the release branch (new SNAPSHOT version, etc)
function push_release() {
  echo -e "\033[0;32m* Switch to release base branch\033[0m"
  git co ${RELEASE_FROM_BRANCH}
  echo -e "\033[0;32m* Merge release branch\033[0m"
  git merge ${RELEASE_BRANCH}
  echo -e "\033[0;32m* Push release base branch\033[0m"
  git push origin ${RELEASE_FROM_BRANCH}
}

# Generate a clirr report. Requires xsltproc to work properly.
function clirr_report() {
  echo -e "\033[0;32m* Generating clirr report\033[0m"
  # Process the pom, so that all the specified excludes following the "to be removed after x.y is released" comment are removed.
  xsltproc -o pom.xml $PRGDIR/clirr-excludes.xslt pom.xml
  # Excludes are also specified in two other poms for xwiki-commons and xwiki-platform
  if [[ -f xwiki-commons-core/pom.xml ]]
  then
    xsltproc -o xwiki-commons-core/pom.xml $PRGDIR/clirr-excludes.xslt xwiki-commons-core/pom.xml
  elif [[ -f xwiki-platform-core/pom.xml ]]
  then
    xsltproc -o xwiki-platform-core/pom.xml $PRGDIR/clirr-excludes.xslt xwiki-platform-core/pom.xml
  fi
  # Run clirr
  mvn clirr:check -DfailOnError=false -DtextOutputFile=clirr-result.txt -Plegacy,integration-tests,office-tests -DskipTests -q 1>/dev/null
  # Aggregate results in one file
  find . -name clirr-result.txt | xargs cat | grep ERROR > clirr.txt ; sed -r -e 's/ERROR: [0-9]+: //g' -e 's/\s+$//g' -i clirr.txt
}

# Cleanup sources again, after the release.
function post_cleanup() {
  echo -e "\033[0;32m* Cleanup\033[0m"
  # Temporarily move the clirr report to a different place, so that we can safely clean up the whole source tree
## TODO: put back when fixed
#  mv clirr.txt /tmp/clirr.txt
  git reset --hard -q
  git co master -q
  # Delete the release branch
  git branch -D ${RELEASE_BRANCH}
  git reset --hard -q
  git clean -dxfq
  # Move back the clirr report
## TODO: put back when fixed
#   mv /tmp/clirr.txt clirr.txt
}

# Push the signed tag to the upstream repository.
function push_tag() {
  echo -e "\033[0;32m* Pushing tag\033[0m"
  git push --tags
}

# Wrapper function that calls all the other release steps, for one project only.
# The first (mandatory) parameter is the name of the subdirectory where the project sources are (xwiki-commons, xwiki-enterprise, etc).
function release_project() {
  cd $1
  pre_cleanup
  update_sources
  check_branch
  create_release_branch
  pre_update_parent_versions
  release_maven
  post_update_parent_versions
  push_release
## TODO: put back when fixed
#  clirr_report
  post_cleanup
  push_tag
  cd ..
}

# Wrapper function that calls release_project for each XWiki project in order: commons, rendering, platform, enterprise.
# This is the main function that is called when running the script.
function release_all() {
  init
  check_env
  check_versions
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
  echo -e "\033[1;32mAll done!\033[0m"
  clean_env
}

# Display a help message describing this script.
function display_help() {
  echo "XWiki Release script - Part 1"
  echo ""
  echo "This script performs the technical release:"
  echo "* Create a release branch"
  echo "* Update the root project's parent version and the commons.version variable, if needed"
  echo "* Invoke the maven release process (mvn release:prepare and mvn release:perform)"
## TODO: put back when fixed
#  echo "* Generate a clirr report"
  echo "* Create GPG-signed tags and push them to the upstream repository"
  echo "* [Optional] Branch the current master into a stable release and update the master to the next version"
  echo ""
  echo "Prerequisite steps:"
  echo "* Configure a proper global .giconfig file holding the release manager's username/email address"
  echo "* Setup a GPG signing key corresponding to the email address above"
  echo "* Change to the xwiki-trunks directory, where the xwiki-commons, xwiki-rendering, xwiki-platform and xwiki-enterprise have been checked out"
  echo "* [Optional] Export a VERSION shell variable holding the name of the version being released, in the X.Y-milestone-Z format"
  echo "The release script will check and refuse to proceed if these steps haven't been performed."
}

# Main code that gets executed. Invoke either display_help or release_all.
if [[ $1 == '--help' || $1 == '-h' ]]
then
  display_help
  exit -1
else
  release_all
fi
