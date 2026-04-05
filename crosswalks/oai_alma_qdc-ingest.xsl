<?xml version="1.0" encoding="UTF-8"?>
<!--
    oai_alma_qdc-ingest.xsl
    Crosswalk de ingesta: ALMA oai_qdc (Qualified Dublin Core) → DSpace DIM
    
    Proyecto: InES Ciencia Abierta USACH
    Autor: Ricardo Rodriguez — VRIIC USACH
    Fecha: Marzo 2026
    
    Fuente OAI: https://na06.alma.exlibrisgroup.com/view/oai/56USACH_INST
    Set: OAI_cienciaabierta
    Namespace origen: http://alma.exlibrisgroup.com/schemas/qdc-1.0/
    Entidad DSpace destino: Publication (Tesis)
    
    Campos mapeados:
      dc:title              → dc.title
      dc:creator            → dc.contributor.author
      dc:contributor        → dc.contributor.advisor (si contiene "profesor guía")
                            → dc.contributor (otros roles)
      dcterms:contributor   → dc.description.department (facultad/departamento)
      dc:publisher          → dc.publisher
      dcterms:date          → dc.date.issued (año académico)
      dc:date               → dc.date.available
      dcterms:dateAccepted  → dc.date.accessioned
      dcterms:dateSubmitted → dc.date.submitted
      dc:subject            → dc.subject
      dc:description /
      dcterms:description   → dc.description.abstract / dc.description.place
      dcterms:educationLevel→ dc.description.degree
      dcterms:extent        → dcterms.extent
      dc:format             → dc.format
      dc:language           → dc.language.iso
      dcterms:license       → dc.rights.license
      dcterms:rights        → dc.rights
      dc:type               → dc.type
      dc:identifier (URI)   → dc.identifier.uri
      dc:identifier (alma:) → dc.identifier.other
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/1.1/"
    xmlns:oai_qdc="http://alma.exlibrisgroup.com/schemas/qdc-1.0/"
    xmlns:dim="http://www.dspace.org/xmlns/dspace/dim"
    version="1.0">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <xsl:template match="/">
    <dim:dim>

      <!-- ── TÍTULO ─────────────────────────────────────────── -->
      <xsl:for-each select="//dc:title">
        <dim:field mdschema="dc" element="title">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── AUTOR (dc:creator) ─────────────────────────────── -->
      <xsl:for-each select="//dc:creator">
        <dim:field mdschema="dc" element="contributor" qualifier="author">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── COLABORADORES (dc:contributor) ────────────────────
           Distingue "profesor guía" del resto por texto libre   -->
      <xsl:for-each select="//dc:contributor">
        <xsl:choose>
          <xsl:when test="contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'profesor') or
                          contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'guía') or
                          contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'guia') or
                          contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'tutor') or
                          contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'director')">
            <dim:field mdschema="dc" element="contributor" qualifier="advisor">
              <!-- Extraer solo el nombre, sin el rol -->
              <xsl:choose>
                <xsl:when test="contains(., ',')">
                  <!-- Formato: "Apellido, Nombre, rol" → tomar hasta la segunda coma -->
                  <xsl:value-of select="normalize-space(substring-before(
                    substring-after(concat(., ','), ','), ','))"/>
                  <xsl:if test="not(contains(substring-after(., ','), ','))">
                    <xsl:value-of select="normalize-space(.)"/>
                  </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="normalize-space(.)"/>
                </xsl:otherwise>
              </xsl:choose>
            </dim:field>
          </xsl:when>
          <xsl:otherwise>
            <dim:field mdschema="dc" element="contributor">
              <xsl:value-of select="normalize-space(.)"/>
            </dim:field>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>

      <!-- ── FACULTAD / DEPARTAMENTO (dcterms:contributor) ──── -->
      <xsl:for-each select="//dcterms:contributor">
        <dim:field mdschema="dc" element="description" qualifier="department">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── EDITORIAL / UNIVERSIDAD ───────────────────────── -->
      <xsl:for-each select="//dc:publisher">
        <dim:field mdschema="dc" element="publisher">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── FECHAS ──────────────────────────────────────────── -->
      <!-- Año académico (dcterms:date) → dc.date.issued -->
      <xsl:for-each select="//dcterms:date">
        <dim:field mdschema="dc" element="date" qualifier="issued">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- Fecha de disponibilidad (dc:date) → dc.date.available -->
      <xsl:for-each select="//dc:date">
        <dim:field mdschema="dc" element="date" qualifier="available">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- Fecha de aceptación → dc.date.accessioned -->
      <xsl:for-each select="//dcterms:dateAccepted">
        <dim:field mdschema="dc" element="date" qualifier="accessioned">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- Fecha de envío → dc.date.submitted -->
      <xsl:for-each select="//dcterms:dateSubmitted">
        <dim:field mdschema="dc" element="date" qualifier="submitted">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── MATERIAS / PALABRAS CLAVE ──────────────────────── -->
      <xsl:for-each select="//dc:subject">
        <dim:field mdschema="dc" element="subject">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── DESCRIPCIÓN / RESUMEN ──────────────────────────── -->
      <xsl:for-each select="//dc:description">
        <dim:field mdschema="dc" element="description" qualifier="abstract">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- dcterms:description → lugar (Santiago) -->
      <xsl:for-each select="//dcterms:description">
        <dim:field mdschema="dc" element="description" qualifier="place">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── GRADO ACADÉMICO (dcterms:educationLevel) ────────── -->
      <xsl:for-each select="//dcterms:educationLevel">
        <dim:field mdschema="dc" element="description" qualifier="degree">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── EXTENSIÓN (dcterms:extent) ─────────────────────── -->
      <xsl:for-each select="//dcterms:extent">
        <dim:field mdschema="dcterms" element="extent">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── FORMATO ─────────────────────────────────────────── -->
      <xsl:for-each select="//dc:format">
        <dim:field mdschema="dc" element="format">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── IDIOMA ──────────────────────────────────────────── -->
      <xsl:for-each select="//dc:language">
        <dim:field mdschema="dc" element="language" qualifier="iso">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── LICENCIA ────────────────────────────────────────── -->
      <xsl:for-each select="//dcterms:license">
        <dim:field mdschema="dc" element="rights" qualifier="license">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── DERECHOS ────────────────────────────────────────── -->
      <xsl:for-each select="//dcterms:rights">
        <dim:field mdschema="dc" element="rights">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── TIPO ────────────────────────────────────────────── -->
      <xsl:for-each select="//dc:type">
        <dim:field mdschema="dc" element="type">
          <xsl:value-of select="normalize-space(.)"/>
        </dim:field>
      </xsl:for-each>

      <!-- ── IDENTIFICADORES ─────────────────────────────────── -->
      <xsl:for-each select="//dc:identifier">
        <xsl:choose>
          <!-- URL del descubridor ALMA → dc.identifier.uri -->
          <xsl:when test="starts-with(normalize-space(.), 'http')">
            <dim:field mdschema="dc" element="identifier" qualifier="uri">
              <xsl:value-of select="normalize-space(.)"/>
            </dim:field>
          </xsl:when>
          <!-- ID interno ALMA (alma:...) → dc.identifier.other -->
          <xsl:when test="starts-with(normalize-space(.), 'alma:')">
            <dim:field mdschema="dc" element="identifier" qualifier="other">
              <xsl:value-of select="normalize-space(.)"/>
            </dim:field>
          </xsl:when>
          <xsl:otherwise>
            <dim:field mdschema="dc" element="identifier">
              <xsl:value-of select="normalize-space(.)"/>
            </dim:field>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>

    </dim:dim>
  </xsl:template>

</xsl:stylesheet>
