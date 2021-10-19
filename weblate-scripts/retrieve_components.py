#!/usr/bin/env python

## This script aims at displaying the template path for each component on a given project
## information are directly retrieved from the XWiki.org Weblate instance.

import argparse
import requests

WEBLATE_REST_API_COMPONENTS_URL = "https://l10n.xwiki.org/api/projects/%s/components/?format=json"


def parse_arguments():
    parser = argparse.ArgumentParser(description='Output Weblate components paths')
    parser.add_argument('project_name', metavar='project_name', help='Project name')
    args = parser.parse_args()
    return args.project_name


def display_components(results):
    for component in results:
        print(component["template"])


def request_result(url):
    r = requests.get(url)
    if r.status_code == 200:
        json_answer = r.json()
        if json_answer["results"] and len(json_answer["results"]) > 0:
            display_components(json_answer["results"])
        if json_answer["next"]:
            request_result(json_answer["next"])


def main():
    """Main function"""
    project_name = parse_arguments()
    request_result(WEBLATE_REST_API_COMPONENTS_URL % project_name)


if __name__ == "__main__":
    main()