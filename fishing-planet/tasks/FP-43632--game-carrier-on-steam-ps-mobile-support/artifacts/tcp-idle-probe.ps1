<#
.SYNOPSIS
    Opens TCP connections to a game server, sends nothing at all, and measures how long the
    server takes to close them.

.DESCRIPTION
    A connection that is established and then stays silent is what accumulates on GameCarrier
    nodes. TCP itself never closes such a connection, so whether it goes away depends entirely
    on the server having an idle timeout of its own.

    The probe reports, per connection, how the server ended it:
      FIN    - the server closed it normally. This is the expected behaviour.
      RST    - the server reset it. Also a close, less polite.
      DATA   - the server sent bytes instead of closing; the probe keeps waiting.
      (none) - still open when the wait ran out.

    Local ports are printed so the connection can be found on the server side, in
    Get-NetTCPConnection or in TracePeers-<App>.log.

.EXAMPLE
    .\tcp-idle-probe.ps1 -Target 127.0.0.1 -Port 4531 -MaxWaitSeconds 300

.EXAMPLE
    .\tcp-idle-probe.ps1 -Target yellowtest.fishingplanet.com -Port 4531 -Count 3 -MaxWaitSeconds 600
#>
param(
    [Parameter(Mandatory = $true)][string] $Target,
    [int] $Port = 4531,
    [int] $Count = 1,
    [int] $MaxWaitSeconds = 300,
    [int] $PollMs = 200
)

$ErrorActionPreference = 'Stop'

function Get-CloseReason([System.Net.Sockets.Socket] $sock) {
    # Readable with no data means the peer closed; readable with data means the server spoke first.
    if (-not $sock.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) { return $null }
    $buffer = New-Object byte[] 4096
    try {
        $read = $sock.Receive($buffer, 0, $buffer.Length, [System.Net.Sockets.SocketFlags]::None)
        if ($read -eq 0) { return 'FIN' }
        return "DATA:$read"
    }
    catch [System.Net.Sockets.SocketException] {
        if ($_.Exception.SocketErrorCode -eq 'ConnectionReset') { return 'RST' }
        return "ERR:$($_.Exception.SocketErrorCode)"
    }
}

$connections = @()

try {
    for ($i = 1; $i -le $Count; $i++) {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($Target, $Port)
        $connections += [pscustomobject]@{
            Index     = $i
            Client    = $client
            LocalPort = $client.Client.LocalEndPoint.Port
            ClosedAt  = $null
            Reason    = $null
            DataBytes = 0
        }
        Write-Host ("connection {0}: local port {1}" -f $i, $client.Client.LocalEndPoint.Port)
    }

    Write-Host ""
    Write-Host ("connected to {0}:{1} at {2}. Sending nothing; waiting up to {3} s." -f `
        $Target, $Port, (Get-Date -Format 'HH:mm:ss'), $MaxWaitSeconds)
    Write-Host ""

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $announced = 0

    while ($watch.Elapsed.TotalSeconds -lt $MaxWaitSeconds) {
        foreach ($c in $connections | Where-Object { -not $_.Reason }) {
            $reason = Get-CloseReason $c.Client.Client
            if (-not $reason) { continue }
            if ($reason -like 'DATA:*') {
                # The server answered without being asked; note it and keep waiting for the close.
                $c.DataBytes += [int]($reason -replace 'DATA:', '')
                continue
            }
            $c.Reason = $reason
            $c.ClosedAt = [math]::Round($watch.Elapsed.TotalSeconds, 2)
            Write-Host ("  closed after {0,8:N2} s  -  connection {1} (local port {2}), {3}" -f `
                $c.ClosedAt, $c.Index, $c.LocalPort, $reason) -ForegroundColor Yellow
        }

        if (-not ($connections | Where-Object { -not $_.Reason })) { break }

        $elapsed = [int]$watch.Elapsed.TotalSeconds
        if ($elapsed -ge $announced + 30) {
            $announced = $elapsed - ($elapsed % 30)
            $stillOpen = @($connections | Where-Object { -not $_.Reason }).Count
            Write-Host ("  {0,5} s  -  {1} still open" -f $announced, $stillOpen) -ForegroundColor DarkGray
        }

        Start-Sleep -Milliseconds $PollMs
    }

    Write-Host ""
    Write-Host "result:"
    foreach ($c in $connections) {
        if ($c.Reason) {
            $line = "  connection {0} (local port {1}): closed by server after {2} s, {3}" -f `
                $c.Index, $c.LocalPort, $c.ClosedAt, $c.Reason
        }
        else {
            $line = "  connection {0} (local port {1}): STILL OPEN after {2} s" -f `
                $c.Index, $c.LocalPort, $MaxWaitSeconds
        }
        if ($c.DataBytes -gt 0) { $line += (" (server had sent {0} bytes)" -f $c.DataBytes) }
        Write-Host $line
    }
}
finally {
    foreach ($c in $connections) {
        if ($c.Client) { $c.Client.Close() }
    }
}
