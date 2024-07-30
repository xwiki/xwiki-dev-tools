if [ $1 == 'h' ]
then
  echo "Usage: set-branch-version.sh GROUPID:ARTIFACTID VERSION TYPE"
  echo "Print the SHA256 (256-bit) checksums of a Maven artifact accessible through http://nexus.xwiki.org/nexus/content/groups/public."
  echo ""
  echo "-h: Display this help."
  echo ""
  echo "Example: mvn-sha256sum.sh org.xwiki.platform:xwiki-platform-distribution-war 16.6.0 war"

  exit 0
fi
id=$1
groupid=${id%%:*}
artifactid=${id##*:}
groupidpath=${groupid//./\/}
version=$2
type=$3
filename=${artifactid}-${version}.${type}
wget http://nexus.xwiki.org/nexus/content/groups/public/${groupidpath}/${artifactid}/${version}/${filename} && sha256sum ${filename} && rm ${filename}