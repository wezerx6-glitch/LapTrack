$ErrorActionPreference = "Stop"
$root = (Resolve-Path $PSScriptRoot).Path
$port = 8000
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)

try {
    $listener.Start()
    Write-Host ""
    Write-Host "LapTrack lokale server draait." -ForegroundColor Green
    Write-Host "Open in Edge: http://localhost:$port/LapTrack.html" -ForegroundColor Cyan
    Write-Host "Laat dit venster open. Stoppen kan met Ctrl+C."
    Start-Process "msedge.exe" "http://localhost:$port/LapTrack.html" -ErrorAction SilentlyContinue

    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
            $requestLine = $reader.ReadLine()
            if (-not $requestLine) { continue }

            while (($line = $reader.ReadLine()) -ne $null -and $line -ne "") { }

            $parts = $requestLine.Split(" ")
            $rawPath = if ($parts.Length -ge 2) { $parts[1] } else { "/" }
            $pathOnly = [System.Uri]::UnescapeDataString(($rawPath -split "\?")[0])
            if ($pathOnly -eq "/") { $pathOnly = "/LapTrack.html" }

            $relative = $pathOnly.TrimStart("/") -replace "/", "\"
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $root $relative))

            if (-not $fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                $body = [System.Text.Encoding]::UTF8.GetBytes("404 - Bestand niet gevonden")
                $status = "404 Not Found"
                $contentType = "text/plain; charset=utf-8"
            } else {
                $body = [System.IO.File]::ReadAllBytes($fullPath)
                $status = "200 OK"
                $ext = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
                $contentType = switch ($ext) {
                    ".html" { "text/html; charset=utf-8" }
                    ".css"  { "text/css; charset=utf-8" }
                    ".js"   { "application/javascript; charset=utf-8" }
                    ".png"  { "image/png" }
                    ".jpg"  { "image/jpeg" }
                    ".svg"  { "image/svg+xml" }
                    default { "application/octet-stream" }
                }
            }

            $header = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
            $stream.Flush()
        } catch {
            # Negeer een verbroken browserverbinding en blijf beschikbaar.
        } finally {
            if ($client) { $client.Close() }
        }
    }
} catch {
    Write-Host ""
    Write-Host "LapTrack kon niet starten: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Controleer of poort 8000 al in gebruik is."
    Read-Host "Druk op Enter om af te sluiten"
} finally {
    if ($listener) { $listener.Stop() }
}
