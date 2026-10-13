<#
.SYNOPSIS
  Read-only Windows 10/11 support snapshot; exports timestamped CSV and HTML.
.DESCRIPTION
  Collects computer/OS, CPU, memory, fixed disk, IP configuration, DNS and
  selected service status. Does not repair or change system configuration.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'Reports'),
    [string[]]$ServicesToCheck = @('Spooler', 'Dhcp', 'Dnscache', 'Winmgmt')
)
$ErrorActionPreference = 'Continue'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$Category, [string]$Name, [object]$Value, [string]$Status = 'INFO') {
    $rows.Add([pscustomobject]@{ Timestamp=(Get-Date -Format 's'); Category=$Category; Check=$Name; Value=[string]$Value; Status=$Status })
}
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Add-Result 'System' 'Computer Name' $env:COMPUTERNAME
    Add-Result 'System' 'OS' ($os.Caption + ' ' + $os.Version)
    Add-Result 'System' 'Last Boot' $os.LastBootUpTime
    Add-Result 'System' 'Uptime (hours)' ([math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1))
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Add-Result 'Hardware' 'Processor' $cpu.Name
    Add-Result 'Hardware' 'Logical Processors' $cpu.NumberOfLogicalProcessors
    Add-Result 'Hardware' 'Installed RAM (GB)' ([math]::Round($os.TotalVisibleMemorySize / 1MB, 2))
    Add-Result 'Hardware' 'Free RAM (GB)' ([math]::Round($os.FreePhysicalMemory / 1MB, 2))
} catch { Add-Result 'System' 'System query' $_.Exception.Message 'WARNING' }
try {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $freePct = if ($_.Size -gt 0) { [math]::Round(100 * $_.FreeSpace / $_.Size, 1) } else { 0 }
        $status = if ($freePct -lt 10) { 'WARNING' } else { 'OK' }
        Add-Result 'Storage' ($_.DeviceID + ' free space') (('{0:N1} GB free / {1:N1} GB total ({2}%)' -f ($_.FreeSpace/1GB), ($_.Size/1GB), $freePct)) $status
    }
} catch { Add-Result 'Storage' 'Disk query' $_.Exception.Message 'WARNING' }
try {
    Get-NetIPConfiguration | ForEach-Object {
        $ipv4 = ($_.IPv4Address.IPAddress -join ', ')
        $gateway = ($_.IPv4DefaultGateway.NextHop -join ', ')
        $dns = ($_.DNSServer.ServerAddresses -join ', ')
        Add-Result 'Network' ($_.InterfaceAlias + ' IPv4') $ipv4
        Add-Result 'Network' ($_.InterfaceAlias + ' Gateway') $gateway
        Add-Result 'Network' ($_.InterfaceAlias + ' DNS') $dns
    }
} catch { Add-Result 'Network' 'IP configuration query' $_.Exception.Message 'WARNING' }
foreach ($serviceName in $ServicesToCheck) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        $status = if ($service.Status -eq 'Running') { 'OK' } else { 'CHECK' }
        Add-Result 'Services' $serviceName $service.Status $status
    } catch { Add-Result 'Services' $serviceName 'Not found or unavailable' 'CHECK' }
}
$csvPath = Join-Path $OutputDirectory "Windows-Health-$timestamp.csv"
$htmlPath = Join-Path $OutputDirectory "Windows-Health-$timestamp.html"
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath
$body = $rows | ConvertTo-Html -Fragment -PreContent "<h1>Windows PC Health Check</h1><p>Computer: $env:COMPUTERNAME | Generated: $(Get-Date)</p>"
$style = '<style>body{font-family:Segoe UI,Arial;margin:2rem;color:#222}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:8px;text-align:left}th{background:#17202a;color:white}tr:nth-child(even){background:#f4f6f7}</style>'
ConvertTo-Html -Title 'Windows PC Health Check' -Head $style -Body $body | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Completed. Review the reports before drawing conclusions." -ForegroundColor Green
Write-Host "CSV : $csvPath"
Write-Host "HTML: $htmlPath"
