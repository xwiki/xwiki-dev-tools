#!/bin/bash

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
#

#
# This script will create links in the src/webapp directory to the needed files in xwiki-platform
#

# This function takes a parameters, a directory, and checks that this is a valid root for
# the xwiki-platform sources.
function check_xwiki_platform {
  grep "<artifactId>xwiki-platform" "$1/pom.xml" &> /dev/null
  if [ "$?" != "0" ]; then
    return 1
  fi
  
  # Check that the needed sources are there.
  read -r -d '' LOCATIONS <<EOF
$1/xwiki-platform-core/xwiki-platform-web/src/main/webapp/
$1/xwiki-platform-core/xwiki-platform-toucan/src/main/resources/toucan
$1/xwiki-platform-core/xwiki-platform-colibri/src/main/resources/colibri
EOF

  for l in $LOCATIONS; do
    if [ ! -e $l ]; then
      return 1
    fi
  done

  return 0
}

# Where the script, and thus xwiki-debug-idea, is located.
BASE_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Check if we can find an xwiki-platform source tree by going up in the directory tree.
CUR_DIR="$( cd "$BASE_DIR" && pwd )"
while [ "$CUR_DIR" != "/" ]; do
  if [ -e "$CUR_DIR/xwiki-platform" ]; then
    check_xwiki_platform "$CUR_DIR/xwiki-platform"
    if [ "$?" == "0" ]; then
      echo found
      XWIKI_PLATFORM_DIR="$( cd "$CUR_DIR/xwiki-platform"  && pwd )"
      break
    fi
  fi
  CUR_DIR="$( cd "$CUR_DIR/.." && pwd )"
done

# Loop until the user chooses a valid xwiki-platform source directory.
while [ true ]; do
  if [ "$XWIKI_PLATFORM_DIR" != "" ]; then
    echo -e "\033[00;32mXWiki platform sources found at $XWIKI_PLATFORM_DIR\033[00m"
    read -e -p "Do you want to use this? (y/n) "
    echo
    [[ "$REPLY" == [yY] ]] && break || XWIKI_PLATFORM_DIR=""
  else
    if [ "$XWIKI_PLATFORM_DIR" != "" ]; then
      echo -e "\033[00;31mXWiki platform not found at $XWIKI_PLATFORM_DIR\033[00m"
    fi
    read -e -p "Please specify the path to xwiki-platform sources: " XWIKI_PLATFORM_DIR
    echo
  fi
done

# Start linking resources
read -r -d '' LOCATIONS <<EOF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/resources/logback.xml:$BASE_DIR/src/main/resources
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/redirect:$BASE_DIR/src/main/webapp
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/resources:$BASE_DIR/src/main/webapp
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/templates:$BASE_DIR/src/main/webapp
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/cache:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/fonts:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/observation:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/portlet.xml:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/struts-config.xml:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/sun-web.xml:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-web/src/main/webapp/WEB-INF/web.xml:$BASE_DIR/src/main/webapp/WEB-INF
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-toucan/src/main/resources/toucan:$BASE_DIR/src/main/webapp/skins
$XWIKI_PLATFORM_DIR/xwiki-platform-core/xwiki-platform-colibri/src/main/resources/colibri:$BASE_DIR/src/main/webapp/skins
EOF

mkdir -p $BASE_DIR/src/main/resources
mkdir -p $BASE_DIR/src/main/webapp/skins
echo -e "\033[00;32mCreating symbolic links...\033[00m"
for l in $LOCATIONS; do
  l=(${l//:/ });
  ln -s ${l[0]} ${l[1]}
done
