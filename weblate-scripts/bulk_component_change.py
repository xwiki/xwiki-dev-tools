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

# This script aims at performing bulk changes on translation_list files, for example to add new columns.

import os
import fnmatch

impacted_projects = ["xwiki-contrib"]

def perform_change(line):
    return line + "; LGPL-2.1"

def main():
    directory = os.getcwd()
    for file_name in os.listdir(directory):
        if not fnmatch.fnmatch(file_name, "translation_list_*.txt"):
            continue
        start, end = len("translation_list_"), file_name.index(".txt")
        project = file_name[start:end]

        if (project in impacted_projects):
            new_content = []
            with open(file_name, 'r') as f:
                for line in f.read().splitlines():
                    if not line or line[0] == '#':
                        new_content.append(line + "\n")
                    else:
                        new_content.append(perform_change(line) + "\n")
            with open(file_name, 'w') as f:
                f.writelines(new_content)


if __name__ == '__main__':
    """Main function"""
    main()