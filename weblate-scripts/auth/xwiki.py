# ---------------------------------------------------------------------------
# See the NOTICE file distributed with this work for additional
# information regarding copyright ownership.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
# ---------------------------------------------------------------------------
from social_core.backends.oauth import BaseOAuth2

class XWikiOAuth2(BaseOAuth2):
    name = 'XWiki'
    ID_KEY = 'sub'
    ## We cannot direct to the load balancer since all request should be made on same instance
    ## and we cannot guarantee that first request won't be done on node1 and then on node2.
    ## So to avoid the problem we direct requests to node1 directly.
    XWIKI_URL = 'https://www.xwikiorg-node1.xwikisas.com/xwiki'
    AUTHORIZATION_URL = '{0}/oidc/authorization'.format(XWIKI_URL)
    ACCESS_TOKEN_URL = '{0}/oidc/token'.format(XWIKI_URL)
    REDIRECT_STATE = False
    ACCESS_TOKEN_METHOD = 'POST'

    def get_user_details(self, response):
        username = response.get('sub').split('.')[-1]
        fullname, first_name, last_name = self.get_user_names(response.get('name'))
        return {
            'username': username,
            'email': response.get('email'),
            'fullname': fullname,
            'first_name': first_name,
            'last_name': last_name
        }

    def user_data(self, access_token, *args, **kwargs):
        return self.get_json(
            '{0}/oidc/userinfo'.format(self.XWIKI_URL),
            params={'access_token': access_token}
        )

## For using this authentication module in Weblate, perform the following step:
## 1. Import the module in settings.py with
## from weblate.auth.xwiki import XWikiOAuth2
## 2. Enable the usage of the module in AUTHENTICATION_BACKENDS:
## AUTHENTICATION_BACKENDS = ("weblate.auth.xwiki.XWikiOAuth2",)
## 3. Set the SOCIAL_AUTH_XWIKI_KEY in settings.py with the appropriate value.
