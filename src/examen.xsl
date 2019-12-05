<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:exsl="http://exslt.org/common"
                xmlns:func="http://exslt.org/functions"
                xmlns:date="http://exslt.org/dates-and-times"
                xmlns:str="http://exslt.org/strings"
                xmlns:math="http://exslt.org/math"
                extension-element-prefixes="exsl func date str math">

   <xsl:output method="html"
               indent="yes"
               omit-xml-declaration="yes"
               encoding="UTF-8" />

   <xsl:decimal-format name="puntuacion" decimal-separator="," />

   <!-- Devuelve el primer argumento si tiene valor o no es NaN
        o, en caso, contrario, el valor proporcionado en el segundo argumento -->
   <func:function name="xsl:default">
      <xsl:param name="variable"/>
      <xsl:param name="defvalue"/>

      <xsl:choose>
         <xsl:when test="string($variable) = ''">
            <func:result select="$defvalue" />
         </xsl:when>
         <xsl:when test="string(number($variable)) = 'NaN'">
            <func:result select="$defvalue" />
         </xsl:when>
         <xsl:otherwise>
            <func:result select="$variable" />
         </xsl:otherwise>
      </xsl:choose>
   </func:function>

   <!-- Orden: si hay caos, aletatorio. En caso,
        contrario, se toma el orden del XML -->
   <func:function name="xsl:order">
      <xsl:param name="azar" select="false()"/>

      <xsl:choose>
         <xsl:when test="$azar">
            <func:result select="math:random()" />
         </xsl:when>
         <xsl:otherwise>
            <func:result select="position()" />
         </xsl:otherwise>
      </xsl:choose>
   </func:function>

   <!-- Yuxtapone un conjunto de nodos, mediante un separador 
        (str:concat no vale, porque yuxtapone sin separador)
    -->
   <func:function name="str:concat-sep">
      <xsl:param name="nodes"/>
      <xsl:param name="separador" select="' '"/>
      <xsl:param name="pos" select="0"/>
      <xsl:param name="res" select="''"/>

      <func:result>
         <xsl:choose>
            <xsl:when test="$pos = count($nodes)">
               <xsl:value-of select="$res"/>
            </xsl:when>
            <xsl:when test="$pos = 0">
               <xsl:value-of select="str:concat-sep($nodes, $separador, 1, $nodes[1])"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="str:concat-sep($nodes, $separador, $pos+1, concat($res, $separador, $nodes[$pos+1]))"/>
            </xsl:otherwise>
         </xsl:choose>
      </func:result>
   </func:function>

   <!-- ++++++++++++++++++++++++++++
        ++  Parámetros de entrada ++
        ++++++++++++++++++++++++++++ -->

   <!-- Hoja de estilos y Javascript -->
   <xsl:param name="css" select="src/examen.css"/>
   <xsl:param name="extracss"/>
   <xsl:param name="js" select="src/examen.js"/>
   <xsl:param name="extrajs"/>

   <!-- Directorio base donde se encuentra el directorio src -->
   <xsl:param name="base"/>

   <!-- Número de preguntas de que consta el examen -->
   <xsl:param name="preguntas"/>

   <!-- Puntuación total del examen (sobre 10 puntos por defecto)
        La suma de las puntuaciones de todas las preguntas suma la total -->
   <xsl:param name="puntuacion" select="10"/>

   <!-- ¿Se desordenan las preguntas? -->
   <xsl:param name="desordenar" select="true()"/>
   <!-- ¿Se desordenan las respuestas en las tipo test? -->
   <xsl:param name="desordenarr" select="false()"/>
   <!-- Si hay "caos", se entremezclan las preguntas de cada parte -->
   <xsl:param name="caos" select="false()" />

   <!-- Muestra información adicional para depuración -->
   <xsl:param name="debug" select="false()" />

   <!-- Mantiene como fichero externo la hoja de estilos -->
   <xsl:param name="externa" select="true()" />

   <!-- Si se piensa pasar el mensaje en papel, en cuyo
        caso se marca la respuesta correcta en el propio HTML -->
   <xsl:param name="papel" select="false()" />

   <!-- Presentes en el documento, pero permiten reutilizar el examen -->
   <xsl:param name="grupo" select="/examen/datos/prueba/grupo" />
   <xsl:param name="fecha">
      <xsl:choose>
         <xsl:when test="/examen/datos/prueba/fecha/@dia">
            <xsl:number value="/examen/datos/prueba/fecha/@dia" format="01"/>
            <xsl:text>/</xsl:text>
            <xsl:number value="/examen/datos/prueba/fecha/@mes" format="01"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="/examen/datos/prueba/fecha/@anno"/>
            </xsl:when>
         <!-- Si no se especifica fecha, se utiliza la de hoy -->
         <xsl:otherwise>
            <xsl:value-of select="date:day-in-month()"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="date:month-in-year()"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="date:year()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:param>
   <xsl:param name="convocatoria" select="/examen/datos/prueba/evaluacion/@cual" />
   <xsl:param name="secuencia" select="/examen/datos/prueba/evaluacion/@numero" />
   <!-- Ejemplar generado anteriormente -->
   <xsl:param name="ejemplar"/>


   <!-- +++++++++++++++++++++++++++++++++++++++++++++++++++++
        ++ Genera una prueba a partir del examen original. ++
        +++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
   <xsl:template name="plantilla">
      <!-- Calcula el número de preguntas de cada parte
           
           La variable almacena un conjunto de nodos de la forma:

            <numpre>3</numpre>
            <numpre>2</numpre>
            <numpre>4</numpre>

          Donde cada nodo represente el número de preguntas que se extraen
          de la parte correspondiente. El primer nodo corresponde con la primera parte;
          el segundo, con la segunda; y así sucesivamente.
      -->
      <xsl:variable name="cantidad">
         <xsl:if test="number($preguntas) != $preguntas">
            <xsl:message terminate="yes">ERROR: No ha definido cuál es el número de preguntas o no lo ha hecho con un número</xsl:message>
         </xsl:if>

         <xsl:choose>
            <!-- El examen no tiene partes -->
            <xsl:when test="not(//parte)">
               <numpre peso="1" paso="1"><xsl:value-of select="$preguntas"/></numpre>
            </xsl:when>
            <!-- Si tiene partes, hay que obtener preguntas de cada parte, según el peso
                 y la puntuación de las preguntas (paso) -->
            <xsl:otherwise>
               <xsl:call-template name="def_cantidad">
                  <xsl:with-param name="restantes" select="$preguntas"/>
                  <xsl:with-param name="resultado">
                     <xsl:for-each select="//parte">
                        <numpre peso="{xsl:default(@peso, 1)}" paso="{xsl:default(@suma, 1)}" divisor="1">0</numpre>
                     </xsl:for-each>
                  </xsl:with-param>
               </xsl:call-template>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- ++ Fin del cálculo ++ -->

      <!-- ++++++++++++++++++++++++++++
           ++ Selección de preguntas ++
           ++++++++++++++++++++++++++++ -->

      <xsl:variable name="seleccion">
         <xsl:choose>
            <xsl:when test="//parte">
               <xsl:for-each select="/examen/texto/parte">
                  <xsl:variable name="parte" select="position()"/>
                  <xsl:variable name="numpre" select="exsl:node-set($cantidad)/numpre[$parte]" />
                  
                  <xsl:apply-templates select="cuestion" mode="seleccion">
                     <xsl:sort select="xsl:order($desordenar)" data-type="number"/>
                     <xsl:with-param name="cantidad" select="$numpre"/>
                  </xsl:apply-templates>
               </xsl:for-each>
            </xsl:when>

            <xsl:otherwise>
               <xsl:apply-templates select="cuestion" mode="seleccion">
                  <xsl:sort select="xsl:order($desordenar)" data-type="number"/>
                  <xsl:with-param name="cantidad" select="$preguntas"/>
               </xsl:apply-templates>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- ++ Fin de la selección ++ -->

      <ejemplar examen="{/examen/@id}" id="{generate-id(exsl:node-set($seleccion))}">
         <!-- Corrige las puntuaciones de cada pregunta
              para que sumen la puntuación prescrita por $puntuación -->
         <xsl:attribute name="factor">
            <xsl:variable name="total">
               <xsl:variable name="numpres" select="exsl:node-set($cantidad)/numpre"/>
               <xsl:call-template name="sumaproducto">
                  <xsl:with-param name="nod1" select="$numpres/text()"/>
                  <xsl:with-param name="nod2" select="$numpres/@paso"/>
               </xsl:call-template>
            </xsl:variable>
            <xsl:value-of select="$puntuacion div $total"/>
         </xsl:attribute>

         <xsl:for-each select="exsl:node-set($seleccion)/cuestion">
           <xsl:sort select="xsl:order($caos)" data-type="number"/>
           <xsl:copy-of select="."/>
         </xsl:for-each>
      </ejemplar>
   </xsl:template>

   <!-- ++ Fin de parámetros ++ -->

   <xsl:template match="cuestion" mode="seleccion">
      <xsl:param name="cantidad"/>

      <!-- Sólo se incluye el número de preguntas que indique $cantidad -->
      <xsl:if test="position() &lt;= $cantidad">
         <!-- En el examen sin partes, parte=0 -->
         <xsl:variable name="parte"><xsl:number count="//parte"/></xsl:variable>
         <xsl:variable name="num"><xsl:number/></xsl:variable>
         <xsl:if test="$debug">
            <xsl:message><xsl:value-of select="concat($parte, '_', $num)"/></xsl:message>
         </xsl:if>
         <cuestion parte="{$parte}" num="{$num}">
            <xsl:if test="respuesta">
               <!--
               <xsl:attribute name="correcta">
                  <xsl:variable name="posiciones">
                     <xsl:for-each select="respuesta[@es='correcta']">
                        <c><xsl:number /></c>
                     </xsl:for-each>
                  </xsl:variable>
                  <xsl:value-of select="str:concat-sep(exsl:node-set($posiciones)/c)" />
               </xsl:attribute>
               -->
               <xsl:attribute name="orden">
                  <xsl:variable name="posiciones">
                     <xsl:for-each select="respuesta">
                        <xsl:sort select="xsl:order($desordenarr)" data-type="number"/>
                        <c><xsl:number /></c>
                     </xsl:for-each>
                  </xsl:variable>
                  <xsl:value-of select="str:concat-sep(exsl:node-set($posiciones)/c)" />
               </xsl:attribute>
            </xsl:if>
         </cuestion>
      </xsl:if>
   </xsl:template>

   <!-- La cantidad de preguntas se reparte aplicando d'Hont -->
   <xsl:template name="def_cantidad">
      <xsl:param name="restantes"/>
      <xsl:param name="resultado"/>

      <xsl:if test="not(function-available('exsl:node-set'))">
         <xsl:message terminate="yes">Paa exámenes con partes es necesario exsl:node-set</xsl:message>
      </xsl:if>

      <xsl:choose>
         <xsl:when test="$restantes = 0">
            <xsl:variable name="document" select="/"/>

            <!-- ¿Hay suficientes preguntas en cada parte? -->
            <xsl:for-each select="exsl:node-set($resultado)/numpre">
               <xsl:variable name="parte" select="position()"/>
               <!-- El cálculo del número de preguntas, depende de si el documento
                    se ha dividido o no en partes -->
               <xsl:variable name="numpre">
                  <xsl:choose>
                     <xsl:when test="$document//parte">
                        <xsl:value-of select="count($document//parte[$parte]/cuestion)"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="count($document//cuestion)"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:variable>

               <xsl:if test=". &gt; $numpre">
                  <xsl:message terminate="yes">La <xsl:value-of select="$parte"/>ª parte no tiene suficientes preguntas.
                     Se requieren al menos <xsl:value-of select="." />.
                  </xsl:message>
               </xsl:if>
            </xsl:for-each>

            <xsl:copy-of select="exsl:node-set($resultado)"/>
         </xsl:when>

         <!-- Si quedan preguntas por repartir, se obtiene una de la parte con mayor peso
              y se divide ese peso por su divisor + 1 -->
         <xsl:otherwise>

            <xsl:call-template name="def_cantidad">
               <xsl:with-param name="restantes" select="$restantes - 1"/>
               <xsl:with-param name="resultado">
                  <xsl:for-each select="exsl:node-set($resultado)/numpre">
                     <xsl:choose>
                        <!-- Se escoge pregunta de la parte con peso mayor y si varias partes
                             tienen el mismo peso máximo, se toma la primera de ellas -->
                        <xsl:when test="not(@peso &lt; exsl:node-set($resultado)/numpre/@peso) and
                                        generate-id(exsl:node-set($resultado)/numpre[@peso = current()/@peso][1]) = generate-id(.)">
                              <numpre peso="{@peso * @divisor div (@divisor + @paso)}" divisor="{@divisor + @paso}" paso="{@paso}">
                              <xsl:value-of select="text() + 1"/>
                           </numpre>
                        </xsl:when>

                        <xsl:otherwise>
                           <xsl:copy-of select="."/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:for-each>
               </xsl:with-param>
            </xsl:call-template>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:variable name="plantilla">
      <xsl:choose>
         <xsl:when test="$ejemplar">
            <xsl:variable name="p" select="document($ejemplar)/ejemplar"/>
            <xsl:if test="$p/@examen != /examen/@id">
               <xsl:message terminate="yes">La plantilla suministrada no es plantilla del examen a generar.</xsl:message>
            </xsl:if>
            <xsl:copy-of select="$p"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="value">
               <xsl:call-template name="plantilla"/>
            </xsl:variable>
            <exsl:document href="{concat(exsl:node-set($value)/ejemplar/@id,'.xml')}" method="xml">
               <xsl:copy-of select="$value"/>
            </exsl:document>
            <xsl:copy-of select="exsl:node-set($value)/ejemplar"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <!-- Estructura del documento HTML -->
   <xsl:template match="/">
      <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
      <html lang="es">
         <meta charset="utf-8"/>
         <title>
            <xsl:call-template name="prueba" />
         </title>
         <xsl:call-template name="css"/>
         <xsl:call-template name="js"/>

         <xsl:apply-templates select="examen"/>
      </html>
   </xsl:template>

   <!-- Denominación de la prueba -->
   <xsl:template name="prueba">
      <xsl:value-of select="$convocatoria" />.
      <xsl:value-of select="$secuencia" />ª prueba.
      <xsl:value-of select="$fecha" />
   </xsl:template>


   <!-- Cuerpo del cuestionario -->
   <xsl:template match="examen">
      <header>
         <xsl:apply-templates select="datos"/>
         <xsl:apply-templates select="texto/nota_previa"/>
      </header>

      <main>
         <h1>
            <span>Cuestiones</span>
            <xsl:choose>
               <xsl:when test="$papel">
                  <button id="responder">Responder</button>
               </xsl:when>
               <xsl:otherwise>
                  <button form="cuestionario" name="examen" value="{@id}">Enviar</button>
               </xsl:otherwise>
            </xsl:choose>
         </h1>

         <xsl:variable name="parte" select="//parte"/>
         <xsl:variable name="cuestion" select="//cuestion"/>

         <form action="#" id="cuestionario">
            <ol>
               <xsl:for-each select="exsl:node-set($plantilla)/ejemplar/cuestion">
                  <xsl:variable name="orden" select="@orden"/>
                  <xsl:variable name="factor" select="../@factor"/>
                  <xsl:variable name="id">
                     <xsl:call-template name="id_cuestion"/>
                  </xsl:variable>

                  <xsl:choose>
                     <xsl:when test="@parte = 0">
                        <xsl:apply-templates select="$cuestion[position() = current()/@num]" mode="html">
                           <xsl:with-param name="factor" select="$factor"/>
                           <xsl:with-param name="orden" select="$orden"/>
                           <xsl:with-param name="id" select="$id"/>
                        </xsl:apply-templates>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:apply-templates select="$parte[position() = current()/@parte]/cuestion[position() = current()/@num]" mode="html">
                           <xsl:with-param name="factor" select="$factor"/>
                           <xsl:with-param name="orden" select="$orden"/>
                           <xsl:with-param name="id" select="$id"/>
                        </xsl:apply-templates>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:for-each>
            </ol>
         </form>
      </main>
   </xsl:template>


   <!-- Datos del examen: conforman la tabla de cabecera -->
   <xsl:template match="datos">
      <table>
         <tr>
            <td colspan="4">
               <textarea name="apellidos" placeholder="Apellidos"><xsl:value-of select="examinando/apellidos" /></textarea>
            </td>
            <td colspan="3">
               <textarea name="nombre" placeholder="Nombre"><xsl:value-of select="examinando/nombre" /></textarea>
            </td>
            <td>
               <textarea disabled="disabled" name="grupo" placeholder="Grupo"><xsl:value-of select="$grupo" /></textarea>
            </td>
         </tr>
         <tr>
            <td colspan="2">
               <textarea name="asignatura" placeholder="Asignatura">
                  <xsl:if test="prueba/asignatura">
                     <xsl:attribute name="disabled"/>
                     <xsl:value-of select="prueba/asignatura" />
                  </xsl:if>
               </textarea>
            </td>
            <td colspan="2">
               <xsl:variable name="prueba">
                  <xsl:value-of select="$convocatoria" /> - <xsl:value-of select="$secuencia" />
               </xsl:variable>
               <textarea name="prueba" placeholder="Prueba">
                  <xsl:if test="$prueba != ' - '">
                     <xsl:attribute name="disabled"/>
                     <xsl:value-of select="$prueba"/>
                  </xsl:if>
               </textarea>
            </td>
            <td colspan="3">
               <textarea name="fecha" placeholder="Fecha">
                  <xsl:if test="$fecha">
                     <xsl:attribute name="disabled"/>
                     <xsl:value-of select="$fecha" />
                  </xsl:if>
               </textarea>
            </td>
            <td class="calificacion" rowspan="2">
               <textarea disabled="disabled" name="calificacion" placeholder="Nota"/>
            </td>
         </tr>
         <tr>
            <td class="observaciones" colspan="7">
               <textarea disabled="disabled" name="observaciones" placeholder="Observaciones"/>
            </td>
         </tr>
      </table>
   </xsl:template>

   <!-- Aviso al examinando -->
   <xsl:template match="nota_previa">
      <details id="nota">
         <summary><xsl:value-of select="leyenda" /></summary>
         <ul>
            <xsl:for-each select="item">
               <li><xsl:apply-templates /></li>
            </xsl:for-each>
         </ul>
      </details>
   </xsl:template>

   <!-- Genera el identificador de la cuestión -->
   <xsl:template name="id_cuestion">
      <xsl:text>c</xsl:text>
      <xsl:number value="@parte" format="01"/>
      <xsl:text>_</xsl:text>
      <xsl:number value="@num" format="001"/>
   </xsl:template>

   <func:function name="xsl:orden_respuestas">
      <xsl:param name="pos"/>
      <xsl:param name="orden"/>

      <func:result select="str:split($orden, ' ')[$pos]"/>
   </func:function>

   <!-- Cuestiones -->
   <xsl:template match="cuestion" mode="html">
      <xsl:param name="factor"/>
      <xsl:param name="orden"/>
      <xsl:param name="id"/>

      <li id="{$id}">
         <div class="pregunta">
            <xsl:call-template name="puntuacion">
               <xsl:with-param name="factor" select="$factor"/>
            </xsl:call-template>
            <xsl:apply-templates select="pregunta" />
         </div>
         <xsl:choose>
            <xsl:when test="@tipo='simple' or @tipo='multi'">
               <ul class="test">
                  <xsl:apply-templates select="respuesta">
                     <xsl:with-param name="id" select="$id"/>
                     <xsl:sort select="xsl:orden_respuestas(position(), $orden)"/>
                  </xsl:apply-templates>
               </ul>
            </xsl:when>
            <xsl:when test="@tipo = 'libre'"/>
            <xsl:otherwise>
               <xsl:message terminate="yes">El tipo de pregunta '<xsl:value-of select="@tipo"/>' no tiene soporte</xsl:message>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:apply-templates select="borrador" />
      </li>
   </xsl:template>

   <!-- Genera la puntuación de la pregunta -->
   <xsl:template name="puntuacion">
      <xsl:param name="factor"/>
      <xsl:variable name="suma" select="xsl:default(../@suma, 1) * $factor" />
      <span class="puntuacion">
         <xsl:text>[punt=+</xsl:text><b><xsl:value-of select="format-number($suma,'#0,000','puntuacion')" /></b>
         <!-- Sólo las preguntas de test con una única respuesta, restan nota -->
         <xsl:if test="@tipo='simple'">
            <xsl:text>;-</xsl:text>
            <b>
               <xsl:variable name="resta" select="xsl:default(../@resta*$factor, $suma div (count(respuesta) - 1))" />
               <xsl:value-of select="format-number($resta,'#0,000','puntuacion')" />
            </b>
         </xsl:if>
         <xsl:text>]</xsl:text>
      </span>
   </xsl:template>

   <!-- El texto de la pregunta es código HTML -->
   <xsl:template match="pregunta">
      <xsl:apply-templates />
   </xsl:template>

   <!-- Opción de una respuesta en tipo test -->
   <xsl:template match="respuesta">
      <xsl:param name="id"/>

      <xsl:variable name="opcion">
         <xsl:number format="a"/>
      </xsl:variable>
      <xsl:variable name="tipo">
         <xsl:choose>
            <xsl:when test="../@tipo = 'simple'">
               <xsl:text>radio</xsl:text>
            </xsl:when>
            <xsl:when test="../@tipo = 'multi'">
               <xsl:text>checkbox</xsl:text>
            </xsl:when>
            <xsl:otherwise>
               <xsl:message terminate="yes">Test <xsl:value-of select="../@tipo"/> no soportado.</xsl:message>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <li>
         <xsl:if test="$papel and @es = 'correcta'">
            <xsl:attribute name="class">correcta</xsl:attribute>
         </xsl:if>
         <label>
            <input type="{$tipo}" name="{$id}" value="{$opcion}"/>
            <span><span class="casilla"><xsl:number value="position()" format="a" /></span></span><span><xsl:apply-templates /></span>
         </label>
      </li>
   </xsl:template>

   <!-- Espacio para borrador o escribir el texto de la respuesta -->
   <xsl:template match="borrador">
      <xsl:variable name="leyenda">
         <xsl:choose>
            <xsl:when test="../@tipo='libre'" >Respuesta...</xsl:when>
            <xsl:otherwise>Borrador...</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <textarea name="{../@id}" class="borrador" rows="{@espacio}" placeholder="{$leyenda}" />
   </xsl:template>


   <!-- Incluye la hoja de estilos en el documento -->
   <xsl:template name="css">
      <xsl:choose>
         <xsl:when test="$externa">
            <link rel="stylesheet" href="{$css}" />
            <xsl:if test="$extracss">
               <link rel="stylesheet" href="{$extracss}" />
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="content">
               <xsl:message terminate="yes">ERROR. Debe generar el elemento xi:include</xsl:message>
            </xsl:variable>
            <style>
               <xsl:value-of select="$content"/>
            </style>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


   <!-- Incluye el código Javascript en el documento -->
   <xsl:template name="js">
      <xsl:choose>
         <xsl:when test="$externa">
            <script src="{$js}"></script>
            <xsl:if test="$extrajs">
               <script src="{$extrajs}"></script>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="content">
               <xsl:message terminate="yes">ERROR. Debe generar el elemento xi:include</xsl:message>
            </xsl:variable>
            <script>
               <xsl:value-of select="$content"/>
            </script>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


   <!-- Cálcula la sumaproducto de dos series de números -->
   <xsl:template name="sumaproducto">
      <xsl:param name="nod1"/>
      <xsl:param name="nod2"/>
      <xsl:param name="num" select="1"/>
      <xsl:param name="acomulado" select="0"/>

      <xsl:choose>
         <xsl:when test="$num &gt; count($nod1) or $num &gt; count($nod2)">
            <xsl:value-of select="$acomulado"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:call-template name="sumaproducto">
               <xsl:with-param name="nod1" select="$nod1"/>
               <xsl:with-param name="nod2" select="$nod2"/>
               <xsl:with-param name="num" select="$num + 1"/>
               <xsl:with-param name="acomulado" select="$acomulado + $nod1[$num]*$nod2[$num]"/>
            </xsl:call-template>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


   <!-- Para poder escribir directamente código HTML -->
   <xsl:template match="*">
      <xsl:copy-of select="."/>
   </xsl:template>

</xsl:stylesheet>
