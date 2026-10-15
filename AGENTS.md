# Taste of Japan — project instructions

## What this is
An English-language guide to Japanese restaurants for international visitors.
- **Live:** https://ofjapantaste.com  ·  **Repo:** `github.com/ishikawaminami1113/taste-of-japan` (branch `main`)
- **Hosting:** GitHub Pages + custom domain, DNS through Cloudflare (proxied, SSL Flexible).
- **Stack:** static, no build step. Plain HTML / CSS / JS edited directly.
- **Language:** always answer the user in **Japanese**, short and plain.

## Hard rules
1. **Never invent facts.** No dummy data, no placeholder copy, no invented reviews,
   prices, ratings or awards. Verify against public sources; if unsure, omit it or say so.
2. **Never use `Set-Content` / `Out-File` on text here** — they corrupt UTF-8 on this
   machine. Use the `edit` / `write` tools, or
   `[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))`.
3. Keep the design photo-led, calm and hand-made. Avoid an AI-template look.
4. Prefer many small verified improvements over one big speculative rewrite.

## File map
- `index.html` — homepage (hero, food guide, 33 restaurant cards, filters, FAQ, phrasebook)
- `tokyo-areas.html` `eat-in-japan.html` `budget.html` `seasonal.html` `vegetarian.html` — articles
- `about.html` `privacy.html` `404.html`
- `js/data.js` — `RESTAURANTS` (33), `CATEGORIES`, `FOOD_GUIDE`, `AREAS` — **source of truth for all content**
- `js/main.js` — rendering, filters, sort, favourites, deep links, scroll reveal, progress bar
- `js/analytics.js` — GA4 (`G-M431X9CSS7`); optional Microsoft Clarity
- `css/styles.css` — all styling
- `sitemap.xml` `robots.txt` `feed.xml` `ads.txt` `CNAME` `toj6fac6cac677d48d1.txt` (IndexNow key)
- `serve.ps1` — local preview server (port 8000)
- `tools/site-check.ps1` — one-shot health & visibility report
- `tools/ga4-report.ps1` — GA4 traffic report (service account; see below)
- `tools/.ga4/` — **gitignored**: `key.json` (service-account key) + `property.txt`
- `PROJECT_BACKUP.md` — full project documentation

## Cache busting (important)
Cloudflare **ignores query strings** (`?v=13`) and keeps serving stale files, and the
Cloudflare token has **no cache-purge permission**. Assets are therefore versioned
**in the filename**:
`css/styles-v18.css`, `js/main-v14.js`, `js/data-v14.js`, `js/analytics-v14.js`.
The unversioned originals (`styles.css`, `main.js`, …) stay in the repo as the source
of truth. **When you change an asset:**
1. edit the original file (e.g. `js/main.js`)
2. copy it to the next version name (e.g. `js/main-v15.js`)
3. update every HTML reference to the new name
4. delete the old versioned file

Never rely on `?v=`.

## Verify before every push
Target: **Lighthouse 100/100/100** (accessibility, best-practices, SEO) with **zero failing
audits and zero console errors** on every page.
- Local server: `powershell -NoProfile -ExecutionPolicy Bypass -File .\serve.ps1` (port 8000)
- Audit at a plain URL: `http://127.0.0.1:8000/` (no query string)
- `tools/site-check.ps1` for health + visibility
- Lighthouse per page with the browser tool

## Publishing (PAT push)
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Set-Location "C:\Users\mishi\OneDrive\ドキュメント\デフォルトプロジェクト"
git add -A
git commit -m "<message>"
git remote set-url origin "https://x-access-token:<TOKEN>@github.com/ishikawaminami1113/taste-of-japan.git"
git push origin main
git remote set-url origin "https://github.com/ishikawaminami1113/taste-of-japan.git"
```
Always reset the remote URL back to the token-free form afterwards.
The token lives in the previous session context (`github_pat_...`); ask if it is missing.

## IndexNow (submit changed URLs to Bing after a push)
```powershell
Invoke-WebRequest -Uri "https://api.indexnow.org/indexnow?url=https://ofjapantaste.com/&key=toj6fac6cac677d48d1" -UseBasicParsing
```
A `202 Accepted` means it worked. Repeat for each changed URL.

---

## Playbook: "サイトの人気どうなった？今できることを考えてやっておいて"
When the user sends this sentence (or anything close), run this checklist without
asking for permission first, then report in Japanese.

1. **Gather** — run `tools/site-check.ps1` and read the output.
2. **Popularity** — run `tools/ga4-report.ps1` (real GA4 traffic, once set up — see
   "GA4 Data API setup"). If it is not configured yet, fall back to the visibility signal
   from `site-check.ps1` and say plainly which numbers still need a login.
3. **Decide & act** — pick the highest-value fix you can fully verify, for example:
   - verify a few restaurant facts (prices, hours, ratings, awards) against public sources
     and correct `js/data.js`
   - fix any page that fails Lighthouse
   - add or improve genuinely useful content (a new area, allergy/phrase section)
   - submit changed URLs to IndexNow; re-sync `sitemap.xml` `lastmod`
   - tighten metadata / internal links
   Do **not** fabricate anything to have something to do. If nothing needs fixing, say so.
4. **Verify** — Lighthouse 100/100/100 + zero console errors on all pages.
5. **Publish** — bump the asset version, commit, push, then confirm the live site.
6. **Report** — short Japanese summary: what you found, what you changed, what you could
   not check (and why).

## Popularity data
Real traffic/revenue numbers need a login, which the agent's browser does **not** have:

| Source | Status |
| --- | --- |
| GA4 traffic | **Automatable** via `tools/ga4-report.ps1` (service account) |
| Bing `site:` query | **Automatable** — used by `site-check.ps1` as the visibility probe |
| Google Search Console | needs the user's logged-in browser |
| AdSense revenue | needs the user's logged-in browser |
| Cloudflare Web Analytics | token lacks account analytics permission |

If a needed number cannot be read automatically, ask the user to paste a screenshot.

## GA4 Data API setup (one time, ~10 minutes)
The user does this in the browser; the agent cannot (it needs their Google login).

1. Go to <https://console.cloud.google.com/> and create (or pick) a project.
2. **APIs & Services → Library** → search **"Google Analytics Data API"** → **Enable**.
3. **IAM & Admin → Service Accounts → Create service account**
   - Name it e.g. `ga4-reader`, click **Create and continue**, then **Done**.
   - (No project-level role is needed.)
4. Open the new service account → **Keys** tab → **Add key → Create new key → JSON**.
   The JSON file downloads.
5. Move that file to `tools/.ga4/key.json` (create the folder). It is gitignored —
   **never commit it**.
6. Copy the service-account email (`...@....iam.gserviceaccount.com`).
7. In GA4: **Admin → (Property) → Property access management → Add users** →
   paste that email, role **Viewer** (uncheck "Notify by email") → **Add**.
8. In GA4: **Admin → Property settings** → copy the numeric **Property ID**.
   Put it in `tools/.ga4/property.txt` (just the number, e.g. `123456789`).
9. Test:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ga4-report.ps1
   ```
   A traffic report means it works. `invalid_grant: account not found` means step 5 or 7
   was missed; `PERMISSION_DENIED` means step 7 was missed.

The scripting itself needs no installs: `ga4-report.ps1` signs the JWT with the OpenSSL
that ships with Git for Windows.

`/site-status` runs this playbook as a slash command.
