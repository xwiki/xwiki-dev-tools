
usage () {
  echo "Usage: set-branch-version.sh GROUPID:ARTIFACTID VERSION TYPE"
  echo "Print the SHA256 (256-bit) checksums of a Maven artifact accessible through http://nexus.xwiki.org/nexus/content/groups/public."
  echo ""
  echo "-h: Display this help."
  echo ""
  echo "Example: mvn-sha256sum.sh org.xwiki.platform:xwiki-platform-distribution-war 16.6.0 war"
}
if [ $1 == 'h' ]
then
  usage
  exit 0
fi
if [ -z $1 ]
then
  echo "Missing GROUPID:ARTIFACTID."

  usage
  exit 1
fi
if [ -z $2 ]
then
  echo "Missing VERSION."

  usage
  exit 1
fi
if [ -z $3 ]
then
  echo "Missing TYPE."

  usage
  exit 1
fi
id=$1
groupid=${id%%:*}
artifactid=${id##*:}
groupidpath=${groupid//./\/}
version=$2
type=$3
filename=${artifactid}-${version}.${type}
wget http://nexus.xwiki.org/nexus/content/groups/public/${groupidpath}/${artifactid}/${version}/${filename} && sha256sum ${filename} && rm ${filename}