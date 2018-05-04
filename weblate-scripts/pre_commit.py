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
import os
import re
import sys

from common import XmlFile, PropertiesFile

def properties_to_xwiki_xml(path, path_prefix, lang):
    """Convert a java properties file to an XWiki XML file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
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

    properties_path = "{}.translation/{}_{}.properties".format(
            path_prefix, relative_dir_path + "/" + file_name, lang)
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

    properties_path = "{}.translation/{}_{}.properties".format(
            path_prefix, relative_dir_path + "/" + file_name, lang)
    properties = PropertiesFile()
    with open(properties_path, "r") as f_properties:
        properties.load(f_properties.read())
        properties.escape_export()
        properties.write(path_prefix + path)

if __name__ == '__main__':
    reload(sys)
    sys.setdefaultencoding('utf8')
    PATH_PREFIX = os.environ["WL_PATH"] if "WL_PATH" in os.environ else ""
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"
    TRANSLATION_XML_FILE_NAME = sys.argv[1] if len(sys.argv) > 1 else "translation_xml.txt"
    TRANSLATION_XML_PROPERTIES_FILE_NAME = "translation_xml_properties.txt"
    TRANSLATION_PROPERTIES_FILE_NAME = "translation_properties.txt"

    with open(TRANSLATION_XML_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            properties_to_xwiki_xml(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}.*.xml".format(name)):
                    lang = file_name.split(".")[-2]
                    if lang != "en":
                        properties_to_xwiki_xml(dir_name + "/" + file_name, PATH_PREFIX, lang)
    with open(TRANSLATION_XML_PROPERTIES_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            properties_to_xwiki_xml_properties(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}.*.xml".format(name)):
                    lang = file_name.split(".")[-2]
                    if lang != "en":
                        properties_to_xwiki_xml_properties(
                            dir_name + "/" + file_name, PATH_PREFIX, lang)
    with open(TRANSLATION_PROPERTIES_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            properties_to_xwiki_properties(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}_*.properties".format(name)):
                    lang = file_name.split(".")[0]
                    lang = lang[lang.rfind("_") + 1:]
                    if lang != "en":
                        properties_to_xwiki_properties(
                            dir_name + "/" + file_name, PATH_PREFIX, lang)
