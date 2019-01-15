#!/usr/bin/env python2

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

import os
import re
import readline
import sys

from collections import namedtuple
from subprocess import call

Project = namedtuple('Project', ['name', 'file'])
Component = namedtuple('Component', ['name', 'path', 'url'])
urls_vcs_names = {}

def import_component(project, component):
    ans = None
    while ans is None:
        ans = raw_input('Do you want to import the new component in Weblate?'
                        ' (y/n): ')
        if ans.lower() in ['y', 'yes']:
            ans = True
        elif ans.lower() in ['n', 'no', 'q']:
            ans = False
        else:
            ans = None
    if not ans:
        return

    vcs_path = None
    while vcs_path is None:
        vcs_path = raw_input('Please specify the Weblate vcs path: ').strip()
        if not vcs_path or not os.path.exists(vcs_path):
            print("This directory doesn't exists")
            vcs_path = None

    component_vcs_path = (vcs_path + ('' if vcs_path[-1] == '/' else '/')
                          + urls_vcs_names[component.url])
    if not os.path.exists(component_vcs_path):
        os.makedirs(component_vcs_path)
    if not os.path.exists(component_vcs_path + '/.git'):
        print
        print 'git clone ' + component.url + ' ' + component_vcs_path
        call(['git', 'clone', component.url, component_vcs_path])

    print
    print ('./call_updates.py ' + vcs_path + ' --project ' + project.name
         + ' --component ' + component.url)
    os.system('./call_updates.py ' + vcs_path + ' --project ' + project.name
            + ' --component ' + component.url)

    print
    print './generate_components.py'
    os.system('./generate_components.py')

    print
    print 'You can now import the new component using these commands:'
    print ('$ weblate import_json --project ' + project.name + ' components_'
          + project.name + '.json --ignore')

    slug = component.name.lower().replace(' ', '-').replace('.', '-')
    print ('$ weblate install_addon --addon xwiki.post_update '
          + project.name + '/' + slug)
    print ('$ weblate install_addon --addon xwiki.pre_commit '
            + project.name + '/' + slug)
    print ('$ weblate install_addon --addon xwiki.post_commit '
            + project.name + '/' + slug)

def write_component(project, component):
    with open(project.file, 'a') as project_file:
        project_file.write(component.name + '; ' + component.path + '; '
                           + component.url + '\n')
    print 'The component has been saved, please commit the file '
    print '"' + project.file + '"' + ' when you are done'
    print

def add_url(component):
    slug = component.name.lower().replace(' ', '-').replace('.', '-')
    if component.url not in urls_vcs_names:
        urls_vcs_names[component.url] = project.name + '/' + slug

def get_component(components):
    component_names = set(map(lambda x: x.name, components))
    component_paths_urls = dict(
            ((component.path, component.url), component.name)
            for component in components)
    component_name = raw_input('Name of the new component: ').strip()
    if component_name in component_names:
        sys.exit('Component with this name already exists')
    component_path = (raw_input('Relative path to the translation file: ')
                      .strip())
    if components:
        print ' Existing component urls:'
        for url in set(map(lambda c: c.url, components)):
            print '  ' + url
    component_url = raw_input('Repository URL: ').strip()
    component = Component(component_name, component_path, component_url)
    if (component.path, component.url) in component_paths_urls:
        sys.exit('This component already exists and is named: '
                 + component_paths_urls[(component.path, component.url)])
    add_url(component)

    print
    return component

def get_components(project):
    components = []
    with open(project.file) as project_file:
        for line in project_file:
            line = line.strip()
            if not line or line[0] == '#':
                continue
            component = Component(*map(str.strip, line.rsplit(';', 2)))
            components.append(component)
            add_url(component)
    return components

def get_project(projects):
    print('Projects found:')
    for i, project in enumerate(projects):
        print(('  %d. ' + project.name) % (i + 1))
    project_id = -1
    while not (0 <= project_id < len(projects)):
        try:
            project_id = int(input('Please select a project (1 - '
                         + str(len(projects)) + '): ') - 1)
        except (NameError, SyntaxError, TypeError):
            project_id = -1

    print
    return projects[project_id]

def get_project_list():
    DIRECTORY = os.getcwd()
    projects = []
    for file_name in os.listdir(DIRECTORY):
        match = re.match('translation_list_(.*).txt', file_name)
        if match:
            projects.append(Project(match.group(1), file_name))
    return sorted(projects)

def display_intro():
    print 'You are about to create a new XWiki component in Weblate.'
    print
    print 'You will need to select an existing project and then specify the'
    print 'name of the new component, the relative path to the translation file'
    print 'and the repository URL.'
    print
    print 'Help:'
    print '- Example of component name: XWiki Core Resources'
    print '- Example of translation file path:'
    print('    xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/'
          'ApplicationResources.properties')
    print '- Example of repository URL: https://github.com/xwiki/xwiki-platform'
    print '- Be aware that, for performances reasons, the repository URL should'
    print '  be the exactly the same as the one of other existing components'
    print '  whenever it is possible.'
    print '- Example of vcs path:'
    print '    /home/weblate/weblate/lib/python2.7/site-packages/data/vcs'
    print

if __name__ == '__main__':
    projects = get_project_list()
    if not projects:
        sys.exit('Could not find any project.\nThe script needs to be executed'
                 ' next to the translation_list_*.txt files.')
    display_intro()
    project = get_project(projects)
    components = get_components(project)
    component = get_component(components)
    write_component(project, component)
    import_component(project, component)
