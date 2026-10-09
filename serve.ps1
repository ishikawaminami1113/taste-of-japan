# Taste of Japan — lightweight static file server (no dependencies)
# Usage:  powershell -ExecutionPolicy Bypass -File .\serve.ps1 [-Port 8000]
param([int]$Port = 8000)

$root = $PSScriptRoot
$enc = [System.Text.Encoding]::UTF8

function Get-ContentType([string]$ext) {
  switch ($ext) {
    ".html"  { "text/html; charset=utf-8" }
    ".css"   { "text/css; charset=utf-8" }
    ".js"    { "text/javascript; charset=utf-8" }
    ".json"  { "application/json; charset=utf-8" }
    ".png"   { "image/png" }
    ".jpg"   { "image/jpeg" }
    ".svg"   { "image/svg+xml" }
    ".ico"   { "image/x-icon" }
    ".woff2" { "font/woff2" }
    default  { "application/octet-stream" }
  }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "Serving $root at http://127.0.0.1:$Port/  (Ctrl+C to stop)"

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, $enc)
    $requestLine = $reader.ReadLine()
    do { $h = $reader.ReadLine() } while ($null -ne $h -and $h -ne "")

    if ($requestLine) {
      $path = ($requestLine -split " ")[1]
      if ($path -eq "/" -or $path -eq "") { $path = "/index.html" }
      $rel = [System.Uri]::UnescapeDataString(($path -split "\?")[0]).TrimStart("/").Replace("/", "\")
      $file = Join-Path $root $rel
      $resolved = if (Test-Path $file -PathType Leaf) { (Resolve-Path $file).Path } else { $null }

      if ($resolved -and $resolved.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $ct = Get-ContentType ([System.IO.Path]::GetExtension($resolved).ToLower())
        $header = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $hs = $enc.GetBytes($header)
        $stream.Write($hs, 0, $hs.Length)
        $stream.Write($bytes, 0, $bytes.Length)
      } else {
        $body = $enc.GetBytes("404 Not Found")
        $header = "HTTP/1.1 404 Not Found`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
        $hs = $enc.GetBytes($header)
        $stream.Write($hs, 0, $hs.Length)
        $stream.Write($body, 0, $body.Length)
      }
    }
  } catch { }
  finally {
    if ($null -ne $stream) { $stream.Close() }
    $client.Close()
  }
}
