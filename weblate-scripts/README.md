# Weblate scripts

These scripts are intended to be automatically executed by Weblate to convert XWiki translations into a single readable file format.

## Post update script

This script is executed after each update of the repository.

The following tasks are performed:

* Read a list of XML / Java properties files, corresponding to the base translation file (the English one)
* Read the file and create a new Java properties file
  * The new file stays the same if a properties file is given except that the deprecated section will be removed/ignored
  * XML files with properties as content have their content extracted and are treated the same way as above
  * XML files with normal content (XWiki syntax) are converted to a properties file where two keys are created: title and content. The values of the keys are the content of their corresponding tag
  * Make some replacement/escaping (e.g `''` is replaced by `'`)
* Place the new file in a hidden directory
  * e.g. `.translation/xwiki-platform-core/xwiki-platform-help/xwiki-platform-help-ui/src/main/resources/Help/SupportPanel/Content_en.properties`
* Do the same for every other languages found for this file

## Pre commit script

This script is executed before each commit.

The following tasks are performed:

* Take the same list of translation file as the import script
* For each base file, search for the translation files in the `.translation` directory (for every languages)
* Convert them back to their original format
* Replace the original translation with the new one

## Post commit script

This script is executed after each commit.

The following tasks are performed:

* Remove the `.translation/[file]` added by Weblate from the commit
* Add the real translation file to the commit
