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

import fs from 'fs';
import path from 'path';
import {execFileSync} from 'child_process';

/**
 * @param {string} root the root directory of a pnpm workspace
 * @param {function} run runs a command in a directory and returns its output, injectable for the tests
 * @returns {{name: string, version: string, private: boolean, packageJsonPath: string}[]} the packages of the
 *   workspace that have a version, i.e. every package except the workspace root
 */
export function readWorkspacePackages(root, run = runCommand) {
  // pnpm resolves the workspace from pnpm-workspace.yaml, so the packages listed are exactly the ones that
  // "pnpm -r publish" considers.
  const projects = JSON.parse(run('pnpm', ['-r', 'ls', '--json', '--depth', '-1'], root));
  return projects
    .map(project => {
      const packageJsonPath = path.join(project.path, 'package.json');
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
      return {
        name: packageJson.name,
        version: packageJson.version,
        private: packageJson.private === true,
        packageJsonPath
      };
    })
    .filter(({version}) => version);
}

function runCommand(command, args, cwd) {
  return execFileSync(command, args, {cwd, encoding: 'utf8'});
}

/**
 * @param {{version: string, private: boolean}[]} packages the packages of the workspace
 * @returns {string} the version of the packages "pnpm publish" sends to the registry
 * @throws {Error} when there is no such package, or when they do not all have the same version
 */
export function publishedVersion(packages) {
  const versions = [...new Set(packages.filter(({private: isPrivate}) => !isPrivate).map(({version}) => version))];
  if (versions.length !== 1) {
    throw new Error(`Expected a single version to publish but found: [${versions.join(', ')}]`);
  }
  return versions[0];
}

/**
 * @param {string} version a SNAPSHOT version, e.g. "18.10.0-SNAPSHOT"
 * @param {string} timestamp the timestamp of the publication
 * @returns {string} the version to publish, e.g. "18.10.0-1793975578": a registry refuses to publish the same version
 *   twice, so every SNAPSHOT publication needs a version of its own
 */
export function timestampedVersion(version, timestamp) {
  return version.replace('SNAPSHOT', timestamp);
}
