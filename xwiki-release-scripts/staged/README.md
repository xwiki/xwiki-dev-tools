Staged Release Scripts
======================

These scripts are designed to reconsile the need for an automated release
with the release manager's need for verifyability and oversight.

The release scripts attempt to break the release down into small pieces,
In the long term, these scripts may be called by a larger script, after
they are well understood and known to be bug free.

Scripts
=======


release-translations.sh
-----------------------

This script downloads the translations from l10n.xwiki.org and applies
them to the git repository. When it is finished, it prints all of changes
using git-diff. It does *not* do any commit or push, this is the RM's job
after he has verified that the patches are correct.

Example:

    cd ./xwiki-trunks
    ~/release-translations.sh
    cd xwiki-platform
    git commit -m "updating translations"
    git push
    cd ../xwiki-enterprise
    git commit -m "updating translations"
    git push

If there are any uncommitted changes to the repository, the script will fail.
To rempve all uncommitted changes in **all repositories**, use

    cd ./xwiki-trunks
    ~/release-translations.sh clean


stage-release.sh
----------------

Place the release into staging as per the agreed upon process.
This script expects there to be a file called `clirr-excludes.xslt` in
the directory above the dir where the script is stored. To alter this location,
edit line #2 of the script. It also expects the VERSION environment variable to
be set indicating the version to be released.
This is an adapted version of release-maven.sh, notable differences are:

* Release is placed into staging on nexus.xwiki.org rather than being pushed to
maven.xwiki.org
* Projects can be released one at a time using `~/stage-release.sh <project>`
* Tags are *not* automatically pushed to github, they are left on the system
until the RM decides the release is successful and should be publicised.
* A file called hashes.txt is outputted listing the sha1sums of all downloadable
files this will be used later to assure that the files were uploaded properly.

Example:

    cd ./xwiki-trunks
    export VERSION=4.1-milestone-2
    ~/stage-release.sh xwiki-commons
    ~/stage-release.sh xwiki-platform
    ....


upload-all.sh
-------------

This script is meant to be used on maven.xwiki.org to upload finished release
files to forge.ow2.org. It is called using your ow2 username and the version
of the release.

Example:

    ~/push-all.sh cjdelisle 4.1-milestone-2

