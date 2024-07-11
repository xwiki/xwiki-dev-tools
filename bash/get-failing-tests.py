#!/usr/bin/env python

import requests
import collections
import argparse


def get_failing_tests_by_block(base_url):
    url = base_url + '/testReport/api/json'
    response = requests.get(url)
    data = response.json()
    failing_tests_by_block = collections.defaultdict(list)
    for suite in data['suites']:
        for case in suite['cases']:
            if case['status'] != 'PASSED' and case['status'] != 'SKIPPED' and case['status'] != 'FIXED':
                failing_tests_by_block[suite['enclosingBlocks'][0]].append(case['className'] + '.' + case['name'])

    return failing_tests_by_block


def get_maven_commands(base_url, failing_tests_by_block):
    maven_commands = []

    # Get information about the build to get the blocks with failures
    for block in failing_tests_by_block.keys():
        url = base_url + '/execution/node/' + block + '/wfapi/describe'
        response = requests.get(url)
        data = response.json()
        stages = data['stageFlowNodes']
        for stage in stages:
            # Check if the parameter description starts with "mvn "
            if stage['parameterDescription'].startswith('mvn '):
                print("Failing stage: " + data['name'])
                print("Failing tests:")
                for test in failing_tests_by_block[block]:
                    print('  -', test)
                print('Maven command: ')
                print(stage['parameterDescription'])
                print()
                maven_commands.append(stage['parameterDescription'])

    return maven_commands


if __name__ == '__main__':
    # Get the build URL from the command line
    parser = argparse.ArgumentParser(description='Get failing tests from a Jenkins build')
    parser.add_argument('build_url', help='The URL of the Jenkins build')
    args = parser.parse_args()
    base_url = args.build_url

    failing_tests_by_block = get_failing_tests_by_block(base_url)
    maven_commands = get_maven_commands(base_url, failing_tests_by_block)
    print('\n'.join(maven_commands))
