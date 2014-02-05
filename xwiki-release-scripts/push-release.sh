#!/bin/bash

# Read the credentials from the file passed as the first argument, if any.
# See example.passwords for more details on the credentials file.
function read_credentials() {
  if [[ $PASSWORDS ]]
  then
    source $PASSWORDS
  fi
}

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

#####################################################
# Authentication functions
#####################################################

# Login to Jira. This function uses the REST authentication API and will store the resulting cookie in the J_AUTH variable.
function authenticate_jira() {
  while [[ -z $J_AUTH ]]
  do
    # Prompt for credentials
    if [[ -z $J_U ]]
    then
      echo -e "\033[0mJira username:\033[0;32m"
      read -e -p "> " J_U
      echo -n -e "\033[0m"
    fi
    if [[ -z $J_P ]]
    then
      echo -e "\033[0mJira password:\033[0;32m"
      read -e -s -p "> " J_P
      echo -e "\033[0m"
    fi

    # HTTP request sending the username and password as JSON. Store the resulting JSON in J_AUTH for further processing.
    J_AUTH=`curl -f -s -X POST --data "{\"username\":\"${J_U}\", \"password\":\"${J_P}\"}" -H "Content-Type: application/json" http://jira.xwiki.org/rest/auth/1/session`
    # If the authentication failed, then curl will exit with a non-zero status.
    if [[ $? == 0 ]]
    then
      # The response should look like:
      # {"session":{"name":"JSESSIONID","value":"XYZ"},"loginInfo":{"failedLoginCount":3,"loginCount":42,"lastFailedLoginTime":"2011-01-01T00:00:00.000+0200","previousLoginTime":"2011-02-03T04:05:06.007+0800"}}
      # Split the JSON response into lines whenever a curly bracket is encountered, and keep only the JSESSION one
      J_AUTH=`echo $J_AUTH | sed -e 's/[{}]/\n/g' | grep JSESS`
      # Extract the JSESSION value into proper cookie syntax
      J_AUTH=`echo $J_AUTH | cut -d\" -f4,8 | sed -e 's/"/=/'`
      J_AUTH="Cookie: $J_AUTH"
    else
      echo -e "\033[0;33mWrong credentials, please re-enter\033[0m"
    J_U=
    J_P=
    fi
  done
}

# Login to OW2. This function emulates a browser login by submitting a login HTTP request and storing the resulting cookie in the O_AUTH variable.
function authenticate_ow2() {
  while [[ -z $O_AUTH ]]
  do
    # Prompt for credentials
    if [[ -z $O_U ]]
    then
      echo -e "\033[0mOW2Forge username:\033[0;32m"
      read -e -p "> " O_U
      echo -n -e "\033[0m"
    fi
    if [[ -z $O_P ]]
    then
      echo -e "\033[0mOW2Forge password:\033[0;32m"
      read -e -s -p "> " O_P
      echo -e "\033[0m"
    fi

    # HTTP request sending the username and password as form data to OW2's login page. Keep the resulting Set-Cookie header in the O_AUTH variable.
    O_AUTH=`curl -f -o /dev/null -v --insecure -X POST --data "return_to=%2F&form_loginname=${O_U}&form_pw=${O_P}&login=Login+with+SSL" https://forge.ow2.org/account/login.php 2>&1 | grep Set-Cookie | cut -d: -f2 | cut '-d ' -f2 | cut '-d;' -f1`
    # If the authentication failed, then no cookie is sent by the server. Retry.
    if [[ -z $O_AUTH ]]
    then
      echo -e "\033[0;33mWrong credentials, please re-enter\033[0m"
      O_U=
      O_P=
    fi
  done
}

# Login to freecode (ex FreshMeat). This function emulates a browser login by submitting a login HTTP request and storing the resulting cookies in a file on the disk, /tmp/fm.cookies
# This cookie file will be used later by passing it to curl, and will be deleted at the end of the script.
function authenticate_freecode() {
  while [[ -z $F_AUTH ]]
  do
    # Prompt for credentials
    if [[ -z $F_U ]]
    then
      echo -e "\033[0mFreeCode username:\033[0;32m"
      read -e -p "> " F_U
      echo -n -e "\033[0m"
    fi
    if [[ -z $F_P ]]
    then
      echo -e "\033[0mFreeCode password:\033[0;32m"
      read -e -s -p "> " F_P
      echo -e "\033[0m"
    fi

    # HTTP request, send credentials as form data, store cookies in a file. If the response contains an error message, remember that in the F_AUTH variable.
    F_AUTH=`curl -c /tmp/fm.cookies -f -v --insecure -X POST --data "user_session%5Blogin%5D=${F_U}&user_session%5Bpassword%5D=${F_P}&commit=Log+in%21&user_session%5Bremember_me%5D=0" https://freecode.com/session  2>&1 | grep errorExplanation`
    # errorExplanation found in the response, retry.
    if [[ $F_AUTH ]]
    then
      echo -e "\033[0;33mWrong credentials, please re-enter\033[0m"
      F_AUTH=
      F_U=
      F_P=
    else
      F_AUTH="OK"
    fi
  done
}

# Login to xwiki.org. This function emulates a browser login by submitting a login HTTP request and storing the resulting cookies in a file on the disk, /tmp/xwo.cookis
# Also retrieve the current CSRF prevention token and store it in X_AUTH.
function authenticate_xwiki() {
  while [[ -z $X_AUTH ]]
  do
    # Prompt for credentials
    if [[ -z $X_U ]]
    then
      echo -e "\033[0mXWiki.org username:\033[0;32m"
      read -e -p "> " X_U
      echo -n -e "\033[0m"
    fi
    if [[ -z $X_P ]]
    then
      echo -e "\033[0mXWiki.org password:\033[0;32m"
      read -e -s -p "> " X_P
      echo -e "\033[0m"
    fi

    # HTTP request, send credentials as form data, store cookies in a file
    curl -c /tmp/xwo.cookies -f -s -X POST --data "j_username=${X_U}&j_password=${X_P}" http://www.xwiki.org/xwiki/bin/loginsubmit/XWiki/XWikiLogin  2>&1
    if [[ $? == 0 ]]
    then
      X_AUTH="OK"
    # Error response code, failed authentication
    else
      echo -e "\033[0;33mWrong credentials, please re-enter\033[0m"
      X_U=
      X_P=
    fi

    # Get the CSRF- prevention token by looking at the source of an edit page; we're already logged in with the X_U user, so this should work
    X_TOKEN=`curl -b /tmp/xwo.cookies -f -v http://www.xwiki.org/xwiki/bin/edit/XWiki/${X_U}?editor=wiki  2>&1 | grep form_token | grep input | sed -r -e 's/.*value="([^"]+)".*/\1/'`
  done
}

# Login to purl.org. This function emulates a browser login by submitting a login HTTP request and storing the resulting cookie in the P_AUTH variable.
function authenticate_purl() {
  while [[ -z $P_AUTH ]]
  do
    # Prompt for credentials
    if [[ -z $P_U ]]
    then
      echo -e "\033[0mPURL.org username:\033[0;32m"
      read -e -p "> " P_U
      echo -n -e "\033[0m"
    fi
    if [[ -z $P_P ]]
    then
      echo -e "\033[0mPURL.org password:\033[0;32m"
      read -e -s -p "> " P_P
      echo -e "\033[0m"
    fi

    # HTTP request sending the username and password as form data to the login page. Keep the resulting Set-Cookie header in the P_AUTH variable.
    P_AUTH=`curl -f -o /dev/null -v --insecure -X POST --data "id=${P_U}&passwd=${P_P}" http://purl.org/admin/login/login-submit.bsh 2>&1 | grep Set-Cookie | cut -d: -f2- | cut '-d ' -f2 | cut '-d;' -f1`

    # No cookie sent, failed authentication
    if [[ -z $P_AUTH ]]
    then
      echo -e "\033[0;33mWrong credentials, please re-enter\033[0m"
      P_U=
      P_P=
    fi
  done
}

# Cleanup temporary cookie files holding authentication information. These files are created by the FreeCode and XWiki.org authentication mechanisms.
function cleanup_auth() {
  rm -f /tmp/xwo.cookies
  rm -f /tmp/fm.cookies
}
#####################################################
# Helper functions
#####################################################

# Encode a string using URL %XY escapes. Works only for ASCII characters.
# @param $1 the string to encode
# @return the output is stored in the $i variable
urlencode() {
  arg="$1"
  i="0"
  while [ "$i" -lt ${#arg} ]
  do
    c=${arg:$i:1}
    if echo "$c" | grep -q '[a-zA-Z/:_\.\-]'; then
      echo -n "$c"
    else
      echo -n "%"
      printf "%X" "'$c'"
    fi
    i=$((i+1))
  done
}

# Push a file to the user's incoming folder on the OW2 forge using the SCP protocol.
# @param $1 the OW2 username to use; should be taken from O_U
# @param $2 the file to send
function push_ow2_file() {
  scp $2 $1@forge.objectweb.org:incoming/
}

#####################################################
# Actual action functions
#####################################################

# Perform the release on jira.xwiki.org.
# This means that the version being released is marked as released for all the top level projects, with the current date as the release date.
function release_jira() {
  echo -e "\033[0;32m* Updating JIRA\033[0m"
  authenticate_jira

  for PROJECT in "XCOMMONS" "XRENDERING" "XWIKI" "XE" "XEM"
  do
    # Get the list of versions for the current release
    J_VERSION_URL=`curl -s -X GET -H "${J_AUTH}" -H "Content-Type: application/json" http://jira.xwiki.org/rest/api/latest/project/${PROJECT}/versions`
    # Extract only the target version
    J_VERSION_URL=`echo $J_VERSION_URL | sed -e 's/[{}]/\n/g' | grep "\"name\":\"${JIRA_VERSION}\""`
    J_VERSION_URL=`echo $J_VERSION_URL | cut -d\" -f4`

    # See if there are any unresolved issues
    UNRESOLVED_ISSUES=`curl -s -X GET -H "${J_AUTH}" ${J_VERSION_URL}/unresolvedIssueCount`
    UNRESOLVED_ISSUES=`echo $UNRESOLVED_ISSUES | cut -d\" -f7 | sed -e 's/[:}]//g'`
    if [[ $UNRESOLVED_ISSUES != 0 ]]
    then
      echo -e "\033[0;93mThere are outstanding issues for this version, you should move them now!\033[0m"
      echo -e "\033[0;93mOpen \033[4;33mhttp://jira.xwiki.org/secure/IssueNavigator.jspa?reset=true&mode=hide&fixfor=`echo ${J_VERSION_URL} | sed -e 's/.*\///g'`&resolution=-1\033[0m\033[0;93m and move the issues to the next version\033[0m"
      echo -e "\033[0;93mPress enter when done\033[0m"
      read -e -s DISCARD
      # Don't re-check, assume the user did move/close all the outstanding issues
    fi

    # Release the version
    DATE=`date  +%F`
    DISCARD=`curl -s -X PUT -H "${J_AUTH}" -H "Content-Type: application/json" --data "{\"released\":true,\"releaseDate\":\"${DATE}\"}" $J_VERSION_URL`
  done
}

# Transfer the major release files to the OW2 download forge.
# This only transfers the files, without actually publishing the files on OW2.
# @see update_ow2
function push_ow2() {
  echo -e "\033[0;32m* Publishing files on OW2\033[0m"
  authenticate_ow2

  push_ow2_file ${O_U} ${BASE}/org/xwiki/enterprise/xwiki-enterprise-installer-generic/${VERSION}/xwiki-enterprise-installer-generic-${VERSION}-standard.jar
  push_ow2_file ${O_U} ${BASE}/org/xwiki/enterprise/xwiki-enterprise-installer-windows/${VERSION}/xwiki-enterprise-installer-windows-${VERSION}.exe
  push_ow2_file ${O_U} ${BASE}/org/xwiki/enterprise/xwiki-enterprise-jetty-hsqldb/${VERSION}/xwiki-enterprise-jetty-hsqldb-${VERSION}.zip
  push_ow2_file ${O_U} ${BASE}/org/xwiki/enterprise/xwiki-enterprise-web/${VERSION}/xwiki-enterprise-web-${VERSION}.war
  push_ow2_file ${O_U} ${BASE}/org/xwiki/enterprise/xwiki-enterprise-ui-mainwiki-all/${VERSION}/xwiki-enterprise-ui-mainwiki-all-${VERSION}.xar
}

# Create the releases on OW2.
# This means creating new versions for XE and XEM with the proper release notes and changelog, and adding all the required files in these versions.
# The files must be
# @see push_ow2
# @see announce_ow2
function update_ow2() {
  echo -e "\033[0;32m* Creating the release version on OW2\033[0m"
  authenticate_ow2

  # XE
  # Create the package while uploading the first file, the generic installer
  DATE=`date '+%Y-%m-%d %k:%M'`
  EDIT_RELEASE_URL=`curl -s -X POST --form-string "package_id=208" \
    --form-string "release_name=xwiki-enterprise-${VERSION}" \
    --form-string "release_date=${DATE}" \
    --form-string "userfile2=xwiki-enterprise-installer-generic-${VERSION}-standard.jar" \
    --form-string "userfile=" \
    --form-string "type_id=3000" \
    --form-string "processor_id=8000" \
    --form-string "release_notes=${RELNOTES}" \
    --form-string "release_changes=${CHANGELOG}" \
    --form-string "submit=Release File" \
    -H "Cookie: ${O_AUTH}" \
    http://forge.ow2.org/project/admin/qrs.php?group_id=170 | grep "editrelease"  | sed -r -e 's/.*You can now <a href="//' -e 's/">.*//' -e 's/&amp;/\&/g'`

  EDIT_RELEASE_URL="http://forge.ow2.org${EDIT_RELEASE_URL}"

  # XE Windows installer
  curl -s -o /dev/null -X POST --form-string "step2=1" \
    --form-string "userfile2=xwiki-enterprise-installer-windows-${VERSION}.exe" \
    --form-string "userfile=" --form-string "type_id=9999" --form-string "processor_id=1000" --form-string "submit=Add This File" \
    -H "Cookie: ${O_AUTH}" ${EDIT_RELEASE_URL}

  # XE standalone distribution
  curl -s -o /dev/null -X POST --form-string "step2=1" \
    --form-string "userfile2=xwiki-enterprise-jetty-hsqldb-${VERSION}.zip" \
    --form-string "userfile=" --form-string "type_id=3000" --form-string "processor_id=8000" --form-string "submit=Add This File" \
    -H "Cookie: ${O_AUTH}" ${EDIT_RELEASE_URL}

  # XE WAR
  curl -s -o /dev/null -X POST --form-string "step2=1" \
    --form-string "userfile2=xwiki-enterprise-web-${VERSION}.war" \
    --form-string "userfile=" --form-string "type_id=3000" --form-string "processor_id=8000" --form-string "submit=Add This File" \
    -H "Cookie: ${O_AUTH}" ${EDIT_RELEASE_URL}

  # XE XAR
  curl -s -o /dev/null -X POST --form-string "step2=1" \
    --form-string "userfile2=xwiki-enterprise-ui-mainwiki-all-${VERSION}.xar" \
    --form-string "userfile=" --form-string "type_id=3000" --form-string "processor_id=8000" --form-string "submit=Add This File" \
    -H "Cookie: ${O_AUTH}" ${EDIT_RELEASE_URL}
}

# Update the xwiki.org download pages.
# FIXME needs updating to the new download pages
function update_download() {
  echo -e "\033[0;32m* Updating the download page on XWiki.org\033[0m"
  authenticate_xwiki

  # Get the current page content via REST
  curl -s -o /tmp/xwiki.download.page http://www.xwiki.org/xwiki/rest/wikis/xwiki/spaces/Main/pages/Download
  sed -r -e 's/.*<content>//g' -e 's/<\/content>.*//g' -e 's/&#xD;/\r/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g' -e 's/&gt;/>/g' -e 's/&lt;/</g' -i /tmp/xwiki.download.page


  curl -s -X POST --basic --user ${X_U}:${X_P} --data-urlencode "comment=Released ${VERSION}" --data-urlencode "content=`cat /tmp/xwiki.download.page`" http://www.xwiki.org/xwiki/bin/save/Main/Download
  rm -f /tmp/xwiki.ow2.files /tmp/xwiki.download.page
}

# Update the API pages on xwiki.org with links to the new version.
# FIXME needs updating to use the CSRF token and the cookie file
function update_api() {
  echo -e "\033[0;32m* Updating the API page on XWiki.org\033[0m"
  authenticate_xwiki

  curl -s -o /tmp/xwiki.api.page http://www.xwiki.org/xwiki/rest/wikis/platform/spaces/DevGuide/pages/API
  sed -r -e 's/.*<content>//g' -e 's/<\/content>.*//g' -e 's/&#xD;/\r/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g' -e 's/&gt;/>/g' -e 's/&lt;/</g' -i /tmp/xwiki.api.page

  if [[ $RELEASE_TYPE == "stable" ]]
  then
    sed -r -e "s/versionStable = \".*\"/versionStable = \"${VERSION}\"/" \
       -i /tmp/xwiki.api.page
  else
    sed -r -e "s/versionDev = \".*\"/versionDev = \"${VERSION}\"/" -e "s/nameDev = \".*\"/nameDev = \"${PRETTY_VERSION}\"/" \
       -i /tmp/xwiki.api.page
  fi

  curl -s -X POST --basic --user ${X_U}:${X_P} --data-urlencode "comment=Released ${VERSION}" --data-urlencode "content=`cat /tmp/xwiki.api.page`" http://platform.xwiki.org/xwiki/bin/save/DevGuide/API
  rm -f /tmp/xwiki.api.page
}

# Create a News item on OW2.
function announce_ow2() {
  echo -e "\033[0;32m* Announcing the release on OW2\033[0m"
  authenticate_ow2

  curl -s -o /tmp/resp -X POST --data "group_id=170" --data "post_changes=1" \
    --data-urlencode "summary=XWiki ${PRETTY_VERSION} Released" \
    --data-urlencode "description=The XWiki development team is proud to announce the availability of XWiki Enterprise ${PRETTY_VERSION}. ${RELSUMMARY}. " \
    --data-urlencode "details=The XWiki development team is proud to announce the availability of XWiki Enterprise ${PRETTY_VERSION}. $RELNOTES" \
    --data "submit=SUBMIT" \
    -H "Cookie: ${O_AUTH}" http://forge.ow2.org/news/submit.php
}

# Create a blog post on xwiki.org announcing the release.
function announce_xwiki() {
  echo -e "\033[0;32m* Announcing the release on XWiki.org\033[0m"
  authenticate_xwiki

  SUMMARY="XWiki ${PRETTY_VERSION} Released"
  BLOGPOST_URL=`echo $SUMMARY | sed -e 's/\.//g'`
  BLOGPOST_URL=`urlencode "$BLOGPOST_URL"`
  # If the blog post exists already, skip this step
  #if [[ `curl -f -s http://www.xwiki.org/xwiki/bin/get/Blog/${BLOGPOST_URL}` ]]
  #then
  #  return
  #fi
  BLOGPOST_URL="http://www.xwiki.org/xwiki/bin/save/Blog/${BLOGPOST_URL}"

  curl -s -b /tmp/xwo.cookies -X POST \
    --data-urlencode "form_token=${X_TOKEN}" \
    --data-urlencode "content={{include document=\"Blog.BlogPostSheet\"/}}" \
    --data-urlencode "parent=Blog.WebHome" \
    --data-urlencode "title=${SUMMARY}" \
    --data-urlencode "syntaxId=xwiki/2.0" \
    ${BLOGPOST_URL}

  BLOGPOST_URL=`echo $BLOGPOST_URL | sed -e 's/\/save\//\/objectadd\//'`
  curl -s -b /tmp/xwo.cookies -X POST \
    --data-urlencode "form_token=${X_TOKEN}" \
    --data-urlencode "classname=Blog.BlogPostClass" \
    --data-urlencode "Blog.BlogPostClass_category=Blog.Releases" \
    --data-urlencode "Blog.BlogPostClass_hidden=0" \
    --data-urlencode "Blog.BlogPostClass_published=1" \
    --data-urlencode "Blog.BlogPostClass_title=${SUMMARY}" \
    --data-urlencode "Blog.BlogPostClass_content=The XWiki development team is proud to announce the [[availability>>Main.Download]] of XWiki ${PRETTY_VERSION}. `cat ${RELEASE_NOTES} | grep -v ReleaseNotes`

See [[the full release notes>>ReleaseNotes.ReleaseNotesXWiki${TINY_VERSION}]] for more details." \
    ${BLOGPOST_URL}
}

# Create a new release on freecode.
# FIXME this doesn't work yet reliably
function announce_freecode() {
  echo -e "\033[0;32m* Announcing the release on Freecode\033[0m"
  authenticate_freecode

  CREATED=$(curl -v -X POST -b /tmp/fm.cookies \
    --data-urlencode "release[version]=${PRETTY_VERSION}" \
    --data-urlencode "release[changelog]=`cat ${RELEASE_NOTES} | grep -v RseleaseNotes`" \
    --data-urlencode "release[tag_list]=`echo ${VERSION} | cut -d- -f1 | cut -d. -f1,2`" \
    http://freecode.com/projects/xwiki/releases 2>&1 | grep Location)
  if [[ -z `echo $CREATED | grep 'projects/xwiki/releases/' ` ]]
  then
    echo -e "\033[0;93mFailed to push the announcement to Freecode, probably the release notes are too large. Giving up, you should do this manually at \033[4;93mhttp://freecode.net/projects/xwiki/releases/new\033[0m"
  fi
}

# Create a new purl entry in the format purl.org/xwiki/XE32M1 pointing to the blog post on xwiki.org.
function create_purl() {
  echo -e "\033[0;32m* Creating PURL for the release notes\033[0m"
  authenticate_purl

  BLOGPOST_URL="XWiki ${PRETTY_VERSION} Released"
  BLOGPOST_URL=`echo ${BLOGPOST_URL} | sed -e 's/\.//g'`
  BLOGPOST_URL=`urlencode "${BLOGPOST_URL}"`
  BLOGPOST_URL="http://www.xwiki.org/xwiki/bin/Blog/${BLOGPOST_URL}"

  curl -s -o /dev/null -X POST --data "maintainers=${P_U}" --data-urlencode "target=${BLOGPOST_URL}" --data "type=302" \
    -H "Cookie: ${P_AUTH}" http://purl.org/admin/purl/xwiki/rn/${TINY_VERSION}
}

# Announce the release on twitter.
function announce_twitter() {
  echo -e "\033[0;32m* Announcing the release on Twitter\033[0m"

  $PRGDIR/twidge-1.1.0-linux-i386-bin update "#XWiki ${PRETTY_VERSION} has been #released! Check it out: http://purl.org/xwiki/rn/${TINY_VERSION}"
}

#####################################################
# Main code
#####################################################
trap "echo -e '\033[0m\nExiting'" EXIT

if [ ! -n "$1" ]
then
  echo -e "Usage: $0 <action>, where valid actions are:"
  echo -e "- release_jira"
  echo -e "- push_ow2"
  echo -e "- update_ow2"
  echo -e "- update_download"
  echo -e "- update_api"
  echo -e "- announce_ow2"
  echo -e "- announce_xwiki"
  echo -e "- announce_freecode"
  echo -e "- create_purl"
  echo -e "- announce_twitter"
  echo -e "- cleanup_auth"
  exit -1
fi

init
read_credentials

BASE=~/public_html/releases/
if [[ -z $VERSION ]]
then
  echo -e "Which version are you releasing?\033[0;32m"
  GUESSED_VERSION=`ls -1t ${BASE}/org/xwiki/enterprise/xwiki-enterprise-jetty-hsqldb/ | grep -v metadata | head -1`
  read -e -p "${GUESSED_VERSION}> " VERSION
  echo -n -e "\033[0m"
  if [[ -z $VERSION ]]
  then
    VERSION=$GUESSED_VERSION
  fi
fi
PRETTY_VERSION=`echo ${VERSION} | sed -e 's/-/ /g' -e 's/milestone/Milestone/' -e 's/rc/Release Candidate/'`
SHORT_VERSION=`echo ${VERSION} | sed -e 's/-//g' -e 's/milestone/M/' -e 's/rc/RC/'`
TINY_VERSION=`echo ${SHORT_VERSION} | sed -e 's/\.//g'`
#JIRA_VERSION=`echo ${VERSION} | sed -e 's/-//g' -e 's/milestone/ M/' -e 's/rc/ RC/'`
JIRA_VERSION=`echo ${VERSION}`

if [[ `echo $VERSION | grep -E 'milestone|rc'` ]]
then
  RELEASE_TYPE="dev"
else
  RELEASE_TYPE="stable"
fi

while [[ -z $RELEASE_NOTES ]]
do
  echo -e "Select a short release notes file:\033[0;32m"
  read -e -p "$PRGDIR/releasenotes-${version}.txt> " RELEASE_NOTES
  echo -n -e "\033[0m"
  if [[ -z $RELEASE_NOTES ]]
  then
    RELEASE_NOTES=$PRGDIR/releasenotes-${version}.txt
  fi
  if [[ ! -f $RELEASE_NOTES ]]
  then
    echo Not a valid file
    RELEASE_NOTES=
  fi
done

RELNOTES=`cat $RELEASE_NOTES`
CHANGELOG=`urlencode "$JIRA_VERSION"`
CHANGELOG="See http://jira.xwiki.org/secure/IssueNavigator.jspa?reset=true&jqlQuery=category+in+%28%22Top+Level+Projects%22%29+and+fixVersion+in+%28%22${CHANGELOG}%22%29+and+resolution+in+%28%22Fixed%22%29 for more details"
RELSUMMARY="See http://www.xwiki.org/xwiki/bin/ReleaseNotes/ReleaseNotesXWiki${TINY_VERSION} for more details"

type $1 &>/dev/null && $1 || echo "'$1' action doesn't exist"

