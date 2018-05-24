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

    title = properties.get_value("{}.title".format(file_name))
    content = properties.get_value("{}.content".format(file_name))
    xml_file = XmlFile(path_prefix + file_path)
    xml_file.set_tag_content("title", title)
    xml_file.set_tag_content("content", content)
    xml_file.write()

def properties_to_xwiki_xml_properties(file_path, path_prefix, lang):
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
        properties.filter_export()

    # Base translation file
    base_properties_path = "{}_{}.properties".format(
            path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, 'en')
    base_properties = PropertiesFile()
    with open(base_properties_path, "r") as f_properties:
        base_properties.load(f_properties.read())

    base_properties.replace_with(properties)

    xml_file = XmlFile(path_prefix + file_path)
    xml_file.set_tag_content("content", base_properties.document)
    xml_file.write()

def properties_to_xwiki_properties(file_path, path_prefix, lang):
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
        properties.filter_export()

    # Base translation file
    base_properties_path = "{}_{}.properties".format(
            path_prefix + TRANSLATION_PREFIX + relative_dir_path + "/" + file_name, 'en')
    base_properties = PropertiesFile()
    with open(base_properties_path, "r") as f_properties:
        base_properties.load(f_properties.read())

    base_properties.replace_with(properties)
    base_properties.write(path_prefix + file_path)

def create_xml_file(file_name, base_file_name, lang):
    """Creates the default xml translation file"""
    xml_file = XmlFile(base_file_name)
    xml_file.file_name = file_name
    xml_file.document = xml_file.document.replace('locale=""', 'locale="{}"'.format(lang))
    xml_file.set_tag_content('language', lang)
    xml_file.set_tag_content('translation', '1')
    xml_file.remove_all_tags("object")
    xml_file.remove_all_tags("attachment")
    xml_file.write()

def convert(file_type, file_name_properties, base_file_name, lang):
    """Convert the translation file depending on its type"""
    # Current file name with xml extension
    file_name_xml = file_name_properties.replace('_{}.properties'.format(lang),
                                                 '.{}.xml'.format(lang))

    if FILE_TYPE in [FileType.XML_PROPERTIES, FileType.XML]:
        if not os.path.isfile(PATH_PREFIX + file_name_xml):
            # Create the xml translation if it doesn't exists
            create_xml_file(PATH_PREFIX + file_name_xml, PATH_PREFIX + BASE_FILE, lang)

    if FILE_TYPE == FileType.PROPERTIES:
        properties_to_xwiki_properties(file_name_properties, PATH_PREFIX, lang)
    elif FILE_TYPE == FileType.XML_PROPERTIES:
        properties_to_xwiki_xml_properties(file_name_xml, PATH_PREFIX, lang)
    elif FILE_TYPE == FileType.XML:
        properties_to_xwiki_xml(file_name_xml, PATH_PREFIX, lang)

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf8')

    # Path to the git repository
    PATH_PREFIX = os.environ["WL_PATH"]
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"

    # File mask used by the component
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
        with open(PATH_PREFIX + BASE_XML) as f:
            if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                # XML with properties
                FILE_TYPE = FileType.XML_PROPERTIES
            else:
                # XML without properties
                FILE_TYPE = FileType.XML

    # Glob string to find Weblate translation files (.translation folder)
    FILES_GLOB = PATH_PREFIX + TRANSLATION_PREFIX + FILE_MASK
    # List of every Weblate translation files found + the base file
    FILE_NAMES = [file_name.replace(PATH_PREFIX + TRANSLATION_PREFIX, '')
                  for file_name in glob.glob(FILES_GLOB)]
    FILE_NAMES.append(BASE_FILE)
    for file_name in FILE_NAMES:
        # Name of the base file without the extension
        name = os.path.basename(BASE_FILE).split(".")[0]
        # Regex to find the language of the current file if not the base file
        match = re.search('{}_(.*).properties'.format(name), file_name)
        lang = match.group(1) if match else ''
        if lang not in ['', 'en']:
            convert(FILE_TYPE, file_name, PATH_PREFIX, lang)
        elif lang == '':
            convert(FILE_TYPE, file_name, PATH_PREFIX, 'en')
