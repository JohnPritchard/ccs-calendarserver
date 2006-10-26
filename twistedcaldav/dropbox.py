##
# Copyright (c) 2006 Apple Computer, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# DRI: Cyrus Daboo, cdaboo@apple.com
##

"""
Implements drop-box functionality. A drop box is an external attachment store that provides
for automatic notification of changes to subscribed users.
"""

__all__ = [
    "DropBox",
]

from twisted.web2.dav.resource import twisted_dav_namespace

from twistedcaldav.customxml import davxml
from twistedcaldav.resource import CalendarPrincipalResource
from twistedcaldav.static import CalDAVFile

import os

class DropBox(object):
    
    # These are all options that will be set from a .plist configuration file.

    enabled = True                # Whether or not drop box functionaility is enabled.
    dropboxName = "dropbox"       # Name of the collection in which drop boxes can be created.
    inheritedACLs = True          # Whether or not ACLs set on a drop box collection are automatically
                                  # inherited by child resources.
                                  
    notifications = True          # Whether to post notification messages into per-user notification collection.
    notifcationName = "notify"    # Name of the collection in which notifications will be stored.
    
    @classmethod
    def enable(clzz, enabled, dropboxName=None, inheritedACLs=None, notifications=None, notificationName=None):
        """
        This method must be used to enable drop box support as it will setup live properties etc,
        and turn on the notification system. It must only be called once

        @param enable: C{True} if drop box feature is enabled, C{False} otherwise
        @param dropboxName: C{str} containing the name of the drop box home collection
        @param inheritedACLs: C{True} if ACLs on drop boxes should be inherited by their contents, C{False} otehrwise.
        @param notifications: C{True} if automatic notifications are to be sent when a drop box changes, C{False} otherwise.
        @param notificationName: C{str} containing the name of the collection used to store per-user notifications.
        """
        DropBox.enabled = enabled
        if dropboxName:
            DropBox.dropboxName = dropboxName
        if inheritedACLs:
            DropBox.inheritedACLs = inheritedACLs
        if notifications:
            DropBox.notifications = notifications
        if notificationName:
            DropBox.notifcationName = notificationName

        if DropBox.enabled:

            # Need to setup live properties
            assert (twisted_dav_namespace, "dropbox-home-URL") not in CalendarPrincipalResource.liveProperties, \
                "DropBox.enable must only be called once"

            CalendarPrincipalResource.liveProperties += (
                (twisted_dav_namespace, "dropbox-home-URL"  ),
                (twisted_dav_namespace, "notifications-URL" ),
            )

    @classmethod
    def provision(clzz, principal, cuhome):
        """
        Provision user account with appropriate collections for drop box
        and notifications.
        
        @param principal: the L{CalendarPrincipalResource} for the principal to provision
        @param cuhome: C{tuple} of (C{str} - URI of user calendar home, L{DAVResource} - resource of user calendar home)
        """
        
        # Only if enabled
        if not DropBox.enabled:
            return
        
        # Create drop box collection in calendar-home collection resource if not already present.
        
        child = CalDAVFile(os.path.join(cuhome[1].fp.path, DropBox.dropboxName))
        child_exists = child.exists()
        if not child_exists:
            c = child.createSpecialCollection(davxml.ResourceType.dropboxhome)
            assert c.called
            c = c.result
        
        if not DropBox.notifications:
            return
        
        child = CalDAVFile(os.path.join(cuhome[1].fp.path, DropBox.notifcationName))
        child_exists = child.exists()
        if not child_exists:
            c = child.createSpecialCollection(davxml.ResourceType.notifications)
            assert c.called
            c = c.result
        