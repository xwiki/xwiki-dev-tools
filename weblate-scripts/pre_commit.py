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

import glob
import os
import re
import sys

from common import XmlFile, PropertiesFile, FileType

TRANSLATION_PREFIX = ".translation/"

def properties_to_xwiki_xml(file_path, path_prefix, lang):
    """Convert a java properties file to an XWiki XML file"""
    # Directory of the translation file
    relative_dir_path = os.path.dirname(file_path)
    # Translation file name without the extension
    file_name = os.path.basename(file_path).split(".")[0]

    # Weblate translation file
    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())

    if not properties.is_empty():
        title = properties.get_value("{}.title".format(file_name))
        content = properties.get_value("{}.content".format(file_name))
        xml_file = XmlFile()
        xml_file.load(path_prefix + file_path)
        xml_file.set_tag_content("title", title)
        xml_file.set_tag_content("content", content, ['xwikidoc'])
        xml_file.write(path_prefix + file_path)
    else:
        print "Warning: {} translation is empty. Skipping it.".format(properties_path)

def properties_to_xwiki_xml_properties(file_path, path_prefix, base_file_name, lang):
    """Convert a java properties file to an XWiki XML file with properties"""
    # Directory of the translation file
    relative_dir_path = os.path.dirname(file_path)
    # Translation file name without the extension
    file_name = os.path.basename(file_path).split(".")[0]

    # Weblate translation file
    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())

    if not properties.is_empty():
        # Use the base translation file as template
        xml_base_file = XmlFile()
        xml_base_file.load(path_prefix + base_file_name)
        content = xml_base_file.get_tag_content("content")
        base_properties = PropertiesFile()
        base_properties.load(content)

        # Replace keys with the current translation
        base_properties.replace_with(properties)
        base_properties.filter_export()

        xml_file = XmlFile()
        xml_file.load(path_prefix + file_path)
        xml_file.set_tag_content("content", base_properties.document)
        xml_file.write(path_prefix + file_path)
    else:
        print "Warning: {} translation is empty. Skipping it.".format(properties_path)

def properties_to_xwiki_properties(file_path, path_prefix, base_file_name, lang):
    """Convert a java properties file to an XWiki java properties file"""
    # Directory of the translation file
    relative_dir_path = os.path.dirname(file_path)
    # Translation file name without the extension
    file_name = os.path.basename(file_path).split(".")[0]
    lang_delimiter_index = file_name.rfind("_" + lang)
    if lang_delimiter_index > 0:
        file_name = file_name[:lang_delimiter_index]

    # Weblate translation file
    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())

    if not properties.is_empty():
        # Use the base translation file as template
        base_properties = PropertiesFile()
        with open(path_prefix + base_file_name, "r") as f_properties:
            base_properties.load(f_properties.read())

        # Replace keys with the current translation
        base_properties.replace_with(properties)
        base_properties.filter_export()

        base_properties.write(path_prefix + file_path)
    else:
        print "Warning: {} translation is empty. Skipping it.".format(properties_path)

def convert(file_type, file_name_properties, path_prefix, base_file_name, lang):
    """Convert the translation file depending on its type"""
    # Current file name with xml extension
    file_name_xml = file_name_properties.replace('_{}.properties'.format(lang),
                                                 '.{}.xml'.format(lang))

    if file_type in [FileType.XML_PROPERTIES, FileType.XML]:
        if not os.path.isfile(path_prefix + file_name_xml):
            # Create the xml translation if it doesn't exists
            XmlFile.create_xml_file(path_prefix + file_name_xml, path_prefix + base_file_name, lang)

    if file_type == FileType.PROPERTIES:
        properties_to_xwiki_properties(file_name_properties, path_prefix, base_file_name, lang)
    elif file_type == FileType.XML_PROPERTIES:
        properties_to_xwiki_xml_properties(file_name_xml, path_prefix, base_file_name, lang)
    elif file_type == FileType.XML:
        properties_to_xwiki_xml(file_name_xml, path_prefix, lang)

def main():
    """Main function"""
    # Path to the git repository
    path_prefix = os.environ["WL_PATH"]
    if path_prefix and path_prefix[-1] != "/":
        path_prefix += "/"

    # File mask for the Weblate translations
    file_mask = os.environ["WL_FILEMASK"].replace(TRANSLATION_PREFIX, '')
    # Relative path to the base translation (could be .properties or .xml)
    base_properties = file_mask.replace('_*.properties', '.properties')
    base_xml = file_mask.replace('_*.properties', '.xml')
    base_file = None

    if os.path.isfile(path_prefix + base_properties):
        # Base file is a .properties
        base_file = base_properties
        file_type = FileType.PROPERTIES
    elif os.path.isfile(path_prefix + base_xml):
        # Base file is a .xml
        base_file = base_xml
        with open(path_prefix + base_xml) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                # XML with properties
                file_type = FileType.XML_PROPERTIES
            else:
                # XML without properties
                file_type = FileType.XML

    if not base_file:
        sys.exit("Couldn't find the base translation file for this file mask: [" + file_mask + "]")

    # Glob string to find Weblate translation files (.translation folder)
    files_glob = path_prefix + TRANSLATION_PREFIX + file_mask
    # List of every Weblate translation files found + the base file
    file_names = [file_name.replace(path_prefix + TRANSLATION_PREFIX, '')
                  for file_name in glob.glob(files_glob)]
    file_names.append(base_file)
    # Name of the base file without the extension
    base_name = os.path.basename(base_file).split(".")[0]
    for file_name in file_names:
        # Regex to find the language of the current file if not the base file
        match = re.search('{}_(.*).properties'.format(base_name), file_name)
        # lang is None for the base file
        lang = match.group(1) if match else None
        # Treat the base file as the 'en' file
        if lang is None:
            convert(file_type, file_name, path_prefix, base_file, 'en')
        elif lang != 'en':
            convert(file_type, file_name, path_prefix, base_file, lang)

if __name__ == '__main__':
    main()
