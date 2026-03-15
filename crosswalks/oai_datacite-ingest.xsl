<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:datacite="http://datacite.org/schema/kernel-4"
    xmlns:dim="http://www.dspace.org/xmlns/dspace/dim"
    version="1.0">

    <xsl:output method="xml" indent="yes"/>

    <xsl:template match="/">
        <dim:dim>

            <!-- Identificador DOI -->
            <xsl:for-each select="//datacite:identifier[@identifierType='DOI']">
                <dim:field mdschema="dc" element="identifier" qualifier="doi">
                    <xsl:value-of select="."/>
                </dim:field>
                <dim:field mdschema="dc" element="identifier" qualifier="uri">
                    <xsl:text>https://doi.org/</xsl:text>
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Título principal -->
            <xsl:for-each select="//datacite:titles/datacite:title[not(@titleType)]">
                <dim:field mdschema="dc" element="title">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Título alternativo -->
            <xsl:for-each select="//datacite:titles/datacite:title[@titleType='AlternativeTitle']">
                <dim:field mdschema="dc" element="title" qualifier="alternative">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Creadores -->
            <xsl:for-each select="//datacite:creators/datacite:creator">
                <dim:field mdschema="dc" element="contributor" qualifier="author">
                    <xsl:value-of select="datacite:creatorName"/>
                </dim:field>
                <xsl:if test="datacite:affiliation">
                    <dim:field mdschema="oairecerif" element="author" qualifier="affiliation">
                        <xsl:value-of select="datacite:affiliation"/>
                    </dim:field>
                </xsl:if>
            </xsl:for-each>

            <!-- Colaboradores -->
            <xsl:for-each select="//datacite:contributors/datacite:contributor">
                <dim:field mdschema="dc" element="contributor">
                    <xsl:value-of select="datacite:contributorName"/>
                </dim:field>
            </xsl:for-each>

            <!-- Publisher -->
            <xsl:for-each select="//datacite:publisher">
                <dim:field mdschema="dc" element="publisher">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Año de publicación -->
            <xsl:for-each select="//datacite:publicationYear">
                <dim:field mdschema="dc" element="date" qualifier="issued">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Fecha submitted -->
            <xsl:for-each select="//datacite:dates/datacite:date[@dateType='Submitted']">
                <dim:field mdschema="dc" element="date" qualifier="submitted">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Tipo de recurso -->
            <xsl:for-each select="//datacite:resourceType">
                <dim:field mdschema="dc" element="type">
                    <xsl:value-of select="@resourceTypeGeneral"/>
                </dim:field>
            </xsl:for-each>

            <!-- Materias -->
            <xsl:for-each select="//datacite:subjects/datacite:subject">
                <dim:field mdschema="dc" element="subject">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Abstract -->
            <xsl:for-each select="//datacite:descriptions/datacite:description[@descriptionType='Abstract']">
                <dim:field mdschema="dc" element="description" qualifier="abstract">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Descripción técnica -->
            <xsl:for-each select="//datacite:descriptions/datacite:description[@descriptionType='TechnicalInfo']">
                <dim:field mdschema="dc" element="description">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Derechos de acceso -->
            <xsl:for-each select="//datacite:rightsList/datacite:rights[@rightsURI]">
                <xsl:if test="contains(@rightsURI,'openAccess') or contains(@rightsURI,'restrictedAccess') or contains(@rightsURI,'embargoedAccess')">
                    <dim:field mdschema="datacite" element="rights">
                        <xsl:value-of select="@rightsURI"/>
                    </dim:field>
                </xsl:if>
                <xsl:if test="contains(@rightsURI,'creativecommons') or contains(@rightsURI,'licenses')">
                    <dim:field mdschema="oaire" element="licenseCondition">
                        <xsl:value-of select="@rightsURI"/>
                    </dim:field>
                </xsl:if>
            </xsl:for-each>

            <!-- Versión -->
            <xsl:for-each select="//datacite:version">
                <dim:field mdschema="dc" element="description" qualifier="version">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Formato -->
            <xsl:for-each select="//datacite:formats/datacite:format">
                <dim:field mdschema="dc" element="format">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Identificador alternativo -->
            <xsl:for-each select="//datacite:alternateIdentifiers/datacite:alternateIdentifier">
                <dim:field mdschema="dc" element="identifier">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

            <!-- Financiamiento -->
            <xsl:for-each select="//datacite:fundingReferences/datacite:fundingReference">
                <dim:field mdschema="dc" element="relation" qualifier="funding">
                    <xsl:value-of select="datacite:funderName"/>
                    <xsl:if test="datacite:awardNumber">
                        <xsl:text>::</xsl:text>
                        <xsl:value-of select="datacite:awardNumber"/>
                    </xsl:if>
                </dim:field>
            </xsl:for-each>

            <!-- Idioma -->
            <xsl:for-each select="//datacite:language">
                <dim:field mdschema="dc" element="language" qualifier="iso">
                    <xsl:value-of select="."/>
                </dim:field>
            </xsl:for-each>

        </dim:dim>
    </xsl:template>
</xsl:stylesheet>
