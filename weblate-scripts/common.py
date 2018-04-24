import os
import re

class XmlFile(object):
    """"Simple class working on XML files using regex"""

    def __init__(self, file_name):
        self.file_name = file_name
        with open(file_name, "r") as f_xml:
            self.document = f_xml.read()

    def get_tag_content(self, tag):
        """Get content of the specified tag using regex"""
        start = re.search(r"\<\s*{}\s*\>\s*".format(tag), self.document)
        end = re.search(r"\s*\<\s*\/\s*{}\s*\>".format(tag), self.document)
        if start is None or end is None:
            return ""
        content = self.document[start.end():end.start()]
        content = content.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        return content

    def set_tag_content(self, tag, content):
        """Set content of an existing tag"""
        content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        start = re.search(r"\<\s*{}\s*\>\s*".format(tag), self.document)
        if start is None:
            tag_start = re.search(r"\<\s*{}\s*\/\s*\>".format(tag), self.document)
            if tag_start is None:
                raise LookupError("Couldn't find the tag {}".format(tag))
            self.document = "{0}<{1}>{2}</{1}>{3}".format(
                self.document[:tag_start.start()], tag, content, self.document[tag_start.end():])
        else:
            end = re.search(r"\s*\<\s*\/\s*{}\s*\>".format(tag), self.document)
            self.document = self.document[:start.end()] + content + self.document[end.start():]

    def write(self):
        """Write the XML document into the file"""
        with open(self.file_name, "w") as f_xml:
            f_xml.write(self.document)

class PropertiesFile(object):
    """"Simple class working on Java properties files using regex"""

    def __init__(self):
        self.document = ""

    def load(self, document):
        """Load the document from a string"""
        self.document = document

    def get_value(self, key):
        """Get value of the specified key using regex"""
        start = re.search(r"^{}\s*[=:]\s*".format(key), self.document, re.MULTILINE)
        end = re.search(r"^{}\s*[=:].*".format(key), self.document, re.MULTILINE)
        if start is None or end is None:
            return ""
        return self.unescape(self.document[start.end():end.end() + 1].strip())

    def set_value(self, key, value):
        """Set value of key"""
        value = self.escape(value.strip())
        start = re.search(r"^{}\s*[=:]\s*".format(key), self.document, re.MULTILINE)
        end = re.search(r"^{}\s*[=:].*".format(key), self.document, re.MULTILINE)
        if start is None:
            if self.document and self.document[-1] != "\n":
                self.document += "\n"
            self.document += "{} = {}\n".format(key, value)
        else:
            self.document = self.document[:start.end()] + value + self.document[end.end() + 1:]

    def write(self, file_name):
        """Write the Java properties into the file"""
        dirname = os.path.dirname(file_name)
        if not os.path.exists(dirname):
            os.makedirs(dirname)
        with open(file_name, "w") as f_properties:
            f_properties.write(self.document)

    @staticmethod
    def escape(text):
        #return text.encode("string_escape")
        return text.replace("\n", "\\n")

    @staticmethod
    def unescape(text):
        #return text.decode("string_escape")
        return text.replace("\\n", "\n")
