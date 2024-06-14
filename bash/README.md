# Bash helpers for various common tasks of XWiki devs

* `set-branch-version.sh`: switch the version of the current Maven project to a branch name based version (used for example to build feature-deploy-* branches on CI) to not collide with the standard version, see `set-branch-version.sh -h` for more details
* `reset-branch-version.sh`: reset back the version of the current Maven project to a more standard versioning to reduce the number of changes when you want to commit or diff your own, see `reset-branch-version.sh -h` for more details

# Install

To make those command line helpers available to your user, you can add the following to your ~/.profile file:

```bash
# add XWiki bash helpers to the PATH
XWIKI_DEV_TOOLS="/your/path/to/xwiki-dev-tools"
if [ -d "$XWIKI_DEV_TOOLS" ] ; then
    PATH="$XWIKI_DEV_TOOLS:$PATH"
fi
```

You can then open a new shell or execute the following if you want to make those commands available in an already open shell:

```bash
source ~/.profile
```