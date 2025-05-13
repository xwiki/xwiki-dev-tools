#!/bin/bash
wget https://github.com/validator/validator/releases/download/latest/vnu.jar -O vnu.jar
VERSION_LINE=`unzip -p vnu.jar META-INF/MANIFEST.MF | grep Implementation-Version`
VERSION=${VERSION_LINE##* }
VERSION=`echo $VERSION | tr -d '\r'`
echo "Setting the version $VERSION in the pom file"
sed -i "s/<version>version<\/version>/<version>$VERSION<\/version>/g" pom.xml
echo "Deploying version $VERSION"
mvn deploy:deploy-file -DrepositoryId=nexus.xwiki.org -Durl=https://nexus.xwiki.org/nexus/content/repositories/externals/ -Dfile=vnu.jar -DpomFile=pom.xml -Dversion=$VERSION
echo "Restoring the pom file"
git checkout pom.xml

