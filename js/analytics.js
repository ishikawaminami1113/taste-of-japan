/* ============================================================
   Site analytics — free, privacy-friendly
   ============================================================
   How to enable either tracker:
     1. Google Analytics 4 : create a property at
        https://analytics.google.com  ->  Admin -> Data streams
        -> Web -> paste https://ofjapantaste.com -> copy the
        "Measurement ID" (looks like G-XXXXXXXXXX) and paste it
        below. Free, connects to AdSense for revenue tracking.
     2. Microsoft Clarity (free heatmaps + session replay, no
        cookies): sign in at https://clarity.microsoft.com,
        create a project for https://ofjapantaste.com, copy the
        Project ID (looks like 8a9b7c6d) and paste it below.
   Leave either ID empty (default) to keep that tracker disabled.
   ============================================================ */
(function () {
  "use strict";

  // ---- edit these two IDs to activate a tracker ----
  var GA4_MEASUREMENT_ID = "";   // e.g. "G-ABC123DEF4"
  var CLARITY_PROJECT_ID  = "";   // e.g. "abc1def2g3"

  // ---- Google Analytics 4 (loads only if GA4_MEASUREMENT_ID is set) ----
  if (GA4_MEASUREMENT_ID) {
    var gtagScript = document.createElement("script");
    gtagScript.async = true;
    gtagScript.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(GA4_MEASUREMENT_ID);
    document.head.appendChild(gtagScript);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag("js", new Date());
    // anonymize_ip = true keeps things privacy-friendly even on EU visitors
    window.gtag("config", GA4_MEASUREMENT_ID, { anonymize_ip: true, send_page_view: true });
  }

  // ---- Microsoft Clarity (loads only if CLARITY_PROJECT_ID is set) ----
  if (CLARITY_PROJECT_ID) {
    (function (c, l, a, r, i, t, y) {
      c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
      t = l.createElement(r);
      t.async = 1;
      t.src = "https://www.clarity.ms/tag/" + i;
      y = l.getElementsByTagName(r)[0];
      y.parentNode.insertBefore(t, y);
    })(window, document, "clarity", "script", CLARITY_PROJECT_ID);
  }

  // ---- Cloudflare Web Analytics (no code needed: enable ON/OFF) ----
  // Because this site is proxied through Cloudflare (orange cloud) and the
  // domain is registered in the same Cloudflare account, Web Analytics can be
  // turned on with a dashboard toggle:
  //   Cloudflare Dashboard -> Analytics -> Web Analytics -> Add site
  //     -> choose ofjapantaste.com  (auto-injected when proxied, or copy the
  //        provided snippet). Cookieless, GDPR-friendly, zero extra cost.
  // No <script> tag is required here for that path.
})();
