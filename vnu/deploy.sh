#!/bin/bash
wget https://github.com/validator/validator/releases/download/latest/vnu.jar -O vnu.jar
VERSION_LINE=`unzip -p vnu.jar META-INF/MANIFEST.MF | grep Implementation-Version`
VERSION=${VERSION_LINE##* }
echo "Deploying version $VERSION"
mvn deploy -Dfile=vnu.jar -DpomFile=pom.xml -Dversion=$VERSION
