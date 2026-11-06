/*
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */

// Publish the npm packages of an XWiki project: every package of its pnpm workspace that is not private. Called by
// publish.sh, which provides the Node and pnpm versions of the project and the registries from its pom.
//
// Usage: node publish.js --snapshot-registry <url> --release-registry <url> [--dry-run] <workspace root>
//
// - A SNAPSHOT version is published to the snapshot registry, under the "snapshot" dist-tag, with SNAPSHOT replaced
//   by a timestamp. The package.json files are restored afterwards.
// - A release version is published to the release registry, under the dist-tag computed by computeDistTag().
// - --dry-run runs every check of the publication and sends nothing to the registry.
// Publishing again a release that is partly published is safe: pnpm skips the versions already on the registry, and
// the dist-tag stays the same.

import fs from 'fs';
import {execSync} from 'child_process';
import {parseArgs} from 'util';
import {computeDistTag, needsPublishedVersions} from './lib/tags.js';
import {readPublishedVersions} from './lib/registry.js';
import {publishCommand} from './lib/publish.js';
import {publishedVersion, readWorkspacePackages, timestampedVersion} from './lib/workspace.js';

const {values: options, positionals} = parseArgs({
  options: {
    'snapshot-registry': {type: 'string'},
    'release-registry': {type: 'string'},
    'dry-run': {type: 'boolean', default: false},
  },
  allowPositionals: true,
});
const root = positionals[0];
if (!root || !options['snapshot-registry'] || !options['release-registry']) {
  console.error('Usage: node publish.js --snapshot-registry <url> --release-registry <url> [--dry-run] '
    + '<workspace root>');
  process.exit(1);
}

const packages = readWorkspacePackages(root);
// The dist-tag is computed from the version declared in the package.json files, before a SNAPSHOT version is
// replaced by a timestamp.
const version = publishedVersion(packages);
const snapshot = version.includes('SNAPSHOT');
const registry = snapshot ? options['snapshot-registry'] : options['release-registry'];
const publishedNames = packages.filter(({private: isPrivate}) => !isPrivate).map(({name}) => name);
const existingVersions = needsPublishedVersions(version)
  ? await readPublishedVersions(publishedNames, {registry})
  : [];
const distTag = computeDistTag(version, existingVersions);
console.log(`Publishing ${publishedNames.length} packages at version ${version} to ${registry} under the "${distTag}"`
  + ` dist-tag${options['dry-run'] ? ' (dry run)' : ''}`);

// Every SNAPSHOT package gets the same timestamp, private ones included, so that the dependencies between the
// workspace packages ("workspace:*") resolve to the published versions.
const timestamp = Math.floor(Date.now() / 1000).toString();
const stamped = snapshot ? packages.filter(({version: packageVersion}) => packageVersion.includes('SNAPSHOT')) : [];
const originals = stamped.map(({packageJsonPath}) => [packageJsonPath, fs.readFileSync(packageJsonPath, 'utf8')]);
try {
  for (const {packageJsonPath} of stamped) {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    packageJson.version = timestampedVersion(packageJson.version, timestamp);
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2) + '\n');
  }
  execSync(publishCommand({registry, snapshot, distTag, dryRun: options['dry-run']}),
    {stdio: 'inherit', cwd: root});
} catch (error) {
  console.error(`The publication failed: ${error.message}`);
  process.exitCode = 1;
} finally {
  for (const [packageJsonPath, content] of originals) {
    fs.writeFileSync(packageJsonPath, content);
  }
}
