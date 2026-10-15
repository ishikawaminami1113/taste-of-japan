# Taste of Japan - Complete Project Backup
# Generated: 2026-10-15
# Status: All pages Lighthouse 100/100/100, 0 failures

## Project Structure
- GitHub Repository: ishikawaminami1113/taste-of-japan (main)
- Live URL: https://ofjapantaste.com/
- Custom Domain: ofjapantaste.com (Cloudflare DNS + Proxy ON)
- SSL: Flexible via Cloudflare

## Restaurant Data (33 stores)
All data stored in: js/data.js

### Area Distribution (18 areas, 33 stores):
- Ginza: 9 restaurants
- Shinjuku: 6 restaurants  
- Shibuya: 2 restaurants
- Ebisu: 2 restaurants
- Toyosu: 1 restaurant
- Roppongi: 1 restaurant
- Jimbocho: 1 restaurant
- Nihonbashi: 1 restaurant
- Nishi-Azabu: 1 restaurant
- Harajuku: 1 restaurant
- Akihabara: 1 restaurant
- Ikebukuro: 1 restaurant
- Akasaka: 1 restaurant
- Azabu-Juban: 1 restaurant
- Daikanyama: 1 restaurant
- Ebisu: 1 restaurant
- Ningyocho: 1 restaurant
- Tsukishima: 1 restaurant
- Yoyogi-Uehara: 1 restaurant

### Category Distribution (10 categories):
- sushi: 5 restaurants
- ramen: 4 restaurants
- izakaya: 3 restaurants
- tempura: 1 restaurant
- wagyu: 4 restaurants
- soba: 3 restaurants
- kaiseki: 1 restaurant
- cafe: 3 restaurants
- okonomiyaki: 3 restaurants
- curry: 1 restaurant

## New Articles (5 pages)
1. **tokyo-areas.html** - 18-neighborhood guide with per-area restaurant links
   - Deep-linking via `?area=XX` URL parameter
   - JSON-LD Article schema

2. **eat-in-japan.html** - First-timer's guide to dining in Japan
   - Covering: choosing a spot, ordering without Japanese, manners, paying
   - JSON-LD Article schema

3. **budget.html** - Eating well in Tokyo on a budget
   - Price bands: $ (under ¥1,000), $$ (¥1,000-3,000), $$$ (¥3,000+)
   - JSON-LD Article schema

4. **seasonal.html** - What to eat in Japan by season
   - Spring (bamboo shoots, sakura mochi), Summer (unagi, cold noodles)
   - Autumn (sanma, matsutake), Winter (oden, fugu)
   - JSON-LD Article schema

5. **vegetarian.html** - Vegetarian & Vegan dining in Tokyo
   - The dashi issue explained
   - Communication phrases in Japanese
   - Naturally plant-based options
   - JSON-LD Article schema

## Technical Configuration

### Lighthouse Results (all 9 pages):
- Accessibility: 100/100
- Best Practices: 100/100
- SEO: 100/100
- Failures: 0

### Image Optimization:
- 12 content images with explicit width/height attributes
- Total size: 902 KB (optimized from 956 KB)
- OGP images: 5 pieces (1200x630, 138-169 KB each)

### SEO Foundation:
- Sitemap.xml: 8 URLs (lastmod: 2026-10-14)
- robots.txt: Allow all, point to sitemap
- Canonical tags: All pages
- OGP tags: All pages (root + 5 article-specific)
- Twitter cards: summary_large_image
- JSON-LD: WebSite + FAQPage + 5 Article schemas

### Analytics:
- Cloudflare Web Analytics: Enabled (automatic injection)
- Google Analytics 4: Not configured (requires manual ID)
- Microsoft Clarity: Not configured (requires manual ID)

### Cloudflare Settings:
- DNS: ofjapantaste.com (orange cloud = proxied)
- Custom Domain: ✅ Active
- HTTPS: Flexible
- Web Analytics: ✅ Active (automatic injection)

## Files Created/Modified (git status):
### New Files (7):
- tokyo-areas.html (18-area guide)
- eat-in-japan.html (first-timer guide)
- budget.html (budget guide)
- seasonal.html (seasonal guide)
- vegetarian.html (vegetarian guide)
- 404.html (custom error page)
- feed.xml (RSS feed)

### Modified HTML Files (9):
- index.html (33 restaurants, new nav links)
- about.html (nav links updated)
- privacy.html (nav links updated)
- tokyo-areas.html (nav + article content)
- eat-in-japan.html (article content + nav)
- budget.html (article content + nav)
- seasonal.html (article content + nav)
- vegetarian.html (article content + nav)
- sitemap.xml (8 URLs)

### Modified CSS (1):
- css/styles.css (width/height attributes, article styles, analytics script)

### Modified JS (2):
- js/main.js (deep link ?cat/ ?area support, article page guards)
- js/data.js (7 new restaurants, 7 new areas)

### Modified Images (12):
- img/art-areas.jpg, img/art-dining.jpg (new article images)
- img/og-areas.jpg, img/og-budget.jpg, img/og-dining.jpg, img/og-seasonal.jpg, img/og-vegetarian.jpg (OGP images)
- img/cat-*.jpg (10 food-category icons, width/height added)
- img/sec-sushibar.jpg, img/sec-lanterns.jpg (section photos)

### Git Commits (3):
1. a9d4371 - Grow to 33 restaurants, add 3 articles, 404 page, RSS feed, and per-article OGP images
2. eddc20b - Add explicit width/height attributes to all content images
3. 744e9da - Wire free privacy-friendly analytics (js/analytics.js)

## Backup Location
- Local: C:\Users\mishi\OneDrive\ドキュメント\デフォルトプロジェクト\
- Git: https://github.com/ishikawaminami1113/taste-of-japan
- Remote: GitHub Pages at https://ofjapantaste.com/

## Known Limitations
- AdSense: Review status unknown (requires manual login at https://adsense.google.com/)
- Search Console: Index submission requires manual operation at https://search.google.com/search-console/
- GA4 / Clarity IDs: Not configured (require manual setup)

## Last Verified
- Lighthouse: All 9 pages 100/100/100, 0 failures (2026-10-15)
- Live site: All URLs 200 OK (2026-10-15)
- Cloudflare Analytics: Active (2026-10-15)
- IndexNow: 8 URLs submitted (2026-10-15)