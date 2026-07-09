Start-Transcript -Path "C:\ot\llama.cpp\optimize-log.txt" -Force
# =============================================================================
# LLM-Dedicated Machine Optimization Script
# MSI Titan 18 HX - i9-14900HX / RTX 4090 / 128GB DDR5
# =============================================================================
# WARNING: This disables many Windows features. Only use on a dedicated LLM box.
# To revert, re-enable services manually or restore from a system restore point.
# =============================================================================

Write-Host "=== LLM Server Optimization ===" -ForegroundColor Cyan

# ---- 1. Power Plan: Ultimate Performance ----
Write-Host "`n[1/8] Setting Ultimate Performance power plan..." -ForegroundColor Yellow
# Unhide and activate Ultimate Performance plan
powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
$ultimatePlan = powercfg /list | Select-String "Ultimate Performance"
if ($ultimatePlan -match '([a-f0-9-]{36})') {
    powercfg /setactive $Matches[1]
    Write-Host "  Activated Ultimate Performance plan" -ForegroundColor Green
} else {
    # Fallback to High Performance
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    Write-Host "  Activated High Performance plan (Ultimate not available)" -ForegroundColor Green
}
# Disable USB selective suspend, hard disk timeout, sleep, hibernate
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /hibernate off

# ---- 2. Disable unnecessary services ----
Write-Host "`n[2/8] Disabling unnecessary services..." -ForegroundColor Yellow
$servicesToDisable = @(
    # Print
    "Spooler",              # Print Spooler

    # Search & Indexing
    "WSearch",              # Windows Search

    # Superfetch/Prefetch (useless for server workload)
    "SysMain",

    # Audio (headless server doesn't need it)
    "Audiosrv",             # Windows Audio
    "AudioEndpointBuilder", # Windows Audio Endpoint Builder
    "NahimicService",       # Nahimic bloatware

    # Wireless (use ethernet for LLM serving)
    "WlanSvc",              # WLAN AutoConfig
    "icssvc",               # Mobile Hotspot

    # Misc bloat
    "lfsvc",                # Geolocation
    "SSDPSRV",              # SSDP Discovery (UPnP)
    "SharedAccess",         # Internet Connection Sharing
    "RmSvc",                # Radio Management
    "WpnService",           # Push Notifications System
    "WpnUserService_*",     # Push Notifications User
    "DiagTrack",            # Connected User Experiences and Telemetry
    "dmwappushservice",     # WAP Push Message Routing
    "MapsBroker",           # Downloaded Maps Manager
    "TabletInputService",   # Touch Keyboard
    "wisvc",                # Windows Insider Service
    "WerSvc",               # Windows Error Reporting
    "TbtHostControllerService",  # Thunderbolt (unless using TB peripherals)
    "TbtP2pShortcutService",
    "KillerSmartphoneSleepService",  # Killer bloat
    "KNDBWM",               # Killer Dynamic Bandwidth Management
    "Killer Analytics Service",

    # OneDrive sync
    "OneSyncSvc_*",

    # Delivery Optimization (Windows Update P2P)
    "DoSvc",

    # Themes & visual
    "Themes"
)

foreach ($svc in $servicesToDisable) {
    if ($svc -match '\*') {
        Get-Service -Name $svc -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Service $_.Name -Force -ErrorAction SilentlyContinue
            Set-Service $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  Disabled: $($_.DisplayName)" -ForegroundColor DarkGray
        }
    } else {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  Disabled: $($s.DisplayName)" -ForegroundColor DarkGray
        }
    }
}

# ---- 3. Disable Windows Defender real-time protection ----
Write-Host "`n[3/8] Disabling Windows Defender real-time monitoring..." -ForegroundColor Yellow
# Add exclusion for the entire model directory and Docker
Add-MpPreference -ExclusionPath "C:\ot\llama.cpp" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\ProgramData\Docker" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionPath "C:\Users\albert\AppData\Local\Docker" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "docker.exe" -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "com.docker.backend.exe" -ErrorAction SilentlyContinue
# Reduce Defender CPU usage
Set-MpPreference -ScanAvgCPULoadFactor 5 -ErrorAction SilentlyContinue
# Disable scheduled scans
Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
Write-Host "  Added exclusions and reduced scan CPU load" -ForegroundColor Green
Write-Host "  NOTE: To fully disable Defender, use Group Policy or Windows Security UI" -ForegroundColor DarkYellow

# ---- 4. WSL2 ----
Write-Host "`n[4/8] WSL2: no limits applied (per user preference)" -ForegroundColor Yellow

# ---- 5. Disable visual effects ----
Write-Host "`n[5/8] Disabling visual effects..." -ForegroundColor Yellow
# Set to "Adjust for best performance"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue
# Disable transparency
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -ErrorAction SilentlyContinue
# Disable animations
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -ErrorAction SilentlyContinue
Write-Host "  Visual effects minimized" -ForegroundColor Green

# ---- 6. Disable startup programs ----
Write-Host "`n[6/8] Disabling startup programs..." -ForegroundColor Yellow
$startupToDisable = @(
    "OneDrive",
    "MicrosoftEdgeAutoLaunch*",
    "SecurityHealth*"
)
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)
foreach ($regPath in $regPaths) {
    $entries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if ($entries) {
        foreach ($pattern in $startupToDisable) {
            $entries.PSObject.Properties | Where-Object { $_.Name -like $pattern } | ForEach-Object {
                Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction SilentlyContinue
                Write-Host "  Removed startup: $($_.Name)" -ForegroundColor DarkGray
            }
        }
    }
}

# ---- 7. NVIDIA GPU optimizations ----
Write-Host "`n[7/8] Applying NVIDIA optimizations..." -ForegroundColor Yellow
# Set GPU to prefer maximum performance
& nvidia-smi -pm 1 2>$null                          # Persistence mode
& nvidia-smi --power-limit=175 2>$null              # Max TDP for 4090 Mobile
& nvidia-smi -ac 9501,2520 2>$null                  # Max clocks (may vary)
# Disable ECC if enabled (frees ~5% VRAM)
& nvidia-smi -e 0 2>$null
Write-Host "  GPU set to max performance mode" -ForegroundColor Green

# ---- 8. System memory optimizations ----
Write-Host "`n[8/8] Applying memory optimizations..." -ForegroundColor Yellow
# Disable page file (128GB RAM is enough, avoid swapping which kills LLM perf)
# WARNING: Only do this with 128GB RAM on a dedicated LLM box
$cs = Get-CimInstance Win32_ComputerSystem
$cs | Set-CimInstance -Property @{AutomaticManagedPagefile=$false}
$pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
if ($pf) {
    $pf | Remove-CimInstance -ErrorAction SilentlyContinue
    Write-Host "  Page file will be removed on next reboot" -ForegroundColor Green
} else {
    Write-Host "  Page file already unmanaged" -ForegroundColor Green
}

# Increase system responsiveness for background services
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 24 -ErrorAction SilentlyContinue
Write-Host "  Priority set to favor background services" -ForegroundColor Green

# ---- Summary ----
Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host @"

Actions completed. Manual steps remaining:

1. BIOS: Enable XMP/EXPO profile to run RAM at 5600MHz (currently 3600MHz)
   - Reboot > Enter BIOS (DEL key) > OC settings > Enable XMP Profile
   - This alone is a ~55% memory bandwidth improvement

2. Reboot to apply: page file removal, visual effects, startup changes

3. After reboot, restart Docker and the container:
   wsl --shutdown
   docker compose up -d

4. Optional - fully disable Defender via Group Policy:
   gpedit.msc > Computer Config > Admin Templates > Windows Components
   > Microsoft Defender Antivirus > Turn off Microsoft Defender Antivirus = Enabled

"@ -ForegroundColor White
