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

def xwiki_xml_to_properties(path, path_prefix, lang):
    """Convert an XWiki XML file to a java properties file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]

    properties = PropertiesFile()
    xml_file = XmlFile(path_prefix + path)
    properties.set_value("{}.title".format(file_name), xml_file.get_tag_content("title"))
    properties.set_value("{}.content".format(file_name), xml_file.get_tag_content("content"))

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
    properties.write(properties_path)

def xwiki_xml_properties_to_properties(path, path_prefix, lang):
    """Convert an XWiki XML file with properties to a java properties file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]

    properties = PropertiesFile()
    xml_file = XmlFile(path_prefix + path)
    content = xml_file.get_tag_content("content")
    properties.load(content)
    properties.filter_import()

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
    properties.write(properties_path)

def xwiki_properties_to_properties(path, path_prefix, lang):
    """Convert an XWiki properties file to a java properties file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]
    lang_delimiter_index = file_name.rfind("_" + lang)
    if lang_delimiter_index > 0:
        file_name = file_name[:lang_delimiter_index]

    properties = PropertiesFile()
    with open(path_prefix + path, "r") as f_properties:
        properties.load(f_properties.read())
        properties.filter_import()

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
    properties.write(properties_path)

if __name__ == '__main__':
    PATH_PREFIX = os.environ["WL_PATH"]
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"
    FILE_MASK = os.environ["WL_FILEMASK"]
    FILE_MASK = PATH_PREFIX + FILE_MASK[len(TRANSLATION_PREFIX):]
    BASE_PROPERTIES = FILE_MASK.replace('_*.properties', '.properties')
    BASE_XML = FILE_MASK.replace('_*.properties', '.xml')
    if os.path.isfile(BASE_PROPERTIES):
        BASE_FILE = BASE_PROPERTIES
        FILE_TYPE = FileType.PROPERTIES
    elif os.path.isfile(BASE_XML):
        BASE_FILE = BASE_XML
        FILE_MASK = FILE_MASK.replace('_*.properties', '.*.xml')
        with open(BASE_FILE) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                FILE_TYPE = FileType.XML_PROPERTIES
            else:
                FILE_TYPE = FileType.XML

    FILE_NAMES = glob.glob(FILE_MASK) + [BASE_FILE]
    for file_name in FILE_NAMES:
        file_name = file_name.replace(PATH_PREFIX, '')
        name = os.path.basename(BASE_FILE).split(".")[0]
        match_properties = re.search('{}_(.*).properties'.format(name), file_name)
        match_xml = re.search('{}.(.*).xml'.format(name), file_name)
        if FILE_TYPE == FileType.PROPERTIES:
            if match_properties:
                lang = match_properties.group(1)
                if lang != "en":
                    xwiki_properties_to_properties(file_name, PATH_PREFIX, lang)
            else:
                xwiki_properties_to_properties(file_name, PATH_PREFIX, 'en')
        elif FILE_TYPE == FileType.XML_PROPERTIES:
            name = os.path.basename(BASE_FILE).split(".")[0]
            if match_xml:
                lang = match_xml.group(1)
                if lang != "en":
                    xwiki_xml_properties_to_properties(file_name, PATH_PREFIX, lang)
            else:
                xwiki_xml_properties_to_properties(file_name, PATH_PREFIX, 'en')
        elif FILE_TYPE == FileType.XML:
            name = os.path.basename(BASE_FILE).split(".")[0]
            if match_xml:
                lang = match_xml.group(1)
                if lang != "en":
                    xwiki_xml_to_properties(file_name, PATH_PREFIX, lang)
            else:
                xwiki_xml_to_properties(file_name, PATH_PREFIX, 'en')
