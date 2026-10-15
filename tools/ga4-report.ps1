<#
  tools/ga4-report.ps1
  ---------------------------------------------------------------------------
  Reads GA4 traffic with the GA4 Data API, authenticating as a service account.
  No extra installs: uses Windows PowerShell 5.1 plus the OpenSSL that ships
  with Git for Windows to sign the JWT.

  One-time setup (see the instructions printed by -Help, or AGENTS.md):
    tools/.ga4/key.json        the service-account JSON key you download
    tools/.ga4/property.txt    the numeric GA4 property id, e.g. 123456789

  Both are gitignored, so the private key is never published.

  Usage:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ga4-report.ps1
  Options:
    -Days 28          reporting window
    -Top 10           rows for the detail tables
    -KeyFile <path>   override the key location
    -PropertyId <id>  override the property id
#>
param(
  [string]$KeyFile,
  [string]$PropertyId,
  [int]$Days = 28,
  [int]$Top = 10
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot
$confDir = Join-Path $PSScriptRoot '.ga4'

function Head($s) { Write-Host ''; Write-Host "=== $s ===" }
function Fail($m) { Write-Host "  [FAIL] $m"; exit 1 }

# Read the response body from a failed web request (PowerShell 5.1 safe).
function Get-ErrorBody($err) {
  $text = $null
  try {
    $rs = $err.Exception.Response.GetResponseStream()
    if ($rs) {
      $sr = New-Object System.IO.StreamReader($rs)
      $text = $sr.ReadToEnd()
    }
  } catch { }
  if (-not $text -and $err.ErrorDetails) { $text = $err.ErrorDetails.Message }
  if (-not $text) { $text = $err.Exception.Message }
  return $text
}

# ------------------------------------------------------------- resolve config
if (-not $KeyFile) {
  $def = Join-Path $confDir 'key.json'
  if (Test-Path $def) { $KeyFile = $def }
  else {
    $cand = @(Get-ChildItem -Path $confDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notmatch 'client_secret' })
    if ($cand.Count -eq 1) { $KeyFile = $cand[0].FullName }
  }
}
if (-not $KeyFile -or -not (Test-Path $KeyFile)) {
  Fail @"
service-account key not found.
  Put the downloaded JSON key at: $confDir\key.json
  (See AGENTS.md > "GA4 Data API setup".)
"@
}

if (-not $PropertyId) {
  $pf = Join-Path $confDir 'property.txt'
  if (Test-Path $pf) { $PropertyId = (Get-Content $pf -Raw).Trim() }
}
if (-not $PropertyId) {
  Fail "GA4 property id not set. Create $confDir\property.txt containing the numeric id."
}
$PropertyId = ($PropertyId -replace '^properties/', '').Trim()

# ---------------------------------------------------------------- find openssl
$openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $openssl) {
  foreach ($p in @(
      (Join-Path $env:ProgramFiles 'Git\usr\bin\openssl.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Git\usr\bin\openssl.exe'))) {
    if ($p -and (Test-Path $p)) { $openssl = $p; break }
  }
}
if (-not $openssl) { Fail 'openssl.exe not found. Install Git for Windows (it bundles OpenSSL).' }

# -------------------------------------------------------- read service account
try { $sa = Get-Content $KeyFile -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Fail "could not parse $KeyFile as JSON: $($_.Exception.Message)" }
if (-not $sa.client_email -or -not $sa.private_key) {
  Fail 'JSON is missing client_email / private_key. Is this really a service-account key?'
}
$email = $sa.client_email
$tokenUri = if ($sa.token_uri) { $sa.token_uri } else { 'https://oauth2.googleapis.com/token' }

# ------------------------------------------------------------------ sign JWT
function B64Url([byte[]]$b) {
  [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}
function B64UrlJson($o) {
  B64Url([System.Text.Encoding]::UTF8.GetBytes(($o | ConvertTo-Json -Compress)))
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ga4-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($tmp)
$access = $null
try {
  $pem = Join-Path $tmp 'key.pem'
  [System.IO.File]::WriteAllText($pem, $sa.private_key, (New-Object System.Text.UTF8Encoding($false)))

  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $signingInput = (B64UrlJson @{ alg = 'RS256'; typ = 'JWT' }) + '.' + (B64UrlJson @{
      iss   = $email
      scope = 'https://www.googleapis.com/auth/analytics.readonly'
      aud   = $tokenUri
      iat   = $now
      exp   = $now + 3600
    })

  $inFile = Join-Path $tmp 'in.txt'
  $sigFile = Join-Path $tmp 'sig.bin'
  [System.IO.File]::WriteAllText($inFile, $signingInput, (New-Object System.Text.UTF8Encoding($false)))

  & $openssl dgst -sha256 -sign $pem -out $sigFile $inFile | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail 'openssl failed to sign the JWT.' }

  $jwt = $signingInput + '.' + (B64Url ([System.IO.File]::ReadAllBytes($sigFile)))

  $body = 'grant_type=' + [uri]::EscapeDataString('urn:ietf:params:oauth:grant-type:jwt-bearer') + '&assertion=' + $jwt
  try {
    $tok = Invoke-RestMethod -Uri $tokenUri -Method Post -TimeoutSec 45 `
      -ContentType 'application/x-www-form-urlencoded' -Body $body
  } catch {
    Fail "Google rejected the token request: $(Get-ErrorBody $_)"
  }
  $access = $tok.access_token
  if (-not $access) { Fail 'no access_token returned.' }
}
finally {
  Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------ GA4 calls
$api = "https://analyticsdata.googleapis.com/v1beta/properties/$PropertyId"
$auth = @{ Authorization = "Bearer $access" }

function Invoke-Ga4($method, $payload) {
  $json = $payload | ConvertTo-Json -Depth 8 -Compress
  try {
    return Invoke-RestMethod -Uri "$api`:$method" -Method Post -Headers $auth `
      -ContentType 'application/json; charset=utf-8' -Body $json -TimeoutSec 60
  } catch {
    Fail "GA4 API error ($method): $(Get-ErrorBody $_)"
  }
}

function Show-Rows($resp, [string[]]$cols) {
  if (-not $resp.rows -or $resp.rows.Count -eq 0) { Write-Host '  (no data yet)'; return }
  Write-Host ('  ' + ($cols -join '  '))
  foreach ($row in $resp.rows) {
    $vals = @()
    foreach ($d in $row.dimensionValues) { $vals += $d.value }
    foreach ($m in $row.metricValues) { $vals += $m.value }
    Write-Host ('  ' + (($vals | ForEach-Object { '{0,-16}' -f $_ }) -join ''))
  }
}

Write-Host "Taste of Japan - GA4 report"
Write-Host ("property {0}  |  last {1} days  |  {2}" -f $PropertyId, $Days, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Write-Host "account:  $email"

# 1) headline numbers
Head "Traffic - last $Days days"
$sum = Invoke-Ga4 'runReport' @{
  dateRanges = @(@{ startDate = "$($Days)daysAgo"; endDate = 'today' })
  metrics    = @(
    @{ name = 'activeUsers' }, @{ name = 'newUsers' }, @{ name = 'sessions' },
    @{ name = 'screenPageViews' }, @{ name = 'averageSessionDuration' },
    @{ name = 'engagementRate' }, @{ name = 'screenPageViewsPerSession' }
  )
}
if ($sum.rows -and $sum.rows.Count) {
  $m = $sum.rows[0].metricValues
  Write-Host ("  {0,-26} {1}" -f 'users (active)', $m[0].value)
  Write-Host ("  {0,-26} {1}" -f 'users (new)', $m[1].value)
  Write-Host ("  {0,-26} {1}" -f 'sessions', $m[2].value)
  Write-Host ("  {0,-26} {1}" -f 'page views', $m[3].value)
  Write-Host ("  {0,-26} {1}" -f 'avg session (sec)', ([math]::Round([double]$m[4].value, 1)))
  Write-Host ("  {0,-26} {1}" -f 'engagement rate', ([math]::Round([double]$m[5].value * 100, 1).ToString() + ' %'))
  Write-Host ("  {0,-26} {1}" -f 'pages / session', ([math]::Round([double]$m[6].value, 2)))
} else { Write-Host '  (no data yet)' }

# 2) compare previous equal window
Head "Change vs previous $Days days"
$prev = Invoke-Ga4 'runReport' @{
  dateRanges = @(@{ startDate = "$($Days*2)daysAgo"; endDate = "$($Days+1)daysAgo" })
  metrics    = @(@{ name = 'activeUsers' }, @{ name = 'sessions' }, @{ name = 'screenPageViews' })
}
if ($sum.rows -and $sum.rows.Count -and $prev.rows -and $prev.rows.Count) {
  $cur = $sum.rows[0].metricValues
  $old = $prev.rows[0].metricValues
  $names = @('users (active)', 'sessions', 'page views')
  for ($i = 0; $i -lt 3; $i++) {
    $a = [double]$cur[$i].value; $b = [double]$old[$i].value
    $pct = if ($b -gt 0) { [math]::Round((($a - $b) / $b) * 100, 1) } else { $null }
    $sign = if ($null -eq $pct) { 'n/a' } elseif ($pct -ge 0) { "+$pct%" } else { "$pct%" }
    Write-Host ("  {0,-18} {1,8}  (was {2,8})  {3}" -f $names[$i], $a, $b, $sign)
  }
} else { Write-Host '  (not enough history to compare)' }

# 3) where visitors came from
Head "Traffic sources - last $Days days"
Show-Rows (Invoke-Ga4 'runReport' @{
    dateRanges = @(@{ startDate = "$($Days)daysAgo"; endDate = 'today' })
    dimensions = @(@{ name = 'sessionDefaultChannelGroup' })
    metrics    = @(@{ name = 'sessions' }, @{ name = 'activeUsers' })
    orderBys   = @(@{ metric = @{ metricName = 'sessions' }; desc = $true })
    limit      = $Top
  }) @('channel', 'sessions', 'users')

# 4) top pages
Head "Top pages - last $Days days"
Show-Rows (Invoke-Ga4 'runReport' @{
    dateRanges = @(@{ startDate = "$($Days)daysAgo"; endDate = 'today' })
    dimensions = @(@{ name = 'pagePath' })
    metrics    = @(@{ name = 'screenPageViews' }, @{ name = 'activeUsers' })
    orderBys   = @(@{ metric = @{ metricName = 'screenPageViews' }; desc = $true })
    limit      = $Top
  }) @('page', 'views', 'users')

# 5) countries
Head "Top countries - last $Days days"
Show-Rows (Invoke-Ga4 'runReport' @{
    dateRanges = @(@{ startDate = "$($Days)daysAgo"; endDate = 'today' })
    dimensions = @(@{ name = 'country' })
    metrics    = @(@{ name = 'activeUsers' })
    orderBys   = @(@{ metric = @{ metricName = 'activeUsers' }; desc = $true })
    limit      = $Top
  }) @('country', 'users')

# 6) daily trend
Head "Daily trend - last $Days days"
Show-Rows (Invoke-Ga4 'runReport' @{
    dateRanges = @(@{ startDate = "$($Days)daysAgo"; endDate = 'today' })
    dimensions = @(@{ name = 'date' })
    metrics    = @(@{ name = 'activeUsers' }, @{ name = 'screenPageViews' })
    orderBys   = @(@{ dimension = @{ dimensionName = 'date' } })
  }) @('date', 'users', 'views')

# 7) right now
Head 'Active right now'
try {
  $rt = Invoke-Ga4 'runRealtimeReport' @{ metrics = @(@{ name = 'activeUsers' }) }
  $n = if ($rt.rows -and $rt.rows.Count) { $rt.rows[0].metricValues[0].value } else { '0' }
  Write-Host "  $n user(s) on the site in the last 30 minutes"
} catch { Write-Host '  (realtime unavailable)' }

Write-Host ''
Write-Host 'done.'
