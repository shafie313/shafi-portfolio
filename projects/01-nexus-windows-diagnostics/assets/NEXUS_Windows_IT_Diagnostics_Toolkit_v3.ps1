
# ============================================================
# Windows IT Diagnostics Toolkit v3.0
# Compatible: Windows 10 / Windows 11
# Requires: Windows PowerShell 5.1 or later
# Purpose: Read-only diagnostics and HTML report generation
# designed : MUHAMMED SHAFI AM
# ============================================================


# ------------------------------------------------------------
# BASIC LAUNCH PASSWORD GATE
# Note: this is an access prompt, NOT strong source-code protection.
# SHA-256 hash of the configured password "11111".
# ------------------------------------------------------------
$ExpectedPasswordHash = 'd17f25ecfbcc7857f7bebea469308be0b2580943e96d13a3ad98a13675c4bfc2'

$SecurePassword = Read-Host 'Enter toolkit password' -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
try {
    $EnteredPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    $SHA256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($EnteredPassword)
        $HashBytes = $SHA256.ComputeHash($Bytes)
        $EnteredHash = ([BitConverter]::ToString($HashBytes)).Replace('-', '').ToLowerInvariant()
        [Array]::Clear($Bytes, 0, $Bytes.Length)
        [Array]::Clear($HashBytes, 0, $HashBytes.Length)
    } finally {
        $SHA256.Dispose()
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    $EnteredPassword = $null
}

if ($EnteredHash -ne $ExpectedPasswordHash) {
    Write-Host 'Incorrect password. Toolkit will exit.' -ForegroundColor Red
    exit 1
}
$EnteredHash = $null

$ErrorActionPreference = 'Continue'

$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectPath) {
    $ProjectPath = (Get-Location).Path
}

$ReportPath = Join-Path $ProjectPath 'Reports'
New-Item -ItemType Directory -Path $ReportPath -Force |
    Out-Null

$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$ReportFile = Join-Path $ReportPath "IT-Report-$Timestamp.html"
$CsvFile = Join-Path $ReportPath "IT-Report-$Timestamp.csv"

# Optional: configure a known, authorized shared folder to test.
# Example: $SharedPath = '\\FILESERVER\Public'
$SharedPath = ''

$Results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Value,
        [ValidateSet('PASS','WARNING','FAIL','INFO','NOT TESTED')]
        [string]$Status = 'INFO',
        [string]$Recommendation = ''
    )

    [void]$Results.Add([PSCustomObject]@{
        Category       = $Category
        Check          = $Check
        Value          = $Value
        Status         = $Status
        Recommendation = $Recommendation
    })
}

function Get-CheckStatus {
    param($Value, [string]$WarningText = 'Investigate this result')
    if ($Value) { return 'PASS' }
    return 'WARNING'
}

function Get-IPv4Config {
    Get-NetIPConfiguration -ErrorAction Stop |
        Where-Object {
            $_.IPv4Address -and
            $_.NetAdapter.Status -eq 'Up'
        } | Select-Object -First 1
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' NEXUS WINDOWS IT DIAGNOSTICS v3.0' -ForegroundColor Cyan
Write-Host ' LinkedIn: linkedin.com/in/muhammedshafiam2001' -ForegroundColor Yellow
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Collecting diagnostic information...'
Write-Host ''

# ------------------------------------------------------------
# 1. SYSTEM INFORMATION
# ------------------------------------------------------------

try {
    $Computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $CPU = Get-CimInstance Win32_Processor -ErrorAction Stop |
        Select-Object -First 1

    Add-Check 'System' 'Computer name' $env:COMPUTERNAME 'PASS'
    Add-Check 'System' 'Manufacturer' $Computer.Manufacturer 'INFO'
    Add-Check 'System' 'Model' $Computer.Model 'INFO'
    Add-Check 'System' 'Windows version' `
        "$($OS.Caption), build $($OS.BuildNumber)" 'INFO'

    $Uptime = (Get-Date) - $OS.LastBootUpTime
    Add-Check 'System' 'System uptime' `
        "$([math]::Floor($Uptime.TotalDays)) days, $($Uptime.Hours) hours" 'INFO'

    Add-Check 'Hardware' 'Processor' $CPU.Name 'INFO'
    Add-Check 'Hardware' 'CPU reported load' `
        "$($CPU.LoadPercentage)%" 'INFO'

    $TotalRAM = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)
    $FreeRAM = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
    $UsedRAMPercent = if ($TotalRAM -gt 0) {
        [math]::Round((1 - ($FreeRAM / $TotalRAM)) * 100, 1)
    } else { 0 }

    $MemoryStatus = if ($UsedRAMPercent -ge 95) {
        'WARNING'
    } else { 'PASS' }

    Add-Check 'Performance' 'Installed RAM' "$TotalRAM GB" 'INFO'
    Add-Check 'Performance' 'Estimated memory usage' `
        "$UsedRAMPercent%" $MemoryStatus `
        'High usage can cause slow performance; inspect processes and workload.'
}
catch {
    Add-Check 'System' 'System information' $_.Exception.Message 'FAIL'
}

# ------------------------------------------------------------
# 2. DISK SPACE
# ------------------------------------------------------------

try {
    $Disks = Get-CimInstance Win32_LogicalDisk `
        -Filter 'DriveType=3' -ErrorAction Stop

    foreach ($Disk in $Disks) {
        $FreeGB = [math]::Round($Disk.FreeSpace / 1GB, 2)
        $SizeGB = [math]::Round($Disk.Size / 1GB, 2)

        $PercentFree = if ($Disk.Size -gt 0) {
            [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 1)
        } else { 0 }

        $Status = if ($PercentFree -lt 10) {
            'WARNING'
        } else { 'PASS' }

        Add-Check 'Storage' "$($Disk.DeviceID) free space" `
            "$FreeGB GB free / $SizeGB GB total ($PercentFree% free)" `
            $Status 'Investigate low disk space before deleting files.'
    }
}
catch {
    Add-Check 'Storage' 'Disk space inspection' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 3. NETWORK CONFIGURATION
# ------------------------------------------------------------

try {
    $Config = Get-IPv4Config

    if ($Config) {
        $IP = $Config.IPv4Address.IPAddress -join ', '
        $Gateway = $Config.IPv4DefaultGateway.NextHop -join ', '
        $DNS = $Config.DNSServer.ServerAddresses -join ', '

        Add-Check 'Network' 'IPv4 address' $IP 'PASS'
        Add-Check 'Network' 'Default gateway' `
            $(if ($Gateway) { $Gateway } else { 'Not configured' }) `
            $(if ($Gateway) { 'PASS' } else { 'WARNING' }) `
            'Check the expected gateway for this network.'

        Add-Check 'Network' 'DNS servers' `
            $(if ($DNS) { $DNS } else { 'Not configured' }) `
            $(if ($DNS) { 'PASS' } else { 'WARNING' }) `
            'Check DNS settings against the approved network configuration.'

        $AdapterName = $Config.NetAdapter.InterfaceDescription
        Add-Check 'Network' 'Active network adapter' $AdapterName 'INFO'

        if ($Gateway) {
            $GatewayIP = $Config.IPv4DefaultGateway.NextHop |
                Select-Object -First 1

            $GatewayOK = Test-Connection -ComputerName $GatewayIP `
                -Count 2 -Quiet -ErrorAction SilentlyContinue

            Add-Check 'Network' 'Gateway ping' `
                $(if ($GatewayOK) { 'Responding' } else { 'No ping response' }) `
                $(if ($GatewayOK) { 'PASS' } else { 'WARNING' }) `
                'A failed ping may mean ICMP is blocked; verify other connectivity.'
        } else {
            Add-Check 'Network' 'Gateway ping' 'Skipped: no gateway' 'NOT TESTED'
        }
    } else {
        Add-Check 'Network' 'IPv4 configuration' `
            'No active adapter with IPv4 found' 'WARNING' `
            'Inspect adapter state and IP configuration.'
    }
}
catch {
    Add-Check 'Network' 'Network configuration' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 4. DNS RESOLUTION
# ------------------------------------------------------------

try {
    Resolve-DnsName 'microsoft.com' -ErrorAction Stop |
        Select-Object -First 1 | Out-Null

    Add-Check 'Network' 'DNS resolution' `
        'microsoft.com resolved successfully' 'PASS'
}
catch {
    Add-Check 'Network' 'DNS resolution' `
        'Test hostname did not resolve' 'WARNING' `
        'Check DNS configuration, network access and whether external DNS is allowed.'
}

# ------------------------------------------------------------
# 5. EXTERNAL HTTPS CONNECTIVITY
# ------------------------------------------------------------

try {
    $InternetTest = Test-NetConnection `
        -ComputerName 'www.microsoft.com' `
        -Port 443 -InformationLevel Quiet `
        -WarningAction SilentlyContinue

    Add-Check 'Network' 'External HTTPS connectivity' `
        $(if ($InternetTest) { 'TCP port 443 reachable' } else { 'TCP port 443 failed' }) `
        $(if ($InternetTest) { 'PASS' } else { 'WARNING' }) `
        'A failure may be caused by a proxy, firewall, DNS or restricted internet access.'
}
catch {
    Add-Check 'Network' 'External HTTPS connectivity' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 6. INTERNET PING QUALITY (PACKET LOSS / LATENCY)
# Merged from the Network Troubleshooting Toolkit.
# ICMP may be blocked; interpret failed pings with other checks.
# ------------------------------------------------------------

$InternetTarget = '1.1.1.1'
$PingCount = 10
try {
    $PingResults = @(
        Test-Connection -ComputerName $InternetTarget -Count $PingCount `
            -ErrorAction SilentlyContinue
    )

    $Received = $PingResults.Count
    $Lost = [math]::Max(0, $PingCount - $Received)
    $PacketLoss = [math]::Round(($Lost / $PingCount) * 100, 2)

    $LatencyValues = @(
        $PingResults | ForEach-Object {
            if ($null -ne $_.Latency) { [double]$_.Latency }
            elseif ($null -ne $_.ResponseTime) { [double]$_.ResponseTime }
        } | Where-Object { $null -ne $_ }
    )

    if ($LatencyValues.Count -gt 0) {
        $AvgLatency = [math]::Round(($LatencyValues | Measure-Object -Average).Average, 2)
        $MinLatency = [math]::Round(($LatencyValues | Measure-Object -Minimum).Minimum, 2)
        $MaxLatency = [math]::Round(($LatencyValues | Measure-Object -Maximum).Maximum, 2)
    } else {
        $AvgLatency = 'N/A'
        $MinLatency = 'N/A'
        $MaxLatency = 'N/A'
    }

    $PingStatus = if ($Received -gt 0) { 'PASS' } else { 'WARNING' }
    Add-Check 'Network Quality' "Ping $InternetTarget" `
        "$Received of $PingCount responses received" $PingStatus `
        'A failed ping may mean ICMP is blocked; compare with DNS and HTTPS results.'

    $LossStatus = if ($PacketLoss -eq 0) { 'PASS' } else { 'WARNING' }
    Add-Check 'Network Quality' 'Packet loss' `
        "$PacketLoss% ($Lost lost / $PingCount sent)" $LossStatus `
        'Repeat the test at different times; brief ICMP tests do not prove a persistent fault.'

    $LatencyStatus = if ($LatencyValues.Count -eq 0) { 'NOT TESTED' } else { 'INFO' }
    Add-Check 'Network Quality' 'Average / minimum / maximum latency' `
        "$AvgLatency / $MinLatency / $MaxLatency ms" $LatencyStatus `
        'Compare latency with the normal baseline for this network.'
}
catch {
    Add-Check 'Network Quality' 'Internet ping quality test' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 7. NETWORK ADAPTER STATE
# ------------------------------------------------------------

try {
    $Adapters = Get-NetAdapter -ErrorAction Stop

    foreach ($Adapter in $Adapters) {
        $AdapterStatus = if ($Adapter.Status -eq 'Up') {
            'PASS'
        } else { 'WARNING' }

        Add-Check 'Network Adapter' $Adapter.Name `
            "$($Adapter.Status) - $($Adapter.InterfaceDescription)" `
            $AdapterStatus 'Check disconnected adapters if they are expected to be in use.'
    }
}
catch {
    Add-Check 'Network Adapter' 'Adapter inspection' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 8. DHCP CLIENT SERVICE
# ------------------------------------------------------------

try {
    $Dhcp = Get-Service -Name 'Dhcp' -ErrorAction Stop

    Add-Check 'Network Services' 'DHCP Client service' `
        $Dhcp.Status.ToString() `
        $(if ($Dhcp.Status -eq 'Running') { 'PASS' } else { 'WARNING' }) `
        'Check DHCP service and address assignment if automatic IP configuration is expected.'
}
catch {
    Add-Check 'Network Services' 'DHCP Client service' `
        'Unable to inspect service' 'WARNING'
}

# ------------------------------------------------------------
# 9. PRINT SPOOLER
# ------------------------------------------------------------

try {
    $Spooler = Get-Service -Name 'Spooler' -ErrorAction Stop

    Add-Check 'Printing' 'Print Spooler service' `
        $Spooler.Status.ToString() `
        $(if ($Spooler.Status -eq 'Running') { 'PASS' } else { 'WARNING' }) `
        'If printing is expected, investigate the service and printer queue.'
}
catch {
    Add-Check 'Printing' 'Print Spooler service' `
        'Unable to inspect service' 'WARNING'
}

# ------------------------------------------------------------
# 10. PRINTER QUEUE INSPECTION
# ------------------------------------------------------------

try {
    $Printers = @(Get-Printer -ErrorAction Stop)

    if ($Printers.Count -eq 0) {
        Add-Check 'Printing' 'Installed printers' `
            'No printers returned by Get-Printer' 'INFO'
    }

    foreach ($Printer in $Printers) {
        $PrinterStatus = if (
            $Printer.PrinterStatus -eq 'Normal' -or
            $Printer.PrinterStatus -eq 0
        ) { 'PASS' } else { 'WARNING' }

        Add-Check 'Printing' "Printer: $($Printer.Name)" `
            "Status: $($Printer.PrinterStatus); Driver: $($Printer.DriverName)" `
            $PrinterStatus 'Confirm printer availability and inspect its queue if jobs are stuck.'
    }

    try {
        $Jobs = @(Get-PrintJob -PrinterName '*' -ErrorAction Stop)
        Add-Check 'Printing' 'Visible queued jobs' `
            "$($Jobs.Count) job(s) returned" 'INFO'
    }
    catch {
        Add-Check 'Printing' 'Queued jobs' `
            'Queue enumeration unavailable or unsupported' 'NOT TESTED'
    }
}
catch {
    Add-Check 'Printing' 'Printer inspection' `
        'Printer cmdlets unavailable or access denied' 'NOT TESTED'
}

# ------------------------------------------------------------
# 11. INSTALLED SOFTWARE
# ------------------------------------------------------------

try {
    $RegistryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $InstalledApps = @(
        foreach ($Path in $RegistryPaths) {
            Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName }
        }
    ) | Sort-Object DisplayName -Unique

    Add-Check 'Software' 'Registered installed applications' `
        "$($InstalledApps.Count) entries found" 'INFO'

    $RequiredApp = 'Microsoft Office'
    $AppFound = $InstalledApps |
        Where-Object { $_.DisplayName -like "*$RequiredApp*" } |
        Select-Object -First 1

    Add-Check 'Software' 'Example application check' `
        $(if ($AppFound) { $AppFound.DisplayName } else { "$RequiredApp not detected" }) `
        $(if ($AppFound) { 'PASS' } else { 'INFO' }) `
        'Edit RequiredApp to match software actually required by the organization.'
}
catch {
    Add-Check 'Software' 'Installed application inspection' `
        $_.Exception.Message 'WARNING'
}

# ------------------------------------------------------------
# 12. WINDOWS ACTIVATION
# ------------------------------------------------------------

try {
    $Licenses = @(
        Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object {
                $_.PartialProductKey -and
                $_.Name -like 'Windows*'
            }
    )

    $Activated = $Licenses |
        Where-Object { $_.LicenseStatus -eq 1 } |
        Select-Object -First 1

    Add-Check 'Licensing' 'Windows activation' `
        $(if ($Activated) { 'Activated' } else { 'Activation not confirmed' }) `
        $(if ($Activated) { 'PASS' } else { 'WARNING' }) `
        'Confirm status with the organization administrator; edition and licensing configuration matter.'
}
catch {
    Add-Check 'Licensing' 'Windows activation' `
        'Unable to query licensing status' 'NOT TESTED'
}

# ------------------------------------------------------------
# 13. WINDOWS UPDATE EVENT LOG
# ------------------------------------------------------------

try {
    $UpdateEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-WindowsUpdateClient/Operational'
            Level = 2
            StartTime = (Get-Date).AddDays(-7)
        } -MaxEvents 20 -ErrorAction Stop
    )

    Add-Check 'Windows Update' 'Recent update error events' `
        "$($UpdateEvents.Count) error event(s) in the last 7 days" `
        $(if ($UpdateEvents.Count -gt 0) { 'WARNING' } else { 'PASS' }) `
        'Review event details and error codes; not every event indicates a current failure.'
}
catch {
    Add-Check 'Windows Update' 'Update event log' `
        'Log unavailable or no matching events returned' 'INFO'
}

# ------------------------------------------------------------
# 14. UNEXPECTED SHUTDOWNS / CRASH EVENTS
# ------------------------------------------------------------

try {
    $SystemEvents = @(
        Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Id = @(41, 6008)
            StartTime = (Get-Date).AddDays(-7)
        } -MaxEvents 20 -ErrorAction Stop
    )

    Add-Check 'System Events' 'Unexpected shutdown events' `
        "$($SystemEvents.Count) event(s) in the last 7 days" `
        $(if ($SystemEvents.Count -gt 0) { 'WARNING' } else { 'PASS' }) `
        'Review event timestamps and surrounding events to investigate the cause.'
}
catch {
    Add-Check 'System Events' 'Unexpected shutdown events' `
        'Event log query unavailable' 'INFO'
}

# ------------------------------------------------------------
# 15. ENDPOINT PROTECTION SERVICE CHECKS
# ------------------------------------------------------------

foreach ($ServiceName in @('WinDefend', 'Sense')) {
    try {
        $SecurityService = Get-Service -Name $ServiceName `
            -ErrorAction Stop

        Add-Check 'Security' "$ServiceName service" `
            $SecurityService.Status.ToString() `
            $(if ($SecurityService.Status -eq 'Running') { 'PASS' } else { 'WARNING' }) `
            'Confirm expected state in the organization-approved security platform.'
    }
    catch {
        Add-Check 'Security' "$ServiceName service" `
            'Not present or inaccessible' 'INFO' `
            'This service may not be installed or used by this organization.'
    }
}

# ------------------------------------------------------------
# 16. SHARED FOLDER ACCESS (OPTIONAL)
# ------------------------------------------------------------

if ($SharedPath) {
    try {
        $ShareOK = Test-Path -LiteralPath $SharedPath -ErrorAction Stop

        Add-Check 'File Sharing' 'Configured shared path' `
            $(if ($ShareOK) { 'Path accessible' } else { 'Path inaccessible' }) `
            $(if ($ShareOK) { 'PASS' } else { 'WARNING' }) `
            'Verify VPN connectivity, DNS, share permissions and NTFS permissions.'
    }
    catch {
        Add-Check 'File Sharing' 'Configured shared path' `
            $_.Exception.Message 'WARNING'
    }
} else {
    Add-Check 'File Sharing' 'Configured shared path' `
        'Not configured; edit SharedPath to test an approved share' 'NOT TESTED'
}

# ------------------------------------------------------------
# 17. REPORT SUMMARY
# ------------------------------------------------------------

$PassCount = @($Results | Where-Object Status -eq 'PASS').Count
$WarningCount = @($Results | Where-Object Status -eq 'WARNING').Count
$FailCount = @($Results | Where-Object Status -eq 'FAIL').Count
$InfoCount = @($Results | Where-Object Status -eq 'INFO').Count
$NotTestedCount = @($Results | Where-Object Status -eq 'NOT TESTED').Count

# CSV export
$Results | Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8

# HTML-encode report data
$HtmlRows = foreach ($Result in $Results) {
    $C = [System.Net.WebUtility]::HtmlEncode([string]$Result.Category)
    $K = [System.Net.WebUtility]::HtmlEncode([string]$Result.Check)
    $V = [System.Net.WebUtility]::HtmlEncode([string]$Result.Value)
    $S = [System.Net.WebUtility]::HtmlEncode([string]$Result.Status)
    $StatusClass = ([string]$Result.Status).Replace(' ', '_')
    $R = [System.Net.WebUtility]::HtmlEncode([string]$Result.Recommendation)

    @"
<tr>
<td>$C</td>
<td>$K</td>
<td>$V</td>
<td><span class="badge $StatusClass">$S</span></td>
<td>$R</td>
</tr>
"@
}

$Generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$ComputerName = [System.Net.WebUtility]::HtmlEncode($env:COMPUTERNAME)
$OSName = [System.Net.WebUtility]::HtmlEncode(
    (Get-CimInstance Win32_OperatingSystem).Caption
)

$HTML = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Windows IT Support Diagnostic Report</title>
<style>
body {
    margin: 0;
    padding: 24px;
    background: #f1f5f9;
    color: #172033;
    font-family: Segoe UI, Arial, sans-serif;
}
main { max-width: 1400px; margin: auto; }
header {
    background: #14213d;
    color: white;
    padding: 28px;
    border-radius: 12px;
}
.cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: 12px;
    margin: 20px 0;
}
.card {
    background: white;
    border-radius: 10px;
    padding: 18px;
    box-shadow: 0 2px 8px #0000000d;
}
.number { font-size: 28px; font-weight: 700; }
.table-wrap { overflow-x: auto; }
table {
    width: 100%;
    border-collapse: collapse;
    background: white;
}
th, td {
    text-align: left;
    vertical-align: top;
    padding: 12px;
    border-bottom: 1px solid #e2e8f0;
}
th { background: #e2e8f0; }
.badge {
    display: inline-block;
    border-radius: 5px;
    padding: 4px 7px;
    font-weight: 700;
    white-space: nowrap;
}
.PASS { background: #dcfce7; color: #166534; }
.WARNING { background: #fef3c7; color: #92400e; }
.FAIL { background: #fee2e2; color: #991b1b; }
.INFO { background: #dbeafe; color: #1e40af; }
.NOT_TESTED { background: #e5e7eb; color: #374151; }
footer { margin-top: 22px; color: #64748b; }
@media print {
    body { background: white; padding: 0; }
    header { background: #14213d !important; }
}
</style>
</head>
<body>
<main>
<header>
<h1>Windows IT Support Toolkit</h1>
<p>System Diagnostic &amp; Health Report</p>
<p>Computer: $ComputerName</p>
<p>Operating System: $OSName</p>
<p>Generated: $Generated</p>
<p>Designed by: MUHAMMED SHAFI AM</p>
<p>LinkedIn: linkedin.com/in/muhammedshafiam2001</p>
</header>

<div class="cards">
<div class="card"><div>Passed</div><div class="number">$PassCount</div></div>
<div class="card"><div>Warnings</div><div class="number">$WarningCount</div></div>
<div class="card"><div>Failed</div><div class="number">$FailCount</div></div>
<div class="card"><div>Informational</div><div class="number">$InfoCount</div></div>
<div class="card"><div>Not tested</div><div class="number">$NotTestedCount</div></div>
</div>

<h2>Diagnostic Results</h2>
<p>PASS means the check met its basic test. WARNING indicates investigation may be needed.
INFO is informational. NOT TESTED means the check was skipped or unavailable.
A successful check does not guarantee the entire system is healthy.</p>

<div class="table-wrap">
<table>
<thead>
<tr><th>Category</th><th>Check</th><th>Result</th><th>Status</th><th>Recommended next step</th></tr>
</thead>
<tbody>
$($HtmlRows -join "`n")
</tbody>
</table>
</div>

<footer>
<p>Generated by NEXUS WINDOWS IT DIAGNOSTICS v3.0.</p>
<p>Designed by MUHAMMED SHAFI AM | LinkedIn: linkedin.com/in/muhammedshafiam2001</p>
<p>Read-only diagnostic checks; no automatic repairs were performed.</p>
</footer>
</main>
</body>
</html>
"@

$HTML | Set-Content -Path $ReportFile -Encoding UTF8

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' DIAGNOSTICS COMPLETED' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "Checks performed: $($Results.Count)"
Write-Host "Passed:           $PassCount" -ForegroundColor Green
Write-Host "Warnings:         $WarningCount" -ForegroundColor Yellow
Write-Host "Failed:           $FailCount" -ForegroundColor Red
Write-Host "Informational:    $InfoCount"
Write-Host "Not tested:       $NotTestedCount"
Write-Host ''
Write-Host "HTML report: $ReportFile" -ForegroundColor Cyan
Write-Host "CSV report:  $CsvFile" -ForegroundColor Cyan
#designed by : MUHAMMED SHAFI AM
# Open the HTML report on a local interactive computer.
# For PowerShell Remoting, leave this commented out.
# Start-Process $ReportFile
try { Start-Process -FilePath $ReportFile -ErrorAction SilentlyContinue } catch { }
