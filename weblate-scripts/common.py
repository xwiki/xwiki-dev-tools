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

    def __init__(self, file_name):
        self.file_name = file_name
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
        """Set content of an existing tag"""
        content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").strip()
        start = re.search(self.START_REGEX.format(tag), self.document)
        if start is None:
            tag_start = re.search(self.SELF_CLOSE_REGEX.format(tag), self.document)
            if tag_start is None:
                raise LookupError("Couldn't find the tag {}".format(tag))
            self.document = "{0}<{1}>{2}</{1}>{3}".format(
                self.document[:tag_start.start()], tag, content, self.document[tag_start.end():])
        else:
            end = re.search(self.END_REGEX.format(tag), self.document)
            self.document = self.document[:start.end()] + content + self.document[end.start():]

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

    def write(self):
        """Write the XML document into the file"""
        with open(self.file_name, "w") as f_xml:
            f_xml.write(self.document)

class PropertiesFile(object):
    """"Simple class working on Java properties files using regex"""
    # Matches key =
    START_REGEX = r"^{}\s*[=:]\s*"
    # Matches key = value
    END_REGEX = r"^{}\s*[=:].*"

    def __init__(self):
        self.document = ""
        self.key_values = {}

    def load(self, document):
        """Load the document from a string"""
        self.document = document
        self.map_keys()

    def get_value(self, key):
        """Get value of the specified key"""
        return self.key_values[key] if key in self.key_values else ''

    def set_value(self, key, value):
        """Set value of key"""
        value = self.escape(value.strip())
        start = re.search(self.START_REGEX.format(key), self.document, re.MULTILINE)
        end = re.search(self.END_REGEX.format(key), self.document, re.MULTILINE)
        if start is None:
            if self.document and self.document[-1] != "\n":
                self.document += "\n"
            self.document += "{} = {}\n".format(key, value)
        else:
            self.document = self.document[:start.end()] + value + self.document[end.end() + 1:]
        self.key_values[key] = self.unescape(value)

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
            if re.search(r"\{[0-9]*\}", line):
                line = line.replace(old, new)
            res += line
        return res

    def filter_import(self):
        """Filter the document for the import"""
        document = ''
        for line in self.document.splitlines(True):
            if line.strip().startswith('notranslationsmarker'):
                break
            if line.strip() == '' or line.startswith('#'):
                continue
            document += line

        self.document = document
        self.document = self.replace_values("''", "'")

    def filter_export(self):
        """Filter the document for the export"""
        self.document = self.replace_values("''", "'")
        self.document = self.replace_values("'", "''")

    def replace_with(self, properties_file):
        """Keep this document structure and take keys from the given properties file"""
        # Lines ending with '\' are automatically removed by Weblate and hard to handle
        self.document = re.sub(r'\\\n\s*', '', self.document)
        self.map_keys()
        properties_file.document = re.sub(r'\\\n\s*', '', properties_file.document)
        properties_file.map_keys()

        document = ''
        has_no_translations_marker = False
        for line in self.document.splitlines(True):
            # Matches key = value
            match = re.search(r'^([^#].*?)(\s*[=:]\s*)(.*)', line)
            if match:
                key, equal, value = match.group(1), match.group(2), match.group(3)
                if key == 'notranslationsmarker':
                    has_no_translations_marker = True
                if value and not has_no_translations_marker:
                    new_value = self.escape(properties_file.get_value(key))
                    if new_value:
                        line = key + equal + new_value + '\n'
                    else:
                        line = '### Missing: ' + line.strip() + '\n'
            document += line
        self.document = document

    def map_keys(self):
        self.key_values.clear()
        for line in self.document.splitlines():
            # Matches key = value
            match = re.search(r'^([^#][^\s]*?)\s*[=:]\s*(.*)', line)
            if match:
                key, value = match.group(1).strip(), self.unescape(match.group(2))
                if key in self.key_values:
                    print "Warning: {} already exists.".format(key)
                self.key_values[key] = value

    @staticmethod
    def escape(text):
        return text.replace("\n", "\\n")

    @staticmethod
    def unescape(text):
        return text.replace("\\n", "\n")

class FileType(object):
    PROPERTIES = 1
    XML = 2
    XML_PROPERTIES = 3
