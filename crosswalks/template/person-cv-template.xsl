<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:fox="http://xmlgraphics.apache.org/fop/extensions"
                xmlns:pdf="http://xmlgraphics.apache.org/fop/extensions/pdf"
                exclude-result-prefixes="fo">

    <xsl:param name="imageDir" />
    <xsl:param name="fontFamily" />

    <!-- Language parameter for conjunctions in author lists: 'es' or 'en' -->
    <xsl:param name="lang" select="'es'"/>

    <xsl:template match="person">
        <fo:root
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:fox="http://xmlgraphics.apache.org/fop/extensions">
            <xsl:attribute name="font-family">
                <xsl:value-of select="$fontFamily" />
            </xsl:attribute>
            <fo:layout-master-set>
                <fo:simple-page-master master-name="simpleA4"
                                       page-height="29.7cm" page-width="24cm" margin-top="2cm"
                                       margin-bottom="2cm" margin-left="1cm" margin-right="1cm">
                    <fo:region-body />
                </fo:simple-page-master>
            </fo:layout-master-set>
            <fo:page-sequence master-reference="simpleA4">
                <fo:flow flow-name="xsl-region-body">

                    <fo:table>
                        <xsl:choose>
                            <xsl:when test="personal-picture">
                                <fo:table-column column-width="33%"/>
                                <fo:table-column column-width="67%"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <fo:table-column />
                            </xsl:otherwise>
                        </xsl:choose>
                        <fo:table-body>
                            <fo:table-row>
                                <xsl:if test="personal-picture">
                                    <fo:table-cell>
                                        <fo:block font-size="10pt" font-weight="bold" text-align="center" >
                                            <xsl:variable name="picturePath" select="concat('file:',$imageDir,'/',personal-picture)" />
                                            <fo:external-graphic content-height="scale-to-fit" height="2.40in"  content-width="2.00in" scaling="non-uniform">
                                                <xsl:attribute name="src">
                                                    <xsl:value-of select="$picturePath" />
                                                </xsl:attribute>
                                            </fo:external-graphic>
                                        </fo:block>
                                    </fo:table-cell>
                                </xsl:if>
                                <fo:table-cell>
                                    <fo:block background-color="#8cc0db" margin-bottom="5mm" padding="2mm">
                                        <fo:block font-size="26pt" font-weight="bold" text-align="center" >
                                            <xsl:value-of select="names/preferred-name"  />
                                        </fo:block>
                                        <fo:block font-size="12pt" text-align="center">
                                            <xsl:value-of select="job-title"  />
                                            <xsl:if test="job-title and main-affiliation">
                                                <xsl:text> at </xsl:text>
                                            </xsl:if>
                                            <xsl:value-of select="main-affiliation"  />
                                        </fo:block>
                                    </fo:block>

                                    <xsl:call-template name="print-value">
                                        <xsl:with-param name="label" select="'Birth Date'" />
                                        <xsl:with-param name="value" select="birth-date" />
                                    </xsl:call-template>
                                    <xsl:call-template name="print-value">
                                        <xsl:with-param name="label" select="'Gender'" />
                                        <xsl:with-param name="value" select="gender" />
                                    </xsl:call-template>
                                    <xsl:call-template name="print-value">
                                        <xsl:with-param name="label" select="'Country'" />
                                        <xsl:with-param name="value" select="country" />
                                    </xsl:call-template>
                                    <xsl:call-template name="print-value">
                                        <xsl:with-param name="label" select="'Email'" />
                                        <xsl:with-param name="value" select="email" />
                                    </xsl:call-template>
                                    <xsl:call-template name="print-value">
                                        <xsl:with-param name="label" select="'ORCID'" />
                                        <xsl:with-param name="value" select="identifiers/orcid" />
                                    </xsl:call-template>
                                    <xsl:call-template name="print-values">
                                        <xsl:with-param name="label" select="'Scopus Author IDs'" />
                                        <xsl:with-param name="values" select="identifiers/scopus-author-ids/scopus-author-id" />
                                    </xsl:call-template>

                                </fo:table-cell>
                            </fo:table-row>
                        </fo:table-body>
                    </fo:table>

                    <fo:block font-size="10pt" space-after="5mm" text-align="justify" margin-top="5mm" >
                        <xsl:value-of select="biography" />
                    </fo:block>

                </fo:flow>
            </fo:page-sequence>

            <xsl:if test="personal-cv">
                <xsl:variable name="cvPath" select="concat('file:',$imageDir,'/',personal-cv)" />
                <fox:external-document content-type="pdf" content-width="scale-to-fit" width="24cm">
                    <xsl:attribute name="src">
                        <xsl:value-of select="$cvPath" />
                    </xsl:attribute>
                </fox:external-document>
            </xsl:if>

            <xsl:if test="(affiliations/affiliation) or (educations/education) or (qualifications/qualification) or (publications/publication) or (personal-sites/personal-site) or (( count(working-groups/working-group) &gt; 0 ) or ( count(interests/interest) &gt; 0 ) or ( count(knows-languages/language) &gt; 0 ))">
                <fo:page-sequence master-reference="simpleA4">
                    <fo:flow flow-name="xsl-region-body">
                        <xsl:if test="affiliations/affiliation">

                            <xsl:call-template name="section-title">
                                <xsl:with-param name="label" select="'Affiliations'" />
                            </xsl:call-template>

                            <xsl:for-each select="affiliations/affiliation">
                                <fo:block font-size="10pt">
                                    <xsl:value-of select="role" /> at <xsl:value-of select="name" />
                                    from <xsl:value-of select="start-date" />
                                    <xsl:if test="end-date/text()">
                                        to <xsl:value-of select="end-date" />
                                    </xsl:if>
                                </fo:block>
                            </xsl:for-each>

                        </xsl:if>

                        <xsl:if test="educations/education">

                            <xsl:call-template name="section-title">
                                <xsl:with-param name="label" select="'Education'" />
                            </xsl:call-template>

                            <xsl:for-each select="educations/education">
                                <fo:block font-size="10pt">
                                    <xsl:value-of select="role" /> at <xsl:value-of select="name" />
                                    from <xsl:value-of select="start-date" />
                                    <xsl:if test="end-date/text()">
                                        to <xsl:value-of select="end-date" />
                                    </xsl:if>
                                </fo:block>
                            </xsl:for-each>

                        </xsl:if>

                        <xsl:if test="qualifications/qualification">

                            <xsl:call-template name="section-title">
                                <xsl:with-param name="label" select="'Qualifications'" />
                            </xsl:call-template>

                            <xsl:for-each select="qualifications/qualification">
                                <fo:block font-size="10pt">
                                    <xsl:value-of select="name" /> from <xsl:value-of select="start-date" />
                                    <xsl:if test="end-date/text()">
                                        to <xsl:value-of select="end-date" />
                                    </xsl:if>
                                </fo:block>
                            </xsl:for-each>

                        </xsl:if>


                        <xsl:if test="publications/publication">

                            <xsl:call-template name="section-title">
                                <xsl:with-param name="label" select="'Publications (APA 7)'" />
                            </xsl:call-template>

                            <xsl:for-each select="publications/publication">
                                <fo:block font-size="10pt" space-after="2mm">

                                    <!-- APA 7 Authors with language-aware conjunction and +20 rule -->
                                    <xsl:variable name="authorCount" select="count(authors/author)"/>
                                    <xsl:choose>
                                        <!-- Case: more than 20 authors → first 19, ellipsis, last author (no conjunction) -->
                                        <xsl:when test="$authorCount &gt; 20">
                                            <!-- First 19 authors -->
                                            <xsl:for-each select="authors/author[position() &lt;= 19]">
                                                <xsl:variable name="apaAuthor">
                                                    <xsl:call-template name="apa-author">
                                                        <xsl:with-param name="full" select="."/>
                                                    </xsl:call-template>
                                                </xsl:variable>
                                                <xsl:value-of select="normalize-space($apaAuthor)"/>
                                                <xsl:if test="position() != last()">
                                                    <xsl:text>, </xsl:text>
                                                </xsl:if>
                                            </xsl:for-each>
                                            <!-- Ellipsis and last author -->
                                            <xsl:text>, …, </xsl:text>
                                            <xsl:for-each select="authors/author[position() = last()]">
                                                <xsl:variable name="apaAuthor">
                                                    <xsl:call-template name="apa-author">
                                                        <xsl:with-param name="full" select="."/>
                                                    </xsl:call-template>
                                                </xsl:variable>
                                                <xsl:value-of select="normalize-space($apaAuthor)"/>
                                            </xsl:for-each>
                                        </xsl:when>
                                        <!-- Case: up to 20 authors → include all; use lang-specific conjunction before last -->
                                        <xsl:otherwise>
                                            <xsl:for-each select="authors/author">
                                                <xsl:variable name="apaAuthor">
                                                    <xsl:call-template name="apa-author">
                                                        <xsl:with-param name="full" select="."/>
                                                    </xsl:call-template>
                                                </xsl:variable>
                                                <xsl:value-of select="normalize-space($apaAuthor)"/>
                                                <xsl:choose>
                                                    <xsl:when test="position() = last()"/>
                                                    <xsl:when test="position() = last() - 1">
                                                        <xsl:text>, </xsl:text>
                                                        <xsl:choose>
                                                            <xsl:when test="$lang = 'en'">
                                                                <xsl:text>&amp; </xsl:text>
                                                            </xsl:when>
                                                            <xsl:otherwise>
                                                                <xsl:text>y </xsl:text>
                                                            </xsl:otherwise>
                                                        </xsl:choose>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:text>, </xsl:text>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>

                                    <xsl:text> </xsl:text>

                                    <!-- (Year). -->
                                    <xsl:if test="date-issued">
                                        <xsl:text>(</xsl:text>
                                        <xsl:value-of select="substring(normalize-space(date-issued), 1, 4)"/>
                                        <xsl:text>). </xsl:text>
                                    </xsl:if>

                                    <!-- Article title (sentence case left as-is) -->
                                    <xsl:value-of select="title"/>
                                    <xsl:text>. </xsl:text>

                                    <!-- Journal Title, Volume(Issue), pages. -->
                                    <xsl:if test="journal">
                                        <fo:inline font-style="italic">
                                            <xsl:value-of select="journal"/>
                                        </fo:inline>
                                        <!-- Solo agrega coma si hay más información después (volumen, número o páginas) -->
                                        <xsl:if test="volume or issue or pages">
                                            <xsl:text>, </xsl:text>
                                        </xsl:if>
                                    </xsl:if>

                                    <xsl:if test="volume">
                                        <fo:inline font-style="italic">
                                            <xsl:value-of select="volume"/>
                                        </fo:inline>
                                    </xsl:if>

                                    <xsl:if test="issue">
                                        <xsl:text>(</xsl:text>
                                        <xsl:value-of select="issue"/>
                                        <xsl:text>)</xsl:text>
                                    </xsl:if>

                                    <xsl:if test="volume or issue">
                                        <xsl:text>, </xsl:text>
                                    </xsl:if>

                                    <xsl:if test="pages">
                                        <xsl:value-of select="pages"/>
                                        <xsl:text>. </xsl:text>
                                    </xsl:if>

                                    <xsl:if test="(journal or volume or issue) and not(pages)">
                                        <xsl:text>. </xsl:text>
                                    </xsl:if>

                                    <!-- DOI hyperlink as URL -->
                                    <xsl:if test="doi">
                                        <fo:basic-link>
                                            <xsl:attribute name="external-destination">
                                                <xsl:choose>
                                                    <xsl:when test="starts-with(normalize-space(doi),'10.')">
                                                        <xsl:text>url(https://doi.org/</xsl:text><xsl:value-of select="normalize-space(doi)"/><xsl:text>)</xsl:text>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:text>url(</xsl:text><xsl:value-of select="normalize-space(doi)"/><xsl:text>)</xsl:text>
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:attribute>
                                            <xsl:choose>
                                                <xsl:when test="starts-with(normalize-space(doi),'10.')">
                                                    <xsl:text>https://doi.org/</xsl:text><xsl:value-of select="normalize-space(doi)"/>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:value-of select="normalize-space(doi)"/>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </fo:basic-link>
                                    </xsl:if>

                                </fo:block>
                            </xsl:for-each>

                        </xsl:if>

                        <xsl:if test="( count(working-groups/working-group) &gt; 0 ) or ( count(interests/interest) &gt; 0 ) or ( count(knows-languages/language) &gt; 0 )">

                            <xsl:call-template name="section-title">
                                <xsl:with-param name="label" select="'Other informations'" />
                            </xsl:call-template>
                            <xsl:call-template name="print-values">
                                <xsl:with-param name="label" select="'Working groups'" />
                                <xsl:with-param name="values" select="working-groups/working-group" />
                            </xsl:call-template>
                            <xsl:call-template name="print-values">
                                <xsl:with-param name="label" select="'Interests'" />
                                <xsl:with-param name="values" select="interests/interest" />
                            </xsl:call-template>
                            <xsl:call-template name="print-values">
                                <xsl:with-param name="label" select="'Knows languages'" />
                                <xsl:with-param name="values" select="knows-languages/language" />
                            </xsl:call-template>

                        </xsl:if>

                        <xsl:if test="personal-sites/personal-site">

                            <fo:block font-size="10pt" margin-top="2mm">
                                <fo:inline font-weight="bold" text-align="right" >
                                    Personal sites:
                                </fo:inline>
                                <fo:inline>
                                    <xsl:for-each select="personal-sites/personal-site">
                                        <xsl:value-of select="site-url" />
                                        <xsl:text> </xsl:text>
                                        <xsl:if test="site-title">
                                            ( <xsl:value-of select="site-title" /> )
                                        </xsl:if>
                                        <xsl:if test="position() != last()">, </xsl:if>
                                    </xsl:for-each>
                                </fo:inline >
                            </fo:block>

                        </xsl:if>
                    </fo:flow>
                </fo:page-sequence>
            </xsl:if>
        </fo:root>
    </xsl:template>

    <xsl:template name = "print-value" >
        <xsl:param name = "label" />
        <xsl:param name = "value" />
        <xsl:if test="$value">
            <fo:block font-size="10pt" margin-top="2mm">
                <fo:inline font-weight="bold" text-align="right" >
                    <xsl:value-of select="$label" />
                </fo:inline >
                <xsl:text>: </xsl:text>
                <fo:inline>
                    <xsl:value-of select="$value" />
                </fo:inline >
            </fo:block>
        </xsl:if>
    </xsl:template>

    <xsl:template name = "section-title" >
        <xsl:param name = "label" />
        <fo:block font-size="16pt" font-weight="bold" margin-top="8mm" >
            <xsl:value-of select="$label" />
        </fo:block>
        <fo:block>
            <fo:leader leader-pattern="rule" leader-length="100%" rule-style="solid" />
        </fo:block>
    </xsl:template>

    <xsl:template name = "print-values" >
        <xsl:param name = "label" />
        <xsl:param name = "values" />
        <xsl:if test="$values">
            <fo:block font-size="10pt" margin-top="2mm">
                <fo:inline font-weight="bold" text-align="right"  >
                    <xsl:value-of select="$label" />
                </fo:inline >
                <xsl:text>: </xsl:text>
                <fo:inline>
                    <xsl:for-each select="$values">
                        <xsl:value-of select="current()" />
                        <xsl:if test="position() != last()">, </xsl:if>
                    </xsl:for-each>
                </fo:inline >
            </fo:block>
        </xsl:if>
    </xsl:template>

    <!-- Helpers to format author names in APA 7 -->
    <xsl:template name="apa-author">
        <xsl:param name="full"/>
        <xsl:variable name="s" select="normalize-space($full)"/>
        <xsl:choose>
            <!-- Case 1: Input like "Surname, Given Names" -->
            <xsl:when test="contains($s, ',')">
                <xsl:variable name="surnameRaw" select="normalize-space(substring-before($s, ','))"/>
                <xsl:variable name="given" select="normalize-space(substring-after($s, ','))"/>
                <!-- Preserve surname exactly as provided (accents/case/hyphens) -->
                <xsl:value-of select="$surnameRaw"/>
                <xsl:variable name="inis">
                    <xsl:call-template name="initials-from">
                        <xsl:with-param name="s" select="$given"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:if test="string-length(normalize-space($inis)) &gt; 0">
                    <xsl:text>, </xsl:text>
                    <xsl:value-of select="normalize-space($inis)"/>
                </xsl:if>
            </xsl:when>
            <!-- Case 2: Input like "given names surname" -->
            <xsl:otherwise>
                <!-- Surname = last token (title-case each hyphen part) -->
                <xsl:variable name="surnameRaw">
                    <xsl:call-template name="last-word">
                        <xsl:with-param name="s" select="$s"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="surname">
                    <xsl:call-template name="cap-first-hyphenated">
                        <xsl:with-param name="w" select="normalize-space($surnameRaw)"/>
                    </xsl:call-template>
                </xsl:variable>
                <!-- Initials from all tokens except the last (handles hyphens) -->
                <xsl:variable name="inis">
                    <xsl:call-template name="initials-except-last">
                        <xsl:with-param name="s" select="$s"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:value-of select="normalize-space($surname)"/>
                <xsl:if test="string-length(normalize-space($inis)) &gt; 0">
                    <xsl:text>, </xsl:text>
                    <xsl:value-of select="normalize-space($inis)"/>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="last-word">
        <xsl:param name="s"/>
        <xsl:choose>
            <xsl:when test="contains($s,' ')">
                <xsl:call-template name="last-word">
                    <xsl:with-param name="s" select="substring-after($s,' ')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$s"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Produce initials for all space-separated tokens in $s -->
    <xsl:template name="initials-from">
        <xsl:param name="s"/>
        <xsl:variable name="t" select="normalize-space($s)"/>
        <xsl:choose>
            <xsl:when test="contains($t,' ')">
                <xsl:variable name="first" select="substring-before($t,' ')"/>
                <xsl:variable name="rest" select="substring-after($t,' ')"/>
                <xsl:call-template name="emit-initial">
                    <xsl:with-param name="w" select="$first"/>
                </xsl:call-template>
                <xsl:if test="string-length(normalize-space($rest)) &gt; 0">
                    <xsl:text> </xsl:text>
                    <xsl:call-template name="initials-from">
                        <xsl:with-param name="s" select="$rest"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:when test="string-length($t) &gt; 0">
                <xsl:call-template name="emit-initial">
                    <xsl:with-param name="w" select="$t"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>

    <!-- Initials from all tokens except the last (for "given names surname" inputs) -->
    <xsl:template name="initials-except-last">
        <xsl:param name="s"/>
        <xsl:choose>
            <xsl:when test="contains($s,' ')">
                <xsl:variable name="first" select="substring-before($s,' ')"/>
                <xsl:variable name="rest" select="substring-after($s,' ')"/>
                <xsl:call-template name="emit-initial">
                    <xsl:with-param name="w" select="$first"/>
                </xsl:call-template>
                <xsl:if test="contains($rest,' ')">
                    <xsl:text> </xsl:text>
                    <xsl:call-template name="initials-except-last">
                        <xsl:with-param name="s" select="$rest"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>

    <!-- Emit initial(s) for a token; if hyphenated, emit for each sub-token joined by '-' (e.g., "J.-P.") -->
    <xsl:template name="emit-initial">
        <xsl:param name="w"/>
        <xsl:variable name="word" select="normalize-space($w)"/>
        <xsl:choose>
            <xsl:when test="contains($word,'-')">
                <xsl:variable name="first" select="substring-before($word,'-')"/>
                <xsl:variable name="rest" select="substring-after($word,'-')"/>
                <xsl:call-template name="emit-initial">
                    <xsl:with-param name="w" select="$first"/>
                </xsl:call-template>
                <xsl:text>-</xsl:text>
                <xsl:call-template name="emit-initial">
                    <xsl:with-param name="w" select="$rest"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="c1" select="substring($word,1,1)"/>
                <xsl:value-of select="translate($c1,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
                <xsl:text>.</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Capitalize first letter of each hyphen-separated part of a word -->
    <xsl:template name="cap-first-hyphenated">
        <xsl:param name="w"/>
        <xsl:variable name="word" select="normalize-space($w)"/>
        <xsl:choose>
            <xsl:when test="contains($word,'-')">
                <xsl:variable name="first" select="substring-before($word,'-')"/>
                <xsl:variable name="rest" select="substring-after($word,'-')"/>
                <xsl:call-template name="cap-first">
                    <xsl:with-param name="w" select="$first"/>
                </xsl:call-template>
                <xsl:text>-</xsl:text>
                <xsl:call-template name="cap-first-hyphenated">
                    <xsl:with-param name="w" select="$rest"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="cap-first">
                    <xsl:with-param name="w" select="$word"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="cap-first">
        <xsl:param name="w"/>
        <xsl:variable name="c1" select="substring($w,1,1)"/>
        <xsl:variable name="rest" select="substring($w,2)"/>
        <xsl:value-of select="concat(translate($c1,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'), $rest)"/>
    </xsl:template>

</xsl:stylesheet>
