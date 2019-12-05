#!/bin/sh
#
# Generador de exámenes
#

REALPATH=$(dirname "$(realpath "$0")")
XSL=${XSL:-$REALPATH/src/examen.xsl}
PRE=10

help() {
   echo "$(basename "$0") [opciones] <input.xml>
   Genera un examen en HTML a partir del fichero de entrada,
   en que se selecciona un límite de preguntas y permite
   desorganizarlas para crear distintos modelos de examen.

   Los exámenes pueden estar constituidos por partes. En ese
   caso, se extraerá de cada parte un número de preguntas
   proprocional al peso de la parte, de modo que la suma
   de las preguntas de cada parte coincida con el número total
   de preguntas.

Opciones:

 -C, --css FILE        CSS extra que utilizará el HTML resultante.
 -c, --caos            Si el examen se compone  de varias partes
                       el orden de las preguntas no respeta ni
                       siquiera la división en partes. Por defecto,
                       se conserva el orden de las partes y. sólo
                       dentro de cada parte, se desordenan las preguntas.
 -d, --desordem-resp   Desordena las alternativas de una pregunta de
                       tipo test. Por defecto, se conserva el orden.
 -E, --en-papel        El examen se pasará en papel, así que se incluyen
                       dentro del código las propias respuestas, y un
                       botón para hacerlas evidentes.
 -e, --externa         Refiere el CSS y el Javascript en vez de incluirlo
                       dentro del HTML. Por defecto, se incluyen a menos
                       que no esté instalado xsltproc.
 -h, --help            Muestra este mensaje de ayuda.
 -j, --javascript FILE Javascript extra que utilizará el HTML resultante.
 -n, --num NUM         Número de exámenes que se desea generar. Por
                       defecto, 1.
 -o, --output FILE     Fichero de salida.
 -O, --orden           Mantiene el orden que las preguntas muestran
                       en el XML de entrada. Por defecto, se desordenan.
 -P, --puntuacion N    Puntuación total del examen. Por defecto, 10.
 -p, --preguntas  NUM  Número de preguntas de las que se compone
                       el examen. Por defecto, 10.
 -t, --template FILE   Utiliza la plantilla para generar el examen,
                       en vez de generar uno ex-novo.
 -v, --verbose         Muestra en la salida de errores la lista de
                       preguntas seleccionadas en el orden en que
                       aparecerán.
 -x, --xsl FILE        XSL de tranformación. Por defecto, src/examen.xsl
"
}


error() {
   local EXITCODE=$1
   shift

   if [ "$EXITCODE" -eq 0 ]; then
      echo "¡Atención! "$* >&2
   else
      echo "ERROR. "$* >&2
      exit $EXITCODE
   fi
}


entero() {
    expr "$1" : "^[0-9]\+$" > /dev/null
}


#
# Convierte código hexadecimal en binario
# (requiere bc, que puede no estar instalado)
# $1: El número en hexadecimal
#
hex2dec() {
   echo "ibase=16;$1" | bc
}


#
# Obtiene n bytes al azar expresados en hexadecimal
# $1: Número de bytes. 1, si no se especifica.
#
random_x() {
   # hexdump -n${1:-1} -ve '"%02X"' /dev/urandom
   # od debería ser más portable que hexdump,
   # aunque debemos eliminar espacios y pasar a mayúsculas.
   od -v -An -tx1 -N${1:-1} /dev/urandom | tr -d '\n ' | tr '[:lower:]' '[:upper:]'
}


#
# Obtiene un número decimal aleatorio entre 0 y 2**n-1.
# $1: El valor de n.
#
random() {
   hex2dec $(random_x "$1")
}


#
# Espera un número aleatorio de segundos.
# $1: Límite de la espera.
#
espera() {
   local SEG=$((`random 1`%$1 + 1))
   for i in `seq 1 $SEG`; do
      printf -- "%d... " "$i"
      sleep 1
   done
   echo
}


#
# Agrega parámetros al procesador XSLT
# $1: Tipo (s[tring], p[aram], o b[oolean])
# $2: Nombre del parámetro
# $3: Valor del parámetro.
#
agrega_param() {
   local P S

   # Un valor booleano es un param con valor false() o true().
   # Si $3 está vacía entonces es false().
   if [ "$1" = "b" ]; then
      value="false()"
      [ -n "$3" ] && value="true()"
      set -- p "$2" "$value"
   fi

   case "$PROCESSOR" in
      *xsltproc)
         if [ "$1" = "p" ]; then
            echo --param "$2" "'$3'"
         else
            echo --stringparam "$2" "'$3'"
         fi
         ;;
      *xmlstarlet)
         if [ "$1" = "p" ]; then
            echo "-p '$2=$3'"
         else
            echo "-s '$2=$3'"
         fi
         ;;
      *)
         error 1 "Procesador '$(basename "$PROCESSOR")' sin sopoete"
   esac
}


{  ### Parámetros

   DESORDENR=
   CAOS=
   DESORDEN=1
   NUM=1
   VERBOSE=
   PAPEL=
   CSS=
   JS=
   PUNT=10

   while [ $# -gt 0 ]; do
      case "$1" in
         -C|--css)
            CSS=$(realpath "$2")
            shift
            ;;
         -c|--caos)
            CAOS=1
            ;;
         -d|--desorden-resp)
            DESORDENR=1
            ;;
         -E|--en-papel)
            PAPEL=1
            ;;
         -e|--externa)
            EXTERNA=1
            ;;
         -h|--help)
            help
            exit 0
            ;;
         -j|--javascript)
            JS=$(realpath "$2")
            shift
            ;;
         -p|--preguntas)
            PRE="$2"
            shift
            ;;
         -P|--puntuacion)
            PUNT="$2"
            shift
            ;;
         -n|--num)
            NUM="$2"
            shift
            ;;
         -o|--output)
            OUTPUT="$2"
            shift
            ;;
         -O|--orden)
            DESORDEN=
            ;;
         -t|--template)
            PLANTILLA=$(realpath "$2")
            shift
            ;;
         -x|--xsl)
            XSL="$2"
            shift
            ;;
         -v|--verbose)
            VERBOSE=1
            ;;
         -*)
            error 2 "$1: Opción desconocida"
            ;;
         *)
            [ -n "$INPUT" ] && error 2 "Demasiados parámetros"
            INPUT=$1
      esac
      shift
   done

   if [ -n "$CSS" ] && [ ! -f "$CSS" ]; then
      error 1 "No existe el fichero '$CSS'."
   fi

   if [ -n "$JS" ] && [ ! -f "$JS" ]; then
      error 1 "No existe el fichero '$JS'."
   fi

   if [ ! -f "$XSL" ]; then
      error 1 "No existe el fichero '$XSL'."
   fi

   if ! entero "$PRE"; then
      error 1 "$PRE: Número de preguntas no entero."
   fi

   if ! entero "$PUNT"; then
      error 1 "$UNT: La puntuación no es un número entero"
   fi

   if [ -z "$DESORDEN" ] && [ -n "$CAOS" ]; then
      error 2 "Orden y caos son opciones incompatibles"
   fi

   if [ -n "$PLATILLA" ] && [ ! -f "$PLANTILLA" ]; then
      error 1 "No existe el fichero '$PLANTILLA'."
   fi
   

   if [ -z "$INPUT" ]; then
      error 2 "No ha indicado ningún XML"
   elif [ ! -f "$INPUT" ]; then
      error 1 "'$INPUT': XML inexistente"
   fi

   OUTPUT=${OUTPUT:-$(basename "$INPUT")}
   OUTPUT="${OUTPUT%.*}"
   EXTENSION="html"

   PROCESSOR="$(command -v xsltproc)"
   if [ -z "$PROCESSOR" ]; then
      PROCESSOR="$(command -v xmlstarlet)"
      if [ $? -eq 1 ]; then
         error 1 "El scropt requiere xsltproc o xmlstarlet"
      elif [ -z "$EXTERNA" ]; then
         error 0 "Para incrustar el CSS se requiere xsltproc."
         EXTERNA=1
      fi
   fi

   # Si se incluye el CSS dentro del HTML, hay que usar un xi:include
   # cuyo href es una variable. Como tal cosa es imposible, hay que
   # generar un XSL intermedio que tenga ese href ya calculado.
   if [ -z "$EXTERNA" ]; then
      ARGS="$(agrega_param s base "$REALPATH")"
      ARGS="$ARGS $(agrega_param s extracss "$CSS")"
      ARGS="$ARGS $(agrega_param s extrajs "$JS")"

      eval set -- $ARGS

      TMPFILE="$(mktemp -p "$(dirname "$XSL")" tmp.XXXXXX.xsl)"
      trap 'rm -f "$TMPFILE"' EXIT TERM INT
      xsltproc "$@" "$(dirname "$XSL")/include.xsl" "$XSL" > "$TMPFILE"
      XSL="$TMPFILE"
   fi
}

ARGS="$(agrega_param p preguntas "$PRE")"
ARGS="$ARGS $(agrega_param s puntuacion "$PUNT")"
ARGS="$ARGS $(agrega_param s extracss "$CSS")"
ARGS="$ARGS $(agrega_param s extrajs "$JS")"
ARGS="$ARGS $(agrega_param b externa "$EXTERNA")"
ARGS="$ARGS $(agrega_param b desordenar "$DESORDEN")"
ARGS="$ARGS $(agrega_param b caos "$CAOS")"
ARGS="$ARGS $(agrega_param b desordenarr "$DESORDENR")"
ARGS="$ARGS $(agrega_param b debug "$VERBOSE")"
ARGS="$ARGS $(agrega_param b papel "$PAPEL")"
ARGS="$ARGS $(agrega_param s ejemplar "$PLANTILLA")"

eval set -- $ARGS

for i in `seq 1 $NUM`; do
   output="${OUTPUT}#$i.$EXTENSION"
   [ "$i" != 1 ] && espera 4

   case "$PROCESSOR" in
      *xmlstarlet)
         "$PROCESSOR" tr "$XSL" "$@" "$INPUT" > "$output"
         ;;
      *xsltproc)
         "$PROCESSOR" --xincludestyle "$@" "$XSL" "$INPUT" > "$output"
         ;;
      *)
         error 1 "$PROCESSOR no soportado"
   esac
done
