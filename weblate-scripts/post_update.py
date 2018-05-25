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

    xml_file = XmlFile(path_prefix + file_path)
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

    xml_file = XmlFile(path_prefix + file_path)
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

def convert(file_type, file_name_properties, base_file_name, lang):
    """Convert the translation file depending on its type"""
    # Current file name with xml extension
    file_name_xml = file_name_properties.replace('_{}.properties'.format(lang),
                                                 '.{}.xml'.format(lang))

    if file_type == FileType.PROPERTIES:
        xwiki_properties_to_properties(file_name_properties, PATH_PREFIX, lang)
    elif file_type == FileType.XML_PROPERTIES:
        xwiki_xml_properties_to_properties(file_name_xml, PATH_PREFIX, lang)
    elif file_type == FileType.XML:
        xwiki_xml_to_properties(file_name_xml, PATH_PREFIX, lang)

if __name__ == '__main__':
    # Path to the git repository
    PATH_PREFIX = os.environ["WL_PATH"]
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"

    # File mask for the XWiki translations
    FILE_MASK = os.environ["WL_FILEMASK"].replace(TRANSLATION_PREFIX, '')
    # Relative path to the base translation (could be .properties or .xml)
    BASE_PROPERTIES = FILE_MASK.replace('_*.properties', '.properties')
    BASE_XML = FILE_MASK.replace('_*.properties', '.xml')

    if os.path.isfile(PATH_PREFIX + BASE_PROPERTIES):
        # Base file is a .properties
        BASE_FILE = BASE_PROPERTIES
        FILE_TYPE = FileType.PROPERTIES
    elif os.path.isfile(PATH_PREFIX + BASE_XML):
        # Base file is a .xml
        BASE_FILE = BASE_XML
        FILE_MASK = FILE_MASK.replace('_*.properties', '.*.xml')
        with open(PATH_PREFIX + BASE_FILE) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                # XML with properties
                FILE_TYPE = FileType.XML_PROPERTIES
            else:
                # XML without properties
                FILE_TYPE = FileType.XML

    # Glob string to find XWiki translation files
    FILES_GLOB = PATH_PREFIX + FILE_MASK
    FILE_NAMES = [file_name.replace(PATH_PREFIX, '')
                  for file_name in glob.glob(FILES_GLOB)]
    FILE_NAMES.append(BASE_FILE)
    for file_name in FILE_NAMES:
        # Name of the base file without the extension
        name = os.path.basename(BASE_FILE).split(".")[0]
        # Regex to find the language of the current file if not the base file
        match_properties = re.search('{}_(.*).properties'.format(name), file_name)
        match_xml = re.search('{}.(.*).xml'.format(name), file_name)
        # lang is None for the base file
        lang = None
        if match_properties:
            lang = match_properties.group(1)
        elif match_xml:
            lang = match_xml.group(1)
        # Treat the base file as the 'en' file
        if lang is None:
            convert(FILE_TYPE, file_name, PATH_PREFIX, 'en')
        elif lang != 'en':
            convert(FILE_TYPE, file_name, PATH_PREFIX, lang)
