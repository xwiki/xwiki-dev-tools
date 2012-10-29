<?xml version="1.0" encoding="UTF-8"?>
<!--
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
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:mvn="http://maven.apache.org/POM/4.0.0">

    <xsl:output method="xml" encoding="UTF-8"/>

    <!-- Generic copy template that keeps everything as it is. Low priority, so more specific templates will be called for more specific cases. -->
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <!-- Skip all the clirr exclude nodes following the "to be removed" comment, so that they are removed from the output XML. -->
    <xsl:template match="mvn:plugin[string(./mvn:artifactId) = 'clirr-maven-plugin']/mvn:configuration/mvn:excludes/node()">
      <xsl:if test="not(preceding-sibling::comment()[contains(string(.), 'release')])">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:if>
    </xsl:template>
</xsl:stylesheet>
