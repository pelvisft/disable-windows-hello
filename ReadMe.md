# Windows Hello Nuker

## Overview

This PowerShell script disables Windows Hello on Windows 11 systems by modifying a specific registry key. It is designed as a one-liner for quick execution and includes checks to ensure compatibility and proper permissions.

The method was discovered by stormpike.

## What It Does

- Verifies that the script is running with Administrator privileges. If not, it displays an error message and exits.
- Checks if the system is running Windows 11 (or a compatible build). If not, it informs the user and exits.
- Sets the registry value at `HKLM:\SYSTEM\CCS\Control\DG\Scenarios\WH` to `0`, effectively disabling Windows Hello.
- Displays a success message and prompts the user to restart the computer for the changes to take effect.
- If the issue persists after restart, suggests disabling virtualization in the BIOS as a troubleshooting step.

## How to Run

This script is designed as a one-liner for easy copy-paste execution directly in PowerShell.

1. **Open PowerShell as Administrator**: Right-click on PowerShell and select "Run as administrator".
2. **Copy the Script**: Open `1liner.ps1` and copy its entire content (the single line of code).
3. **Paste and Execute**: Paste the copied code into the PowerShell window and press Enter.
4. **Restart Your Computer**: Follow the on-screen prompt to restart and apply the changes.

## Requirements

- Windows 11 (Build 22000 or higher)
- Administrator privileges
- PowerShell execution policy allowing script runs (typically unrestricted for local scripts)

## Warnings

- This script modifies the Windows registry. It is recommended to back up your system or create a restore point before running.
- If Windows Hello remains enabled after restart, disable virtualization in your BIOS settings.
- Use this script at your own risk. The authors are not responsible for any system issues or data loss resulting from its use.

## Credits

Created for fatality.win, a CS2 software. Discovered by stormpike. Script provided as-is.
