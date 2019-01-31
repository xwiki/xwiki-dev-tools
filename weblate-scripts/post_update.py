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

def xwiki_xml_to_properties(file_path, path_prefix, lang):
    """Convert an XWiki XML file to a java properties file"""
    # Directory of the translation file
    relative_dir_path = os.path.dirname(file_path)
    # Translation file name without the extension
    file_name = os.path.basename(file_path).split(".")[0]

    # Weblate translation file
    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()

    xml_file = XmlFile()
    xml_file.load(path_prefix + file_path)
    properties.set_value("{}.title".format(file_name), xml_file.get_tag_content("title"))
    properties.set_value("{}.content".format(file_name), xml_file.get_tag_content("content"))

    properties.write(properties_path)

def xwiki_xml_properties_to_properties(file_path, path_prefix, lang):
    """Convert an XWiki XML file with properties to a java properties file"""
    # Directory of the translation file
    relative_dir_path = os.path.dirname(file_path)
    # Translation file name without the extension
    file_name = os.path.basename(file_path).split(".")[0]

    # Weblate translation file
    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()

    xml_file = XmlFile()
    xml_file.load(path_prefix + file_path)
    content = xml_file.get_tag_content("content")
    properties.load(content)
    properties.filter_import()

    properties.write(properties_path)

def xwiki_properties_to_properties(file_path, path_prefix, lang):
    """Convert an XWiki properties file to a java properties file"""
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

    with open(path_prefix + file_path, "r") as f_properties:
        properties.load(f_properties.read())
        properties.filter_import()

    properties.write(properties_path)

def convert(file_type, file_name_properties, path_prefix, lang):
    """Convert the translation file depending on its type"""
    # Current file name with xml extension
    file_name_xml = file_name_properties.replace('_{}.properties'.format(lang),
                                                 '.{}.xml'.format(lang))

    if file_type == FileType.PROPERTIES:
        xwiki_properties_to_properties(file_name_properties, path_prefix, lang)
    elif file_type == FileType.XML_PROPERTIES:
        xwiki_xml_properties_to_properties(file_name_xml, path_prefix, lang)
    elif file_type == FileType.XML:
        xwiki_xml_to_properties(file_name_xml, path_prefix, lang)

def main():
    """Main function"""
    # Path to the git repository
    path_prefix = os.environ["WL_PATH"]
    if path_prefix and path_prefix[-1] != "/":
        path_prefix += "/"

    # File mask for the XWiki translations
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
        file_mask = file_mask.replace('_*.properties', '.*.xml')
        with open(path_prefix + base_file) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                # XML with properties
                file_type = FileType.XML_PROPERTIES
            else:
                # XML without properties
                file_type = FileType.XML

    if not base_file:
        sys.exit("Couldn't find the base translation file for this file mask: [" + file_mask + "]")

    # Glob string to find XWiki translation files
    files_glob = path_prefix + file_mask
    file_names = [file_name.replace(path_prefix, '')
                  for file_name in glob.glob(files_glob)]
    file_names.append(base_file)
    # Name of the base file without the extension
    base_name = os.path.basename(base_file).split(".")[0]
    for file_name in file_names:
        # Regex to find the language of the current file if not the base file
        match_properties = re.search('{}_(.*).properties'.format(base_name), file_name)
        match_xml = re.search('{}.(.*).xml'.format(base_name), file_name)
        # lang is None for the base file
        lang = None
        if match_properties:
            lang = match_properties.group(1)
        elif match_xml:
            lang = match_xml.group(1)
        # Treat the base file as the 'en' file
        if lang is None:
            convert(file_type, file_name, path_prefix, 'en')
        elif lang != 'en':
            convert(file_type, file_name, path_prefix, lang)

if __name__ == '__main__':
    main()
