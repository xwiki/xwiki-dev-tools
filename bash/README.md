# Bash helpers for various common task of XWiki devs

* `set-branch-version.sh`: switch the version of the current Maven project to a branch name based version (used for example to builde feature-deploy-* branches on CI)
* `reset-branch-version.sh`: reset back the version of the current Maven project to a more standard versionning

# Install

To make those command line helpers availables to your user you can add the following to your ~/.profile file:

```bash
# add XWiki bash helpers to the PATH
XWIKI_DEV_TOOLS="/your/path/to/xwiki-dev-tools"
if [ -d "$XWIKI_DEV_TOOLS" ] ; then
    PATH="$XWIKI_DEV_TOOLS"
fi
```

execute

```bash
source ~/.profile
```