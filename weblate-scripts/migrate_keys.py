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

import argparse
import glob
import os
import re
import sys

from common import XmlFile, PropertiesFile, FileType

def get_translation_file_name(base_file, file_type, language):
    if not language:
        file_name = base_file
    else:
        if file_type == FileType.PROPERTIES:
            basename = base_file.rsplit('.', 1)[0]
            file_name = basename + '_' + language + '.properties'
        else:
            basename = base_file.rsplit('.', 1)[0]
            file_name = basename + '.' + language + '.xml'
    return file_name

def open_or_create_translation(base_file_name, file_name, file_type, lang):
    properties = PropertiesFile()
    xml = None
    if file_type == FileType.PROPERTIES:
        if os.path.isfile(file_name):
            with open(file_name, "r") as f:
                document = f.read()
            properties.load(document)
    else:
        if os.path.isfile(file_name):
            xml = XmlFile()
            xml.load(file_name)
        else:
            xml = XmlFile.create_xml_file(file_name, base_file_name, lang)
        properties.load(xml.get_tag_content('content'))
    return (properties, xml)

def parse_arguments():
    parser = argparse.ArgumentParser(description='Migrate translation keys between two base ' +
        'translation files (and the available languages).')
    parser.add_argument('source_file', metavar='source_file', help='Source base translation file')
    parser.add_argument('destination_file', metavar='destination_file', help='Destination base ' +
        'translation file')
    parser.add_argument('key_list', metavar='key_list', help='List of keys to migrate')
    args = parser.parse_args()
    return args.source_file, args.destination_file, args.key_list

def process_source(source_file, source_basename, source_type, key_list):
    languages_keys = {'': []}
    if source_type == FileType.PROPERTIES:
        files_glob = source_basename + '_*.properties'
        language_regex = source_basename + r"_(.*)\.properties"
    else:
        files_glob = source_basename + '.*.xml'
        language_regex = source_basename + r"\.(.*)\.xml"

    for file_name in glob.glob(files_glob):
        match = re.search(language_regex, file_name, re.MULTILINE)
        languages_keys[match.group(1)] = []

    for lang in languages_keys.keys():
        file_name = get_translation_file_name(source_file, source_type, lang)
        properties, xml = open_or_create_translation(source_file, file_name, source_type, lang)
        for entry in key_list:
            parts = entry.split('=', 1)
            oldKey = parts[0]
            newKey = oldKey if len(parts) < 2 else parts[1]
            value = properties.get_value(oldKey)
            if value:
                languages_keys[lang].append((newKey, value))
                properties.remove_key(oldKey)
        if source_type == FileType.PROPERTIES:
            properties.write(file_name)
        else:
            xml.set_tag_content('content', properties.document)
            xml.write(file_name)
    return languages_keys

def process_destination(destination_file, destination_type, languages_keys):
    for lang in languages_keys.keys():
        translations = languages_keys[lang]
        if not translations:
            continue
        file_name = get_translation_file_name(destination_file, destination_type, lang)
        properties, xml = open_or_create_translation(destination_file, file_name,
                          destination_type, lang)
        for (key, value) in translations:
            properties.set_value(key, value)
        if destination_type == FileType.PROPERTIES:
            properties.write(file_name)
        else:
            xml.set_tag_content('content', properties.document)
            xml.write(file_name)

def main():
    """Main function"""
    source_file, destination_file, key_list_file = parse_arguments()
    source_basename, source_extension = source_file.rsplit('.', 1)
    destination_basename, destination_extension = destination_file.rsplit('.', 1)

    if not os.path.isfile(key_list_file):
        sys.exit('The specified key_list is not a file')
    with open(key_list_file, "r") as f:
        key_list = f.read().splitlines()

    source_type = FileType.get_file_type(source_file)
    destination_type = FileType.get_file_type(destination_file)
    if source_type not in [FileType.XML_PROPERTIES, FileType.PROPERTIES]:
        sys.exit('Wrong file type for source_file')
    if destination_type not in [FileType.XML_PROPERTIES, FileType.PROPERTIES]:
        sys.exit('Wrong file type for destination_file')

    languages_keys = process_source(source_file, source_basename, source_type, key_list)
    process_destination(destination_file, destination_type, languages_keys)

if __name__ == '__main__':
    main()
