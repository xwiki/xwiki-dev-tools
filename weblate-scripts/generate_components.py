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

import fnmatch
import json
import os

def generate_component(line, repo_urls, project):
    """Creates a component based on the given parameters"""
    name, path, repo_url, license, format = line.rsplit(';', 4)
    name, path, repo_url, license, format = name.strip(), path.strip(), repo_url.strip(), license.strip(), format.strip()
    slug = name.lower().replace(' ', '-').replace('.', '-')
    allowed_formats = ['Java', 'XWiki', 'XWikiPage']
    if not(format in allowed_formats):
        print("Format not correct for project {}: {}. Accepted formats: {}".format(name, format, allowed_formats))
        return
    if repo_url in repo_urls:
        repo_url = repo_urls[repo_url]
        push_url = ''
    else:
        repo_urls[repo_url] = 'weblate://{}/{}'.format(project, slug)
        push_url = repo_url
    basename, extension = path.rsplit('.', 1)
    filemask = '.translation/' + basename + '_*.properties'
    template = path
    if format == 'Java':
        file_format = 'xwiki-java-properties'
        filemask = basename + '_*.properties'
    elif format == 'XWiki':
        file_format = 'xwiki-page-properties'
        filemask = basename + '.*.xml'
    elif extension == 'XWikiPage':
        file_format = 'xwiki-fullpage'
        filemask = basename + '.*.xml'
    component = {
        "name": name,
        "slug": slug,
        "vcs": "github",
        "repo": repo_url,
        "push": push_url,
        "filemask": filemask,
        "template": template,
        "license": license,
        "file_format": file_format,
        "commit_message": "Translated using Weblate ({{ language_name }})\n\n"
                          "Currently translated at {{ stats.translated_percent }}% "
                          "({{ stats.translated }} of {{ stats.all }} strings)\n\n"
                          "Translation: {{ project_name }}/{{ component_name }}\n"
                          "Translate-URL: {{ url }}",
        "add_message": "Added translation using Weblate ({{ language_name }})",
        "delete_message": "Deleted translation using Weblate ({{ language_name }})",
        "committer_name": "XWiki",
        "committer_email": "noreply@xwiki.com",
        "merge_style": "rebase",
        "push_on_commit": False
    }

    return component

def main():
    directory = os.getcwd()
    for file_name in os.listdir(directory):
        if not fnmatch.fnmatch(file_name, "translation_list_*.txt"):
            continue
        start, end = len("translation_list_"), file_name.index(".txt")
        project = file_name[start:end]
        components = []
        repo_urls = {}
        with open(file_name, 'r') as f:
            for line in f.read().splitlines():
                if not line or line[0] == '#':
                    continue
                components.append(generate_component(line, repo_urls, project))
        with open("components_{}.json".format(project), "w+") as f:
            f.write(json.dumps(components))
        print("You can now call: weblate import_json --project {} components_{}.json [--ignore|--update]".format(project,project))

if __name__ == '__main__':
    """Main function"""
    main()
