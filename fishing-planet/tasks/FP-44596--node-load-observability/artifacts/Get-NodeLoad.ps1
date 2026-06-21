<#
.SYNOPSIS
    Poll Fishing Planet farm nodes for current load level, peer count, rotation state and
    (optionally) raw CPU% / RAM% with the load-shedding thresholds applied.

.DESCRIPTION
    Two data sources, by design:

    1) Load LABEL + peers + rotation  -- from the Software Distributor's own status channel.
       Reads the node inventory from Distributor.json, then queries each node's Manage agent:
           GET http://<ip:90>/Manage/Action?name=getStatus
       The CSV is parsed exactly like DistributorCommon.Distributor:
           4 fields: Role,Installed,Downloaded,Status                                (Web/SQL/Mongo/Chat/Tech/Ready)
           5 fields: + PeerCount                          (Load unknown -> "?")      (AllInOne old)
           6 fields: + PeerCount,Load                                                (Master/AllInOne new)
           7 fields: + PeerCount,OutOfRotation,FarmName   (Load unknown -> "?")      (Game old)
           8 fields: + PeerCount,OutOfRotation,FarmName,Load                         (Game new)
       Load labels, encoded from Photon FeedbackLevel (Lowest..Highest):
           Empty < Low < Normal < High < Full

    2) Raw PERCENTAGES (-WithPerf)    -- the inputs the node uses to compute that label.
       Runs Get-Counter ON each node via WinRM (Invoke-Command), reading the same counters
       WorkloadController reads:
           CPU%  = \Processor(_Total)\% Processor Time   (averaged over a short sample)
           RAM%  = 100 - AvailableMBytes * 100 / TotalPhysicalMemory
       Each % is mapped to a level using the load-shedding thresholds below, so you can see
       WHICH metric drives the label. The node's own label (source 1) stays authoritative;
       these %/levels are diagnostic (the server also smooths over ~100 samples and the
       overall level is the MAX across all controllers, not just CPU/RAM).

    Thresholds are the code defaults from LoadShedding\Configuration\DefaultConfiguration.cs.
    On this deployment Workload.config is not present, so the defaults are what runs.

.PARAMETER ConfigPath
    Path to Distributor.json. Defaults to a copy next to this script. On the live box point it
    at the Software Distributor's own Distributor.json (or copy that file next to the script).

.PARAMETER Roles
    Optional role filter, e.g. -Roles Game,Master. Default: all roles.

.PARAMETER WithPerf
    Also pull CPU% / RAM% from each node over WinRM and map them to levels.

.PARAMETER Credential
    Credential for the WinRM perf calls (-WithPerf). Default: current user.

.PARAMETER ShowThresholds
    Print the threshold ladders and exit (no node polling).

.PARAMETER TimeoutSec
    Per-node HTTP timeout in seconds. Default 4.

.PARAMETER ThrottleLimit
    Max concurrent requests (HTTP and WinRM). Default 16.

.PARAMETER Watch / -IntervalSeconds
    Keep refreshing the table until Ctrl+C. Default interval 5s.

.PARAMETER PassThru
    Emit the per-node records to the pipeline (for Export-Csv etc.).

.EXAMPLE
    .\Get-NodeLoad.ps1

.EXAMPLE
    .\Get-NodeLoad.ps1 -WithPerf -Roles Game -Watch -IntervalSeconds 5

.EXAMPLE
    .\Get-NodeLoad.ps1 -ShowThresholds
#>
[CmdletBinding()]
param(
    [string]        $ConfigPath = (Join-Path $PSScriptRoot 'Distributor.json'),
    [string[]]      $Roles,
    [switch]        $WithPerf,
    [pscredential]  $Credential,
    [switch]        $ShowThresholds,
    [int]           $TimeoutSec = 4,
    [int]           $ThrottleLimit = 16,
    [switch]        $Watch,
    [int]           $IntervalSeconds = 5,
    [switch]        $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# FeedbackLevel label -> color (Empty = idle .. Full = saturated).
$LoadRank  = @{ 'Empty' = 0; 'Low' = 1; 'Normal' = 2; 'High' = 3; 'Full' = 4 }
$LoadColor = @{ 'Empty' = 'DarkGray'; 'Low' = 'Green'; 'Normal' = 'Cyan'; 'High' = 'Yellow'; 'Full' = 'Red' }

# Entry thresholds (value at which the metric CLIMBS into that level), from
# LoadShedding\Configuration\DefaultConfiguration.cs. The Lowest value (CPU 20 / RAM 30) is the
# DESCEND boundary (hysteresis); for a snapshot we band by the climb thresholds below.
$CpuEntry = [ordered]@{ Low = 35; Normal = 50; High = 70; Full = 90 }   # Full == Highest
$RamEntry = [ordered]@{ Low = 45; Normal = 60; High = 80; Full = 90 }
$CpuFloor = 20   # <= this drops back to Empty (Lowest)
$RamFloor = 30

function Get-NodeInventory {
    param([string]$Path, [string[]]$RoleFilter)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Distributor.json not found at '$Path'. Pass -ConfigPath or copy the file next to the script."
    }
    $nodes = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($RoleFilter) { $nodes = $nodes | Where-Object { $RoleFilter -contains $_.Role } }
    return $nodes
}

# ---- Source 1: HTTP getStatus (label + peers + rotation) ----

$HttpWorker = {
    param($Node, $TimeoutSec)
    $url = "http://$($Node.Ip)/Manage/Action?name=getStatus"
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        [pscustomobject]@{ Node = $Node; Ok = $true;  Text = ($resp.Content).Trim(); Error = $null }
    }
    catch {
        [pscustomobject]@{ Node = $Node; Ok = $false; Text = $null; Error = $_.Exception.Message }
    }
}

function Invoke-StatusPoll {
    param([object[]]$Nodes, [int]$TimeoutSec, [int]$ThrottleLimit, [scriptblock]$Worker)

    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $ThrottleLimit))
    $pool.Open()
    try {
        $jobs = foreach ($node in $Nodes) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $pool
            [void]$ps.AddScript($Worker).AddArgument($node).AddArgument($TimeoutSec)
            [pscustomobject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
        }
        foreach ($job in $jobs) {
            $out = $job.PS.EndInvoke($job.Handle)
            $job.PS.Dispose()
            $out
        }
    }
    finally {
        $pool.Close(); $pool.Dispose()
    }
}

function ConvertFrom-StatusResult {
    param([object]$Result)

    $node = $Result.Node
    $rec = [ordered]@{
        Name = $node.Name; Role = $node.Role; Ip = $node.Ip
        Status = $null; PeerCount = $null; OutOfRotation = $null; Load = $null; Farm = $null
        Cpu = $null; Ram = $null; Raw = $Result.Text
    }

    if (-not $Result.Ok) {
        $rec.Status = 'Unavailable'; $rec.Load = '-'; $rec.Raw = $Result.Error
        return [pscustomobject]$rec
    }

    $m = ($Result.Text -split ',')
    if ($m.Count -lt 4 -or $m.Count -gt 8) {
        $rec.Status = 'Error'; $rec.Load = '-'
        return [pscustomobject]$rec
    }

    $rec.Role = $m[0]; $rec.Status = $m[3]
    switch ($m.Count) {
        5 { $rec.PeerCount = [int]$m[4]; $rec.Load = '?' }
        6 { $rec.PeerCount = [int]$m[4]; $rec.Load = $m[5] }
        7 { $rec.PeerCount = [int]$m[4]; $rec.OutOfRotation = ($m[5] -eq '1'); $rec.Farm = $m[6]; $rec.Load = '?' }
        8 { $rec.PeerCount = [int]$m[4]; $rec.OutOfRotation = ($m[5] -eq '1'); $rec.Farm = $m[6]; $rec.Load = $m[7] }
    }
    return [pscustomobject]$rec
}

# ---- Source 2: WinRM Get-Counter (CPU% / RAM%) ----

function Get-NodePerf {
    param([string[]]$Hosts, [int]$ThrottleLimit, [pscredential]$Credential)

    $map = @{}
    if (-not $Hosts) { return $map }

    $sb = {
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2 -ErrorAction Stop).CounterSamples |
            Measure-Object CookedValue -Average | Select-Object -ExpandProperty Average
        $free = (Get-Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples[0].CookedValue
        $totalMB = try { [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1MB) }
                   catch { [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1MB) }
        [pscustomobject]@{
            Cpu = [math]::Round($cpu)
            Ram = if ($totalMB -gt 0) { [math]::Round(100 - ($free * 100 / $totalMB)) } else { $null }
        }
    }

    $params = @{ ComputerName = $Hosts; ScriptBlock = $sb; ThrottleLimit = [Math]::Max(1, $ThrottleLimit); ErrorAction = 'SilentlyContinue' }
    if ($Credential) { $params.Credential = $Credential }

    foreach ($r in (Invoke-Command @params)) { $map[[string]$r.PSComputerName] = $r }
    return $map
}

# ---- Threshold helpers ----

function Get-BandLevel {
    param([double]$Value, [System.Collections.Specialized.OrderedDictionary]$Entry)
    $label = 'Empty'
    foreach ($k in $Entry.Keys) { if ($Value -ge [double]$Entry[$k]) { $label = $k } }
    return $label
}

function Show-Thresholds {
    Write-Host ''
    Write-Host 'Load-shedding thresholds (code defaults, LoadShedding\Configuration\DefaultConfiguration.cs):' -ForegroundColor White
    Write-Host '  Overall level = MAX across all metrics. Label = Empty/Low/Normal/High/Full (FeedbackLevel Lowest..Highest).' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Metric   Empty      Low        Normal     High       Full' -ForegroundColor White
    Write-Host ('  CPU %    <{0,-9} >={1,-8} >={2,-8} >={3,-8} >={4}' -f ($CpuEntry.Low), $CpuEntry.Low, $CpuEntry.Normal, $CpuEntry.High, $CpuEntry.Full) -ForegroundColor Gray
    Write-Host ('  RAM %    <{0,-9} >={1,-8} >={2,-8} >={3,-8} >={4}' -f ($RamEntry.Low), $RamEntry.Low, $RamEntry.Normal, $RamEntry.High, $RamEntry.Full) -ForegroundColor Gray
    Write-Host ''
    Write-Host ('  Hysteresis floor (descend back to Empty): CPU <= {0}%, RAM <= {1}%.' -f $CpuFloor, $RamFloor) -ForegroundColor DarkGray
    Write-Host '  Also active by default but not shown here: bandwidth, ENet queue, time-in-server.' -ForegroundColor DarkGray
    Write-Host '  Disabled on this deployment: latency (EnableLatencyMonitor=False).' -ForegroundColor DarkGray
    Write-Host ''
}

# ---- Rendering ----

function Write-Cell {
    param([string]$Text, [int]$Width, [string]$Color = 'Gray', [switch]$Right)
    $s = if ($Right) { $Text.PadLeft($Width) } else { $Text.PadRight($Width) }
    Write-Host ($s + ' ') -ForegroundColor $Color -NoNewline
}

function Get-PctCell {
    param($Value, [System.Collections.Specialized.OrderedDictionary]$Entry)
    if ($Value -eq $null) { return @{ Text = 'n/a'; Color = 'DarkGray' } }
    $band = Get-BandLevel -Value $Value -Entry $Entry
    return @{ Text = ("{0}%" -f $Value); Color = $LoadColor[$band] }
}

function Show-LoadTable {
    param([object[]]$Rows, [switch]$HasPerf)

    $sorted = $Rows | Sort-Object `
        @{ Expression = { if ($_.Load -and $LoadRank.ContainsKey($_.Load)) { $LoadRank[$_.Load] } else { -1 } }; Descending = $true }, `
        @{ Expression = { if ($_.PeerCount -ne $null) { [int]$_.PeerCount } else { -1 } }; Descending = $true }, `
        Role, Name

    # Header
    Write-Cell 'Node' 9 'White'; Write-Cell 'Role' 8 'White'; Write-Cell 'Status' 11 'White'
    Write-Cell 'Peers' 6 'White' -Right; Write-Cell 'Load' 6 'White'
    if ($HasPerf) { Write-Cell 'CPU' 5 'White' -Right; Write-Cell 'RAM' 5 'White' -Right }
    Write-Cell 'Rot' 4 'White'; Write-Host 'Ip' -ForegroundColor White
    Write-Host ('-' * ($(if ($HasPerf) { 78 } else { 66 }))) -ForegroundColor DarkGray

    foreach ($r in $sorted) {
        $down  = $r.Status -in @('Unavailable', 'Error')
        $rot   = if ($r.OutOfRotation -eq $true) { 'OOR' } else { '' }
        $peers = if ($r.PeerCount -ne $null) { [string]$r.PeerCount } else { '' }
        $load  = if ($r.Load) { $r.Load } else { '' }

        Write-Cell $r.Name 9 'Gray'
        Write-Cell $r.Role 8 'Gray'
        Write-Cell $r.Status 11 ($(if ($down) { 'DarkRed' } else { 'Gray' }))
        Write-Cell $peers 6 'Gray' -Right
        Write-Cell $load 6 ($(if ($LoadColor.ContainsKey($load)) { $LoadColor[$load] } else { 'DarkGray' }))

        if ($HasPerf) {
            $c = Get-PctCell $r.Cpu $CpuEntry
            $m = Get-PctCell $r.Ram $RamEntry
            Write-Cell $c.Text 5 $c.Color -Right
            Write-Cell $m.Text 5 $m.Color -Right
        }

        Write-Cell $rot 4 ($(if ($rot) { 'Magenta' } else { 'Gray' }))
        Write-Host $r.Ip -ForegroundColor DarkGray
    }
}

function Show-Summary {
    param([object[]]$Rows, [switch]$HasPerf)

    $totalPeers = 0
    foreach ($r in $Rows) { if ($r.PeerCount -ne $null) { $totalPeers += [int]$r.PeerCount } }
    $byLoad = foreach ($lvl in 'Empty', 'Low', 'Normal', 'High', 'Full') {
        $n = @($Rows | Where-Object { $_.Load -eq $lvl }).Count
        if ($n -gt 0) { "$lvl=$n" }
    }
    $oor  = @($Rows | Where-Object { $_.OutOfRotation -eq $true }).Count
    $down = @($Rows | Where-Object { $_.Status -in @('Unavailable', 'Error') }).Count

    Write-Host ''
    Write-Host ("Nodes: {0}   Peers: {1}   {2}   OutOfRotation: {3}   Down: {4}" -f `
        $Rows.Count, $totalPeers, ($byLoad -join ' '), $oor, $down) -ForegroundColor White

    if ($HasPerf) {
        $withCpu = @($Rows | Where-Object { $_.Cpu -ne $null })
        if ($withCpu.Count) {
            $hotCpu = $withCpu | Sort-Object Cpu -Descending | Select-Object -First 1
            $ramRows = @($Rows | Where-Object { $_.Ram -ne $null })
            $hotRamName = '-'; $hotRamVal = '-'
            if ($ramRows.Count) {
                $hr = $ramRows | Sort-Object Ram -Descending | Select-Object -First 1
                $hotRamName = $hr.Name; $hotRamVal = $hr.Ram
            }
            $noPerf = @($Rows | Where-Object { $_.Cpu -eq $null -and $_.Status -notin @('Unavailable', 'Error') }).Count
            Write-Host ("Perf: hottest CPU {0} {1}%   hottest RAM {2} {3}%   (no perf reply: {4})" -f `
                $hotCpu.Name, $hotCpu.Cpu, $hotRamName, $hotRamVal, $noPerf) -ForegroundColor White
        }
        else {
            Write-Host 'Perf: no node returned counters (WinRM unreachable?). Showing labels only.' -ForegroundColor DarkRed
        }
    }
}

# ---- Main ----

function Invoke-Once {
    $nodes = Get-NodeInventory -Path $ConfigPath -RoleFilter $Roles
    $raw   = Invoke-StatusPoll -Nodes $nodes -TimeoutSec $TimeoutSec -ThrottleLimit $ThrottleLimit -Worker $HttpWorker
    $rows  = @($raw | ForEach-Object { ConvertFrom-StatusResult $_ })

    if ($WithPerf) {
        $hosts = @($nodes | ForEach-Object { ($_.Ip -split ':')[0] } | Select-Object -Unique)
        $perf  = Get-NodePerf -Hosts $hosts -ThrottleLimit $ThrottleLimit -Credential $Credential
        foreach ($row in $rows) {
            $h = ($row.Ip -split ':')[0]
            if ($perf.ContainsKey($h)) { $row.Cpu = $perf[$h].Cpu; $row.Ram = $perf[$h].Ram }
        }
    }

    if ($Watch) { Clear-Host }
    Write-Host ("Fishing Planet node load  -  {0}  (config: {1})" -f (Get-Date), $ConfigPath) -ForegroundColor White
    if ($WithPerf) { Show-Thresholds }
    Show-LoadTable -Rows $rows -HasPerf:$WithPerf
    Show-Summary   -Rows $rows -HasPerf:$WithPerf
    return $rows
}

if ($ShowThresholds) {
    Show-Thresholds
    return
}

if ($Watch) {
    Write-Host 'Watching node load. Press Ctrl+C to stop.' -ForegroundColor DarkGray
    while ($true) {
        [void](Invoke-Once)
        Start-Sleep -Seconds $IntervalSeconds
    }
}
else {
    $result = Invoke-Once
    if ($PassThru) { $result }
}
