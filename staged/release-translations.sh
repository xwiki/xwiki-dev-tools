#!/bin/bash
BRANCH=master
XWIKI_TRUNKS=`pwd`
USER=CalebJamesDeLisle
PASS=l10npassword

function fix_author() {
    find ./ -name '*.xml' -exec sed -i -e 's#<creator>XWiki.Admin</creator>#<creator>xwiki:XWiki.Admin</creator>#' -e 's#<author>XWiki.Admin</author>#<author>xwiki:XWiki.Admin</author>#' -e 's#<contentAuthor>XWiki.Admin</contentAuthor>#<contentAuthor>xwiki:XWiki.Admin</contentAuthor>#' {} \; -print
}

function do_one() {
    wget $1 --user=${USER} --password=${PASS} --auth-no-challenge -O ./translations.zip &&
    unzip -o translations.zip &&
    rm translations.zip || $(git clean -dxf && exit -1)
    fix_author
}

function do_all() {
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XE.XWikiCoreResources&app=XE'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.Stringsproperties&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-gwt/xwiki-platform-gwt-user/src/main/resources/org/xwiki/gwt/user/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.WidgetResources&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.WYSIWYGEditorCoreParametrizedResources&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki-manager/xwiki-platform-wiki-manager-ui/src/main/resources/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.WikiManager&app=XEM'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-application-manager/xwiki-platform-application-manager-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.ApplicationManager&app=XEM'

    cd ${XWIKI_TRUNKS}/xwiki-manager/xwiki-manager-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.XEMtranslations&app=XEM'
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.XEMWebHome&app=XEM'

    cd ${XWIKI_TRUNKS}/xwiki-enterprise/xwiki-enterprise-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XE.MainWelcome&app=XE'
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XE.SandboxWebHome&app=XE'
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XE.XWikiXWikiSyntax&app=XE'

    cd ${XWIKI_TRUNKS}/xwiki-enterprise/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-manager/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-platform/ || exit -1
    git status
    echo 'If there are untracked files, something probably went wrong.'
}

function check_clean() {
    cd ${XWIKI_TRUNKS}/$1
    if [[ "`git status | grep 'nothing to commit (working directory clean)'`" == "" ]]; then
        git status
        echo "Please do something with these changes first."
        echo "in `pwd`"
        exit -1;
    fi
    git reset --hard &&
    git checkout ${BRANCH} &&
    git reset --hard &&
    git clean -dxf &&
    git pull || exit -1
}

function commit() {
    MSG="[release] Updated translations."
    cd ${XWIKI_TRUNKS}/xwiki-enterprise/
    git add . && git commit  -m "${MSG}" && git push
    cd ${XWIKI_TRUNKS}/xwiki-manager/
    git add . && git commit  -m "${MSG}" && git push
    cd ${XWIKI_TRUNKS}/xwiki-platform/
    git add . && git commit  -m "${MSG}" && git push
}

if [[ $1 == 'commit' ]]; then
    commit
elif [[ $1 == 'clean' ]]; then
    cd ${XWIKI_TRUNKS}/xwiki-enterprise/
    git reset --hard && git clean -dxf
    cd ${XWIKI_TRUNKS}/xwiki-manager/
    git reset --hard && git clean -dxf
    cd ${XWIKI_TRUNKS}/xwiki-platform/
    git reset --hard && git clean -dxf
else
    check_clean xwiki-enterprise
    check_clean xwiki-manager
    check_clean xwiki-platform
    do_all
fi
