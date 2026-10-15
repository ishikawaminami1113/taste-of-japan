/* Taste of Japan — main script (v5, polished) */
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

  /* ---------- favorites ---------- */
  function getFavs() {
    try { return JSON.parse(localStorage.getItem("toj_favs") || "[]"); } catch(e) { return []; }
  }
  function toggleFav(id) {
    var favs = getFavs();
    var idx = favs.indexOf(id);
    if (idx === -1) favs.push(id); else favs.splice(idx, 1);
    localStorage.setItem("toj_favs", JSON.stringify(favs));
    return idx === -1;
  }
  function isFav(id) { return getFavs().indexOf(id) !== -1; }

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

  /* ---------- filter controls (restaurant page only) ---------- */
  if (cuisineSelect && areaSelect && budgetSelect && sortSelect) {
    [cuisineSelect, areaSelect, budgetSelect, sortSelect].forEach(function (sel) {
      sel.addEventListener("change", function () {
        state.category = cuisineSelect.value;
        state.area = areaSelect.value;
        state.budget = budgetSelect.value;
        state.sort = sortSelect.value;
        render();
      });
    });
  }

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
    return r.priceNote || "";
  }

  /* ---------- list ---------- */
  function rowHTML(r) {
    var fav = isFav(r.id) ? " fav" : "";
    return (
      '<div class="resto' + fav + '" data-id="' + r.id + '" tabindex="0" role="button">' +
        '<div class="resto__head">' +
          '<span class="resto__icon" style="--h:' + r.hue + '" aria-hidden="true">' + r.emoji + "</span>" +
          "<div>" +
            '<div class="resto__name">' + esc(r.name) + '<span class="jp">' + esc(r.jp) + "</span></div>" +
            '<div class="resto__meta">' + esc(CATEGORIES[r.category].label) + " · " + esc(r.area) + " · " + esc(r.station) + "</div>" +
          "</div>" +
        "</div>" +
        '<div class="resto__row">' +
          '<div class="resto__rating"><span class="star">★</span> ' + r.rating.toFixed(1) + " <small>(" + r.reviews + " reviews)</small></div>" +
          '<div class="resto__price"><b>' + "$".repeat(r.price) + "</b>" + (priceText(r) ? " " + esc(priceText(r)) : "") + "</div>" +
        "</div>" +
        '<button class="resto__fav' + fav + '" data-fav="' + r.id + '" aria-label="Toggle favorite" title="Favorite">' + (isFav(r.id) ? "♥" : "♡") + "</button>" +
      "</div>"
    );
  }

  function render() {
    if (!list || !resultCount) return;
    var rows = RESTAURANTS.filter(matches).sort(SORTS[state.sort] || SORTS.popular);
    resultCount.textContent =
      rows.length === RESTAURANTS.length
        ? rows.length + " restaurants"
        : rows.length + " of " + RESTAURANTS.length + " restaurants";

    if (!rows.length) {
      list.innerHTML =
        '<div style="padding:32px 6px;text-align:center;color:var(--muted)">' +
        "No restaurants match. Try different filters.</div>";
      return;
    }
    list.innerHTML = rows.map(rowHTML).join("");

    list.querySelectorAll(".resto").forEach(function (row) {
      row.addEventListener("click", function (e) {
        if (e.target.closest("[data-fav]")) return;
        openModal(Number(row.dataset.id));
      });
      row.addEventListener("keydown", function (e) {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          openModal(Number(row.dataset.id));
        }
      });
    });
    list.querySelectorAll("[data-fav]").forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.stopPropagation();
        var id = Number(btn.dataset.fav);
        var added = toggleFav(id);
        btn.textContent = added ? "♥" : "♡";
        btn.classList.toggle("fav", added);
        var rowEl = btn.closest(".resto");
        if (rowEl) rowEl.classList.toggle("fav", added);
      });
    });
    if (typeof observeNew === "function") observeNew();
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
        '<span class="resto__icon" style="--h:' + r.hue + '" aria-hidden="true">' + r.emoji + "</span>" +
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
          '<button class="btn btn--ghost" id="modalFav">' + (isFav(r.id) ? "♥ Favorited" : "♡ Add to favorites") + '</button>' +
          '<button class="btn btn--ghost" id="modalBack">Close</button>' +
        "</div>" +
      "</div>";

    modal.classList.add("open");
    modal.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    modalClose.focus();

    document.getElementById("modalBack").addEventListener("click", closeModal);
    document.getElementById("modalFav").addEventListener("click", function () {
      var added = toggleFav(r.id);
      this.textContent = added ? "♥ Favorited" : "♡ Add to favorites";
      render();
    });
  }

  function closeModal() {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
  }

  if (modal && modalClose && modalOverlay) {
    modalClose.addEventListener("click", closeModal);
    modalOverlay.addEventListener("click", closeModal);
  }
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && modal && modal.classList.contains("open")) closeModal();
  });

  /* ---------- search ---------- */
  if (searchInput) {
    searchInput.addEventListener("input", function () {
      state.query = searchInput.value.trim().toLowerCase();
      render();
    });
  }

  /* ---------- featured link ---------- */
  if (featuredLink) {
    featuredLink.addEventListener("click", function () {
      var r = RESTAURANTS.find(function (x) { return x.featured; }) || RESTAURANTS[0];
      openModal(r.id);
    });
  }

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

  /* ---------- scroll reveal ----------
     Hidden state is applied inline by JS (not by a CSS class) so it is
     guaranteed to take effect on the frame the element exists. The
     .is-revealed class then clears those inline values so the CSS
     transition in styles.css (.revealable) animates it back in.
     If anything at all goes wrong, a fallback timer reveals everything,
     so content can never be left stuck at opacity 0. */
  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var REVEAL_SELECTOR = ".resto, .guide-card, .rule-list li, .conv-card, .faq-item, .photo-band, .conv-aside, .area-block, .article-body > *";
  var revealIO = null;
  var revealAllDone = false;

  function hideEl(el) {
    el.classList.add("revealable");
    el.style.opacity = "0";
    el.style.transform = "translateY(16px)";
  }
  function showEl(el) {
    if (el.classList.contains("is-revealed")) return;
    el.classList.add("is-revealed");
    el.style.opacity = "";
    el.style.transform = "";
  }
  function revealEverything() {
    if (revealAllDone) return;
    revealAllDone = true;
    // .reveal-all wins the cascade and drops the transition entirely, so
    // this always lands on opacity:1 regardless of animation state.
    document.documentElement.classList.add("reveal-all");
    Array.prototype.forEach.call(document.querySelectorAll(REVEAL_SELECTOR), function (el) {
      el.classList.add("is-revealed");
      el.style.opacity = "";
      el.style.transform = "";
    });
    if (revealIO) revealIO.disconnect();
  }

  function initReveal() {
    if (revealAllDone) return;
    if (prefersReducedMotion) { revealEverything(); return; }

    var els = document.querySelectorAll(REVEAL_SELECTOR);
    if (!els.length) return;

    if (!("IntersectionObserver" in window)) { revealEverything(); return; }

    // hide, then immediately reveal anything already on screen
    Array.prototype.forEach.call(els, hideEl);

    revealIO = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) {
          showEl(en.target);
          revealIO.unobserve(en.target);
        }
      });
    }, { threshold: 0, rootMargin: "0px 0px -8px 0px" });
    Array.prototype.forEach.call(els, function (el) { revealIO.observe(el); });

    function revealInView() {
      if (revealAllDone) return;
      Array.prototype.forEach.call(els, function (el) {
        if (el.classList.contains("is-revealed")) return;
        var r = el.getBoundingClientRect();
        if (r.top < window.innerHeight && r.bottom > 0) {
          showEl(el);
          revealIO.unobserve(el);
        }
      });
    }
    requestAnimationFrame(revealInView);
    setTimeout(revealInView, 100);
    setTimeout(revealInView, 350);

    // hard safety net: nothing may stay invisible
    setTimeout(revealEverything, 4000);
    window.addEventListener("beforeunload", revealEverything);
  }

  // observe any newly rendered elements (e.g. cards re-rendered by render())
  function observeNew() {
    if (revealAllDone || prefersReducedMotion) return;
    if (!("IntersectionObserver" in window)) { revealEverything(); return; }
    var fresh = document.querySelectorAll(REVEAL_SELECTOR);
    if (!fresh.length) return;
    if (!revealIO) { initReveal(); return; }
    Array.prototype.forEach.call(fresh, function (el) {
      if (el.classList.contains("is-revealed") || el.dataset.revealObserved) return;
      el.dataset.revealObserved = "1";
      if (!el.classList.contains("revealable")) hideEl(el);
      var r = el.getBoundingClientRect();
      if (r.top < window.innerHeight && r.bottom > 0) {
        showEl(el);
        revealIO.unobserve(el);
      } else {
        revealIO.observe(el);
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initReveal);
  } else {
    initReveal();
  }

  /* ---------- back to top ---------- */
  var toTop = document.getElementById("toTop");
  if (toTop) {
    window.addEventListener("scroll", function () {
      if (window.scrollY > 600) toTop.classList.add("show");
      else toTop.classList.remove("show");
    }, { passive: true });
    toTop.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  /* ---------- scroll progress bar ---------- */
  var progress = document.getElementById("progress");
  if (progress) {
    var updateProgress = function () {
      var doc = document.documentElement;
      var scrollable = doc.scrollHeight - doc.clientHeight;
      var pct = scrollable > 0 ? (window.scrollY / scrollable) * 100 : 0;
      progress.style.width = Math.min(100, Math.max(0, pct)).toFixed(2) + "%";
    };
    window.addEventListener("scroll", updateProgress, { passive: true });
    window.addEventListener("resize", updateProgress, { passive: true });
    updateProgress();
  }

  /* ---------- init ---------- */
  if (list && resultCount) {
    buildCuisineSelect();
    buildAreaSelect();

    /* ---------- deep links from article pages (?cat= / ?area=) ---------- */
    (function applyQueryParams() {
      var q;
      try { q = new URLSearchParams(window.location.search); } catch (e) { return; }
      var cat = q.get("cat");
      var area = q.get("area");
      if (cat && CATEGORIES[cat]) {
        state.category = cat;
        cuisineSelect.value = cat;
      }
      if (area) {
        var found = false;
        Array.prototype.forEach.call(areaSelect.options, function (o) {
          if (o.value === area) found = true;
        });
        if (found) {
          state.area = area;
          areaSelect.value = area;
        }
      }
    })();

    render();
  }
})();
