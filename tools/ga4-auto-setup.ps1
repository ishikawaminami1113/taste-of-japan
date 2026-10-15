<#
  tools/ga4-auto-setup.ps1
  ---------------------------------------------------------------------------
  Fully automated GA4 Data API setup.

  How it works: it copies your Chrome profile (which holds your Google
  session), starts Chrome on that copy with the DevTools Protocol open, and
  drives Google Cloud Shell with gcloud to create the service-account key.
  It reads the key straight out of the terminal, so nothing is downloaded
  and no credentials ever touch the clipboard or a file you have to find.

  The ONLY thing you do: sign in to Google in your normal Chrome once.
  Run this script and it will tell you if that step is still missing.

  Usage (in your own terminal):
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\ga4-auto-setup.ps1

  Safe by construction: the live profile is only ever copied, never written
  to; the throwaway Chrome is killed at the end; the key is written directly
  to tools\.ga4\key.json, which .gitignore protects from being published.
  ---------------------------------------------------------------------------
#>
param(
  [int]$Port = 9222,
  [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot
$confDir = Join-Path $PSScriptRoot '.ga4'
$keyFile = Join-Path $confDir 'key.json'
$propFile = Join-Path $confDir 'property.txt'
[void][System.IO.Directory]::CreateDirectory($confDir)

function Say($m) { Write-Host ''; Write-Host ("== " + $m) }
function Ok($m)   { Write-Host "   [ok]   $m" }
function Todo($m) { Write-Host "   [todo] $m" }
function Warn($m) { Write-Host "   [warn] $m" }
function Err($m)  { Write-Host "   [FAIL] $m" }

# --------------------------------------------------------------------------
# Minimal Chrome DevTools Protocol client (no external dependencies).
# --------------------------------------------------------------------------
class Cdp {
  [System.Net.WebSockets.ClientWebSocket]$ws
  [int]$seq = 0
  hidden [System.Threading.CancellationToken]$ct

  Cdp([string]$url) {
    $this.ct = [System.Threading.CancellationToken]::None
    $this.ws = New-Object System.Net.WebSockets.ClientWebSocket
    $t = $this.ws.ConnectAsync([Uri]$url, $this.ct)
    if (-not $t.Wait(20000)) { throw 'CDP connect timed out' }
  }
  [void] Close() { try { $this.ws.Dispose() } catch { } }

  hidden [object] ReadReply([int]$wantId, [int]$timeoutMs) {
    $end = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    $buf = New-Object byte[] 8388608
    $sb = New-Object System.Text.StringBuilder
    while ([DateTime]::UtcNow -lt $end) {
      $left = [int]($end - [DateTime]::UtcNow).TotalMilliseconds
      if ($left -le 0) { break }
      $seg = [System.ArraySegment[byte]]::new($buf, 0, $buf.Length)
      $task = $this.ws.ReceiveAsync($seg, $this.ct)
      if (-not $task.Wait([Math]::Min(1500, $left))) { continue }
      try { $res = $task.Result } catch { break }
      [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $res.Count))
      if (-not $res.EndOfMessage) { continue }
      $text = $sb.ToString(); [void]$sb.Clear()
      if (-not $text) { continue }
      $obj = $text | ConvertFrom-Json
      if ($obj.id -eq $wantId) { return $obj }
    }
    throw "CDP timeout waiting for reply $wantId"
  }

  [object] Send([string]$method, [hashtable]$params) {
    $this.seq++
    $payload = @{ id = $this.seq; method = $method; params = $params } | ConvertTo-Json -Depth 10 -Compress
    $b = [Text.Encoding]::UTF8.GetBytes($payload)
    $seg = [System.ArraySegment[byte]]::new($b, 0, $b.Length)
    $t = $this.ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $this.ct)
    if (-not $t.Wait(20000)) { throw "CDP send timed out: $method" }
    return $this.ReadReply($this.seq, 180000)
  }

  [object] Eval([string]$js) {
    $r = $this.Send('Runtime.evaluate', @{ expression = $js; returnByValue = $true; awaitPromise = $true })
    if ($r.result -and $r.result.exceptionDetails) {
      throw ('JS error: ' + (($r.result.exceptionDetails.exception.description) -replace '\s+',' '))
    }
    if ($r.result -and $r.result.result) { return $r.result.result.value }
    return $null
  }

  [void] Navigate([string]$url) {
    $this.Send('Page.navigate', @{ url = $url }) | Out-Null
    for ($i = 0; $i -lt 200; $i++) {
      Start-Sleep -Milliseconds 250
      if ($this.Eval('document.readyState') -eq 'complete') { Start-Sleep -Milliseconds 800; return }
    }
  }

  [object] WaitFor([string]$js, [int]$timeoutSec = 120) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) {
      $v = $this.Eval($js)
      if ($v) { return $v }
      Start-Sleep -Milliseconds 800
    }
    return $null
  }

  [void] TypeText([string]$text) {
    $this.Send('Input.insertText', @{ text = $text }) | Out-Null
  }
  [void] Press([string]$key, [int]$vk) {
    foreach ($t in @('keyDown','keyUp')) {
      $this.Send('Input.dispatchKeyEvent', @{
        type = $t; key = $key; code = $key
        windowsVirtualKeyCode = $vk; nativeVirtualKeyCode = $vk
      }) | Out-Null
    }
  }
}

# --------------------------------------------------------------------------
# copy the live Chrome profile so it is never written to
# --------------------------------------------------------------------------
function Copy-ChromeProfile([string]$dest) {
  $ud = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
  Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path "$dest\Default" | Out-Null
  foreach ($n in @('Cookies','Network','Preferences','Secure Preferences','Web Data','History')) {
    $s = Join-Path $ud "Default\$n"
    if (Test-Path $s) {
      New-Item -ItemType Directory -Force -Path "$dest\Default\$n" | Out-Null
      Copy-Item "$s\*" "$dest\Default\$n\" -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  $ls = Join-Path $ud 'Local State'
  if (Test-Path $ls) { Copy-Item $ls "$dest\Local State" -Force }
  return (Get-ChildItem $dest -Recurse -File | Measure-Object -Sum Length).Sum
}

$tmp = Join-Path $env:TEMP 'ga4c'
$chrome = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $chrome)) { $chrome = Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe' }
if (-not (Test-Path $chrome)) { Err 'Chrome not found.'; exit 1 }

$proc = $null
$cdp = $null
function Cleanup {
  if ($cdp) { try { $cdp.Close() } catch { } }
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 400
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$exitCode = 0
try {
  do {
  Say 'Preparing a throwaway copy of your Chrome profile'
  $mb = (Copy-ChromeProfile $tmp) / 1MB
  Ok "copied $([math]::Round($mb,1)) MB to a temp folder (your real profile is never touched)"

  Say 'Starting Chrome with the DevTools Protocol'
  $proc = Start-Process -FilePath $chrome -PassThru -WindowStyle Hidden -ArgumentList @(
    '--headless=new', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--disable-sync', '--disable-features=Translate,OptimizationHints',
    "--user-data-dir=$tmp", "--remote-debugging-port=$Port", '--remote-debugging-address=127.0.0.1',
    '--disable-background-networking', '--disable-component-update',
    'about:blank'
  )
  $up = $false
  for ($i = 0; $i -lt 60; $i++) {
    try { $null = Invoke-RestMethod "http://127.0.0.1:$Port/json/version" -TimeoutSec 3; $up = $true; break } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $up) { throw 'Chrome did not open the debugging port' }
  Ok "chrome pid $($proc.Id), debugging port $Port"

  $target = $null
  try { $target = Invoke-RestMethod "http://127.0.0.1:$Port/json/new?about:blank" -Method Put }
  catch { $target = Invoke-RestMethod "http://127.0.0.1:$Port/json/new?about:blank" }
  $cdp = [Cdp]::new($target.webSocketDebuggerUrl)
  $cdp.Send('Page.enable', @{}) | Out-Null
  $cdp.Send('Runtime.enable', @{}) | Out-Null

  # -------------------------------------------------------------------- gate
  Say 'Checking your Google session'
  $cdp.Navigate('https://myaccount.google.com/?hl=en')
  $st = $cdp.Eval(@'
(() => {
  const t = (document.body ? document.body.innerText : '') || '';
  const url = location.href;
  const email = (t.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/) || [null])[0];
  const signedIn = url.indexOf('/account/about/') < 0 && !/Sign in|Choose an account|Google でログイン/i.test(t);
  return { url: url, email: email, signedIn: signedIn };
})()
'@)
  if (-not $st.signedIn) {
    Write-Host ''
    Err 'You are not signed in to Google in this Chrome profile.'
    Write-Host ''
    Write-Host '   Do this, then run the script again:'
    Write-Host '     1. Open Chrome on this PC.'
    Write-Host '     2. Go to https://myaccount.google.com/ and sign in.'
    Write-Host '     3. Run this script again.'
    Write-Host ''
    Write-Host '   That is the only manual step. Everything after it is automated.'
    $exitCode = 2
    break
  }
  Ok "signed in" + $(if ($st.email) { " as $($st.email)" } else { "" })

  # ------------------------------------------------------- cloud shell: gcloud
  Say 'Opening Google Cloud Shell (this takes about a minute on first boot)'
  Todo 'The shell gives an already-authenticated gcloud, so no service-account dance is needed.'
  $cdp.Navigate('https://shell.cloud.google.com/?show=terminal')

  $ready = $cdp.WaitFor(@'
(() => {
  const rows = document.querySelector('.xterm-rows');
  if (!rows) return false;
  const t = rows.innerText || '';
  return t.length > 40 && /@|cloudshell|Welcome|\$/.test(t);
})()
'@, 240)
  if (-not $ready) { throw 'Cloud Shell did not become ready in time' }
  Start-Sleep -Seconds 5
  Ok 'Cloud Shell terminal is ready'

  function Sh([string]$cmd, [int]$waitSec = 60) {
    $cdp.TypeText($cmd)
    Start-Sleep -Milliseconds 300
    $cdp.Press('Enter', 13)
    Start-Sleep -Milliseconds 500
    $end = (Get-Date).AddSeconds($waitSec)
    $last = ''
    while ((Get-Date) -lt $end) {
      $t = $cdp.Eval('(document.querySelector(".xterm-rows")||{innerText:""}).innerText')
      if ($t -and $t -ne $last) { $last = $t }
      if ($t -and $t.Length -gt $last.Length - 1) { }
      # consider finished when the prompt is back
      if ($t -and $t.TrimEnd().EndsWith('$ ') ) { return $t }
      Start-Sleep -Milliseconds 900
    }
    return $last
  }

  if (-not $ProjectId) {
    $out = Sh 'gcloud config get-value project 2>/dev/null' 40
    $m = [regex]::Match($out, '([a-z][a-z0-9-]{4,30}[0-9]{0,3})')
    if ($m.Success -and $out -match 'project') { $ProjectId = $m.Groups[1].Value }
    if (-not $ProjectId) {
      $lst = Sh 'gcloud projects list --format="value(projectId)" 2>/dev/null' 40
      $mm = [regex]::Matches($lst, '([a-z][a-z0-9-]{4,30})')
      foreach ($x in $mm) {
        if ($x.Groups[1].Value -match '^[a-z][a-z0-9-]{5,34}$' -and $x.Groups[1].Value -notmatch '^(gcloud|cloudshell)$') { $ProjectId = $x.Groups[1].Value; break }
      }
    }
  }
  if (-not $ProjectId) {
    Err 'Could not work out which Google Cloud project to use.'
    Write-Host '   Re-run with:  -ProjectId your-project-id'
    $exitCode = 3
    break
  }
  Ok "project: $ProjectId"

  $cdp.TypeText("gcloud config set project $ProjectId")
  Start-Sleep -Milliseconds 200; $cdp.Press('Enter', 13); Start-Sleep -Seconds 3

  Say 'Enabling the Google Analytics Data API'
  $null = Sh "gcloud services enable analyticsdata.googleapis.com" 150
  Ok 'API enabled'

  Say 'Creating the service account'
  $null = Sh 'gcloud iam service-accounts create ga4-reader --display-name="GA4 read-only"' 120
  $sa = "ga4-reader@$ProjectId.iam.gserviceaccount.com"
  Ok "service account: $sa"

  Say 'Creating the JSON key'
  $null = Sh 'rm -f ~/toj-key.json' 30
  $null = Sh "gcloud iam service-accounts keys create ~/toj-key.json --iam-account=$sa --key-file-type=json" 150
  $keyText = $null
  for ($i = 0; $i -lt 40; $i++) {
    $t = $cdp.Eval('(document.querySelector(".xterm-rows")||{innerText:""}).innerText')
    if ($t -and $t -match '"private_key"\s*:\s*"-----BEGIN') { $keyText = $t; break }
    Start-Sleep -Milliseconds 700
  }
  if (-not $keyText) { throw 'could not read the generated key from the terminal' }

  # the terminal text is line-wrapped, so pull the JSON out of the raw text
  $raw = $keyText
  $startIdx = $raw.IndexOf('{')
  $endIdx = $raw.LastIndexOf('}')
  if ($startIdx -lt 0 -or $endIdx -le $startIdx) { throw 'key JSON not found in terminal output' }
  $jsonBlob = $raw.Substring($startIdx, $endIdx - $startIdx + 1)
  # terminal wraps at the column width; join broken lines back together
  $joined = ($jsonBlob -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join ''
  $joined = $joined -replace '\\\s+', ''      # undo wrapped escapes
  try { $sa2 = $joined | ConvertFrom-Json } catch { $sa2 = $null }
  if (-not $sa2 -or -not $sa2.private_key) { throw 'the key text could not be parsed as JSON' }

  [System.IO.File]::WriteAllText($keyFile, $joined, (New-Object System.Text.UTF8Encoding($false)))
  Ok "key written to $keyFile (private key never printed)"

  $null = Sh 'rm -f ~/toj-key.json' 30

  # ------------------------------------------------- GA4 property access grant
  Say 'Adding the service account to the GA4 property'
  Write-Host "   The rest needs the GA4 admin screen. Opening it for you."
  Write-Host "   In that tab:  Admin > Property access management > Add users"
  Write-Host "   paste exactly:  $sa"
  Write-Host "   role: Viewer (leave 'Notify by email' unchecked) > Add."
  Start-Process 'https://analytics.google.com/' | Out-Null

  while ($true) {
    $answ = Read-Host '   Type "done" once that is added'
    if ($answ -match '^(done|ok|y)$') { break }
  }

  while ($true) {
    $p = (Read-Host '   Paste the numeric GA4 Property ID (Admin > Property settings)').Trim()
    $p = ($p -replace '^properties/', '').Trim()
    if ($p -match '^\d{6,}$') { break }
    Write-Host '   That does not look like a property id - just digits, e.g. 123456789.'
  }
  [System.IO.File]::WriteAllText($propFile, $p, (New-Object System.Text.UTF8Encoding($false)))
  Ok "property id saved: $p"
  } while ($false)
}
catch {
  Err $_.Exception.Message
  Write-Host ''
  Write-Host "   $($_ | Out-String)"
  $exitCode = 1
}
finally {
  Cleanup
}

if ($exitCode -eq 0) {
  Say 'Testing the connection'
  $report = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ga4-report.ps1') 2>&1
  $report | ForEach-Object { Write-Host "   $_" }

  if ($report -match '\[FAIL\]') {
    Write-Host ''
    Write-Host '   Common causes:'
    Write-Host '     invalid_grant: account not found  -> the GA4 grant step was skipped'
    Write-Host '     PERMISSION_DENIED                 -> the service account is not a Viewer'
    $exitCode = 1
  } else {
    Write-Host ''
    Ok 'GA4 is automated. From now on /site reads real traffic numbers.'
  }
}
exit $exitCode
