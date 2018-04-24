import fnmatch
import os
import sys

from common import XmlFile, PropertiesFile

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

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
    properties.write(properties_path)

def xwiki_properties_to_properties(path, path_prefix, lang):
    """Convert an XWiki properties file to a java properties file"""
    relative_dir_path = os.path.dirname(path)
    file_name = os.path.basename(path).split(".")[0]
    lang_delimiter_index = file_name.rfind("_")
    if lang_delimiter_index > 0:
        file_name = file_name[:lang_delimiter_index]

    properties = PropertiesFile()
    with open(path_prefix + path, "r") as f_properties:
        properties.load(f_properties.read())

    properties_path = "{}.translation/{}_{}.properties".format(
        path_prefix, relative_dir_path + "/" + file_name, lang)
    properties.write(properties_path)

if __name__ == '__main__':
    PATH_PREFIX = os.environ["WL_PATH"] if "WL_PATH" in os.environ else ""
    if PATH_PREFIX and PATH_PREFIX[-1] != "/":
        PATH_PREFIX += "/"
    TRANSLATION_WIKI_FILE_NAME = sys.argv[1] if len(sys.argv) > 1 else "translation_wiki.txt"
    if len(sys.argv) > 2:
        TRANSLATION_WIKI_PROPERTIES_FILE_NAME = sys.argv[2]
    else:
        TRANSLATION_WIKI_PROPERTIES_FILE_NAME = "translation_wiki_properties.txt"
    if len(sys.argv) > 3:
        TRANSLATION_PROPERTIES_FILE_NAME = sys.argv[3]
    else:
        TRANSLATION_PROPERTIES_FILE_NAME = "translation_properties.txt"

    with open(TRANSLATION_WIKI_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            xwiki_xml_to_properties(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}.*.xml".format(name)):
                    lang = file_name.split(".")[-2]
                    if lang != "en":
                        xwiki_xml_to_properties(dir_name + "/" + file_name, PATH_PREFIX, lang)
    with open(TRANSLATION_WIKI_PROPERTIES_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            xwiki_xml_properties_to_properties(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}.*.xml".format(name)):
                    lang = file_name.split(".")[-2]
                    if lang != "en":
                        xwiki_xml_properties_to_properties(
                            dir_name + "/" + file_name, PATH_PREFIX, lang)
    with open(TRANSLATION_PROPERTIES_FILE_NAME, 'r') as f:
        for line in f.read().splitlines():
            xwiki_properties_to_properties(line, PATH_PREFIX, "en")
            dir_name = os.path.dirname(line)
            name = os.path.basename(line).split(".")[0]
            for file_name in os.listdir(PATH_PREFIX + dir_name):
                if fnmatch.fnmatch(file_name, "{}_*.properties".format(name)):
                    lang = file_name.split(".")[0]
                    lang = lang[lang.rfind("_") + 1:]
                    if lang != "en":
                        xwiki_properties_to_properties(dir_name + "/" + file_name, PATH_PREFIX, lang)
