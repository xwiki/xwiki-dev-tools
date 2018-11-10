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

import os
import re

class XmlFile(object):
    """"Simple class working on XML files using regex"""
    # Matches <tag>
    START_REGEX = r"\<\s*{}\s*\>\s*"
    # Matches <tag/>
    SELF_CLOSE_REGEX = r"\<\s*{}\s*\/\s*\>"
    # Matches </tag>
    END_REGEX = r"\s*\<\s*\/\s*{}\s*\>"

    def __init__(self):
        self.document = ''

    def load(self, file_name):
        with open(file_name, "r") as f_xml:
            self.document = f_xml.read()

    def get_tag_content(self, tag):
        """Get content of the specified tag using regex"""
        start = re.search(self.START_REGEX.format(tag), self.document)
        end = re.search(self.END_REGEX.format(tag), self.document)
        if start is None or end is None:
            return ""
        content = self.document[start.end():end.start()]
        content = content.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        return content

    def set_tag_content(self, tag, content):
        """Set content of an existing tag or create it"""
        content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").strip()
        tag_start = re.search(self.START_REGEX.format(tag), self.document)
        if tag_start is None:
            tag_start = re.search(self.SELF_CLOSE_REGEX.format(tag), self.document)
            if tag_start is None:
                start = end = len(self.document)
            else:
                start, end = tag_start.start(), tag_start.end()
            self.document = "{0}<{1}>{2}</{1}>{3}".format(
                self.document[:start], tag, content, self.document[end:])
        else:
            tag_end = re.search(self.END_REGEX.format(tag), self.document)
            self.document = self.document[:tag_start.end()] + content + \
                self.document[tag_end.start():]

    def remove_tag(self, tag):
        """Remove the first found tag from the document"""
        start = re.search(r"[ \t]*" + self.START_REGEX.format(tag), self.document)
        if start is None:
            tag_start = re.search(
                r"[ \t]*" + self.SELF_CLOSE_REGEX.format(tag) + r"\s*", self.document)
            if tag_start is None:
                return False
            self.document = self.document[:tag_start.start()] + self.document[tag_start.end():]
        else:
            end = re.search(self.END_REGEX.format(tag) + r"\s*", self.document)
            self.document = self.document[:start.start()] + self.document[end.end():]
        return True

    def remove_all_tags(self, tag):
        """Remove from the document all the tags matching the one specified"""
        while self.remove_tag(tag):
            pass

    def write(self, file_name):
        """Write the XML document into the file"""
        with open(file_name, "w") as f_xml:
            f_xml.write(self.document)

    @staticmethod
    def create_xml_file(file_name, base_file_name, lang):
        """Creates the default xml translation file"""
        xml_file = XmlFile()
        xml_file.load(base_file_name)
        xml_file.document = xml_file.document.replace('locale=""', 'locale="{}"'.format(lang))
        xml_file.set_tag_content('language', lang)
        xml_file.set_tag_content('translation', '1')
        xml_file.set_tag_content('content', '')
        xml_file.remove_all_tags("object")
        xml_file.remove_all_tags("attachment")
        xml_file.write(file_name)
        return xml_file

class PropertiesFile(object):
    """"Simple class working on Java properties files using regex"""
    # Matches key = value
    PROPERTY_REGEX = r'^({})\s*[=:](.*)'
    ANY_PROPERTY_REGEX = PROPERTY_REGEX.format(r'[^#][^\s]*?')

    def __init__(self):
        self.document = ""
        self.properties = {}

    def load(self, document):
        """Load the document from a string"""
        self.document = document
        self.map_properties()

    def get_value(self, key):
        """
        Get value of the specified key.
        The map_properties method should be called if any modification has been made since load.
        """
        return self.properties[key] if key in self.properties else ''

    def set_value(self, key, new_value):
        """Set value of key or create it"""
        new_value = self.escape(new_value.strip())
        match = re.search(self.PROPERTY_REGEX.format(key), self.document, re.MULTILINE)
        if match:
            key = match.group(1).strip()
            self.document = self.document[:match.start()] +\
                            key + '=' + new_value +\
                            self.document[match.end():]
        else:
            if self.document and self.document[-1] != "\n":
                self.document += "\n"
            self.document += key + '=' + new_value
        self.properties[key] = self.unescape(new_value)

    def remove_key(self, key):
        """Remove a key if present"""
        match = re.search(self.PROPERTY_REGEX.format(key), self.document, re.MULTILINE)
        if match:
            new_document = self.document[:match.start()]
            if match.end() < len(self.document):
                # Remove the new line if there is one
                new_document += self.document[match.end()].strip() + self.document[match.end() + 1:]
            self.document = new_document

    def write(self, file_name):
        """Write the Java properties into the file"""
        dirname = os.path.dirname(file_name)
        if not os.path.exists(dirname):
            os.makedirs(dirname)
        with open(file_name, "w") as f_properties:
            f_properties.write(self.document)

    def replace_values(self, old, new):
        """Replace values with parameters"""
        res = ""
        for line in self.document.splitlines(True):
            if re.search(r"\{[0-9]+\}", line):
                line = line.replace(old, new)
            res += line
        return res

    def filter_import(self):
        """Filter the document for the import"""
        self.document = self.replace_values("''", "'")
        self.document = self.document.replace('\\ ', ' ')

        document = ''
        is_deprecated = False
        for line in self.document.splitlines(True):
            if is_deprecated and line.startswith('#@deprecatedend'):
                is_deprecated = False
                document += '#@deprecatedend\n\n'
            elif line.startswith('#@deprecatedstart'):
                is_deprecated = True
                document += '#@deprecatedstart\n'
            elif line.strip().startswith('notranslationsmarker'):
                break
            match = re.search(self.ANY_PROPERTY_REGEX, line)
            if match:
                key, value = match.group(1).strip(), match.group(2).strip()
                if value:
                    if is_deprecated:
                        document += '#@deprecated#'
                    document += key + '=' + value + '\n'

        self.document = document

    def filter_export(self):
        """Filter the document for the export"""
        self.document = self.replace_values("''", "'")
        self.document = self.replace_values("'", "''")

    def replace_with(self, properties_file):
        """Keep this document structure and take keys from the given properties file"""
        # Lines ending with '\' are automatically removed by Weblate and hard to handle
        self.document = re.sub(r'\\\n\s*', '', self.document)
        self.map_properties()
        properties_file.document = re.sub(r'\\\n\s*', '', properties_file.document)
        properties_file.map_properties()

        document = ''
        has_no_translations_marker = False
        is_deprecated = False
        for line in self.document.splitlines(True):
            match = re.search(self.ANY_PROPERTY_REGEX, line)
            if match:
                key, value = match.group(1).strip(), match.group(2).strip()
                if key == 'notranslationsmarker':
                    has_no_translations_marker = True
                if value and not has_no_translations_marker:
                    new_value = self.escape(properties_file.get_value(key))
                    if new_value:
                        line = key + '=' + new_value + '\n'
                    else:
                        line = '### Missing: ' + key + '=' + value + '\n'
            document += line
        self.document = document

    def map_properties(self):
        """Add all properties in memory"""
        self.properties.clear()
        for line in self.document.replace('#@deprecated#', '').splitlines():
            match = re.search(self.ANY_PROPERTY_REGEX, line)
            if match:
                key, value = match.group(1).strip(), self.unescape(match.group(2).strip())
                if key in self.properties:
                    print "Warning: {} already exists.".format(key)
                self.properties[key] = value

    @staticmethod
    def escape(text):
        return text.replace("\n", "\\n")

    @staticmethod
    def unescape(text):
        return text.replace("\\n", "\n")

class FileType(object):
    UNDEFINED = -1
    PROPERTIES = 1
    XML = 2
    XML_PROPERTIES = 3

    @staticmethod
    def get_file_type(file_name):
        if not '.' in file_name or not os.path.isfile(file_name):
            return FileType.UNDEFINED
        extension = file_name.rsplit('.', 1)[1]
        if extension == 'properties':
            return FileType.PROPERTIES
        elif extension == 'xml':
            with open(file_name) as f:
                if '<className>XWiki.TranslationDocumentClass</className>' in f.read():
                    return FileType.XML_PROPERTIES
                else:
                    return FileType.XML
        return FileType.UNDEFINED
