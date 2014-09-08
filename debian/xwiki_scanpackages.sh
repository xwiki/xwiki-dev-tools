#!/bin/bash
###############################################################################
#
# Update debian repository indexes
#
# It actually makes maven repositories expose a debian index.
#
# It also create a "virtual" stable debian repository in which is selected only
# stable releases (filter milestonnes and release candidates).
# It also create a "virtual" superstable debian repository in which is selected only
# configured super stable branch releases.
#
# Requirements:
# * This script is based on scna_packages. It is provided by dpkg-dev.
# * The script expect to find
# ** a "releases" folder containing a maven repository with the deployed
#    releases
# ** a "snapshots" dolder containing a maven repository with the deployed
#    snaphots
# ** make sure the "stable" folder exists if you want a filtered stable debian
#    repository
# ** make sure the "superstable" folder exists if you want a filtered super stable debian
#    repository. Also make sure you configured the super stable branch version
#
# Setup:
# You need to set the $ROOT_REP variable to where your maven repositories are
# located.
#
###############################################################################

ROOT_REP=/home/maven/public_html
SNAPSHOTS_REP="snapshots"
RELEASES_REP="releases"
STABLE_REP="stable"
SUPERSTABLE_REP="superstable"
SUPERSTABLE_BRANCH="5.4"
GPG_KEY="0398E391"

cd "$ROOT_REP"

## superstable
if [ -d superstable ]; then
  echo "Generates super stable index"

  rm -rf /tmp/superstable_scanpackages
  mkdir -p /tmp/superstable_scanpackages/$RELEASES_REP

  function link_package ()
  {
    basepath=`dirname $1`
    basepath=${basepath##$ROOT_REP/}
    basepath=${basepath%*/}
    mkdir -p $basepath
    fullpath=`readlink -f $1`
    ln -sf $fullpath "/tmp/superstable_scanpackages/$basepath"
  }

  cd /tmp/superstable_scanpackages/

  for i in $(find "$ROOT_REP/$RELEASES_REP/org" -name "*-$SUPERSTABLE_BRANCH.*.deb" ) ; do
    link_package $i
  done

  dpkg-scanpackages -m $RELEASES_REP /dev/null > "$ROOT_REP/$SUPERSTABLE_REP/Packages.tmp" && mv -f "$ROOT_REP/$SUPERSTABLE_REP/Packages.tmp" "$ROOT_REP/$SUPERSTABLE_REP/Packages"
  gzip -9c "$ROOT_REP/$SUPERSTABLE_REP/Packages" > "$ROOT_REP/$SUPERSTABLE_REP/Packages.gz.tmp" && mv -f "$ROOT_REP/$SUPERSTABLE_REP/Packages.gz.tmp" "$ROOT_REP/$SUPERSTABLE_REP/Packages.gz"

  cd "$ROOT_REP"

  rm -rf $SUPERSTABLE_REP/Release $SUPERSTABLE_REP/Release.gpg
  apt-ftparchive -c=$SUPERSTABLE_REP/Release.conf release $SUPERSTABLE_REP > $SUPERSTABLE_REP/Release
  gpg -abs --default-key $GPG_KEY -o $SUPERSTABLE_REP/Release.gpg $SUPERSTABLE_REP/Release
fi

## stable
if [ -d stable ]; then
  echo "Generates stable index"

  rm -rf /tmp/stable_scanpackages
  mkdir -p /tmp/stable_scanpackages/$RELEASES_REP

  function link_package ()
  {
    basepath=`dirname $1`
    basepath=${basepath##$ROOT_REP/}
    basepath=${basepath%*/}
    mkdir -p $basepath
    fullpath=`readlink -f $1`
    ln -sf $fullpath "/tmp/stable_scanpackages/$basepath"
  }

  cd /tmp/stable_scanpackages/

  for i in $(find "$ROOT_REP/$RELEASES_REP/org" -name "*.[0-9][0-9].deb" ) ; do
    link_package $i
  done

  for i in $(find "$ROOT_REP/$RELEASES_REP/org" -name "*.[0-9].deb" ) ; do
    link_package $i
  done

  dpkg-scanpackages -m $RELEASES_REP /dev/null > "$ROOT_REP/$STABLE_REP/Packages.tmp" && mv -f "$ROOT_REP/$STABLE_REP/Packages.tmp" "$ROOT_REP/$STABLE_REP/Packages"
  gzip -9c "$ROOT_REP/$STABLE_REP/Packages" > "$ROOT_REP/$STABLE_REP/Packages.gz.tmp" && mv -f "$ROOT_REP/$STABLE_REP/Packages.gz.tmp" "$ROOT_REP/$STABLE_REP/Packages.gz"

  cd "$ROOT_REP"

  rm -rf $STABLE_REP/Release $STABLE_REP/Release.gpg
  apt-ftparchive -c=$STABLE_REP/Release.conf release $STABLE_REP > $STABLE_REP/Release
  gpg -abs --default-key $GPG_KEY -o $STABLE_REP/Release.gpg $STABLE_REP/Release
fi

## releases
if [ -d $RELEASES_REP ]; then
  echo "Generates releases index"

  dpkg-scanpackages -m $RELEASES_REP/org /dev/null > $RELEASES_REP/Packages.tmp && mv -f $RELEASES_REP/Packages.tmp $RELEASES_REP/Packages
  gzip -9c $RELEASES_REP/Packages > $RELEASES_REP/Packages.gz.tmp && mv -f $RELEASES_REP/Packages.gz.tmp $RELEASES_REP/Packages.gz

  rm -rf $RELEASES_REP/Release $RELEASES_REP/Release.gpg
  apt-ftparchive -c=$RELEASES_REP/Release.conf release $RELEASES_REP > $RELEASES_REP/Release
  gpg -abs --default-key $GPG_KEY -o $RELEASES_REP/Release.gpg $RELEASES_REP/Release
fi

## snapshots
# Unusable yet: see https://jira.xwiki.org/browse/XE-1090
#if [ -d $SNAPSHOTS_REP ]; then
#  echo "Generates snapshots index"
#
#  dpkg-scanpackages -m $SNAPSHOTS_REP /dev/null > $SNAPSHOTS_REP/Packages.tmp && mv -f $SNAPSHOTS_REP/Packages.tmp $SNAPSHOTS_REP/Packages
#  gzip -9c $SNAPSHOTS_REP/Packages > $SNAPSHOTS_REP/Packages.gz.tmp && mv -f $SNAPSHOTS_REP/Packages.gz.tmp $SNAPSHOTS_REP/Packages.gz
#fi
