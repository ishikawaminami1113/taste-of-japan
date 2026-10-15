---
description: Site health, GA4 popularity, verified improvements, publish, report
---

Run the playbook defined in `AGENTS.md` end to end, without asking first. Then report in
short, plain Japanese.

1. Read the site-check output below, and also run `tools/ga4-report.ps1 -Days 28` for real
   GA4 traffic. If GA4 is not configured yet, say so plainly and fall back to the Bing
   visibility signal from the check output.
2. Decide the single highest-value change you can fully verify (suggestions are listed in
   `AGENTS.md`). Never fabricate data to have something to do — if nothing needs fixing,
   say so.
3. Make the change locally, then verify **every** page at `http://127.0.0.1:8000/`
   (start the local server with `.\serve.ps1` if it is not running):
   Lighthouse 100/100/100, zero failing audits, zero console errors.
4. Re-run `tools/site-check.ps1` to confirm local references still resolve.
5. Publish. Assets are versioned **in the filename** because Cloudflare ignores query
   strings: copy the edited original to the next version name, update every HTML
   reference, delete the old versioned file. Update `sitemap.xml` `lastmod` if content
   changed. Commit, push with the PAT, then reset the remote URL to the token-free form.
6. Submit changed URLs to IndexNow, confirm the live site, and report in Japanese.

Site check output:

!`powershell -NoProfile -ExecutionPolicy Bypass -File tools/site-check.ps1`
