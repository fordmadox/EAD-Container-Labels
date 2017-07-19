<?xml version="1.0"?>
<!-- 
Beinecke XSLT: EAD to Tab Delimited Text file for Folder Labels Mail Merge

Created: 2017-07-01 (significantly revised; also updated to XSLT 3.0, just because i wanted to use format-integer)

Contact: mark.custer@yale.edu

Need to do:  

test a lot!

-->
<xsl:stylesheet version="3.0" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"  
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:ead="urn:isbn:1-931666-22-9" xmlns:xlink="http://www.w3.org/1999/xlink" 
    xmlns:mdc="http://mdc" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    exclude-result-prefixes="#all">
    
    <xsl:output method="text" encoding="UTF-8" indent="yes"/>
    
    <xsl:include href="sort-container-function.xsl"/>
    
    <!-- put into a separate file later on -->
    <xsl:function name="mdc:iso-date-2-display-form" as="xs:string*">
        <xsl:param name="date" as="xs:string"/>
        <xsl:variable name="months"
            select="
            ('January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December')"/>
        <xsl:analyze-string select="$date" flags="x" regex="(\d{{4}})(\d{{2}})?(\d{{2}})?">
            <xsl:matching-substring>
                <!-- year -->
                <xsl:value-of select="regex-group(1)"/>
                <!-- month (can't add an if,then,else '' statement here without getting an extra space at the end of the result-->
                <xsl:if test="regex-group(2)">
                    <xsl:value-of select="subsequence($months, number(regex-group(2)), 1)"/>
                </xsl:if>
                <!-- day -->
                <xsl:if test="regex-group(3)">
                    <xsl:number value="regex-group(3)" format="1"/>
                </xsl:if>
                <!-- still need to handle time... but if that's there, then I can just use xs:dateTime !!!! -->
            </xsl:matching-substring>
        </xsl:analyze-string>
    </xsl:function>
    
    <xsl:template match="@*|node()" mode="copy">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:param name="collection">
        <xsl:value-of select="normalize-space(ead:ead/ead:archdesc/ead:did/ead:unittitle[1])"/>
    </xsl:param>
    <xsl:param name="callnum">
        <xsl:value-of select="normalize-space(ead:ead/ead:archdesc/ead:did/ead:unitid[1])"/>
    </xsl:param>
    
    <xsl:variable name="resorted-container-groups">
        <xsl:element name="flattened-list">
            <xsl:for-each select="//ead:container[@id][not(@parent)][following-sibling::ead:container[lower-case(@type)='folder']]">
                <xsl:sort
                    select="mdc:container-to-number(.)"
                    data-type="number" order="ascending"/>
                <xsl:variable name="current-id" select="@id"/>
                <xsl:variable name="immediate-ancestor" select="ancestor::ead:*[ead:did/ead:unittitle][ancestor::ead:dsc][1]"/>
                <xsl:variable name="folder-title-plus-unitid">
                    <xsl:choose>
                        <!-- if there's just a unitid, use that in place of the title and don't inherit anything.
                            the "inherited" title will still appear as an ancestor title on the label due to the sequence-of-series -->
                        <xsl:when test="not(../ead:unittitle[normalize-space()]) and ../ead:unitid[normalize-space()]">
                            <xsl:value-of select="ead:unitid[1]"/>
                        </xsl:when>
                        <!-- if there's no unitid or title, then grab an ancestor title and unitid, since 
                            the component might only have a unitdate.  later, we'll filter this out of the sequence-of-series list of titles. -->
                        <xsl:when test="not(../ead:unittitle[normalize-space()])">
                            <xsl:if test="$immediate-ancestor[ead:did/ead:unitid]">
                                <xsl:value-of select="concat($immediate-ancestor/ead:did/ead:unitid[1], ' ')"/>
                            </xsl:if>
                            <xsl:value-of select="$immediate-ancestor/ead:did/ead:unittitle[1]"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:if test="normalize-space(../ead:unitid[1])">
                                <xsl:value-of select="normalize-space(../ead:unitid[1])"/>
                                <xsl:text> </xsl:text>
                            </xsl:if>
                            <xsl:value-of select="normalize-space(../ead:unittitle[1])"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="ancestor-sequence">
                    <xsl:sequence select="string-join(
                        for $ancestor in ../../ancestor::*[ead:did][ancestor::ead:dsc] return 
                        if (matches($ancestor/ead:did/ead:unitid, '^\d$')
                            and $ancestor/lower-case(@level) eq 'series') 
                            then concat('Series ', $ancestor/ead:did/ead:unitid/format-integer(., 'I'), '. ', $ancestor/ead:did/ead:unittitle)
                        else if (ends-with($ancestor/ead:did/ead:unitid/normalize-space(), '.'))
                            then concat($ancestor/ead:did/ead:unitid/normalize-space(), ' ', $ancestor/ead:did/ead:unittitle)
                        else if ($ancestor/ead:did/ead:unitid/normalize-space()) then concat($ancestor/ead:did/ead:unitid, ' ', $ancestor/ead:did/ead:unittitle)
                        else $ancestor/ead:did/ead:unittitle
                        , 'xx*****yz')"/>
                </xsl:variable>
                <xsl:variable name="ancestor-sequence-filtered">
                    <xsl:sequence select="string-join(remove($ancestor-sequence
                        , if (exists(index-of($ancestor-sequence, $folder-title-plus-unitid))) 
                        then index-of($ancestor-sequence, $folder-title-plus-unitid)
                        else 0)
                        , 'xx*****yz')"/>
                </xsl:variable>
                <xsl:element name="container-grouping">
                    <!-- copies the origination, unitdate, current container, and following related containers-->
                    <xsl:apply-templates select="../ead:origination
                        , ../ead:unitdate
                        , .
                        , ../ead:container[@parent = $current-id]"
                        mode="copy"/>
                    <xsl:element name="ancestor-sequence">
                        <xsl:sequence select="$ancestor-sequence-filtered"/>
                    </xsl:element>
                    <xsl:element name="constructed-title">
                        <xsl:value-of select="$folder-title-plus-unitid"/>
                    </xsl:element>
                </xsl:element>
            </xsl:for-each>
        </xsl:element>
    </xsl:variable>
    
    <!-- Matches the root of the document, outputs the first tab delimited line, then applies templates to each EAD component with a folder value. -->
    <xsl:template match="/">
        <xsl:text>COLLECTION&#x9;CALL NO.&#x9;BOX&#x9;FOLDER&#x9;C01 ANCESTOR&#x9;C02 ANCESTOR&#x9;C03 ANCESTOR&#x9;C04 ANCESTOR&#x9;C05 ANCESTOR&#x9;FOLDER ORIGINATION&#x9;FOLDER TITLE&#x9;FOLDER DATES&#xA;</xsl:text>
        
        <xsl:for-each select="$resorted-container-groups/flattened-list/container-grouping">
            <xsl:variable name="folderString" select="normalize-space(ead:container[lower-case(@type)='folder'][1])"/>
            <xsl:variable name="folderStringNormal" select="translate($folderString,'–—','-')"/>
            <xsl:choose>
                <xsl:when test="contains($folderStringNormal,'-')">
                    <xsl:choose>
                        <xsl:when test="matches(replace($folderStringNormal, '-', ''), '\D')">
                            <xsl:message>Component with @id="<xsl:value-of select="@id"/>" includes a folder span with an alphabetic value: "<xsl:value-of select="$folderStringNormal"/>".  Span not broken up into discrete lines for each folder</xsl:message>
                            <xsl:call-template name="folderRowOutput">
                                <xsl:with-param name="folderSpanSumToOutput">
                                    <xsl:value-of select="1"/>
                                </xsl:with-param>
                            </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:variable name="folderSpanFirstValue" select="xs:integer(substring-before($folderStringNormal,'-'))"/>
                            <xsl:variable name="folderSpanSecondValue" select="xs:integer(substring-after($folderStringNormal,'-'))"/>
                            <xsl:variable name="folderSpanSum" select="$folderSpanSecondValue - $folderSpanFirstValue + 1"/>
                            <xsl:choose>
                                <xsl:when test="$folderSpanSecondValue lt $folderSpanFirstValue">
                                    <xsl:message>Component with @id="<xsl:value-of select="@id"/>" includes a folder span where the second folder value is smaller than the first folder value: "<xsl:value-of select="$folderStringNormal"/>".  Span not broken up into discrete lines for each folder</xsl:message>
                                    <xsl:call-template name="folderRowOutput">
                                        <xsl:with-param name="folderSpanSumToOutput">
                                            <xsl:value-of select="1"/>
                                        </xsl:with-param>
                                    </xsl:call-template>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:call-template name="folderRowOutput">
                                        <xsl:with-param name="folderSpanSumToOutput">
                                            <xsl:value-of select="$folderSpanSum"/>
                                        </xsl:with-param>
                                        <xsl:with-param name="folderSpanFirstFolder">
                                            <xsl:value-of select="$folderSpanFirstValue"/>
                                        </xsl:with-param>
                                        <xsl:with-param name="folderSpanInstance">
                                            <xsl:value-of select="1"/>
                                        </xsl:with-param>
                                        <xsl:with-param name="folderSpanInstanceTotal">
                                            <xsl:value-of select="$folderSpanSum"/>
                                        </xsl:with-param>
                                    </xsl:call-template>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                     <xsl:call-template name="folderRowOutput">
                        <xsl:with-param name="folderSpanSumToOutput">
                             <xsl:value-of select="1"/>
                        </xsl:with-param>
                   </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <!-- Template for each EAD component with a folder value. Then calls template for each DL column, followed by tabs and a line break on the end. -->
    <xsl:template name="folderRowOutput">
        <xsl:param name="folderSpanSumToOutput"/>
        <xsl:param name="folderSpanFirstFolder"/>
        <xsl:param name="folderSpanInstance"/>
        <xsl:param name="folderSpanInstanceTotal"/>
                
        <xsl:variable name="series-of-series" select="if (contains(ancestor-sequence, 'xx*****yz')) then tokenize(ancestor-sequence, 'xx\*\*\*\*\*yz') else ancestor-sequence"/>
        <xsl:value-of select="$collection"/><xsl:text>&#x9;</xsl:text>
        <xsl:value-of select="$callnum"/><xsl:text>&#x9;</xsl:text>
        <xsl:call-template name="box"/><xsl:text>&#x9;</xsl:text>
        <xsl:call-template name="folder">
            <xsl:with-param name="folderSpanFirstFolder">
                <xsl:value-of select="$folderSpanFirstFolder"/>
            </xsl:with-param>
        </xsl:call-template>
        <xsl:text>&#x9;</xsl:text>
        
        <xsl:sequence select="$series-of-series[1]"/><xsl:text>&#x9;</xsl:text>
        <xsl:sequence select="$series-of-series[2]"/><xsl:text>&#x9;</xsl:text>
        <xsl:sequence select="$series-of-series[3]"/><xsl:text>&#x9;</xsl:text>
        <xsl:sequence select="$series-of-series[4]"/><xsl:text>&#x9;</xsl:text>
        <xsl:sequence select="$series-of-series[5]"/><xsl:text>&#x9;</xsl:text>
       
        <xsl:call-template name="folderOrigination"/><xsl:text>&#x9;</xsl:text>
        
        <xsl:call-template name="folderTitle">
            <xsl:with-param name="folderSpanInstance">
                <xsl:value-of select="$folderSpanInstance"/>
            </xsl:with-param>
            <xsl:with-param name="folderSpanInstanceTotal">
                <xsl:value-of select="$folderSpanInstanceTotal"/>
            </xsl:with-param>
        </xsl:call-template><xsl:text>&#x9;</xsl:text>
        
        <xsl:call-template name="folderDates"/>
        
        <!--make sure to only add a new line if there's another folder row to add.
        this is a bit more complicated than just checking for the last position, because the last group could be a folder span.
        e.g. folder 1000-1004, so we need to make sure that the folderSpanInstance is still less than the folderSpanInstanceTotal in that case.
        -->
        <xsl:if test="position() lt last()
            or (last() and $folderSpanInstance lt $folderSpanInstanceTotal)">
            <xsl:text>&#xA;</xsl:text>
        </xsl:if>
        
        <xsl:if test="$folderSpanSumToOutput != 1">
            <xsl:call-template name="folderRowOutput">
                <xsl:with-param name="folderSpanSumToOutput">
                    <xsl:value-of select="$folderSpanSumToOutput - 1"/>
                </xsl:with-param>
                <xsl:with-param name="folderSpanFirstFolder">
                    <xsl:value-of select="$folderSpanFirstFolder + 1"/>
                </xsl:with-param>
                <xsl:with-param name="folderSpanInstance">
                    <xsl:value-of select="$folderSpanInstance + 1"/>
                </xsl:with-param>
                <xsl:with-param name="folderSpanInstanceTotal">
                    <xsl:value-of select="$folderSpanInstanceTotal"/>
                </xsl:with-param>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>
    
    
    <!-- Template for the box number -->
    <xsl:template name="box">
        <xsl:if test="ead:container[lower-case(@type)='box'][normalize-space()]">
            <xsl:text>box </xsl:text><xsl:value-of select="normalize-space(ead:container[lower-case(@type)='box'])"/>
        </xsl:if>
    </xsl:template>
    
    <!-- Template for folder numbers -->
    <xsl:template name="folder">
        <xsl:param name="folderSpanFirstFolder"/>
        <xsl:if test="normalize-space(ead:container[lower-case(@type)='folder'])">
            <xsl:text>folder </xsl:text>
            <xsl:choose>
                <xsl:when test="normalize-space($folderSpanFirstFolder)">
                    <xsl:value-of select="$folderSpanFirstFolder"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="normalize-space(ead:container[lower-case(@type)='folder'])"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>
    
    <!-- Template for folder originations -->
    <xsl:template name="folderOrigination">
        <xsl:value-of select="normalize-space(ead:origination[1])"/>
    </xsl:template>
    
    <!-- Template for folder unittitles -->
    <xsl:template name="folderTitle">
        <xsl:param name="folderSpanInstance"/>
        <xsl:param name="folderSpanInstanceTotal"/>
        <xsl:value-of select="constructed-title"/>
        <xsl:if test="normalize-space($folderSpanInstance)">
            <xsl:text> [</xsl:text>
            <xsl:value-of select="$folderSpanInstance"/>
            <xsl:text> of </xsl:text>
            <xsl:value-of select="$folderSpanInstanceTotal"/>
            <xsl:text> folders]</xsl:text>
        </xsl:if>
    </xsl:template>
    
    <!-- Template for folder unitdates -->
    <xsl:template name="folderDates">
        <xsl:for-each select="ead:unitdate[not(parent::ead:unittitle)]">
            <xsl:choose>
                <xsl:when test="not(@normal) or matches(replace(., '/|-', ''), '[\D]')">
                    <xsl:apply-templates/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="first-date" select="if (contains(@normal, '/')) then replace(substring-before(@normal, '/'), '\D', '') else replace(@normal, '\D', '')"/>
                    <xsl:variable name="second-date" select="replace(substring-after(@normal, '/'), '\D', '')"/>
                    <!-- just adding the next line until i write a date conversion function-->
                    <xsl:value-of select="mdc:iso-date-2-display-form($first-date)"/>
                    <xsl:if test="$second-date ne '' and ($first-date ne $second-date)">
                        <xsl:text>&#8211;</xsl:text>
                        <xsl:value-of select="mdc:iso-date-2-display-form($second-date)"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="following-sibling::ead:unitdate">
                <xsl:text>, </xsl:text>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>
