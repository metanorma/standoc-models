// Catalogue filter — progressive enhancement; without JS all rows show.
(function () {
  "use strict";

  var chips = document.querySelectorAll(".chip[data-filter]");
  if (!chips.length) return;

  var rows = document.querySelectorAll(".flavor-entry");

  chips.forEach(function (chip) {
    chip.addEventListener("click", function () {
      chips.forEach(function (c) { c.setAttribute("aria-pressed", String(c === chip)); });
      var filter = chip.getAttribute("data-filter");
      rows.forEach(function (row) {
        var hasCards = parseInt(row.getAttribute("data-cards"), 10) > 0;
        var show = filter === "all" || hasCards;
        row.hidden = !show;
      });
    });
  });
})();
