/* Taste of Japan — main script (v3, simple) */
(function () {
  "use strict";

  var list = document.getElementById("restaurantList");
  var searchInput = document.getElementById("searchInput");
  var cuisineSelect = document.getElementById("cuisineSelect");
  var areaSelect = document.getElementById("areaSelect");
  var budgetSelect = document.getElementById("budgetSelect");
  var sortSelect = document.getElementById("sortSelect");
  var resultCount = document.getElementById("resultCount");
  var featuredLink = document.getElementById("featuredLink");
  var modal = document.getElementById("modal");
  var modalContent = document.getElementById("modalContent");
  var modalClose = document.getElementById("modalClose");
  var modalOverlay = document.getElementById("modalOverlay");
  var navToggle = document.getElementById("navToggle");
  var navMenu = document.getElementById("navMenu");

  var state = { category: "all", area: "all", budget: "all", sort: "popular", query: "" };

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  /* ---------- selects ---------- */
  function buildCuisineSelect() {
    var keys = Object.keys(CATEGORIES).filter(function (k) {
      return RESTAURANTS.some(function (r) { return r.category === k; });
    });
    cuisineSelect.innerHTML =
      '<option value="all">All cuisines</option>' +
      keys.map(function (k) {
        return '<option value="' + k + '">' + esc(CATEGORIES[k].label) + "</option>";
      }).join("");
  }

  function buildAreaSelect() {
    var areas = [];
    RESTAURANTS.forEach(function (r) {
      if (areas.indexOf(r.area) === -1) areas.push(r.area);
    });
    areas.sort();
    areaSelect.innerHTML =
      '<option value="all">All areas</option>' +
      areas.map(function (a) { return '<option value="' + esc(a) + '">' + esc(a) + "</option>"; }).join("");
  }

  [cuisineSelect, areaSelect, budgetSelect, sortSelect].forEach(function (sel) {
    sel.addEventListener("change", function () {
      state.category = cuisineSelect.value;
      state.area = areaSelect.value;
      state.budget = budgetSelect.value;
      state.sort = sortSelect.value;
      render();
    });
  });

  /* ---------- hero quick links ---------- */
  document.querySelectorAll("[data-cat]").forEach(function (a) {
    a.addEventListener("click", function () {
      state.category = a.dataset.cat;
      cuisineSelect.value = state.category;
      render();
    });
  });

  /* ---------- filtering ---------- */
  function matches(r) {
    if (state.category !== "all" && r.category !== state.category) return false;
    if (state.area !== "all" && r.area !== state.area) return false;
    if (state.budget !== "all" && r.price !== Number(state.budget)) return false;
    if (!state.query) return true;
    var hay = [r.name, r.jp, CATEGORIES[r.category].label, r.area, r.tagline, r.description, r.station]
      .concat(r.tags).concat(r.dishes).join(" ").toLowerCase();
    return hay.indexOf(state.query) !== -1;
  }

  var SORTS = {
    popular: function (a, b) { return b.reviews - a.reviews; },
    rating: function (a, b) { return b.rating - a.rating; },
    priceAsc: function (a, b) { return a.price - b.price; },
    priceDesc: function (a, b) { return b.price - a.price; },
  };

  function priceText(r) {
    var parts = [];
    if (r.lunch) parts.push("L " + r.lunch);
    if (r.dinner) parts.push("D " + r.dinner);
    return parts.join("<br>") || esc(r.priceNote);
  }

  /* ---------- list ---------- */
  function rowHTML(r) {
    return (
      '<li class="resto" data-id="' + r.id + '" tabindex="0" role="button" aria-label="Details for ' + esc(r.name) + '">' +
        '<span class="resto__icon" style="--h:' + r.hue + '">' + r.emoji + "</span>" +
        '<div class="resto__main">' +
          '<div class="resto__name">' + esc(r.name) + '<span class="jp">' + esc(r.jp) + "</span></div>" +
          '<div class="resto__meta">' + esc(CATEGORIES[r.category].label) + " · " + esc(r.area) + " · " + esc(r.station) + "</div>" +
        "</div>" +
        '<div class="resto__rating"><span class="star">★</span> ' + r.rating.toFixed(1) + " <small>(" + r.reviews + ")</small></div>" +
        '<div class="resto__price"><b>' + "$".repeat(r.price) + "</b><br>" + priceText(r) + "</div>" +
      "</li>"
    );
  }

  function render() {
    var rows = RESTAURANTS.filter(matches).sort(SORTS[state.sort] || SORTS.popular);
    resultCount.textContent =
      rows.length === RESTAURANTS.length
        ? rows.length + " restaurants"
        : rows.length + " of " + RESTAURANTS.length + " restaurants";

    if (!rows.length) {
      list.innerHTML =
        '<li style="padding:32px 6px;text-align:center;color:var(--muted)">' +
        "No restaurants match. Try different filters.</li>";
      return;
    }
    list.innerHTML = rows.map(rowHTML).join("");

    list.querySelectorAll(".resto").forEach(function (row) {
      row.addEventListener("click", function () {
        openModal(Number(row.dataset.id));
      });
      row.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          openModal(Number(row.dataset.id));
        }
      });
    });
  }

  /* ---------- modal ---------- */
  function infoRow(icon, label, value) {
    if (!value) return "";
    return '<li><span class="li-icon">' + icon + "</span><span><b>" + label + ":</b> " + esc(value) + "</span></li>";
  }

  function openModal(id) {
    var r = RESTAURANTS.find(function (x) { return x.id === id; });
    if (!r) return;
    var mapURL =
      "https://www.google.com/maps/search/?api=1&query=" +
      encodeURIComponent(r.name + " " + r.area + " Tokyo");

    modalContent.innerHTML =
      '<div class="modal__head" style="--h:' + r.hue + '">' +
        '<span class="resto__icon" style="--h:' + r.hue + '">' + r.emoji + "</span>" +
        "<div>" +
          "<h3>" + esc(r.name) + '<span class="jp">' + esc(r.jp) + "</span></h3>" +
          '<div class="meta">' +
            esc(CATEGORIES[r.category].label) + " · " + esc(r.area) + " · " +
            '<span class="star">★</span> ' + r.rating.toFixed(1) + " (" + r.reviews + " reviews)" +
          "</div>" +
        "</div>" +
      "</div>" +
      '<div class="modal__body">' +
        "<p>" + esc(r.description) + "</p>" +
        "<h4>Recommended dishes</h4>" +
        '<ul class="modal__list">' +
          r.dishes.map(function (d) {
            return '<li><span class="li-icon">🍽️</span><span>' + esc(d) + "</span></li>";
          }).join("") +
        "</ul>" +
        "<h4>Good to know</h4>" +
        '<ul class="modal__list">' +
          infoRow("🚉", "Station", r.station) +
          infoRow("🪑", "Seating", r.seats) +
          infoRow("📅", "Reservation", r.reservation) +
          infoRow("🕐", "Hours", r.hours) +
          infoRow("💴", "Budget", r.priceNote) +
          infoRow("🏠", "Address", r.address) +
        "</ul>" +
        "<h4>Tags</h4>" +
        '<div class="modal__tags">' + r.tags.map(function (t) { return "<span>" + esc(t) + "</span>"; }).join("") + "</div>" +
        '<div class="modal__actions">' +
          '<a class="btn btn--primary" href="' + mapURL + '" target="_blank" rel="noopener">Show on map</a>' +
          '<button class="btn btn--ghost" id="modalBack">Close</button>' +
        "</div>" +
      "</div>";

    modal.classList.add("open");
    modal.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    modalClose.focus();

    document.getElementById("modalBack").addEventListener("click", closeModal);
  }

  function closeModal() {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
  }

  modalClose.addEventListener("click", closeModal);
  modalOverlay.addEventListener("click", closeModal);
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && modal.classList.contains("open")) closeModal();
  });

  /* ---------- search ---------- */
  searchInput.addEventListener("input", function () {
    state.query = searchInput.value.trim().toLowerCase();
    render();
  });

  /* ---------- featured link ---------- */
  featuredLink.addEventListener("click", function () {
    var r = RESTAURANTS.find(function (x) { return x.featured; }) || RESTAURANTS[0];
    openModal(r.id);
  });

  /* ---------- mobile nav ---------- */
  navToggle.addEventListener("click", function () {
    var open = navMenu.classList.toggle("open");
    navToggle.setAttribute("aria-expanded", String(open));
  });
  navMenu.querySelectorAll("a").forEach(function (a) {
    a.addEventListener("click", function () { navMenu.classList.remove("open"); });
  });

  /* ---------- active nav link ---------- */
  var sections = ["restaurants", "guide", "etiquette", "phrases", "faq"];
  var navIO = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (!en.isIntersecting) return;
      var id = en.target.id;
      document.querySelectorAll(".nav-link").forEach(function (l) {
        l.classList.toggle("active", l.getAttribute("href") === "#" + id);
      });
    });
  }, { rootMargin: "-40% 0px -55% 0px" });
  sections.forEach(function (id) {
    var el = document.getElementById(id);
    if (el) navIO.observe(el);
  });

  /* ---------- init ---------- */
  buildCuisineSelect();
  buildAreaSelect();
  render();
})();
