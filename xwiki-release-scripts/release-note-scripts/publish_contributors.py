#!/usr/bin/env python3

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

"""Computes the contributors of a release with list_contributors.sh and stores them in the "Contributors" entry of the
corresponding release note, where the {{releasenotecontributors/}} macro renders them.

list_contributors.sh is called from here rather than piped into this script because both need the same versions: the
end version gives both the end of the git range and the release note to update. With a pipe, the versions would have
to be passed to each script separately, and nothing would ensure that the list is the one of the release note.

Only the Python standard library is used, so that the script runs on the release machine without installing anything.
"""

import argparse
import base64
import getpass
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

LIST_CONTRIBUTORS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'list_contributors.sh')

PRODUCT = 'XWiki'
ENTRY_CLASS = 'ReleaseNotes.Code.EntryClass'
CONTRIBUTORS_CLASS = 'ReleaseNotes.Code.ContributorsClass'
RELEASE_NOTE_CLASS = 'ReleaseNotes.Code.ReleaseNoteClass'

# Authors and co-authors that are not people (AI agents, dependency updaters, service accounts). Regular expressions,
# matched against whole contributor names.
BOT_PATTERNS = [
    r'.*\[bot\]',
    r'Claude( .*)?',
    r'Copilot',
    r'Kimi Code',
    r'Mend Renovate',
    r'anonymous',
    r'XWiki',
]
BOT_REGEX = re.compile('|'.join('(?:{})'.format(pattern) for pattern in BOT_PATTERNS))

EXIT_USAGE = 1
EXIT_RELEASE_NOTE = 2
EXIT_CONTRIBUTORS = 3
EXIT_PUBLISH = 4


class ScriptError(Exception):
    def __init__(self, message, exit_code=1):
        super().__init__(message)
        self.exit_code = exit_code


class RestError(Exception):
    pass


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse exits with 2 on usage errors, which is the exit code of the release note checks here.
        self.print_usage(sys.stderr)
        self.exit(EXIT_USAGE, '{}: error: {}\n'.format(self.prog, message))


def log(message=''):
    """Everything but the contributor names goes to stderr, so that stdout can be consumed directly."""
    print(message, file=sys.stderr)


class Wiki:
    def __init__(self, url):
        self.url = url
        self.rest_base = url + '/rest/wikis/xwiki'
        self.authorization = None

    def ask_credentials(self):
        username = os.environ.get('XWIKI_USERNAME')
        password = os.environ.get('XWIKI_PASSWORD')
        if not username:
            # The prompt goes to stderr, like the rest of the messages.
            sys.stderr.write('Username on {}: '.format(self.url))
            sys.stderr.flush()
            username = input()
        if not password:
            password = getpass.getpass('Password for [{}]: '.format(username))
        token = base64.b64encode('{}:{}'.format(username, password).encode('utf-8')).decode('ascii')
        self.authorization = 'Basic ' + token

    def request(self, url, accepted, method='GET', data=None):
        """Performs a REST request and returns the status and the decoded JSON response, or None when the response has
        no body. Fails on HTTP errors, except for the accepted statuses."""
        headers = {'Accept': 'application/json'}
        if data is not None:
            headers['Content-Type'] = 'application/json'
            data = json.dumps(data).encode('utf-8')
        if self.authorization:
            headers['Authorization'] = self.authorization
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request) as response:
                status, body = response.status, response.read()
        except urllib.error.HTTPError as e:
            status, body = e.code, None
        except urllib.error.URLError as e:
            raise RestError('unable to reach [{}]: {}'.format(url, e.reason))
        if status not in accepted:
            raise RestError('unexpected HTTP status [{}] for [{} {}]'.format(status, method, url))
        if not body:
            return status, None
        try:
            return status, json.loads(body)
        except ValueError as e:
            raise RestError('invalid JSON response for [{} {}]: {}'.format(method, url, e))

    def object_number(self, page_url, class_name):
        """Returns the number of the first object of the given class on the page at the given REST URL, or None."""
        status, objects = self.request('{}/objects/{}'.format(page_url, class_name), (200, 404))
        if status == 404 or not objects.get('objectSummaries'):
            return None
        return objects['objectSummaries'][0]['number']

    def object_property(self, page_url, class_name, number, name):
        _, prop = self.request('{}/objects/{}/{}/properties/{}'.format(page_url, class_name, number, name), (200,))
        # XWiki stores the line breaks of textarea properties as CRLF.
        return (prop.get('value') or '').replace('\r', '')


def json_object(class_name, **properties):
    """Returns the JSON representation of an object of the given class with the given properties."""
    return {
        'className': class_name,
        'properties': [{'name': name, 'value': value} for name, value in properties.items()],
    }


def normalize(names):
    """Drops the blank names and the duplicates, and sorts the others."""
    names = {name.strip() for name in names if name.strip()}
    return sorted(names, key=lambda name: (name.casefold(), name))


def parse_arguments():
    parser = ArgumentParser(
        usage='%(prog)s [options] start_version end_version',
        description='Publish the contributors of a release to its release note.',
        epilog='Example: %(prog)s 18.7.0 18.8.0-rc-1\n\n'
               'Must be executed from the \'xwiki-trunks\' parent folder, like list_contributors.sh.\n\n'
               'Credentials are read from XWIKI_USERNAME and XWIKI_PASSWORD, or asked for interactively.',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('start_version')
    parser.add_argument('end_version')
    parser.add_argument('-n', '--dry-run', action='store_true',
                        help='only display what would be published; no credentials needed')
    parser.add_argument('-f', '--force', action='store_true', help='replace an existing contributors list')
    parser.add_argument('-w', '--wiki-url', default='https://www.xwiki.org/xwiki', metavar='URL',
                        help='base URL of the wiki (default: %(default)s)')
    parser.add_argument('-r', '--release-note', metavar='SPACE',
                        help='space of the release note, e.g. ReleaseNotes/Data/XWiki/18.8.0RC1 '
                             '(default: derived from end_version)')
    arguments = parser.parse_args()
    arguments.wiki_url = arguments.wiki_url.rstrip('/')
    if arguments.release_note:
        arguments.release_note = arguments.release_note.rstrip('/')
    else:
        # The release note page name uses the version without dashes (e.g. 18.8.0-rc-1 -> 18.8.0RC1).
        arguments.release_note = 'ReleaseNotes/Data/{}/{}'.format(PRODUCT,
                                                                   arguments.end_version.replace('-rc-', 'RC', 1))
    return arguments


def check_release_note(wiki, release_note_url, arguments):
    """Checks that the target is the release note of the end version."""
    log('Checking release note [{}] on [{}]...'.format(arguments.release_note, arguments.wiki_url))
    number = wiki.object_number(release_note_url, RELEASE_NOTE_CLASS)
    if number is None:
        raise ScriptError('no release note found at [{}]. Create it first or use --release-note.'
                          .format(arguments.release_note), EXIT_RELEASE_NOTE)
    version = wiki.object_property(release_note_url, RELEASE_NOTE_CLASS, number, 'version').strip()
    if version != arguments.end_version:
        raise ScriptError('the release note at [{}] is for version [{}], not [{}].'
                          .format(arguments.release_note, version, arguments.end_version), EXIT_RELEASE_NOTE)


def compute_contributors(arguments):
    result = subprocess.run([LIST_CONTRIBUTORS, arguments.start_version, arguments.end_version],
                            stdout=subprocess.PIPE, text=True)
    if result.returncode != 0:
        raise ScriptError('unable to list the contributors.', EXIT_CONTRIBUTORS)
    contributors = [name for name in normalize(result.stdout.splitlines()) if not BOT_REGEX.fullmatch(name)]
    if not contributors:
        raise ScriptError('no contributors found between [{}] and [{}].'
                          .format(arguments.start_version, arguments.end_version), EXIT_CONTRIBUTORS)
    return contributors


def publish(wiki, contributors_url, contributors, contributors_number, entry_number, arguments):
    contributors_json = json_object(CONTRIBUTORS_CLASS, contributors='\n'.join(contributors))
    entry_json = json_object(ENTRY_CLASS, product=PRODUCT, type='Contributors', version=arguments.end_version)

    if contributors_number is None and entry_number is None:
        log('Creating [{}/Contributors]...'.format(arguments.release_note))
        wiki.request(contributors_url, (201, 202), 'PUT',
                     {'title': 'Contributors', 'hidden': True, 'content': ''})

    for class_name, number, body in ((ENTRY_CLASS, entry_number, entry_json),
                                    (CONTRIBUTORS_CLASS, contributors_number, contributors_json)):
        if number is not None:
            wiki.request('{}/objects/{}/{}'.format(contributors_url, class_name, number), (202,), 'PUT', body)
        else:
            wiki.request(contributors_url + '/objects', (201,), 'POST', body)


def run(arguments):
    wiki = Wiki(arguments.wiki_url)
    # Convert a space path (A/B/C) to its REST path (spaces/A/spaces/B/spaces/C).
    rest_space_path = '/'.join('spaces/' + urllib.parse.quote(space) for space in arguments.release_note.split('/'))
    release_note_url = '{}/{}/pages/WebHome'.format(wiki.rest_base, rest_space_path)
    contributors_url = '{}/{}/spaces/Contributors/pages/WebHome'.format(wiki.rest_base, rest_space_path)

    try:
        check_release_note(wiki, release_note_url, arguments)
    except RestError as e:
        raise ScriptError(str(e), EXIT_RELEASE_NOTE)

    contributors = compute_contributors(arguments)
    log()
    log('Contributors of [{}] ({}):'.format(arguments.end_version, len(contributors)))
    print('\n'.join(contributors), flush=True)
    log()

    # Compare with the existing contributors list, if any. A failed read is an error rather than an empty list, which
    # --force would then overwrite.
    try:
        contributors_number = wiki.object_number(contributors_url, CONTRIBUTORS_CLASS)
        entry_number = wiki.object_number(contributors_url, ENTRY_CLASS)
        existing = None
        if contributors_number is not None:
            existing = normalize(wiki.object_property(contributors_url, CONTRIBUTORS_CLASS, contributors_number,
                                                      'contributors').split('\n'))
    except RestError as e:
        raise ScriptError(str(e), EXIT_RELEASE_NOTE)

    if existing is not None:
        if existing == contributors:
            log('The release note already lists these contributors, nothing to do.')
            return
        log('The release note already lists contributors (< existing, > computed):')
        for name in existing:
            if name not in contributors:
                log('< ' + name)
        for name in contributors:
            if name not in existing:
                log('> ' + name)
        log()
        if not arguments.force:
            if arguments.dry_run:
                log('Dry run: the existing list would be kept; use --force to replace it.')
                return
            raise ScriptError('not replacing the existing list; use --force to replace it.')

    if arguments.dry_run:
        log('Dry run: the list would be published to [{}/Contributors].'.format(arguments.release_note))
        return

    wiki.ask_credentials()
    try:
        publish(wiki, contributors_url, contributors, contributors_number, entry_number, arguments)
    except RestError as e:
        raise ScriptError(str(e), EXIT_PUBLISH)
    log('Contributors published to [{}/Contributors].'.format(arguments.release_note))


def main():
    arguments = parse_arguments()
    try:
        run(arguments)
    except ScriptError as e:
        log('ERROR: {}'.format(e))
        sys.exit(e.exit_code)
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == '__main__':
    main()
