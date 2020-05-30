window.onload = function() {
   const responder = document.getElementById("responder");
   if(responder) {
      responder.addEventListener("click", function(e) {
         let responder = this.textContent === "Responder";
         this.textContent = responder?"Limpiar":"Responder";
         document.querySelectorAll("ul.test>li")
                 .forEach(e => e.querySelector("input").disabled=responder);
         this.respondido = this.textContent === "Limpiar";
      });
   }
   else {
      // Permite desmarcar la pregunta
      // volviendo a pinchar sobre ella.
      document.querySelectorAll("ul.test>li")
              .forEach(e => e.addEventListener("click", function(ev) {
                 if(ev.target.tagName === "SPAN") {
                    const input = ev.target.closest("label").querySelector("input");
                    if(input.checked) {
                       ev.preventDefault();
                       input.checked = false;
                    }
                 }
              }));

      parchearEnvio();
   }
}

window.onbeforeprint = function() {
   const nota = document.querySelector("details"),
         responder = document.getElementById("responder");

   // Hay que imprimir el fondo para ver las respuestas de tipo test,
   // a menos que se imprima el formato papel sin haber marcado las respuestas.
   if(!responder || responder.respondido) {
      document.body.style.webkitPrintColorAdjust = "exact";
      document.body.style.colorAdjust = "exact";
      return;
   }

   if(nota.hasAttribute("open")) return;

   nota.changed = true;
   nota.setAttribute("open", "");
}

window.onafterprint = function() {
   const nota = document.querySelector("details");

   document.body.style.removeProperty("webkitPrintColorAdjust");
   document.body.style.removeProperty("colorAdjust");

   if(!nota.changed) return;

   nota.changed = false;
   nota.removeAttribute("open");
}


// Mientras no haya aplicación en el servidor, el botón de envío
// tiene que limitarse a imprimir y descargar un fichero con las respuestas.
function parchearEnvio() {
   const envio = document.querySelector("button[form=cuestionario]");
   envio.addEventListener("click", e => {
      e.preventDefault();

      const valores = new URLSearchParams(new FormData(document.getElementById("cuestionario"))),
            texto = Array.from(valores.entries()).map(v => v[0] + " => " + v[1] + "\n");

      const blob = new Blob(texto, {type: "text/plain;charset=utf-8"});
      
      const link = document.createElement("a");
      link.href =  (window.webkitURL || window.URL).createObjectURL(blob);
      link.download = "respuestas.txt";
      link.dataset.downloadurl = ['text/plain;charset=utf-8', link.download, link.href].join(':');
      
      window.print();
      link.click();
   });
}
