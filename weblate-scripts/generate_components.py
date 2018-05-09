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
import sys

def generate_component(name, slug, path, pre_commit_script, post_commit_script):
    """Creates a component based on the given parameters"""
    basename, extension = path.rsplit('.', 1)
    filemask = '.translation/' + basename + '_*.properties'
    template = '.translation/' + basename + '_en.properties'
    if extension == 'properties':
        file_format = 'properties'
        extra_commit_file = path + "\n" + basename + "_%(language)s.properties"
    elif extension == 'xml':
        file_format = 'properties-utf8'
        extra_commit_file = path + "\n" + basename + ".%(language)s.xml"
    else:
        print "Wrong extension: {}".format(extension)
    component = {
        "name": name,
        "slug": slug,
        "vcs": "github",
        "filemask": filemask,
        "template": template,
        "file_format": file_format,
        "extra_commit_file": extra_commit_file,
        "pre_commit_script": pre_commit_script,
        "post_commit_script": post_commit_script,
        "commit_message": "Translated using Weblate (%(language_name)s)\n"
                          "Currently translated at %(translated_percent)s%% "
                          "(%(translated)s of %(total)s strings)\n"
                          "Translation: %(project)s/%(component)s\n"
                          "Translate-URL: %(url)s",
        "committer_name": "XWiki",
        "committer_email": "noreply@xwiki.com"
    }

    return component

if __name__ == '__main__':
    DIRECTORY = os.getcwd()
    PRE_COMMIT_SCRIPT = sys.argv[1] if len(sys.argv) > 2 else DIRECTORY + "/pre_commit.sh"
    POST_COMMIT_SCRIPT = sys.argv[2] if len(sys.argv) > 3 else DIRECTORY + "/post_commit.sh"

    for file_name in os.listdir(DIRECTORY):
        if not fnmatch.fnmatch(file_name, "translation_list_*.txt"):
            continue
        start, end = len("translation_list_"), file_name.index(".txt")
        component_name = file_name[start:end]
        components = []
        with open(file_name, 'r') as f:
            for line in f.read().splitlines():
                name, path = line.rsplit(' ', 1)
                name = name.strip()
                slug = name.lower().replace(' ', '-').replace('.', '-')
                components.append(generate_component(
                    name, slug, path, PRE_COMMIT_SCRIPT, POST_COMMIT_SCRIPT
                ))
        with open("components_{}.json".format(component_name), "w+") as f:
            f.write(json.dumps(components))
