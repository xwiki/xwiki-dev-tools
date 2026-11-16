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

# Publish the npm packages of an XWiki project: every package of its pnpm workspace that is not private.
# Used by maven-release.sh for a release, and by the CI for the SNAPSHOT versions.
#
# Usage: publish.sh <project directory> [--dry-run]
#
# The project directory holds the root pom.xml and the pnpm-workspace.yaml of the project, with its packages already
# built. The Node and pnpm versions (node.version, pnpm.version) and the registries (xwiki.npm.snapshot.registry,
# xwiki.npm.release.registry) are read from that pom, so that a branch is always published with its own build tools
# and registries. The registry credentials come from the user's .npmrc.

set -e

if [[ -z $1 || ! -f $1/pom.xml || ! -f $1/pnpm-workspace.yaml ]]
then
  echo "Usage: publish.sh <project directory> [--dry-run]" >&2
  echo "The project directory must hold a pom.xml and a pnpm-workspace.yaml." >&2
  exit 1
fi
PROJECT_DIR=$(cd "$1" && pwd)
shift
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function evaluate() {
  mvn -B -ntp -q -N -f "$PROJECT_DIR/pom.xml" help:evaluate -Dexpression=$1 -DforceStdout
}

NODE_VERSION=$(evaluate node.version)
PNPM_VERSION=$(evaluate pnpm.version)
SNAPSHOT_REGISTRY=$(evaluate xwiki.npm.snapshot.registry)
RELEASE_REGISTRY=$(evaluate xwiki.npm.release.registry)

# Install the Node and pnpm versions of the project, the way its build does. The downloads are cached in the local
# Maven repository. One directory per pair of versions, since the plugin keeps an existing installation as it is.
INSTALL_DIR=$SCRIPT_DIR/target/node-$NODE_VERSION-pnpm-$PNPM_VERSION
mvn -B -ntp -q -N -f "$PROJECT_DIR/pom.xml" com.github.eirslett:frontend-maven-plugin:install-node-and-pnpm \
  -DnodeVersion=$NODE_VERSION -DpnpmVersion=$PNPM_VERSION -DinstallDirectory="$INSTALL_DIR"
export PATH=$INSTALL_DIR/node:$PATH

(cd "$SCRIPT_DIR" && pnpm install --frozen-lockfile --silent)

node "$SCRIPT_DIR/publish.js" --snapshot-registry "$SNAPSHOT_REGISTRY" --release-registry "$RELEASE_REGISTRY" "$@" \
  "$PROJECT_DIR"
