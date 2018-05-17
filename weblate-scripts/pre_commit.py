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

def properties_to_xwiki_xml(path, path_prefix, lang):
    """Convert a java properties file to an XWiki XML file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]

    properties_path = "{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())

    title = properties.get_value("{}.title".format(file_name))
    content = properties.get_value("{}.content".format(file_name))
    xml_file = XmlFile(path_prefix + path)
    xml_file.set_tag_content("title", title)
    xml_file.set_tag_content("content", content)
    xml_file.write()

def properties_to_xwiki_xml_properties(path, path_prefix, lang):
    """Convert a java properties file to an XWiki XML file with properties"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]

    properties_path = "{}/{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX, relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())
        properties.escape_export()

    xml_file = XmlFile(path_prefix + path)
    xml_file.set_tag_content("content", properties.document)
    xml_file.write()

def properties_to_xwiki_properties(path, path_prefix, lang):
    """Convert a java properties file to an XWiki java properties file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]
    lang_delimiter_index = file_name.rfind("_")
    if lang_delimiter_index > 0:
        file_name = file_name[:lang_delimiter_index]

    properties_path = "{}/{}_{}.properties".format(
        path_prefix + TRANSLATION_PREFIX, relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())
        properties.escape_export()
        properties.write(path_prefix + path)

def create_xml_file(file_name, base_file_name, lang):
    """Creates the default xml translation file"""
    xml_file = XmlFile(base_file_name)
    xml_file.file_name = file_name
    xml_file.document = xml_file.document.replace('locale=""', 'locale="{}"'.format(lang))
    xml_file.set_tag_content('language', lang)
    xml_file.set_tag_content('translation', '1')
    xml_file.write()

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf8')

    PATH_PREFIX = os.environ["WL_PATH"]
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"

    FILE_MASK = os.environ["WL_FILEMASK"].replace(TRANSLATION_PREFIX, '')
    BASE_PROPERTIES = FILE_MASK.replace('_*.properties', '.properties')
    BASE_XML = FILE_MASK.replace('_*.properties', '.xml')

    if os.path.isfile(PATH_PREFIX + BASE_PROPERTIES):
        BASE_FILE = BASE_PROPERTIES
        FILE_TYPE = FileType.PROPERTIES
    elif os.path.isfile(PATH_PREFIX + BASE_XML):
        BASE_FILE = BASE_XML
        with open(PATH_PREFIX + BASE_XML) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                FILE_TYPE = FileType.XML_PROPERTIES
            else:
                FILE_TYPE = FileType.XML

    FILES_GLOB = PATH_PREFIX + TRANSLATION_PREFIX + FILE_MASK
    FILE_NAMES = [file_name.replace(PATH_PREFIX + TRANSLATION_PREFIX, '')
                  for file_name in glob.glob(FILES_GLOB)]
    FILE_NAMES.append(BASE_FILE)
    for file_name in FILE_NAMES:
        name = os.path.basename(BASE_FILE).split(".")[0]
        match = re.search('{}_(.*).properties'.format(name), file_name)
        if FILE_TYPE == FileType.PROPERTIES:
            if match:
                lang = match.group(1)
                if lang != "en":
                    properties_to_xwiki_properties(file_name, PATH_PREFIX, lang)
            else:
                properties_to_xwiki_properties(file_name, PATH_PREFIX, 'en')
        elif FILE_TYPE == FileType.XML_PROPERTIES:
            if match:
                lang = match.group(1)
                file_name = file_name.replace('_{}.properties'.format(lang),
                                              '.{}.xml'.format(lang))
                if lang != "en":
                    if not os.path.isfile(PATH_PREFIX + file_name):
                        create_xml_file(PATH_PREFIX + file_name, PATH_PREFIX + BASE_FILE, lang)
                    properties_to_xwiki_xml_properties(file_name, PATH_PREFIX, lang)
            else:
                properties_to_xwiki_xml_properties(file_name, PATH_PREFIX, 'en')
        elif FILE_TYPE == FileType.XML:
            if match:
                lang = match.group(1)
                file_name = file_name.replace('_{}.properties'.format(lang),
                                              '.{}.xml'.format(lang))
                if lang != "en":
                    if not os.path.isfile(PATH_PREFIX + file_name):
                        create_xml_file(PATH_PREFIX + file_name, PATH_PREFIX + BASE_FILE, lang)
                    properties_to_xwiki_xml(file_name, PATH_PREFIX, lang)
            else:
                properties_to_xwiki_xml(file_name, PATH_PREFIX, 'en')
