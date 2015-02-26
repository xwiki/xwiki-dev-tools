/*
 * See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */
package org.xwiki.devtools.jira.template;

import org.apache.log4j.LogManager;
import org.apache.log4j.Logger;

import com.atlassian.jira.blueprint.api.AddProjectHook;
import com.atlassian.jira.blueprint.api.ConfigureData;
import com.atlassian.jira.blueprint.api.ConfigureResponse;
import com.atlassian.jira.blueprint.api.ValidateData;
import com.atlassian.jira.blueprint.api.ValidateResponse;
import com.atlassian.jira.component.ComponentAccessor;
import com.atlassian.jira.issue.fields.layout.field.FieldLayoutManager;
import com.atlassian.jira.issue.fields.layout.field.FieldLayoutScheme;
import com.atlassian.jira.issue.fields.screen.issuetype.IssueTypeScreenScheme;
import com.atlassian.jira.issue.fields.screen.issuetype.IssueTypeScreenSchemeManager;
import com.atlassian.jira.notification.NotificationSchemeManager;
import com.atlassian.jira.permission.PermissionSchemeManager;
import com.atlassian.jira.project.Project;
import com.atlassian.jira.project.ProjectCategory;
import com.atlassian.jira.project.ProjectManager;
import com.atlassian.jira.scheme.Scheme;
import com.atlassian.jira.workflow.WorkflowSchemeManager;

public class XWikiAddProjectHook implements AddProjectHook
{
    private static final Logger LOGGER = LogManager.getLogger(XWikiAddProjectHook.class);

    @Override
    public ValidateResponse validate(final ValidateData validateData)
    {
        return ValidateResponse.create();
    }

    @Override
    public ConfigureResponse configure(final ConfigureData configureData)
    {
        Project project = configureData.project();


        // Set Workflow Scheme
        WorkflowSchemeManager workflowSchemeManager = ComponentAccessor.getWorkflowSchemeManager();
        Scheme xwikiScheme = workflowSchemeManager.getSchemeObject("XWiki Workflow Scheme");
        if (xwikiScheme != null) {
            workflowSchemeManager.removeSchemesFromProject(project);
            workflowSchemeManager.addSchemeToProject(project, xwikiScheme);
        } else {
            LOGGER.warn(String.format("[XWiki] Failed to find the \"XWiki Workflow Scheme\" scheme. "
                + "It is not set for the new project [%s]", project.getName()));
        }

        // Set Notification Scheme
        NotificationSchemeManager notificationSchemeManager = ComponentAccessor.getNotificationSchemeManager();
        Scheme notificationScheme = notificationSchemeManager.getSchemeObject("XWiki Notification Scheme");
        if (notificationScheme != null) {
            notificationSchemeManager.removeSchemesFromProject(project);
            notificationSchemeManager.addSchemeToProject(project, notificationScheme);
        } else {
            LOGGER.warn(String.format("[XWiki] Failed to find the \"XWiki Notification Scheme\" scheme. "
                + "It is not set for the new project [%s]", project.getName()));
        }

        // Set Permission Scheme
        PermissionSchemeManager permissionSchemeManager = ComponentAccessor.getPermissionSchemeManager();
        Scheme permissionScheme = permissionSchemeManager.getSchemeObject("XWiki Open");
        if (permissionScheme != null) {
            // Remove all defined permissions screen since there can be only ony apparently
            permissionSchemeManager.removeSchemesFromProject(project);
            permissionSchemeManager.addSchemeToProject(project, permissionScheme);
        } else {
            LOGGER.warn(String.format("[XWiki] Failed to find the \"XWiki Open\" scheme. "
                + "It is not set for the new project [%s]", project.getName()));
        }

        // Set Project Category
        ProjectManager projectManager = ComponentAccessor.getProjectManager();
        ProjectCategory contribCategory = projectManager.getProjectCategoryObjectByName("XWiki Contributed Projects");
        if (contribCategory != null) {
            projectManager.setProjectCategory(project, contribCategory);
        } else {
            LOGGER.warn(String.format("[XWiki] Failed to find the \"XWiki Contributed Projects\" category. "
                + "It is not set for the new project [%s]", project.getName()));
        }

        // Set Field Configuration Scheme
        FieldLayoutManager fieldLayoutManager = ComponentAccessor.getFieldLayoutManager();
        // Note: I couldn't find a way to get the Field Configuration Scheme by String so I'm iterating over all of them
        FieldLayoutScheme fieldLayoutScheme = null;
        for (FieldLayoutScheme scheme : fieldLayoutManager.getFieldLayoutSchemes()) {
            if (scheme.getName().equals("XWiki Open Field Configuration Scheme")) {
                fieldLayoutScheme = scheme;
                break;
            }
        }
        if (fieldLayoutScheme != null) {
            fieldLayoutManager.addSchemeAssociation(project, fieldLayoutScheme.getId());
        }

        // Set Screen Scheme
        IssueTypeScreenSchemeManager issueTypeScreenSchemeManager = ComponentAccessor.getIssueTypeScreenSchemeManager();
        // Note: I couldn't find a way to get the Screen Scheme by String so I'm iterating over all of them
        IssueTypeScreenScheme screenScheme = null;
        for (IssueTypeScreenScheme scheme : issueTypeScreenSchemeManager.getIssueTypeScreenSchemes()) {
            if (scheme.getName().equals("Basic Issue Creation Scheme")) {
                screenScheme = scheme;
                break;
            }
        }
        if (screenScheme != null) {
            issueTypeScreenSchemeManager.addSchemeAssociation(project, screenScheme);
        } else {
            LOGGER.warn(String.format("[XWiki] Failed to find the \"Basic Issue Creation Scheme\" scheme. "
                + "It is not set for the new project [%s]", project.getName()));
        }

        return ConfigureResponse.create().setRedirect("/plugins/servlet/project-config/" + project.getKey()
            + "/summary");
    }
}
