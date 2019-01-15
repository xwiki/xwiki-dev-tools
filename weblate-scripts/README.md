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

## Importing a new weblate component

### Add new component script (recommended)

This script is meant to automatically perform all the necessary operations to add a new component into weblate (except for some given commands that you will have to run manually).

### Manual import

Let's assume you want to add a new component named **XWiki Core Resources** into the **xwiki-platform** project with the full url of the main translation file being `https://github.com/xwiki/xwiki-platform/xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/ApplicationResources.properties`.

First thing you should do is add an entry at the end of `translation_list_xwiki-platform.txt`:
```
XWiki Core Resources; xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/ApplicationResources.properties; https://github.com/xwiki/xwiki-platform
```

It's important to use the same url as other components (when possible) to avoid the duplicating the git repositories.

That being done you should check if the git repository should be cloned into the weblate *vcs* folder or not. You only need to do this step if the url that you have specified is unique (or at least the first in the list):
```
$ cd /home/weblate/weblate/lib/python2.7/site-packages/data/vcs
$ git clone https://github.com/xwiki/xwiki-platform xwiki-core-resources
```

The name of the cloned repository is the slug of the component name (lowercase + `-` instead of spaces and `.`).

You then need to update the components, especially to create the necessary translation files before the weblate import:
```
$ ./call_updates.py /home/weblate/weblate/lib/python2.7/site-packages/data/vcs --project xwiki-platform --component https://github.com/xwiki/xwiki-platform
```

Finally, you can generate and import the component add add the necessary addons:
```
$ ./generate_components.py

$ weblate import_json --project xwiki-platform components_xwiki-platform.json --ignore

$ weblate install_addon --addon xwiki.post_update xwiki-platform/xwiki-core-resources
$ weblate install_addon --addon xwiki.pre_commit xwiki-platform/xwiki-core-resources
$ weblate install_addon --addon xwiki.post_commit xwiki-platform/xwiki-core-resources
```

#### Generate components script

A `components.json` file can be generated and used to automatically create components in weblate.
For instance, you can run:
```
$ weblate import_json components.json --project xwiki-platform --update
```
This will import or update the components into the `xwiki-platform` project.

## Miscellaneous

### Update translations for other branches

The `apply_translations.sh` script can be used to automatically update translation files based on the ones on the master branch. You can run the script from a git repository (e.g. xwiki-plaftorm) within the branch to be updated (for example an LTS branch). Translation files are found reading these files `translation_list_*.txt`

Once you have executed the script, you can `git diff --cached` to see the changes and then commit.
