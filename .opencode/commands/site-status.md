---
description: Check site health + popularity, then make verified improvements and publish
---

Run the playbook "サイトの人気どうなった？今できることを考えてやっておいて" defined in
`AGENTS.md`, end to end and without asking first:

1. Read the site-check output below (and re-run `tools/site-check.ps1` if it is missing).
2. Report whatever popularity/visibility signal is actually available, and say plainly
   what needs a login to read.
3. Do the single highest-value change you can fully verify. Never fabricate data to have
   something to do; if nothing needs fixing, say so.
4. Verify Lighthouse 100/100/100 and zero console errors on every page.
5. Bump the asset version, commit, push, confirm the live site, and submit changed URLs
   to IndexNow.
6. Report in short, plain Japanese.

Site check output:

!`powershell -NoProfile -ExecutionPolicy Bypass -File tools/site-check.ps1`
