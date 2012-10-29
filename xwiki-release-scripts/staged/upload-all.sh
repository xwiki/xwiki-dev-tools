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

if [[ "${1}" == "" || "${2}" == "" ]]; then
    echo "Usage: ${0} <username> <version releasing>"
    echo "Eg:    ${0} cjdelisle 4.1-milestone-2"
    exit 1;
fi

cd
PREFIX="`pwd`/public_html/releases/org/xwiki"

VERSION="${2}"

XE_EXE="${PREFIX}/enterprise/xwiki-enterprise-installer-windows/${VERSION}/xwiki-enterprise-installer-windows-${VERSION}.exe"
XE_JAR="${PREFIX}/enterprise/xwiki-enterprise-installer-generic/${VERSION}/xwiki-enterprise-installer-generic-${VERSION}-standard.jar"
XE_ZIP="${PREFIX}/enterprise/xwiki-enterprise-jetty-hsqldb/${VERSION}/xwiki-enterprise-jetty-hsqldb-${VERSION}.zip"
XE_WAR="${PREFIX}/enterprise/xwiki-enterprise-web/${VERSION}/xwiki-enterprise-web-${VERSION}.war"
XE_XAR="${PREFIX}/enterprise/xwiki-enterprise-ui-all/${VERSION}/xwiki-enterprise-ui-all-${VERSION}.xar"

XEM_WAR="${PREFIX}/manager/xwiki-manager-web/${VERSION}/xwiki-manager-web-${VERSION}.war"
XEM_ALL="${PREFIX}/manager/xwiki-manager-ui-all/${VERSION}/xwiki-manager-ui-all-${VERSION}.xar"
XEM_XAR="${PREFIX}/manager/xwiki-manager-ui/${VERSION}/xwiki-manager-ui-${VERSION}.xar"
XEM_ZIP="${PREFIX}/manager/xwiki-manager-jetty-mysql/${VERSION}/xwiki-manager-jetty-mysql-${VERSION}.zip"

for file in ${XE_EXE} ${XE_JAR} ${XE_ZIP} ${XE_WAR} ${XE_XAR} ${XEM_WAR} ${XEM_ALL} ${XEM_XAR} ${XEM_ZIP}
do
    if [ ! -f ${file} ]; then
        echo "${file} not found.";
        exit 1;
    fi
done

scp ${XE_EXE} ${XE_JAR} ${XE_ZIP} ${XE_WAR} ${XE_XAR} ${XEM_WAR} ${XEM_ALL} ${XEM_XAR} ${XEM_ZIP} \
    $1@forge.objectweb.org:incoming/

