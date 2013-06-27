#!/bin/bash
BRANCH=master
USER='XWikiTranslator'
PASS='<password here>'

XWIKI_TRUNKS=`pwd`

function fix_author() {
    find ./ -name '*.xml' -exec sed -i -e 's#<creator>XWiki.Admin</creator>#<creator>xwiki:XWiki.Admin</creator>#' -e 's#<author>XWiki.Admin</author>#<author>xwiki:XWiki.Admin</author>#' -e 's#<contentAuthor>XWiki.Admin</contentAuthor>#<contentAuthor>xwiki:XWiki.Admin</contentAuthor>#' {} \; -print
}

function do_one() {
    wget $1 --user="${USER}" --password="${PASS}" --auth-no-challenge -O ./translations.zip &&
    unzip -o translations.zip &&
    rm translations.zip || $(git clean -dxf && exit -1)
    fix_author
}

function read_user_and_password() {
    echo -e "\033[0;32mEnter your l10n.xwiki.org credentials:\033[0m"
    read -e -p "user> " USER
    read -e -s -p "pass> " PASS
    echo ""

    if [[ -z "$USER" || -z "$PASS" ]]; then
      echo -e "\033[1;31mPlease provide both user and password in order to be able to get the translations from l10n.xwiki.org.\033[0m"
      exit -1
    fi
}

function do_all() {
    read_user_and_password

    ##
    ## XWiki Enterprise
    ##

    cd ${XWIKI_TRUNKS}/xwiki-enterprise/xwiki-enterprise-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XE.MainWelcome&app=XE'
    cd ${XWIKI_TRUNKS}/xwiki-enterprise/xwiki-enterprise-ui/ && mvn xar:format

    ##
    ## XWiki Enterprise Manager
    ##

    cd ${XWIKI_TRUNKS}/xwiki-manager/xwiki-manager-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.XEMtranslations&app=XEM'
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.XEMDashboard&app=XEM'
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=XEM.XEMWelcome&app=XEM'
    cd ${XWIKI_TRUNKS}/xwiki-manager/xwiki-manager-ui/ && mvn xar:format

    ##
    ## Wysiwyg 2.0
    ##

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.Stringsproperties&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-gwt/xwiki-platform-gwt-user/src/main/resources/org/xwiki/gwt/user/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.WidgetResources&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Wysiwyg.WYSIWYGEditorCoreParametrizedResources&app=Wysiwyg'

    ##
    ## Platform
    ##

    ## Oldcore
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.XWikiCoreResources&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-oldcore/ && mvn xar:format

    ## Workspace
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-workspace/xwiki-platform-workspace-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.WorkspaceApplication&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-workspace/xwiki-platform-workspace-ui/ && mvn xar:format
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-workspace/xwiki-platform-workspace-template-features/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.WorkspaceApplication%2DTemplateTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-workspace/xwiki-platform-workspace-template-features/ && mvn xar:format

    ## Repository
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-repository/xwiki-platform-repository-server-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.Repository&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-repository/xwiki-platform-repository-server-ui/ && mvn xar:format

    ## Annotations
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-annotations/xwiki-platform-annotation-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.AnnotationCodeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-annotations/xwiki-platform-annotation-ui/ && mvn xar:format

    ## Application Manager
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki-manager/xwiki-platform-wiki-manager-ui/src/main/resources/  || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.WikiManager&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki-manager/xwiki-platform-wiki-manager-ui/ && mvn xar:format

    ## Wiki Manager
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-application-manager/xwiki-platform-application-manager-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.ApplicationManager&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-application-manager/xwiki-platform-application-manager-ui/ && mvn xar:format

    ## Sandbox
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-sandbox/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.SandboxWebHome&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-sandbox/ && mvn xar:format

    ## Help
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-help/xwiki-platform-help-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntax&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-help/xwiki-platform-help-ui/ && mvn xar:format

    ## Solr
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-search/xwiki-platform-search-solr/xwiki-platform-search-solr-ui/src/main/resources/ || exit -1
    do_one 'http://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.MainSolrTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-search/xwiki-platform-search-solr/xwiki-platform-search-solr-ui/ && mvn xar:format

    cd ${XWIKI_TRUNKS}/xwiki-enterprise/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-manager/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-platform/ || exit -1
    git status
    echo -e "\033[0;32mIf there are untracked files, something probably went wrong.\033[0m"
}

function check_clean() {
    cd ${XWIKI_TRUNKS}/$1
    if [[ "`git status | grep 'nothing to commit (working directory clean)'`" == "" ]]; then
        git status
        echo -e "\033[1;31mPlease do something with these changes first.\033[0m"
        echo "in `pwd`"
        exit -1;
    fi
    git reset --hard &&
    git checkout ${BRANCH} &&
    git reset --hard &&
    git clean -dxf &&
    git pull origin ${BRANCH} || exit -1
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
