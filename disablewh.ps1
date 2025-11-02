#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Hello Disabler for Windows 11
.DESCRIPTION
    Disables Windows Hello biometric authentication by modifying registry settings.
    If unsuccessful, virtualization must be disabled in BIOS.
.NOTES
    Author: pelvis
    Method discovered by: stormpike
    Version: 2.0
    Requires: Administrator privileges, Windows 11
#>

[CmdletBinding()]
param()

# Import required assemblies
Add-Type -AssemblyName System.Windows.Forms

#region Functions

function Show-MessageBox {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter(Mandatory)]
        [string]$Title,
        
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Windows11 {
    Write-Verbose "Detecting Windows version..."
    
    $isWin11 = $false
    $build = 0
    
    try {
        # Try registry method first
        $versionInfo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        
        if ($versionInfo.ProductName -match 'Windows 11') {
            $isWin11 = $true
        }
        
        # Check build number
        if ($versionInfo.PSObject.Properties.Name -contains 'CurrentBuildNumber') {
            $build = [int]$versionInfo.CurrentBuildNumber
        }
        elseif ($versionInfo.PSObject.Properties.Name -contains 'CurrentBuild') {
            $build = [int]$versionInfo.CurrentBuild
        }
        
        # Windows 11 starts at build 22000
        if ($build -ge 22000) {
            $isWin11 = $true
        }
    }
    catch {
        Write-Verbose "Registry check failed, trying WMI..."
        
        # Fallback to WMI
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $version = [version]$os.Version
            
            if ($version.Build -ge 22000) {
                $isWin11 = $true
            }
        }
        catch {
            Write-Warning "Unable to detect Windows version reliably."
        }
    }
    
    Write-Verbose "Windows 11 detected: $isWin11 (Build: $build)"
    return $isWin11
}

function Disable-WindowsHello {
    Write-Verbose "Attempting to disable Windows Hello via registry..."
    
    try {
        $registryPath = 'SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello'
        $localMachine = [Microsoft.Win32.Registry]::LocalMachine
        
        # Create or open the registry key
        $key = $localMachine.CreateSubKey($registryPath)
        
        if ($null -eq $key) {
            throw "Failed to create or open registry key: $registryPath"
        }
        
        # Set the default value to 0 (disabled)
        $key.SetValue('', 0, [Microsoft.Win32.RegistryValueKind]::DWord)
        $key.Close()
        
        Write-Verbose "Registry modification successful."
        return $true
    }
    catch {
        Write-Error "Registry modification failed: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Script

Write-Host "`n=== Windows Hello Disabler ===" -ForegroundColor Cyan
Write-Host "Version 2.0`n" -ForegroundColor Gray

# Check admin privileges
if (-not (Test-AdminPrivileges)) {
    Show-MessageBox `
        -Message "This script requires administrator privileges.`n`nPlease right-click PowerShell and select 'Run as administrator'." `
        -Title "Administrator Rights Required" `
        -Icon Warning
    
    Write-Error "Script requires administrator privileges."
    exit 1
}

Write-Host "[OK] Administrator privileges confirmed" -ForegroundColor Green

# Check Windows 11
if (-not (Test-Windows11)) {
    Show-MessageBox `
        -Message "This script is designed for Windows 11.`n`nFor other Windows versions, please disable virtualization in your BIOS settings.`n`nSearch online for: '[Your Motherboard Model] disable virtualization'" `
        -Title "Windows 11 Required" `
        -Icon Warning
    
    Write-Warning "Script is intended for Windows 11 only."
    exit 1
}

Write-Host "[OK] Windows 11 detected" -ForegroundColor Green

# Attempt to disable Windows Hello
Write-Host "`nDisabling Windows Hello..." -ForegroundColor Yellow

if (Disable-WindowsHello) {
    Show-MessageBox `
        -Message "Windows Hello has been successfully disabled!`n`n[OK] Registry modification complete`n`nPlease restart your computer for changes to take effect.`n`nNote: If Windows Hello still appears after restart or if the loader still prompts the same error, you'll need to disable virtualization in your BIOS settings.`n`n- Method by stormpike" `
        -Title "Success!" `
        -Icon Information
    
    Write-Host "`n[OK] Windows Hello disabled successfully!" -ForegroundColor Green
    Write-Host "[!] A restart is required for changes to take effect`n" -ForegroundColor Yellow
    
    # Prompt user to restart
    $restartChoice = Show-MessageBox `
        -Message "Would you like to restart your computer now?`n`nClick 'Yes' to restart immediately`nClick 'No' to restart later" `
        -Title "Restart Required" `
        -Buttons ([System.Windows.Forms.MessageBoxButtons]::YesNo) `
        -Icon ([System.Windows.Forms.MessageBoxIcon]::Question)
    
    if ($restartChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host "[!] Restarting computer in 10 seconds..." -ForegroundColor Yellow
        Write-Host "    Press Ctrl+C to cancel`n" -ForegroundColor Gray
        
        Start-Sleep -Seconds 3
        
        shutdown /r /t 10 /c "Restarting to apply Windows Hello disable changes" /d p:4:1
        
        Write-Host "[OK] Restart scheduled" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Remember to restart your computer manually" -ForegroundColor Yellow
    }
    
    exit 0
}
else {
    Show-MessageBox `
        -Message "Failed to disable Windows Hello via registry.`n`nError: $($Error[0].Exception.Message)`n`nYou'll need to disable virtualization in your BIOS settings instead. Visit the guide for instructions." `
        -Title "Error" `
        -Icon Error
    
    Write-Error "Failed to disable Windows Hello."
    exit 2
}

#endregion
