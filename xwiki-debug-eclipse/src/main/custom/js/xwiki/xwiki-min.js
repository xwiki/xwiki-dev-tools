function include(filename)
{
    var head = document.getElementsByTagName('head')[0];

    var script = document.createElement('script');
    script.src = filename;
    script.type = 'text/javascript';

    head.appendChild(script);
}

include('/xwiki/resources/js/xwiki/xwiki.js');
include('/xwiki/resources/js/xwiki/widgets/modalPopup.js');
include('/xwiki/resources/js/xwiki/widgets/jumpToPage.js');
include('/xwiki/resources/uicomponents/model/entityReference.js');
include('/xwiki/resources/uicomponents/widgets/confirmationBox.js');
include('/xwiki/resources/uicomponents/widgets/confirmedAjaxRequest.js');
include('/xwiki/resources/uicomponents/widgets/notification.js');
include('/xwiki/resources/uicomponents/widgets/list/xlist.js');
include('/xwiki/resources/uicomponents/suggest/suggest.js');
