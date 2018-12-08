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

from __future__ import unicode_literals

from django.utils.translation import ugettext_lazy as _

from weblate.addons.scripts import BaseScriptAddon
from weblate.addons.events import EVENT_POST_UPDATE, EVENT_POST_COMMIT, EVENT_PRE_COMMIT


class XWikiPostUpdateAddon(BaseScriptAddon):
    # List of events addon should receive
    events = (EVENT_POST_UPDATE,)
    # Addon unique identifier
    name = 'xwiki.post_update'
    # Verbose name shown in the user interface
    verbose = _('XWiki post update script')
    # Detailed addon description
    description = _('See https://github.com/xwiki/xwiki-dev-tools/tree/master/weblate-scripts#post-update-script')
    # Script to execute
    script = '/home/weblate/xwiki-dev-tools/weblate-scripts/post_update.sh'

class XWikiPostCommitAddon(BaseScriptAddon):
    # List of events addon should receive
    events = (EVENT_POST_COMMIT,)
    # Addon unique identifier
    name = 'xwiki.post_commit'
    # Verbose name shown in the user interface
    verbose = _('XWiki post commit script')
    # Detailed addon description
    description = _('See https://github.com/xwiki/xwiki-dev-tools/tree/master/weblate-scripts#post-commit-script')
    # Script to execute
    script = '/home/weblate/xwiki-dev-tools/weblate-scripts/post_commit.sh'

class XWikiPreCommitAddon(BaseScriptAddon):
    # List of events addon should receive
    events = (EVENT_PRE_COMMIT,)
    # Addon unique identifier
    name = 'xwiki.pre_commit'
    # Verbose name shown in the user interface
    verbose = _('XWiki pre commit script')
    # Detailed addon description
    description = _('See https://github.com/xwiki/xwiki-dev-tools/tree/master/weblate-scripts#pre-commit-script')
    # Script to execute
    script = '/home/weblate/xwiki-dev-tools/weblate-scripts/pre_commit.sh'
    # Files to add
    add_file = '*' # The post commit script take care of removing the .translation folder
