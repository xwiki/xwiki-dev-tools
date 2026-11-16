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
import os from 'os';
import path from 'path';
import {afterEach, beforeEach, describe, expect, it} from 'vitest';
import {publishedVersion, readWorkspacePackages, timestampedVersion} from './workspace.js';

describe('readWorkspacePackages', () => {
  let root;

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-'));
  });

  afterEach(() => {
    fs.rmSync(root, {recursive: true, force: true});
  });

  function writePackage(directory, packageJson) {
    const packageDirectory = path.join(root, directory);
    fs.mkdirSync(packageDirectory, {recursive: true});
    fs.writeFileSync(path.join(packageDirectory, 'package.json'), JSON.stringify(packageJson));
    return {name: packageJson.name, path: packageDirectory, private: packageJson.private === true};
  }

  it('reads the packages pnpm lists, except the workspace root which has no version', () => {
    const projects = [
      writePackage('.', {name: '@xwiki/platform', private: true}),
      writePackage('api', {name: '@xwiki/platform-api', version: '18.10.0-SNAPSHOT'}),
      writePackage('webjar', {name: 'xwiki-webjar', version: '0.0.0', private: true}),
    ];
    const calls = [];
    const run = (command, args, cwd) => {
      calls.push([command, ...args, cwd]);
      return JSON.stringify(projects);
    };

    expect(readWorkspacePackages(root, run)).toEqual([
      {name: '@xwiki/platform-api', version: '18.10.0-SNAPSHOT', private: false,
        packageJsonPath: path.join(root, 'api', 'package.json')},
      {name: 'xwiki-webjar', version: '0.0.0', private: true,
        packageJsonPath: path.join(root, 'webjar', 'package.json')},
    ]);
    expect(calls).toEqual([['pnpm', '-r', 'ls', '--json', '--depth', '-1', root]]);
  });
});

describe('publishedVersion', () => {
  it('ignores the version of the private packages', () => {
    expect(publishedVersion([
      {version: '18.10.0', private: false},
      {version: '18.10.0', private: false},
      {version: '0.0.0', private: true},
    ])).toBe('18.10.0');
  });

  it('fails when the published packages have different versions', () => {
    expect(() => publishedVersion([{version: '18.10.0', private: false}, {version: '18.9.0', private: false}]))
      .toThrow('Expected a single version to publish but found: [18.10.0, 18.9.0]');
  });

  it('fails when no package is published', () => {
    expect(() => publishedVersion([{version: '0.0.0', private: true}]))
      .toThrow('Expected a single version to publish but found: []');
  });
});

describe('timestampedVersion', () => {
  it('replaces SNAPSHOT with the timestamp', () => {
    expect(timestampedVersion('18.10.0-SNAPSHOT', '1793975578')).toBe('18.10.0-1793975578');
  });
});
