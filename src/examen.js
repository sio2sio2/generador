window.onload = function() {
   const responder = document.getElementById("responder");
   if(!responder) return;

   responder.addEventListener("click", function(e) {
      let responder = this.textContent === "Responder";
      this.textContent = responder?"Limpiar":"Responder";
      document.querySelectorAll("ul.test>li")
              .forEach(e => e.querySelector("input").disabled=responder);
      this.respondido = this.textContent === "Limpiar";
   });
}

window.onbeforeprint = function() {
   const nota = document.querySelector("details"),
         responder = document.getElementById("responder");

   if(nota.hasAttribute("open") || responder && responder.respondido) return;

   nota.changed = true;
   nota.setAttribute("open", "");
}

window.onafterprint = function() {
   const nota = document.querySelector("details");
   if(!nota.changed) return;

   nota.changed = false;
   nota.removeAttribute("open");
}
