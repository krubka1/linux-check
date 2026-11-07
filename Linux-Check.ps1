# Linux-Check.ps1 - quick "will Linux run on this PC?" report. Read-only, changes nothing.
$ErrorActionPreference = 'SilentlyContinue'
$script:warn = 0; $script:bad = 0

function Show($level, $label, $text) {
    $color = @{ OK = 'Green'; WARN = 'Yellow'; BAD = 'Red'; INFO = 'Cyan' }[$level]
    if ($level -eq 'WARN') { $script:warn++ }
    if ($level -eq 'BAD')  { $script:bad++ }
    Write-Host ("[{0,-4}] " -f $level) -ForegroundColor $color -NoNewline
    Write-Host ("{0,-14} {1}" -f $label, $text)
}

Write-Host "`n=== Linux Compatibility Check ===`n" -ForegroundColor White

# Machine
$cs = Get-CimInstance Win32_ComputerSystem
Show INFO 'Machine' ("{0} {1}" -f $cs.Manufacturer, $cs.Model)

# CPU
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Show INFO 'CPU' $cpu.Name
if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
    Show WARN 'Architecture' 'ARM64: most distros work, but hardware support (Snapdragon laptops) is still rough.'
} elseif ([Environment]::Is64BitOperatingSystem) {
    Show OK 'Architecture' '64-bit x86'
} else {
    Show BAD 'Architecture' '32-bit only: most modern distros will not run.'
}

# RAM
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
if ($ramGB -ge 4)     { Show OK   'RAM' "$ramGB GB" }
elseif ($ramGB -ge 2) { Show WARN 'RAM' "$ramGB GB: use a lightweight distro (Xfce/LXQt)." }
else                  { Show BAD  'RAM' "$ramGB GB: too low for most desktops." }

# Disk
$sys = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
$freeGB = [math]::Round($sys.FreeSpace / 1GB, 0)
if ($freeGB -ge 40)     { Show OK   'Free disk' "$freeGB GB on $($env:SystemDrive)" }
elseif ($freeGB -ge 20) { Show WARN 'Free disk' "$freeGB GB on $($env:SystemDrive): OK for dual boot, but tight." }
else                    { Show BAD  'Free disk' "$freeGB GB on $($env:SystemDrive): not enough for dual boot." }

# Firmware / Secure Boot
$sbKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State'
if (Test-Path $sbKey) {
    Show OK 'Firmware' 'UEFI'
    $sb = (Get-ItemProperty $sbKey).UEFISecureBootEnabled
    if ($sb -eq 1) { Show WARN 'Secure Boot' 'On. Most big distros (Ubuntu, Fedora, Mint) boot fine; others need it off.' }
    else           { Show OK   'Secure Boot' 'Off' }
} else {
    Show WARN 'Firmware' 'Legacy BIOS (or undetectable). Linux works, but dual boot with Windows needs care.'
}

# Storage controller (Intel RST / VMD / RAID can hide the NVMe drive from the installer)
$stor = Get-CimInstance Win32_SCSIController | Where-Object { $_.Name -match 'RAID|VMD|Rapid Storage' }
if ($stor) {
    Show WARN 'Storage' ("{0}: switch SATA mode to AHCI in BIOS first, or the installer may see no disk." -f $stor[0].Name)
} else {
    Show OK 'Storage' 'No RAID/VMD controller detected'
}

# GPU
$gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual' })
foreach ($g in $gpus) {
    if     ($g.Name -match 'Intel')       { Show OK   'GPU' "$($g.Name): excellent open-source driver." }
    elseif ($g.Name -match 'AMD|Radeon')  { Show OK   'GPU' "$($g.Name): excellent open-source driver." }
    elseif ($g.Name -match 'NVIDIA')      { Show WARN 'GPU' "$($g.Name): works, but best with the proprietary driver (easy on Ubuntu/Mint)." }
    else                                  { Show INFO 'GPU' $g.Name }
}
if ($gpus.Count -gt 1) { Show INFO 'GPU' 'Hybrid graphics: works, but switching takes some setup.' }

# Wi-Fi
$nics = @(Get-NetAdapter -Physical | Where-Object { $_.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN' })
foreach ($n in $nics) {
    $d = $n.InterfaceDescription
    if     ($d -match 'Intel|Qualcomm|Atheros') { Show OK   'Wi-Fi' "${d}: well supported." }
    elseif ($d -match 'MediaTek|Ralink')        { Show OK   'Wi-Fi' "${d}: generally fine on a recent kernel." }
    elseif ($d -match 'Realtek')                { Show WARN 'Wi-Fi' "${d}: usually works on a new kernel; some models need extra drivers." }
    elseif ($d -match 'Broadcom')               { Show WARN 'Wi-Fi' "${d}: often needs a proprietary driver; keep Ethernet/USB tethering handy." }
    else                                        { Show INFO 'Wi-Fi' $d }
}
if (-not $nics) { Show INFO 'Wi-Fi' 'No Wi-Fi adapter found.' }

# Hit-or-miss hardware
$pnp = Get-CimInstance Win32_PnPEntity
if ($pnp | Where-Object { $_.Name -match 'Fingerprint|Biometric' }) {
    Show WARN 'Fingerprint' 'Reader found: support depends on the exact model.'
}
if ($pnp | Where-Object { $_.Name -match 'Windows Hello Face|IR Camera|Infrared' }) {
    Show WARN 'Face login' 'IR camera found: Windows Hello-style login usually will not work.'
}

# Known-device database (devices.json): match PCI/USB IDs against hand-curated rules
Write-Host "`nKnown-device scan:" -ForegroundColor White
$dbFile = Join-Path $PSScriptRoot 'devices.json'
if (Test-Path $dbFile) {
    $db = Get-Content $dbFile -Raw | ConvertFrom-Json
    $seen = @{}
    $unknown = @()
    foreach ($d in (Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match '^(PCI|USB)\\' })) {
        if     ($d.PNPDeviceID -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})') { $v = $Matches[1].ToLower(); $p = $Matches[2].ToLower() }
        elseif ($d.PNPDeviceID -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') { $v = $Matches[1].ToLower(); $p = $Matches[2].ToLower() }
        else { continue }
        $key = "${v}:${p}"
        if ($seen[$key]) { continue }
        $seen[$key] = $true
        $rule = $db | Where-Object { $_.id -eq $key } | Select-Object -First 1
        if (-not $rule) { $rule = $db | Where-Object { $_.id -eq "${v}:*" } | Select-Object -First 1 }
        if ($rule -and $rule.status -ne 'INFO') {
            if ($rule.status -eq 'OK') { continue }   # keep output short: only show risks
            Show $rule.status $key ("{0} ({1}): {2}" -f $rule.name, $d.Name, $rule.note)
        } elseif (-not $rule -and $d.Name -match 'Wi-?Fi|Wireless|Bluetooth|Fingerprint|Camera|Touch') {
            $unknown += "$key $($d.Name)"
        }
    }
    foreach ($u in $unknown) { Show INFO 'Not in DB' "$u - look it up on linux-hardware.org" }
    Write-Host "(Database is small and hand-curated. 'Nothing flagged' means nothing KNOWN, not that all is fine.)" -ForegroundColor DarkGray
} else {
    Show INFO 'Database' 'devices.json not found next to the script; skipped.'
}

# Hardware IDs for lookup (linux-hardware.org / kernel driver lists)
$ids = @()
$ids += Get-NetAdapter -Physical | ForEach-Object { "NET   " + $_.InterfaceDescription + "  " + (Get-PnpDeviceProperty -InstanceId $_.PnPDeviceID -KeyName DEVPKEY_Device_HardwareIds).Data[0] }
$ids += Get-CimInstance Win32_VideoController | ForEach-Object { "GPU   " + $_.Name + "  " + $_.PNPDeviceID }
$ids += Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'Bluetooth|Audio|Touchpad|Camera|Webcam|Fingerprint' -and $_.PNPDeviceID -match '^(PCI|USB)' } | ForEach-Object { "DEV   " + $_.Name + "  " + $_.PNPDeviceID }
$outDir = if ($env:LINUXCHECK_OUT) { $env:LINUXCHECK_OUT } else { $PSScriptRoot }
$report = Join-Path $outDir 'linux-check-report.txt'
@("Machine: $($cs.Manufacturer) $($cs.Model)", "BIOS: $((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion)", "") + $ids | Set-Content $report

# Verdict
Write-Host "`n--- Verdict ---" -ForegroundColor White
if ($bad -gt 0) {
    Write-Host "NO-GO: $bad blocking problem(s). Do not install until fixed." -ForegroundColor Red
} elseif ($warn -gt 0) {
    Write-Host "CAUTION: $warn known risk(s) above. Likely works, but some feature may need manual setup." -ForegroundColor Yellow
} else {
    Write-Host "GO: no known problems found." -ForegroundColor Green
}
Write-Host "`nThis is NOT a guarantee. The checks only cover known problem areas."
Write-Host "To be sure: boot a live USB (Ubuntu/Fedora/Mint) and test Wi-Fi, sound, suspend and brightness."
Write-Host "Hardware IDs saved to: $report"
Write-Host "Look them up at https://linux-hardware.org (search your model) to see real-world results.`n"
Write-Host "Tip: back up your data and your BitLocker recovery key before installing.`n"
