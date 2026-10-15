<#
  tools/ga4-setup.ps1
  ---------------------------------------------------------------------------
  One-time GA4 Data API setup helper.

  What this does for you: everything except the Google clicking. It opens each
  Google page in your normal browser (where you are already logged in), waits
  for you, then automatically detects the downloaded service-account key and
  puts it in the right place, saves the property id, and runs a live test.

  Usage (in a normal terminal, NOT from inside an agent):
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ga4-setup.ps1

  Total clicks needed: about 6, plus pasting one number.
  ---------------------------------------------------------------------------
#>
param()

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot
$confDir = Join-Path $PSScriptRoot '.ga4'
$keyFile = Join-Path $confDir 'key.json'
$propFile = Join-Path $confDir 'property.txt'
$downloads = Join-Path $env:USERPROFILE 'Downloads'
[void][System.IO.Directory]::CreateDirectory($confDir)

function Line { Write-Host '' }
function Ok($m)   { Write-Host "  [done] $m" }
function Todo($m) { Write-Host "  >>     $m" }
function Note($m) { Write-Host "         $m" }
function Open-Page($url) { Start-Process $url | Out-Null }
function Press-Key($msg) {
  Write-Host ''
  Write-Host "  $msg"
  Write-Host '  Press ENTER when that is done...' -NoNewline
  $null = Read-Host
}

$done = Test-Path $propFile
if ($done -and (Test-Path $keyFile)) {
  Write-Host 'Already configured. To redo it, delete tools\.ga4 and run this again.'
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ga4-report.ps1')
  exit 0
}

Write-Host ''
Write-Host 'GA4 Data API setup'
Write-Host '=================='
Write-Host 'This script opens the Google pages for you. Do the clicks, and it handles'
Write-Host 'the files and the test at the end.'
Line

# ---------------------------------------------------------------- step 0: plan
Write-Host 'Which property do you want to read?'
Write-Host '  In GA4, open  Admin > Property settings  and read the numeric Property ID.'
Write-Host '  You will paste it at the end. Have the GA4 tab open in your browser.'
Line
Press-Key 'Ready?'

# ------------------------------------------------- step 1: enable the Data API
Write-Host ''
Write-Host 'STEP 1 - Enable the Google Analytics Data API'
Todo 'Opening the API library page now.'
Note 'If you have several projects, pick the one that owns the GA4 property'
Note 'from the project picker at the top, then click the blue  Enable  button.'
Open-Page 'https://console.cloud.google.com/apis/library/analyticsdata.googleapis.com'
Press-Key 'The button should now say  API enabled  or  Manage .'

# ------------------------------------------- step 2: create the service account
Write-Host ''
Write-Host 'STEP 2 - Create a service account'
Todo 'Opening the Service Accounts page now.'
Note 'Click  + CREATE SERVICE ACCOUNT , name it  ga4-reader , then  CREATE AND CONTINUE .'
Note 'The role step can be skipped: click  CONTINUE , then  DONE .'
Open-Page 'https://console.cloud.google.com/iam-admin/serviceaccounts'
Press-Key 'The new service account is listed.'

# --------------------------------------------- step 3: create the JSON key
Write-Host ''
Write-Host 'STEP 3 - Create the JSON key'
Todo 'Open the  ga4-reader  service account you just made.'
Note 'Go to the  KEYS  tab, then  ADD KEY > Create new key > JSON > CREATE .'
Note 'A .json file downloads to your Downloads folder. Do not rename or move it.'
Open-Page 'https://console.cloud.google.com/iam-admin/serviceaccounts'
Press-Key 'The .json key has downloaded.'

# ------------------------------------------------------ step 4: grab the key
Write-Host ''
Write-Host 'STEP 4 - Install the key (automatic)'
$before = @(Get-ChildItem -Path $downloads -Filter *.json -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$found = $null
for ($i = 0; $i -lt 90 -and -not $found; $i++) {
  $new = Get-ChildItem -Path $downloads -Filter *.json -File -ErrorAction SilentlyContinue | Where-Object {
    ($before -notcontains $_.FullName) -and $_.Name -notmatch '^~|\.crdownload$'
  } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($new) {
    $len1 = $new.Length
    Start-Sleep -Milliseconds 700
    $recheck = Get-Item $new.FullName -ErrorAction SilentlyContinue
    if ($recheck -and $recheck.Length -eq $len1) { $found = $recheck }
  }
  if (-not $found) { Start-Sleep -Milliseconds 700 }
}

if (-not $found) {
  Note 'Could not spot a new .json automatically. Drag the file onto this window, or type its full path:'
  $p = Read-Host '  path'
  if (-not (Test-Path $p)) { Write-Host '  [FAIL] that path does not exist. Run this script again.'; exit 1 }
  $found = Get-Item $p
}

Copy-Item -LiteralPath $found.FullName -Destination $keyFile -Force
Ok "key installed at $keyFile"

# sanity check the key file
try {
  $sa = Get-Content $keyFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $sa.client_email) { throw 'no client_email' }
  if (-not $sa.private_key) { throw 'no private_key' }
  Ok 'key looks valid'
} catch {
  Write-Host "  [FAIL] that file is not a Google service-account key: $($_.Exception.Message)"
  Remove-Item $keyFile -Force -ErrorAction SilentlyContinue
  exit 1
}

Line
Note 'You need these two values in the next step:'
Write-Host "  service account email : $($sa.client_email)"

# --------------------------------- step 5: grant the service account access
Write-Host ''
Write-Host 'STEP 5 - Give the service account read access to GA4'
Todo 'Opening GA4 now. In the GA4 tab:'
Note '  Admin  >  Property access management  >  Add users  >'
Note "  paste exactly:  $($sa.client_email)"
Note '  choose  Viewer  (leave  Notify by email  unchecked)  >  Add .'
Open-Page 'https://analytics.google.com/'
Press-Key 'The email has been added as a Viewer.'

# --------------------------------------------------- step 6: the property id
Write-Host ''
Write-Host 'STEP 6 - Save the property id'
while ($true) {
  $propId = (Read-Host '  Paste the numeric GA4 Property ID').Trim()
  $propId = ($propId -replace '^properties/', '').Trim()
  if ($propId -match '^\d{6,}$') { break }
  Note "That does not look like a property id. It is just digits, e.g. 123456789."
}
[System.IO.File]::WriteAllText($propFile, $propId, (New-Object System.Text.UTF8Encoding($false)))
Ok "property id saved: $propId"

# ------------------------------------------------------------- step 7: test
Write-Host ''
Write-Host 'STEP 7 - Verify it works'
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ga4-report.ps1') 2>&1
$out | ForEach-Object { Write-Host "  $_" }

if ($out -match '\[FAIL\]') {
  Write-Host ''
  Write-Host '  Something is off. Common causes:'
  Write-Host '    invalid_grant: account not found  -> step 5 was not completed'
  Write-Host '    PERMISSION_DENIED                -> the service account is not a Viewer'
  Write-Host '    key not found                    -> the .json went somewhere unexpected'
  exit 1
}

Write-Host ''
Ok 'GA4 is now automated. From now on the agent can read traffic directly with:'
Write-Host '    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ga4-report.ps1'
Write-Host '  or by running /site.'
