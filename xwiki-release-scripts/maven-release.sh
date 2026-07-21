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

  # Check that we're in the right directory
  if [[ ! -d xwiki-commons || ! -d xwiki-rendering || ! -d xwiki-platform ]]
  then
    echo -e "\033[1;31mPlease go to the xwiki-trunks directory where the XWiki sources are checked out\033[0m"
    exit -1
  fi

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
    # Restart gpg-agent
    echo -e "\033[0;32m* Setup gpg-agent\033[0m"
    killall gpg-agent || true
    eval $(gpg-agent --daemon) || true
    export GPG_TTY=$(tty)

    # Test GPG passphrase
    echo "Test GPG passphrase" | gpg -o /dev/null -as - || exit
  fi
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

  if ! [[ $VERSION =~ [0-9]+.[0-9]+.[0-9]+(-rc-[0-9])?$ ]]
  then
    echo -e "The version $VERSION is wrong. Format must be <major>.<minor>.<bugfix>[-rc-<rc number>]"
    exit -1
  fi

  if [[ $do_release == 'true' ]]
  then
    # Set the name of the release branch
    export RELEASE_BRANCH=release-${VERSION}

    # Check next SNAPSHOT version
    if [[ -z $NEXT_SNAPSHOT_VERSION ]]
    then
      # Resolve the next SNAPSHOT suggestion
      ISRC=`echo ${VERSION} | cut -d- -f2`
      if [[ $ISRC == 'rc' ]]
      then
        # It's a RC version so we keep the same SNAPSHOT
        # Extract the base version
        BASE_VERSION=`echo ${VERSION} | cut -d- -f1`
        # Append the -SNAPSHOT suffix
        NEXT_SNAPSHOT_VERSION=${BASE_VERSION}-SNAPSHOT
      else
        # It's a final version so we need to increment the minor part
        # Extract the 3rd part of the version and increment it
        let NEXT_SNAPSHOT_VERSION=`echo ${VERSION} | cut -d- -f1 | cut -d. -f3`+1
        # Extract the first 2 parts of the version and append the incremented 3rd part and the -SNAPSHOT suffix
        NEXT_SNAPSHOT_VERSION=`echo ${VERSION} | cut -d. -f1-2`.${NEXT_SNAPSHOT_VERSION}-SNAPSHOT
      fi
      echo "What is the next SNAPSHOT version in release branch?"
      read -e -p "${NEXT_SNAPSHOT_VERSION}> " tmp
      if [[ $tmp ]]
      then
        NEXT_SNAPSHOT_VERSION=${tmp}
      fi
      export NEXT_SNAPSHOT_VERSION=$NEXT_SNAPSHOT_VERSION
    fi

    # Select the JDK version to use
    if [[ -z $RELEASE_JDK_VERSION ]]
    then
      # Get the major part of the version being released
      let VERSION_MAJOR=`echo ${VERSION} | cut -d- -f1 | cut -d. -f1`
      # XWiki 16+ requires Java 17
      if (($VERSION_MAJOR < 16))
      then
        RELEASE_JDK_VERSION=11
      # XWiki 18+ requires Java 21
      elif (($VERSION_MAJOR < 18))
      then
        RELEASE_JDK_VERSION=17
      else
        RELEASE_JDK_VERSION=21
      fi
      echo "What is the version of Java to use to release XWiki ${VERSION}?"
      read -e -p "${RELEASE_JDK_VERSION}> " tmp
      if [[ $tmp ]]
      then
        RELEASE_JDK_VERSION=${tmp}
      fi
      export RELEASE_JDK_VERSION=$RELEASE_JDK_VERSION
    fi
    # Set the selected Java version
    export JAVA_HOME=${HOME}/java$RELEASE_JDK_VERSION
    export PATH=$JAVA_HOME/bin:$PATH
  fi
}

function set_packages_version() {
  if [ -z "$1" ]; then
      echo "Missing version parameter" >&2
      exit 1
  fi
  
  version="$1"
  current_directory=$PWD

  find "$current_directory" -type d -name "node_modules" -prune -o -name "package.json" -print | \
  grep -v "^$current_directory/package.json$" | \
  while IFS= read -r pkg_path; do
      
      ## private or unnamed packages are skipped
      is_skipped=$(jq -r '.private' "$pkg_path")
      
      if [ "$is_skipped" = "true" ]; then
          continue
      fi
  
      # Create a temporary file in case of issue during the version patch
      temp_file=$(mktemp)
      
      # Update the version with jq on the temp file, and replace the original file with the patch version if no
      # problem was encountered.
      if ! jq ".version = \"$version\"" "$pkg_path" > "$temp_file"; then
          relative_pkg_path=$(realpath --relative-to="$current_directory" "$pkg_path")
          echo "Failed to update $relative_pkg_path: jq error" >&2
          rm -f "$temp_file"
          continue
      fi
  
      mv "$temp_file" "$pkg_path"
  done
}

# Clean up the sources, discarding any changes in the local workspace not found in the local git clone and switching back to the master branch.
function pre_cleanup() {
  echo -e "\033[0;32m* Cleaning up\033[0m"
  git reset --hard -q
  git checkout master -q
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
  if [[ -z $CREATE_STABLE_BRANCH ]]
  then
    echo "Do you want to create the stable branch and move trunk to the next version?"
    unset CONFIRM
    read -e -p "[Y|n]> " CONFIRM
    if [[ $CONFIRM != 'n' ]]
    then
      export CREATE_STABLE_BRANCH=true
    fi
  else
    echo "Creating the stable branch and moving trunk to the next version"
  fi
  if [[ ! -z $CREATE_STABLE_BRANCH ]]
  then
    if [[ -z $NEXT_TRUNK_VERSION ]]
    then
      # Extract the 2nd part of the version and increment it
      let NEXT_TRUNK_VERSION=`echo ${VERSION} | cut -d. -f2`+1
      # Check if we should start a new cycle or not
      if (($NEXT_TRUNK_VERSION > 10))
      then
        # New cycle
        # Extract the 1rst part of the version and increment it
        let NEXT_TRUNK_VERSION=`echo ${VERSION} | cut -d. -f1`+1
        # Append .0.0-SNAPSHOT suffix to the incremented 1st part of the version
        NEXT_TRUNK_VERSION=${NEXT_TRUNK_VERSION}.0.0-SNAPSHOT
      else
        # Same cycle
        # Extract the 1st part of the version and append the incremented 2nd part and the .0-SNAPSHOT suffix
        NEXT_TRUNK_VERSION=`echo ${VERSION} | cut -d. -f1`.${NEXT_TRUNK_VERSION}.0-SNAPSHOT
      fi
      echo "What is the next version in master branch?"
      read -e -p "${NEXT_TRUNK_VERSION}> " tmp
      if [[ $tmp ]]
      then
        NEXT_TRUNK_VERSION=${tmp}
      fi

      # Remember the next trunk version for the next time
      export NEXT_TRUNK_VERSION=$NEXT_TRUNK_VERSION
    else
      echo "Using the next version in master branch: $NEXT_TRUNK_VERSION"
    fi
    # Let maven update the version for all the submodules
    mvn -e release:branch -DbranchName=$STABLE_BRANCH -DautoVersionSubmodules -DdevelopmentVersion=${NEXT_TRUNK_VERSION} -DpushChanges=false -Pci,integration-tests,legacy,standalone,flavor-integration-tests,distribution,docker
    git pull --rebase
    ## We must update the node packages version manually to the next development version.
    set_packages_version $NEXT_TRUNK_VERSION
    git add '**/package.json'
    # We must update the root parent manually
    # Using versions:update-parent here is not safe because this version of the parent pom might not exist yet
    # mvn versions:update-parent -DgenerateBackupPoms=false -DparentVersion=[$NEXT_TRUNK_VERSION] -DallowSnapshots=true -N -q
    xmlstarlet ed -P --inplace -N m="http://maven.apache.org/POM/4.0.0" -u "/m:project/m:parent/m:version" -v "${NEXT_TRUNK_VERSION}" pom.xml
    # We must update commons.version manually
    sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${NEXT_TRUNK_VERSION}<\/commons.version>/" -i pom.xml
    git add pom.xml
    git commit -m "[branch] prepare for next development iteration (custom)" -q
    git push origin master
    git push origin $STABLE_BRANCH
    CURRENT_VERSION=`echo $NEXT_TRUNK_VERSION | cut -d- -f1`
  fi
}

# Compute the name of the stable branch the release starts from (stable-X.Y.x), setting
# VERSION_STUB, STABLE_BRANCH and RELEASE_FROM_BRANCH from the version being released.
# Shared by check_branch() (normal flow) and resume_project_after_publish() (resume flow).
function compute_release_source_branch() {
  VERSION_STUB=`echo $VERSION | cut -d. -f1-2`
  STABLE_BRANCH=stable-${VERSION_STUB}.x
  RELEASE_FROM_BRANCH=$STABLE_BRANCH
}

# Check which branch should be the basis for the release.
# Make sure the stable branch corresponding to the release version exist and create it if it does not
# In the end, a variable called RELEASE_FROM_BRANCH will hold the name of the source branch to start the release from (stable-X.Y).
function check_branch() {
  CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
  compute_release_source_branch
  # Offer to create the stable branch if it doesn't exist
  if [[ -z `git branch -r | grep $STABLE_BRANCH` ]]
  then
      stabilize_branch
  fi

  if [[ $do_release == 'true' ]]
  then
    echo
    echo -e "\033[0;32mReleasing version \033[1;32m${VERSION}\033[0;32m from branch \033[1;32m${RELEASE_FROM_BRANCH}\033[0m"
    echo
  fi
}

# Create a temporary branch to be used for the release, starting from the branch detected by check_branch() and set in the RELEASE_FROM_BRANCH variable.
function create_release_branch() {
  echo -e "\033[0;32m* Creating release branch\033[0m"
  git branch ${RELEASE_BRANCH} origin/${RELEASE_FROM_BRANCH} || exit -2
  git checkout ${RELEASE_BRANCH} -q
  CURRENT_VERSION=`mvn help:evaluate -Dexpression='project.version' -N | grep -v '\[' | grep -v 'Download' | cut -d- -f1`
}

function pre_update_versions() {
  echo -e "\033[0;32m* Preparing project for release\033[0m"
  pre_update_parent_versions
  pre_update_packages_versions
  git add pom.xml
  ## We need to be selective otherwise other files such as pom.xml.releaseBackup are also included
  git add '**/package.json'
  git commit -m "[release] Preparing release ${TAG_NAME}" -q
}

# Compute PROJECT_NAME (the Maven artifactId of the current project) and the corresponding
# release TAG_NAME (artifactId-version).
# Shared by pre_update_parent_versions() (normal flow) and resume_project_after_publish() (resume flow).
function compute_tag_name() {
  PROJECT_NAME=`mvn help:evaluate -Dexpression='project.artifactId' -N | grep -v '\[' | grep -v 'Download'`
  TAG_NAME=${PROJECT_NAME}-${VERSION}
}

# Update the root project's parent version and version variables, if needed.
# For xwiki-commons updates the value for the commons.version variable.
# For the other projects it changes the version of the parent in the current repository root pom.
# The changes will be committed as a new git version.
function pre_update_parent_versions() {
  mvn versions:update-parent -DgenerateBackupPoms=false -DskipResolution=true -DparentVersion=$VERSION -N -q
  sed -e "s/<commons.version>.*<\/commons.version>/<commons.version>${VERSION}<\/commons.version>/" -i pom.xml
  compute_tag_name
}

function pre_update_packages_versions() {
  set_packages_version $VERSION
}

# Perform the actual maven release.
# Invoke mvn release:prepare, followed by mvn release:perform (which builds and publishes the
# artifacts to the remote repository: Maven Central for xwiki-commons/xwiki-rendering,
# nexus.xwiki.org for xwiki-platform). The GPG-signed tag and the remaining steps are done
# afterwards by finish_release_after_publish() so they can be replayed on their own when resuming.
function release_maven() {
  TEST_SKIP="-DskipTests"

  # FIXME: Workaround what looks like a Maven release or clean plugin bug until we find/fix the root cause
  echo -e "\033[0;32m* delete target root folder\033[0m"
  rm -rf target || exit -2

  echo -e "\033[0;32m* release:prepare\033[0m"
  # Note: We disable the Develocity local and remote caches to make sure everything is rebuilt and to avoid
  # any security issue (e.g. if the remote cache has been compromised for example).
  # Hence the: -Ddevelocity.cache.local.enabled=false -Ddevelocity.cache.remote.enabled=false
  mvn -e --batch-mode release:prepare -DpushChanges=false -DlocalCheckout=true -DreleaseVersion=${VERSION} -DdevelopmentVersion=${NEXT_SNAPSHOT_VERSION} -Dtag=${TAG_NAME} -DautoVersionSubmodules=true -Plegacy,integration-tests,standalone,flavor-integration-tests,distribution,docker -Ddevelocity.cache.local.enabled=false -Ddevelocity.cache.remote.enabled=false -Darguments="-N ${TEST_SKIP}" ${TEST_SKIP} || exit -2

  # Before executing the perform, make sure any required parent is indeed as published as the Maven Central plugin is claiming
  PARENT="$(mvn -N help:evaluate -Dexpression=project.parent.groupId -q -DforceStdout):$(mvn -N help:evaluate -Dexpression=project.parent.artifactId -q -DforceStdout):$VERSION:pom"
  # We assume a parent never contains a white space (meaning we got an error, most probably due to no having a parent at all)
  if ! [[ $PARENT == *$' '* ]]; then
    echo "Make sure $PARENT is available remotely"
    TMP="$(pwd)/tmp-checkonline"
    mkdir -p $TMP
    cd $TMP
    while ! mvn dependency:get -U -Dartifact=$PARENT -Dmaven.repo.local=$TMP/repository/ > $TMP/log.txt 2>&1
    do
      echo "Failed to get the parent pom remotely (see $TMP/log.txt for more details), trying again in 1 min..."
      sleep 60
    done
    cd ..
    rm -rf $TMP
  fi

  echo -e "\033[0;32m* release:perform\033[0m"
  # Note: We disable the Develocity local and remote caches to make sure everything is rebuilt and to avoid
  # any security issue (e.g. if the remote cache has been compromised for example).
  # Hence the: -Ddevelocity.cache.local.enabled=false -Ddevelocity.cache.remote.enabled=false
  mvn -e --batch-mode release:perform -DpushChanges=false -DlocalCheckout=true -Ddevelocity.cache.local.enabled=false -Ddevelocity.cache.remote.enabled=false -Plegacy,integration-tests,standalone,flavor-integration-tests,distribution,docker ${TEST_SKIP} -Darguments="-Plegacy,integration-tests,flavor-integration-tests,distribution,docker ${TEST_SKIP} -Dxwiki.checkstyle.skip=true -Dxwiki.revapi.skip=true -Dxwiki.enforcer.skip=true -Dxwiki.spoon.skip=true -Ddevelocity.cache.local.enabled=false -Ddevelocity.cache.remote.enabled=false" || exit -2
}

# Create the GPG-signed git tag for the release. release:prepare only creates an unsigned tag,
# this overwrites it with a signed one. Requires TAG_NAME to be set.
function create_signed_tag() {
  echo -e "\033[0;32m* Creating GPG-signed tag\033[0m"
  git checkout ${TAG_NAME} -q
  git tag -s -f -m "Tagging ${TAG_NAME}" ${TAG_NAME}
}

# All the steps that must run once the artifacts have been published by release_maven
# (release:perform): sign the tag, bump the release branch to the next SNAPSHOT, merge and push
# it, clean up and push the tag + create the GitHub release.
# This is the single source of truth for the post-publish steps, shared by the normal release
# flow (release_project) and the resume-after-publish flow (resume_project_after_publish).
function finish_release_after_publish() {
  create_signed_tag
  post_update_versions
  push_release
  post_cleanup
  push_tag
}

function post_update_versions() {
  echo -e "\033[0;32m* Go back to branch ${RELEASE_BRANCH}\033[0m"
  git checkout ${RELEASE_BRANCH}
  post_update_parent_versions
  post_update_packages_versions
}

# Update the root project's parent version and version variables, if needed.
# For xwiki-commons updates the value for the commons.version variable.
# For the other projects it changes the version of the parent in the current repository root pom.
# The changes will be committed as a new git version.
function post_update_parent_versions() {
  echo -e "\033[0;32m* Update parent to ${NEXT_SNAPSHOT_VERSION} after release\033[0m"
  xsltproc -o pom.xml --stringparam parentversion "${NEXT_SNAPSHOT_VERSION}" $PRGDIR/set-parent-version.xslt pom.xml
  echo -e "\033[0;32m* Update commons.version to ${NEXT_SNAPSHOT_VERSION} after release\033[0m"
  sed -e "s/<commons.version>${VERSION}<\/commons.version>/<commons.version>${NEXT_SNAPSHOT_VERSION}<\/commons.version>/" -i pom.xml

  git add pom.xml
  git commit -m "[release] Update parent after release ${TAG_NAME}" -q
}

function post_update_packages_versions() {
  echo -e "\033[0;32m* Update packages to ${NEXT_SNAPSHOT_VERSION} after release\033[0m"
  set_packages_version $NEXT_SNAPSHOT_VERSION
  ## We need to be selective otherwise other files such as pom.xml.releaseBackup are also included
  git add '**/package.json'
  git commit -m "[release] Update packages after release ${TAG_NAME}" -q
}

# Push changes made to the release branch (new SNAPSHOT version, etc)
function push_release() {
  echo -e "\033[0;32m* Switch to release base branch\033[0m"
  git checkout ${RELEASE_FROM_BRANCH}
  echo -e "\033[0;32m* Merge release branch\033[0m"
  git merge ${RELEASE_BRANCH}
  echo -e "\033[0;32m* Push release base branch\033[0m"
  git push origin ${RELEASE_FROM_BRANCH}
}

# Cleanup sources again, after the release.
function post_cleanup() {
  echo -e "\033[0;32m* Cleanup\033[0m"
  git reset --hard -q
  git checkout master -q
  # Delete the release branch
  git branch -D ${RELEASE_BRANCH}
  git reset --hard -q
  git clean -dxfq
}

# Push the signed tag to the upstream repository and create the associated GitHub release
function push_tag() {
  echo -e "\033[0;32m* Pushing tag\033[0m"
  git push --tags

  echo -e "\033[0;32m* Creating the GitHub release\033[0m"
  # We are using a Maven plugin to do the GitHub release, se we need the right pom version
  git checkout ${TAG_NAME}
  mvn build-helper:regex-properties@default github-release:github-release -N -e
  git checkout master -q
}

# Resume a project's release right after the Maven publish (release:perform) succeeded but a
# later step failed (typically Central returning a 502 while polling the deployment status).
# This skips create_release_branch/pre_update_versions/release_maven (prepare+perform+publish)
# and runs only the post-publish steps. It relies on the release branch, the SNAPSHOT-bumping
# commit and the tag created by release:prepare being still present in the local clone, so the
# repository must NOT have been cleaned since the failed run.
# WARNING: only use this once you have confirmed on the Central portal that the artifacts for
# this project have actually been published.
function resume_project_after_publish() {
  echo -e "\033[0;33m* Resuming $1 right after the Maven publish\033[0m"

  # The normal flow sets a number of variables in the steps we are skipping here
  # (create_release_branch, pre_update_versions, ...). We reconstruct the ones consumed by
  # finish_release_after_publish() using the same helpers the normal flow uses:
  #  - RELEASE_FROM_BRANCH / STABLE_BRANCH: normally set by check_branch()
  #  - PROJECT_NAME / TAG_NAME:             normally set by pre_update_parent_versions()
  # VERSION, NEXT_SNAPSHOT_VERSION and RELEASE_BRANCH come from check_versions(), PRGDIR from init().
  # IMPORTANT: if finish_release_after_publish() ever starts depending on another variable set
  # earlier in the normal flow, reconstruct it here too, otherwise resuming will break.
  compute_release_source_branch
  compute_tag_name

  # Fail fast if the local state left by the failed run is gone. finish_release_after_publish()
  # checks out and force-signs ${TAG_NAME}: if the tag (or the release branch) no longer exists
  # locally - e.g. the clone was cleaned since the failed run, or a wrong VERSION was given - the
  # checkout would silently fail and the signed tag would land on whatever is checked out (master)
  # and then get pushed. Refuse to resume in that case rather than pushing a wrong tag.
  if ! git rev-parse --verify --quiet "refs/tags/${TAG_NAME}" > /dev/null
  then
    echo -e "\033[1;31mCannot resume $1: the tag ${TAG_NAME} does not exist in this clone.\033[0m"
    echo -e "\033[1;31mThe release branch and tag from the failed run must still be present; a resume is not possible on a cleaned clone.\033[0m"
    exit -1
  fi
  if ! git rev-parse --verify --quiet "refs/heads/${RELEASE_BRANCH}" > /dev/null
  then
    echo -e "\033[1;31mCannot resume $1: the release branch ${RELEASE_BRANCH} does not exist in this clone.\033[0m"
    exit -1
  fi

  finish_release_after_publish
}

# Wrapper function that calls all the other release steps, for one project only.
# The first (mandatory) parameter is the name of the subdirectory where the project sources are (xwiki-commons, xwiki-enterprise, etc).
function release_project() {
  cd $1
  # If this project is the one to resume after a failed publish, run only the post-publish steps.
  if [[ $do_release == true && "$RESUME_AFTER_PUBLISH_PROJECT" == "$1" ]]
  then
    resume_project_after_publish $1
    cd ..
    return
  fi
  pre_cleanup
  update_sources
  check_branch
  if [[ $do_release == true ]]
  then
    create_release_branch
    pre_update_versions
    release_maven
    finish_release_after_publish
  fi
  cd ..
}

# Validate the -p (resume after publish) option and, since the release order is fixed
# (commons -> rendering -> platform), automatically skip every project ordered before the
# resume target: resuming a project means the ones released before it necessarily already
# succeeded, so re-running them would attempt to re-release and re-publish them.
function check_resume_after_publish() {
  [[ -z $RESUME_AFTER_PUBLISH_PROJECT ]] && return

  if [[ $do_release == false ]]
  then
    echo -e "\033[1;31m-p cannot be combined with -r: there is nothing to resume when the actual release is disabled.\033[0m"
    exit -1
  fi

  case $RESUME_AFTER_PUBLISH_PROJECT in
    xwiki-commons)
      if [[ $do_xwiki_commons == false ]]
      then
        echo -e "\033[1;31m-p commons conflicts with -C (which disables xwiki-commons).\033[0m"
        exit -1
      fi
      ;;
    xwiki-rendering)
      if [[ $do_xwiki_rendering == false ]]
      then
        echo -e "\033[1;31m-p rendering conflicts with -R (which disables xwiki-rendering).\033[0m"
        exit -1
      fi
      if [[ $do_xwiki_commons == true ]]
      then
        echo -e "\033[0;33m* Resuming xwiki-rendering: xwiki-commons is already released, skipping it.\033[0m"
        do_xwiki_commons=false
      fi
      ;;
    xwiki-platform)
      if [[ $do_xwiki_platform == false ]]
      then
        echo -e "\033[1;31m-p platform conflicts with -P (which disables xwiki-platform).\033[0m"
        exit -1
      fi
      if [[ $do_xwiki_commons == true ]]
      then
        echo -e "\033[0;33m* Resuming xwiki-platform: xwiki-commons is already released, skipping it.\033[0m"
        do_xwiki_commons=false
      fi
      if [[ $do_xwiki_rendering == true ]]
      then
        echo -e "\033[0;33m* Resuming xwiki-platform: xwiki-rendering is already released, skipping it.\033[0m"
        do_xwiki_rendering=false
      fi
      ;;
  esac
}

# Wrapper function that calls release_project for each XWiki project in order: commons, rendering, platform, enterprise.
# This is the main function that is called when running the script.
function release_all() {
  # Validate the -p option first (it only depends on flags parsed by getopts) so we fail fast on
  # a bad combination before the gpg setup and the version prompts.
  check_resume_after_publish
  init
  check_env
  check_versions

  if [[ $do_xwiki_commons == 'true' ]]
  then
    echo              "*****************************"
    echo -e "\033[1;32m    Releasing xwiki-commons\033[0m"
    echo              "*****************************"
    release_project xwiki-commons
  fi

  if [[ $do_xwiki_rendering == 'true' ]]
  then
    echo              "*****************************"
    echo -e "\033[1;32m    Releasing xwiki-rendering\033[0m"
    echo              "*****************************"
    release_project xwiki-rendering
  fi

  if [[ $do_xwiki_platform == 'true' ]]
  then
    echo              "*****************************"
    echo -e "\033[1;32m    Releasing xwiki-platform\033[0m"
    echo              "*****************************"
    release_project xwiki-platform
  fi

  echo -e "\033[1;32mAll done!\033[0m"
  clean_env
}

# Display a help message describing this script.
function display_help() {
  echo "XWiki Release script - Part 1"
  echo ""
  echo "Options:"
  echo "-r: Disable actual release (usually when you only want to create the branches)."
  echo "-C: Disable xwiki-commons handling."
  echo "-R: Disable xwiki-rendering handling."
  echo "-P: Disable xwiki-platform handling."
  echo "-p <project>: Resume the given project (commons|rendering|platform) right after the Maven"
  echo "    publish step, when release:perform published the artifacts to Maven Central but a later"
  echo "    step failed (e.g. a 502/timeout while polling the deployment status). Only the"
  echo "    post-publish steps are run for that project (signed tag, version bump, merge/push,"
  echo "    cleanup, tag push and GitHub release). Projects ordered before it are skipped"
  echo "    automatically (they are necessarily already released), and the following projects are"
  echo "    released normally. Requires the local clone to still hold the release branch and tag"
  echo "    from the failed run, and the artifacts to be confirmed as published on the Central portal."
  echo ""
  echo "This script performs the technical release:"
  echo "* Create a release branch"
  echo "* Update the root project's parent version and the commons.version variable, if needed"
  echo "* Invoke the maven release process (mvn release:prepare and mvn release:perform)"
  echo "* Create GPG-signed tags and push them to the upstream repository"
  echo "* [Optional] Branch the current master into a stable release and update the master to the next version"
  echo ""
  echo "Prerequisite steps:"
  echo "* Configure a proper global .giconfig file holding the release manager's username/email address"
  echo "* Setup a GPG signing key corresponding to the email address above"
  echo "* Change to the xwiki-trunks directory, where the xwiki-commons, xwiki-rendering, xwiki-platform and xwiki-enterprise have been checked out"
  echo "* [Optional] Export a VERSION shell variable holding the name of the version being released, in the X.Y-rc-Z format"
  echo "The release script will check and refuse to proceed if these steps haven't been performed."
}

do_release=true
do_xwiki_commons=true
do_xwiki_rendering=true
do_xwiki_platform=true
while getopts ":hbrCRPp:" o
do
    case "${o}" in
        p)
          case "${OPTARG}" in
            commons|xwiki-commons)     RESUME_AFTER_PUBLISH_PROJECT=xwiki-commons ;;
            rendering|xwiki-rendering) RESUME_AFTER_PUBLISH_PROJECT=xwiki-rendering ;;
            platform|xwiki-platform)   RESUME_AFTER_PUBLISH_PROJECT=xwiki-platform ;;
            *)
              echo "Invalid project for -p: '${OPTARG}' (expected commons, rendering or platform)."
              exit -1
              ;;
          esac
          echo "The script will resume ${RESUME_AFTER_PUBLISH_PROJECT} right after the Maven publish step (post-publish steps only)."
          ;;
        r)
          echo "You called the script with skipping the actual release: "
          echo "the script will still ask all the questions related to the versions and will create the branches but it will stop before performing the actual release."
          echo "Do not worry if you see logs containing 'Releasing xwiki-xxx' this is only the call for setting the versions."
          do_release=false
          ;;
        C)
          echo "The script will skip releasing xwiki-commons."
          do_xwiki_commons=false
          ;;
        R)
          echo "The script will skip releasing xwiki-rendering."
          do_xwiki_rendering=false
          ;;
        P)
          echo "The script will skip releasing xwiki-platform."
          do_xwiki_platform=false
          ;;
        h)
          help=true
          ;;
        ?)
          help=true
          ;;
    esac
done

if [ $help ]
then
  display_help
  exit 0
else
  release_all
fi
