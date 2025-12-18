Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host " ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "  This script requires administrator privileges to run." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please run PowerShell as Administrator and try again:" -ForegroundColor White
    Write-Host "  1. Right-click PowerShell" -ForegroundColor Cyan
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor Cyan
    Write-Host "  3. Run: iwr -useb pelvis.site/quickhelp.ps1 | iex" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-SectionHeader "Checking Windows Version"

$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) {
    Write-Status "OK" "Windows 11 detected" "Green"
}
else {
    Write-Status "ERROR" "This script requires Windows 11" "Red"
    Write-Detail "Windows Hello disabling may not work on older versions"
    Show-Notification -Title "Unsupported OS" -Message "This script requires Windows 11." -Icon Error
    exit 1
}

function Show-Notification {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )
    
    $notification = New-Object System.Windows.Forms.NotifyIcon
    $notification.Icon = [System.Drawing.SystemIcons]::Information
    $notification.BalloonTipIcon = $Icon
    $notification.BalloonTipText = $Message
    $notification.BalloonTipTitle = $Title
    $notification.Visible = $true
    $notification.ShowBalloonTip(5000)
    
    $iconType = switch ($Icon) {
        "Error" { [System.Windows.MessageBoxImage]::Error }
        "Warning" { [System.Windows.MessageBoxImage]::Warning }
        "Info" { [System.Windows.MessageBoxImage]::Information }
        default { [System.Windows.MessageBoxImage]::Information }
    }
    
    [System.Windows.MessageBox]::Show($Message, $Title, [System.Windows.MessageBoxButton]::OK, $iconType) | Out-Null
    Start-Sleep -Milliseconds 500
    $notification.Dispose()
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor DarkGray
}

function Write-Status {
    param([string]$Status, [string]$Message, [string]$Color = "White")
    Write-Host "  [$Status] $Message" -ForegroundColor $Color
}

function Write-Detail {
    param([string]$Message)
    Write-Host "    > $Message" -ForegroundColor DarkGray
}


Write-SectionHeader "Checking TPM Status"

try {
    $tpm = Get-Tpm -ErrorAction Stop
    
    if ($tpm.TpmPresent -and $tpm.TpmEnabled) {
        Write-Status "OK" "TPM is present and enabled" "Green"
    } 
    elseif ($tpm.TpmPresent -and -not $tpm.TpmEnabled) {
        Write-Status "ERROR" "TPM is present but NOT enabled" "Red"
        Write-Detail "Please enable TPM in BIOS/UEFI settings"
        Show-Notification -Title "TPM Not Enabled" -Message "TPM is present but not enabled. Please enable it in BIOS/UEFI settings." -Icon Error
    } 
    else {
        Write-Status "ERROR" "TPM is NOT present on this system" "Red"
        Write-Detail "TPM hardware is required for this application"
        Show-Notification -Title "TPM Missing" -Message "TPM is not present on this system. TPM hardware is required." -Icon Error
    }
} 
catch {
    Write-Status "ERROR" "Unable to check TPM status" "Red"
    Write-Detail "Error: $($_.Exception.Message)"
    Show-Notification -Title "TPM Check Failed" -Message "Unable to verify TPM status. Error occurred." -Icon Warning
}

Write-SectionHeader "Checking AVX2 Support"

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class CPUChecker {
    [DllImport("kernel32.dll")]
    static extern bool IsProcessorFeaturePresent(int processorFeature);
    
    public static bool CheckAVX() {
        const int PF_AVX_INSTRUCTIONS_AVAILABLE = 17;
        return IsProcessorFeaturePresent(PF_AVX_INSTRUCTIONS_AVAILABLE);
    }
}
"@
    
    $hasAVX = [CPUChecker]::CheckAVX()
    
    if (-not $hasAVX) {
        Write-Status "ERROR" "AVX is NOT supported on this CPU" "Red"
        Write-Detail "AVX2 requires AVX support as a prerequisite"
        Show-Notification -Title "AVX Not Supported" -Message "AVX instructions are not available on your CPU. AVX2 requires AVX support." -Icon Error
    }
    else {
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $cpuBrand = $cpu.Name
        $avx2Supported = $false
        
        try {
            $cpuInfo = @"
using System;

public class AVX2Detector {
    public static bool DetectAVX2() {
        try {
            var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"HARDWARE\DESCRIPTION\System\CentralProcessor\0");
            if (key != null) {
                var features = key.GetValue("FeatureSet");
                if (features != null) {
                    int featureSet = (int)features;
                    return featureSet >= 1536;
                }
            }
        } catch { }
        return false;
    }
}
"@
            Add-Type -TypeDefinition $cpuInfo
            $avx2Supported = [AVX2Detector]::DetectAVX2()
        }
        catch {
            if ($cpuBrand -match "i[3579]-[4-9]\d{3}" -or $cpuBrand -match "i[3579]-1[0-9]\d{3}" -or $cpuBrand -match "Ryzen" -or $cpuBrand -match "EPYC" -or $cpuBrand -match "Threadripper") {
                $avx2Supported = $true
            }
        }
        
        if ($avx2Supported) {
            Write-Status "OK" "AVX2 is supported on this CPU" "Green"
            Write-Detail "CPU: $cpuBrand"
        }
        else {
            Write-Status "WARNING" "AVX2 support could not be definitively confirmed" "Yellow"
            Write-Detail "CPU: $cpuBrand"
            Write-Detail "AVX is supported, but AVX2 detection requires additional tools"
        }
    }
} 
catch {
    Write-Status "WARNING" "Unable to verify AVX2 support" "Yellow"
    Write-Detail "Error: $($_.Exception.Message)"
}

Write-SectionHeader "Checking Windows Hello Registry"

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"

try {
    if (Test-Path $regPath) {
        $regKey = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        
        if ($null -ne $regKey -and $null -ne $regKey.Enabled) {
            if ($regKey.Enabled -eq 0) {
                Write-Status "OK" "Windows Hello is already disabled (Enabled = 0)" "Green"
            } 
            else {
                Write-SectionHeader "System Restore Point"

                Write-Host "Windows Hello is enabled. Before disabling, it's recommended to create a system restore point."
                $createRestorePoint = Read-Host "Do you want to create a system restore point? (Y/N)"
                if ($createRestorePoint -eq 'Y' -or $createRestorePoint -eq 'y') {
                    try {
                        Checkpoint-Computer -Description "Before disabling Windows Hello" -RestorePointType MODIFY_SETTINGS
                        Write-Status "OK" "System restore point created successfully" "Green"
                    }
                    catch {
                        Write-Status "ERROR" "Failed to create system restore point" "Red"
                        Write-Detail "Error: $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Status "INFO" "Skipping system restore point creation" "Cyan"
                }

                Write-Detail "Attempting to disable Windows Hello..."
                
                try {
                    Set-ItemProperty -Path $regPath -Name "Enabled" -Value 0 -ErrorAction Stop
                    Write-Status "OK" "Windows Hello has been disabled successfully" "Green"
                    Write-Detail "** A SYSTEM RESTART IS REQUIRED for this change to take effect **"
                    Show-Notification -Title "Windows Hello Disabled" -Message "Windows Hello has been disabled. RESTART YOUR SYSTEM for this to take effect." -Icon Info
                } 
                catch {
                    Write-Status "ERROR" "Failed to disable Windows Hello" "Red"
                    Write-Detail "Error: $($_.Exception.Message)"
                    Show-Notification -Title "Registry Modification Failed" -Message "Failed to modify Windows Hello setting." -Icon Warning
                }
            }
        } 
        else {
            Write-Status "INFO" "Windows Hello 'Enabled' value not found" "Cyan"
            Write-Detail "Creating registry value and setting to 0..."
            
            try {
                New-ItemProperty -Path $regPath -Name "Enabled" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                Write-Status "OK" "Windows Hello has been disabled successfully" "Green"
                Write-Detail "** A SYSTEM RESTART IS REQUIRED for this change to take effect **"
                Show-Notification -Title "Windows Hello Disabled" -Message "Windows Hello registry value created and set to disabled. RESTART YOUR SYSTEM for this to take effect." -Icon Info
            } 
            catch {
                Write-Status "ERROR" "Failed to create Windows Hello setting" "Red"
                Write-Detail "Error: $($_.Exception.Message)"
                Show-Notification -Title "Registry Creation Failed" -Message "Failed to create Windows Hello setting." -Icon Warning
            }
        }
    } 
    else {
        Write-Status "INFO" "Windows Hello registry path does not exist" "Cyan"
        Write-Detail "Creating registry path and disabling..."
        
        try {
            New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $regPath -Name "Enabled" -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Status "OK" "Windows Hello registry created and disabled" "Green"
            Write-Detail "** A SYSTEM RESTART IS REQUIRED for this change to take effect **"
            Show-Notification -Title "Windows Hello Disabled" -Message "Windows Hello registry path created and set to disabled. RESTART YOUR SYSTEM for this to take effect." -Icon Info
        } 
        catch {
            Write-Status "ERROR" "Failed to create registry path" "Red"
            Write-Detail "Error: $($_.Exception.Message)"
            Show-Notification -Title "Registry Creation Failed" -Message "Failed to create Windows Hello registry path." -Icon Warning
        }
    }
} 
catch {
    Write-Status "ERROR" "Error checking/modifying Windows Hello setting" "Red"
    Write-Detail "Error: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                   CHECK COMPLETE                               " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  TROUBLESHOOTING:" -ForegroundColor Yellow
Write-Host "  If you receive 'Running inside a VM is prohibited' after restart," -ForegroundColor White
Write-Host "  you need to disable virtualization in your BIOS settings." -ForegroundColor White
Write-Host "  Guide: https://wh.pelvis.site/" -ForegroundColor Cyan
Write-Host ""
Write-Host ""
Write-Host "  Official Support: https://fatality.win/tickets/" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Press any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
