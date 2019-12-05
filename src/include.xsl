<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xi="http://www.w3.org/2001/XInclude"
                xmlns:oxi="https://yo/me/lo/guiso/yo/me/lo/como/xi"
                xmlns:oxsl="https://yo/me/lo/guiso/yo/me/lo/como/xsl">

   <!-- Genera otro XSL idéntico pero con el xi:include adecuado 
        para que se incrute el CSS y el JS dentro del HTML. -->

   <xsl:output method="xml"
               indent="yes"
               encoding="UTF-8" />

   <xsl:namespace-alias stylesheet-prefix="oxsl" result-prefix="xsl"/>
   <xsl:namespace-alias stylesheet-prefix="oxi" result-prefix="xi"/>

   <xsl:param name="base"/>
   <xsl:param name="extracss"/>
   <xsl:param name="extrajs"/>

   <xsl:template match="*">
      <xsl:copy>
         <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="@*|text()|comment()|processing-instruction()">
      <xsl:copy-of select="." />
   </xsl:template>

   <xsl:template match="xsl:variable[@name='content'][../../../@name = 'css']">
      <xsl:call-template name="include">
         <xsl:with-param name="basefile" select="/xsl:stylesheet/xsl:param[@name = 'css']/@select"/>
         <xsl:with-param name="extra" select="$extracss"/>
      </xsl:call-template>
   </xsl:template>

   <xsl:template match="xsl:variable[@name='content'][../../../@name = 'js']">
      <xsl:call-template name="include">
         <xsl:with-param name="basefile" select="/xsl:stylesheet/xsl:param[@name = 'js']/@select"/>
         <xsl:with-param name="extra" select="$extrajs"/>
      </xsl:call-template>
   </xsl:template>

   <xsl:template name="include">
      <xsl:param name="basefile"/>
      <xsl:param name="extra"/>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <oxi:include href="{concat('file://', $base, '/', $basefile)}" parse="text" encoding="utf-8">
            <oxi:fallback>
               <oxsl:message terminate="yes">El CSS/Javascript no puede incluirse dentro del fichero</oxsl:message>
            </oxi:fallback>
         </oxi:include>
         <xsl:if test="$extra">
            <oxi:include href="{concat('file://', $extra)}" parse="text" encoding="utf-8">
               <oxi:fallback>
                  <oxsl:message terminate="yes">El CSS/Javascript no puede incluirse dentro del fichero</oxsl:message>
               </oxi:fallback>
            </oxi:include>
         </xsl:if>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
