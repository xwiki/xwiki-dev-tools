#!/usr/bin/env python3
import os.path
import os
import subprocess

import requests
import argparse
import re
import datetime as dt

WEBLATE_TOKEN_FILE="~/.weblate_token"
WEBLATE_REST_API_ENDPOINT = "https://l10n.xwiki.org/api/"
WEBLATE_CHANGES_ENDPOINT = WEBLATE_REST_API_ENDPOINT + "changes/"
XWIKI_PROJECTS_SLUG = ['xwiki-platform', 'xwiki-commons', 'xwiki-rendering']
BRANCH_PATTERN = re.compile('stable-\\d+\\.(?P<minor>\\d+)\\.x')
VERSION_PATTERN = re.compile('^(?P<major>\\d+)\\.(?P<minor>\\d+).*')
GITHUB_TAG_ENDPOINT = "https://api.github.com/repos/xwiki/xwiki-platform/git/matching-refs/tags/"

BRANCH_MASTER = 'master'
BRANCH_LTS = 'lts'
BRANCH_MID_YEAR_LTS = 'mid-year-lts'

def get_token_header(token):
    if token:
        return {'Authorization': 'Token {}'.format(token)}
    return None

def retrieve_changes_from_url_and_get_language(url, payload, inspected_translations, branch, languages, projects,
                                               token):
    response = requests.get(url, payload, headers=get_token_header(token))
    response.raise_for_status()
    json = response.json()
    if payload:
        print("Found a total of {} results from Weblate API for translation changes.".format(json['count']))
        print("{} authorized requests remaining to Weblate REST API - Reset to {} in {} seconds".format(
            response.headers['X-RateLimit-Remaining'],
            response.headers['X-RateLimit-Limit'],
            response.headers['X-RateLimit-Reset']))
    for result in json['results']:
        count_language_if_needed(result, inspected_translations, branch, languages, projects, token)
    if json['next']:
        retrieve_changes_from_url_and_get_language(json['next'], None, inspected_translations, branch, languages,
                                                   projects, token)

def count_language_if_needed(result, inspected_translations, branch, languages, projects, token):
    if result['translation'] not in inspected_translations:
        print("Inspecting change: {} about translation {}".format(result['url'], result['translation']))
        response = requests.get(result['translation'], headers=get_token_header(token))
        response.raise_for_status()
        json = response.json()
        if not is_matching_branch(json['component']['branch'], branch):
            print("Change ignored: branch {} not matching with {}".format(json['component']['branch'], branch))
        elif json['component']['project']['slug'] not in projects:
            print("Change ignored: project {} not found in {}".format(json['component']['project']['slug'], projects))
        elif json['language_code'] in languages:
            print("Change ignored: language {} already found".format(json['language_code']))
        else:
            print("Language added: " + json['language_code'])
            languages.append(json['language_code'])
        inspected_translations.append(result['translation'])

def is_matching_branch(json_branch_value, branch):
    if branch == BRANCH_MASTER and json_branch_value == BRANCH_MASTER:
        return True
    else:
        match = BRANCH_PATTERN.match(json_branch_value)
        return match and branch == find_branch_from_minor(match.group('minor'))

def retrieve_languages_for_changes(date_previous_version, date_next_version, branch, projects, token):
    ## List of actions can be found in https://github.com/WeblateOrg/weblate/blob/main/weblate/trans/actions.py#L16
    request_payload = {
        'action': [2, 5], ## 2 is translation changed and 5 is translation added
        'timestamp_after': date_previous_version,
        'timestamp_before': date_next_version,
    }
    inspected_translations = []
    languages = []
    retrieve_changes_from_url_and_get_language(WEBLATE_CHANGES_ENDPOINT, request_payload, inspected_translations,
                                               branch, languages, projects, token)
    return sorted(languages)

def find_date_for_version(version, repository):
    ## FIXME: only works for XS right now
    tagName = "xwiki-platform-" + version
    response = requests.get(GITHUB_TAG_ENDPOINT + tagName)
    response.raise_for_status()
    json = response.json()
    date = None
    for entry in json:
        if entry['ref'] == "refs/tags/" + tagName:
            date = find_date_from_tag(entry['object']['url'])
            break

    return date

def find_date_from_tag(tagInfoUrl):
    response = requests.get(tagInfoUrl)
    response.raise_for_status()
    json = response.json()
    return json['tagger']['date']

def find_branch_from_minor(minor_version):
    if minor_version == '4':
        return BRANCH_MID_YEAR_LTS
    elif minor_version == '10':
        return BRANCH_LTS
    else:
        return BRANCH_MASTER

def load_token_from_file():
    token_file = os.path.expanduser(WEBLATE_TOKEN_FILE)
    if os.path.isfile(token_file):
        with open(token_file, "r") as file:
            token = file.read()
            return token.strip()
    return None

def parse_arguments():
    parser = argparse.ArgumentParser(description='Compute contributed languages from one version to another')
    parser.add_argument('previous_version', metavar='previous_version', help='Previous version')
    parser.add_argument('next_version', metavar='next_version', help='Next version')
    parser.add_argument('-p', '--project', metavar='project', help='Project name (default is xwiki)')
    parser.add_argument('-r', '--repository', metavar='repository', help='Repository URL (mandatory when project '
                                                                         'argument is used)')
    parser.add_argument('-t', '--token', metavar='token', help='Weblate token in case of authenticated request')
    return parser.parse_args()

def find_branch_creation_date(branch_name):
    command = "git show -s --format=%cd --date=iso8601 $(git merge-base {} master)".format(branch_name)
    result = subprocess.check_output(command, shell=True, text=True)
    return dt.datetime.fromisoformat(result.strip())

def main():
    args = parse_arguments()
    previous_version = args.previous_version
    next_version = args.next_version
    current_directory = os.getcwd()

    if args.project:
        projects = [args.project]
        if not args.repository:
            raise RuntimeError("The repository is mandatory.")
        repository = args.repository
    else:
        projects = XWIKI_PROJECTS_SLUG
        repository = "https://github.com/xwiki/xwiki-platform"
    next_version_matcher = VERSION_PATTERN.match(next_version)
    if not next_version_matcher:
        raise RuntimeError("The version number is invalid.")

    previous_version_date = find_date_for_version(previous_version, repository)
    is_first_rc = next_version.endswith('-rc-1')
    if is_first_rc:
        branch = BRANCH_MASTER
        next_version_branch = "stable-{}.{}.x".format(next_version_matcher.group('major'), next_version_matcher.group('minor'))
        next_version_date = find_branch_creation_date(next_version_branch)
    else:
        branch = find_branch_from_minor(next_version_matcher.group('minor'))
        next_version_date = find_date_for_version(next_version, repository)

    if not previous_version_date:
        raise RuntimeError("Cannot find next version date")
    if not previous_version_date:
        raise RuntimeError("Cannot find previous version date")
    print("Start looking for translations between {} and {} on branch {} ".format(previous_version_date,
                                                                               next_version_date, branch))
    token = args.token or load_token_from_file()
    if not token:
        print("WARNING: No Weblate token provided, the request will be performed with anonymous user which have a "
              "limited rate.")

    languages = retrieve_languages_for_changes(previous_version_date, next_version_date, branch, projects, token)
    print("Languages: \n%s" % ','.join(languages))

if __name__ == "__main__":
    main()