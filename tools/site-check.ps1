# Taste of Japan - one-shot site health & visibility report
# ---------------------------------------------------------------------------
# Run this to gather every measurable signal in a single pass, with no login.
# It is intentionally ASCII-only: Windows PowerShell 5.1 reads BOM-less
# script files as ANSI, so non-ASCII text here would be corrupted.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\site-check.ps1
#
# Options:
#   -Quick       skip the slower live-page sweep (infra + repo only)
#   -TimeoutSec  per-request timeout, default 25
# ---------------------------------------------------------------------------
param(
  [switch]$Quick,
  [int]$TimeoutSec = 25
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$root = $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'index.html'))) {
  $root = Split-Path -Parent $PSScriptRoot
}
$site = 'https://ofjapantaste.com'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
$H = @{ 'Accept-Language' = 'en-US,en;q=0.9' }
$script:issues = New-Object System.Collections.ArrayList

function Head($s) { Write-Host ''; Write-Host "=== $s ===" }
function OK($s)   { Write-Host "  [ok]   $s" }
function Warn($s) { Write-Host "  [warn] $s"; [void]$script:issues.Add($s) }
function Bad($s)  { Write-Host "  [FAIL] $s"; [void]$script:issues.Add($s) }
function Info($s) { Write-Host "         $s" }

function Get-Url($url) {
  try {
    return Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -UserAgent $ua -Headers $H
  } catch {
    return $null
  }
}

Write-Host "Taste of Japan - site check"
Write-Host ("{0}  (project: {1})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $root)

# ---------------------------------------------------------------- repo state
Head 'Repository'
$head = (& git -C $root log --oneline -1 2>$null)
if ($head) { Ok "HEAD: $head" } else { Warn 'git log unavailable' }
$dirty = @(& git -C $root status --porcelain 2>$null)
if ($dirty.Count -eq 0) { OK 'working tree clean' }
else {
  Warn ("uncommitted changes: {0} file(s)" -f $dirty.Count)
  $dirty | Select-Object -First 8 | ForEach-Object { Info $_ }
}
$remote = (& git -C $root remote get-url origin 2>$null)
if ($remote) {
  if ($remote -match 'x-access-token') { Warn 'origin remote still contains a token (must be reset)' }
  else { OK "origin: $remote" }
}

# ------------------------------------------------------------- local server
Head 'Local preview server'
$localUp = $false
try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/' -UseBasicParsing -TimeoutSec 5
  if ($r.StatusCode -eq 200) { $localUp = $true }
} catch { }
if ($localUp) { OK 'http://127.0.0.1:8000/ responds' }
else { Info 'not running (start with: powershell -NoProfile -ExecutionPolicy Bypass -File .\serve.ps1)' }

# ------------------------------------------------------- local file integrity
Head 'Local files'
$htmlFiles = @(Get-ChildItem -Path $root -Filter *.html -File | Sort-Object Name)
OK ("{0} html pages" -f $htmlFiles.Count)

# UTF-8 corruption check (U+FFFD replacement char)
$assetFiles = @(Get-ChildItem -Path "$root\css","$root\js" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in '.css', '.js' })
$badEnc = 0
foreach ($f in ($htmlFiles + $assetFiles)) {
  $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
  $badEnc += ([regex]::Matches($txt, [char]0xFFFD)).Count
}
if ($badEnc -eq 0) { OK 'no UTF-8 replacement characters' } else { Bad "UTF-8 corruption: $badEnc replacement chars" }

# Broken local references (href/src to missing files)
$broken = New-Object System.Collections.ArrayList
foreach ($f in $htmlFiles) {
  $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($txt, '(?:href|src)="([^"#:?][^":]*\.(?:html|css|js|jpg|jpeg|png|svg|xml|txt|ico))"')) {
    $rel = $m.Groups[1].Value.TrimStart('/').Replace('/', '\')
    $target = Join-Path $root $rel
    if (-not (Test-Path -Path $target -PathType Leaf)) {
      [void]$broken.Add(("{0} -> {1}" -f $f.Name, $m.Groups[1].Value))
    }
  }
}
if ($broken.Count -eq 0) { OK 'all local css/js/img/html references resolve' }
else { Bad ("broken local references: {0}" -f $broken.Count); $broken | Select-Object -Unique | ForEach-Object { Info $_ } }

# sitemap / robots / feed present and sane
$sitemap = Join-Path $root 'sitemap.xml'
$sitemapUrls = @()
if (Test-Path $sitemap) {
  $sm = [System.IO.File]::ReadAllText($sitemap, [System.Text.Encoding]::UTF8)
  $sitemapUrls = @([regex]::Matches($sm, '<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value })
  OK ("sitemap.xml: {0} urls" -f $sitemapUrls.Count)
} else { Bad 'sitemap.xml missing' }

foreach ($f in @('robots.txt','feed.xml','ads.txt','CNAME')) {
  if (Test-Path (Join-Path $root $f)) { OK "$f present" } else { Warn "$f missing" }
}
if (Test-Path (Join-Path $root 'robots.txt')) {
  $rb = [System.IO.File]::ReadAllText((Join-Path $root 'robots.txt'), [System.Text.Encoding]::UTF8)
  if ($rb -match 'Sitemap:') { OK 'robots.txt declares the sitemap' } else { Warn 'robots.txt has no Sitemap line' }
}

# GA4 may be configured inside the external analytics script, not inline.
$analyticsFiles = @(Get-ChildItem -Path (Join-Path $root 'js') -Filter 'analytics*.js' -File -ErrorAction SilentlyContinue)
$analyticsHasId = $false
$analyticsId = ''
foreach ($af in $analyticsFiles) {
  $aj = [System.IO.File]::ReadAllText($af.FullName, [System.Text.Encoding]::UTF8)
  $am = [regex]::Match($aj, 'GA4_MEASUREMENT_ID\s*=\s*"([^"]*)"')
  if ($am.Success -and $am.Groups[1].Value -match '^G-[A-Z0-9]{6,}$') {
    $analyticsHasId = $true
    $analyticsId = $am.Groups[1].Value
  }
}
if ($analyticsHasId) { OK "GA4 measurement id configured: $analyticsId" }
else { Warn 'GA4_MEASUREMENT_ID is empty or unset in js/analytics*.js' }

# ------------------------------------------------------------- live checks
if (-not $Quick) {
  Head 'Live pages (deployed)'
  $liveUrls = if ($sitemapUrls.Count) { $sitemapUrls } else { @("$site/") }
  foreach ($u in $liveUrls) {
    $r = Get-Url $u
    $name = $u -replace [regex]::Escape($site), ''
    if (-not $name) { $name = '/' }
    if (-not $r) { Bad "$name - unreachable"; continue }
    if ($r.StatusCode -ne 200) { Bad "$name - HTTP $($r.StatusCode)"; continue }
    $c = $r.Content
    $css = ([regex]::Match($c, '(?:styles[^"]*?)\.css')).Value
    $mj  = ([regex]::Match($c, '(main[^"]*?)\.js')).Value
    $hasAnalyticsRef = $c -match 'analytics[^"]*\.js'
    $ga4 = if (($c -match 'G-[A-Z0-9]{10}') -or ($hasAnalyticsRef -and $analyticsHasId)) { 'ga4' } else { 'no-ga4' }
    $noindex = if ($c -match 'name="robots"[^>]*noindex') { ' NOINDEX!' } else { '' }
    $canon = if ($c -match 'rel="canonical"') { 'canonical' } else { 'NO-CANONICAL' }
    $flags = @()
    if ($ga4 -eq 'no-ga4') { $flags += 'no-ga4' }
    if ($noindex) { $flags += 'NOINDEX' }
    if ($canon -eq 'NO-CANONICAL') { $flags += 'no-canonical' }
    $tag = if ($flags.Count) { '[warn]' } else { '[ok]' }
    Write-Host ("  {0,-7} {1,-26} 200  {2,-22} {3,-14} {4}" -f $tag, $name, $css, $mj, ($flags -join ','))
    if ($flags.Count) { [void]$script:issues.Add("$name : $($flags -join ',')") }
  }

  Head 'Live infrastructure'
  foreach ($path in @('/robots.txt','/sitemap.xml','/feed.xml','/ads.txt','/toj6fac6cac677d48d1.txt','/404.html')) {
    $r = Get-Url ($site + $path)
    if ($r -and $r.StatusCode -eq 200) { OK "$path 200" } else { Bad "$path not served" }
  }
  $feed = Get-Url "$site/feed.xml"
  if ($feed) {
    try { [void][xml]$feed.Content; OK 'feed.xml is valid XML' }
    catch { Bad 'feed.xml is not valid XML' }
  }

  Head 'Search visibility (no login)'
  $bing = Get-Url ('https://www.bing.com/search?q=site%3Aofjapantaste.com&count=30')
  if ($bing) {
    $noRes = ($bing.Content -match 'There are no results|did not match any')
    if ($noRes) {
      Warn 'Bing: site: query returns NO indexed pages'
      Info 'action: re-submit sitemap to Bing + IndexNow, then allow a few days'
    } else {
      $cnt = ([regex]::Matches($bing.Content, 'ofjapantaste\.com')).Count
      OK "Bing: domain appears in results ($cnt mentions)"
    }
  } else { Info 'Bing probe blocked/unavailable' }
  Info 'for real traffic numbers, see AGENTS.md > "Popularity data"'
}

# ------------------------------------------------------------------ summary
Head 'Summary'
if ($script:issues.Count -eq 0) {
  Write-Host '  All checks passed.'
} else {
  Write-Host ("  {0} item(s) need attention:" -f $script:issues.Count)
  $script:issues | ForEach-Object { Write-Host "   - $_" }
}
