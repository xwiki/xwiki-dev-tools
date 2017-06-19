#!/bin/bash
BRANCH=master
USER="$L10N_USER"
PASS="$L10N_PASSWORD"

XWIKI_TRUNKS=`pwd`

function fix_author() {
    find ./ -name '*.xml' -exec sed -i -e 's#<creator>XWiki.Admin</creator>#<creator>xwiki:XWiki.Admin</creator>#' -e 's#<author>XWiki.Admin</author>#<author>xwiki:XWiki.Admin</author>#' -e 's#<contentAuthor>XWiki.Admin</contentAuthor>#<contentAuthor>xwiki:XWiki.Admin</contentAuthor>#' {} \; -print
}

function do_one() {
    wget $1 --user="${USER}" --password="${PASS}" --auth-no-challenge -O ./translations.zip || exit -1
    unzip -o translations.zip || exit -1
    rm translations.zip || $(git clean -dxf && exit -1)
    fix_author
}

function read_user_and_password() {
    if [[ -z "$USER" || -z "$PASS" ]]; then
        echo -e "\033[0;32mEnter your l10n.xwiki.org credentials:\033[0m"
        read -e -p "user> " USER
        read -e -s -p "pass> " PASS
        echo ""
    fi

    if [[ -z "$USER" || -z "$PASS" ]]; then
      echo -e "\033[1;31mPlease provide both user and password in order to be able to get the translations from l10n.xwiki.org.\033[0m"
      exit -1
    fi
}

function format_xar() {
    ## due to https://github.com/mycila/license-maven-plugin/issues/37 we need to perform "mvn xar:format" twice.
    mvn xar:format
    mvn xar:format
}

function do_all() {
    read_user_and_password

    ##
    ## XWiki Flavor
    ##

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-distribution/xwiki-platform-distribution-flavor/xwiki-platform-distribution-flavor-tour/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.TourHomepageTourTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-distribution/xwiki-platform-distribution-flavor/xwiki-platform-distribution-flavor-tour/ && format_xar

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-distribution/xwiki-platform-distribution-flavor/xwiki-platform-distribution-flavor-common/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MainWebHome&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-distribution/xwiki-platform-distribution-flavor/xwiki-platform-distribution-flavor-common/ && format_xar

    ##
    ## Wysiwyg 2.0
    ##

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Wysiwyg.Stringsproperties&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-gwt/xwiki-platform-gwt-user/src/main/resources/org/xwiki/gwt/user/client/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Wysiwyg.WidgetResources&app=Wysiwyg'

    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wysiwyg/xwiki-platform-wysiwyg-client/src/main/resources/org/xwiki/gwt/wysiwyg/client/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Wysiwyg.WYSIWYGEditorCoreParametrizedResources&app=Wysiwyg'

    ##
    ## Platform
    ##

    ## Administration
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-administration/xwiki-platform-administration-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiTemplateProviderTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-administration/xwiki-platform-administration-ui/ && format_xar

    ## Oldcore
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-oldcore/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiCoreResources&app=Platform'

    ## Repository
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-repository/xwiki-platform-repository-server-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.Repository&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-repository/xwiki-platform-repository-server-ui/ && format_xar

    ## Annotations
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-annotations/xwiki-platform-annotation-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.AnnotationCodeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-annotations/xwiki-platform-annotation-ui/ && format_xar

    ## Sandbox
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-sandbox/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.SandboxWebHome&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.PlatformSandboxTestPage&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-sandbox/ && format_xar

    ## Solr
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-search/xwiki-platform-search-solr/xwiki-platform-search-solr-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MainSolrTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-search/xwiki-platform-search-solr/xwiki-platform-search-solr-ui/ && format_xar

    ## Help
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-help/xwiki-platform-help-ui/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxTranslations&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxDefinitionLists&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxEscapes&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxGeneralRemarks&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxGroups&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxHeadings&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxHorizontalLine&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxHTML&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxImages&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxIntroduction&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxLinks&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxLists&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxMacros&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxNewLineLineBreaks&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxOtherSyntaxes&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxParagraphs&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxParameters&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxQuotations&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxScripts&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxTables&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxTextFormatting&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiXWikiSyntaxVerbatim&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.HelpTranslations&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.HelpSupportPanelContent&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-help/xwiki-platform-help-ui/ && format_xar

    ## Wiki
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-mainwiki/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.WikiManagerTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-mainwiki/ && format_xar
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-wiki/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.WikiWikiManagerTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-wiki/ && format_xar
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-common/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.CommonWikiManagerCommonTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-ui/xwiki-platform-wiki-ui-common/ && format_xar
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-wiki/xwiki-platform-wiki-default/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.xwiki-platform-wiki-default&app=Platform'

    ## Panels
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-panels/xwiki-platform-panels-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.PanelsTranslations&app=Platform'
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.PanelsCodeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-panels/xwiki-platform-panels-ui/ && format_xar

    ## Skin Extensions
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-skin/xwiki-platform-skin-skinx/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.SkinExtensions&app=Platform'

    ## Extension
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-extension/xwiki-platform-extension-handlers/xwiki-platform-extension-handler-xar/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.xwiki-platform-extension-handler-xar&app=Platform'

    ## Localization
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-localization/xwiki-platform-localization-macro/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.LocalizationMacro&app=Platform'

    ## Mail
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-mail/xwiki-platform-mail-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MailTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-mail/xwiki-platform-mail-ui/ && format_xar

    ## Index
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-index/xwiki-platform-index-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.IndexTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-index/xwiki-platform-index-ui/ && format_xar

    ## Document Tree Macro
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-index/xwiki-platform-index-tree/xwiki-platform-index-tree-macro/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiDocumentTreeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-index/xwiki-platform-index-tree/xwiki-platform-index-tree-macro/ && format_xar

    ## Tree Macro
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-tree/xwiki-platform-tree-macro/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MacrosTreeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-tree/xwiki-platform-tree-macro/ && format_xar

    ## Watchlist
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-watchlist/xwiki-platform-watchlist-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiWatchListTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-watchlist/xwiki-platform-watchlist-ui/ && format_xar

    ## Icon
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-icon/xwiki-platform-icon-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.IconThemesCodeTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-icon/xwiki-platform-icon-ui/ && format_xar

    ## Menu
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-menu/xwiki-platform-menu-ui/src/main/resources || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MenuApplication&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-menu/xwiki-platform-menu-ui/ && format_xar

    ## Invitation
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-invitation/xwiki-platform-invitation-ui/src/main/resources || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.InvitationTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-invitation/xwiki-platform-invitation-ui/ && format_xar

    ## Flamingo Theme (location changed in 7.2)
    if [[ -f "${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-flamingo/xwiki-platform-flamingo-themes/xwiki-platform-flamingo-theme-ui/pom.xml" ]]; then
      cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-flamingo/xwiki-platform-flamingo-themes/xwiki-platform-flamingo-theme-ui/src/main/resources/ || exit -1
      do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.FlamingoThemesCodeTranslations&app=Platform'
      cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-flamingo/xwiki-platform-flamingo-themes/xwiki-platform-flamingo-theme-ui && format_xar
    fi

    ## Activity Stream
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-activitystream/xwiki-platform-activitystream-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.MainActivityTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-activitystream/xwiki-platform-activitystream-ui/ && format_xar

    ## User
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-user/xwiki-platform-user-directory/xwiki-platform-user-directory-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiUserDirectoryTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-user/xwiki-platform-user-directory/xwiki-platform-user-directory-ui/ && format_xar

    ## User Profile
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-user/xwiki-platform-user-profile/xwiki-platform-user-profile-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiUserProfileTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-user/xwiki-platform-user-profile/xwiki-platform-user-profile-ui/ && format_xar

    ## Rating
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-ratings/xwiki-platform-ratings-api/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.Ratingmodule&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-ratings/xwiki-platform-ratings-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiRatingsTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-ratings/xwiki-platform-ratings-ui/ && format_xar

    ## Template (introduce in 7.0M1)
    if [[ -f "${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-template/pom.xml" ]]; then
        cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-template/xwiki-platform-template-api/src/main/resources/  || exit -1
        do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.TemplateMacro&app=Platform'
    fi

    ## Skin UI (introduced in 7.0RC1)
    if [[ -f "${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-skin/xwiki-platform-skin-ui/pom.xml" ]]; then
        cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-skin/xwiki-platform-skin-ui/src/main/resources/  || exit -1
        do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.SkinsCodeTranslations&app=Platform'
        cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-skin/xwiki-platform-skin-ui/ && format_xar
    fi

    ## Jetty listener
    if [[ -f "${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-tools/xwiki-platform-tool-jetty/xwiki-platform-tool-jetty-listener/pom.xml" ]]; then
        cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-tools/xwiki-platform-tool-jetty/xwiki-platform-tool-jetty-listener/src/main/resources/org/xwiki/tools/jetty/listener/  || exit -1
        do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.Jettylistener&app=Platform'
    fi

    ## Office UI (translations introduced in 7.2RC1)
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-office/xwiki-platform-office-ui/src/main/resources/  || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiOfficeImporterTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-office/xwiki-platform-office-ui/ && format_xar

    ## App Within Minutes
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-appwithinminutes/xwiki-platform-appwithinminutes-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.AppWithinMinutesTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-appwithinminutes/xwiki-platform-appwithinminutes-ui/ && format_xar

    ## Application
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-application/xwiki-platform-application-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.ApplicationsTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-application/xwiki-platform-application-ui/ && format_xar

    ## Dashboard
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-dashboard/xwiki-platform-dashboard-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.DashboardTranslations&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-dashboard/xwiki-platform-dashboard-ui/ && format_xar

    ## Administration (new in 8.3M1)
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-administration/xwiki-platform-administration-ui/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Platform.XWikiAdminTranslationsxml&app=Platform'
    cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-administration/xwiki-platform-administration-ui && format_xar

    ## Notifications (new in 9.2RC1)
    if [[ -f "${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-notifications/xwiki-platform-notifications-ui/pom.xml" ]]; then
      cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-notifications/xwiki-platform-notifications-ui/src/main/resources/ || exit -1
      do_one 'https://l10n.xwiki.org/xwiki/bin/view/L10NCode/GetTranslationFile?name=Platform.XWikiNotificationsCodeTranslations&app=Platform'
      cd ${XWIKI_TRUNKS}/xwiki-platform/xwiki-platform-core/xwiki-platform-notifications/xwiki-platform-notifications-ui && format_xar
    fi

    ##
    ## Rendering
    ##

    ## Content Macro
    cd ${XWIKI_TRUNKS}/xwiki-rendering/xwiki-rendering-macros/xwiki-rendering-macro-content/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Rendering.ContentMacro&app=Rendering'

    ##
    ## Commons
    ##

    ## Job
    cd ${XWIKI_TRUNKS}/xwiki-commons/xwiki-commons-core/xwiki-commons-job/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Commons.xwiki-commons-job&app=Commons'

    ## Extension
    cd ${XWIKI_TRUNKS}/xwiki-commons/xwiki-commons-core/xwiki-commons-extension/xwiki-commons-extension-api/src/main/resources/ || exit -1
    do_one 'https://l10n.xwiki.org/xwiki/bin/get/L10NCode/GetTranslationFile?name=Commons.xwiki-commons-extension-api&app=Commons'

    cd ${XWIKI_TRUNKS}/xwiki-platform/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-rendering/ || exit -1
    git status
    cd ${XWIKI_TRUNKS}/xwiki-commons/ || exit -1
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
    cd ${XWIKI_TRUNKS}/xwiki-platform/
    git add . && git commit  -m "${MSG}" && git push
    cd ${XWIKI_TRUNKS}/xwiki-rendering/
    git add . && git commit  -m "${MSG}" && git push
    cd ${XWIKI_TRUNKS}/xwiki-commons/
    git add . && git commit  -m "${MSG}" && git push
}

if [[ $1 == 'commit' ]]; then
    commit
elif [[ $1 == 'clean' ]]; then
    cd ${XWIKI_TRUNKS}/xwiki-platform/
    git reset --hard && git clean -dxf
    cd ${XWIKI_TRUNKS}/xwiki-rendering/
    git reset --hard && git clean -dxf
    cd ${XWIKI_TRUNKS}/xwiki-commons/
    git reset --hard && git clean -dxf
else
    check_clean xwiki-platform
    check_clean xwiki-rendering
    check_clean xwiki-commons
    do_all
fi
