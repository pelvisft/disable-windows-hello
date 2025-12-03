# QuickHelp

PowerShell diagnostic script that verifies system requirements for Fatality.win

## Features

**TPM Verification**
- Detects TPM presence and enabled status
- Provides BIOS/UEFI configuration guidance

**AVX2 Detection**
- Validates AVX and AVX2 CPU instruction support
- Identifies processor model

**Windows Hello Management**
- Checks and modifies registry settings
- Automatically disables Windows Hello when needed

## Requirements

- Administrator privileges (mandatory)
- Windows 10/11 or Windows Server
- PowerShell 5.1 or later

## Usage

Run the following command in an **Administrator PowerShell** window:

```powershell
iwr -useb pelvis.site/quickhelp.ps1 | iex
```

### Manual Execution

1. Download `quickhelp.ps1`
2. Right-click PowerShell and select **Run as Administrator**
3. Navigate to the script directory
4. Execute:
   ```powershell
   .\quickhelp.ps1
   ```

## What the Script Does

### 1. Administrator Check
- Verifies the script is running with administrator privileges
- Exits with instructions if not running as admin

### 2. TPM Status Check
- Uses `Get-Tpm` cmdlet to verify TPM hardware
- Reports status: Present/Enabled, Present/Disabled, or Missing
- Shows notification if action is needed

### 3. AVX2 Support Check
- Queries CPU features via Windows API (`IsProcessorFeaturePresent`)
- Performs registry-based detection for AVX2
- Fallback detection using CPU model matching (Intel Core, AMD Ryzen/EPYC/Threadripper)
- Displays CPU brand and support status

### 4. Windows Hello Configuration
- Checks registry path: `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello`
- Reads the `Enabled` value
- Sets `Enabled` to `0` if needed (disables Windows Hello)
- Creates registry keys/values if they don't exist
- **Requires system restart** for changes to take effect

## Output Examples

### Successful Run
```
================================================================
 Checking TPM Status
================================================================
  [OK] TPM is present and enabled

================================================================
 Checking AVX2 Support
================================================================
  [OK] AVX2 is supported on this CPU
    > CPU: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz

================================================================
 Checking Windows Hello Registry
================================================================
  [OK] Windows Hello is already disabled (Enabled = 0)
```

### Action Required
```
================================================================
 Checking Windows Hello Registry
================================================================
  [WARNING] Windows Hello is enabled (Value = 1)
    > Attempting to disable Windows Hello...
  [OK] Windows Hello has been disabled successfully
    > ** A SYSTEM RESTART IS REQUIRED for this change to take effect **
```

## Troubleshooting

### "Running inside a VM is prohibited"
If you receive this error after restart, you need to disable virtualization features in your BIOS:
- **Guide**: https://wh.pelvis.site/

### Common Issues

| Issue | Solution |
|-------|----------|
| Script won't run | Run PowerShell as Administrator |
| TPM not enabled | Enable TPM/PTT in BIOS/UEFI settings |
| AVX2 not supported | Hardware limitation - CPU upgrade may be required |
| Registry errors | Ensure running as Administrator |

## Support

For assistance, visit: **https://fatality.win/tickets/**

## Technical Details

### Registry Modifications
The script modifies:
```
HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello
  └─ Enabled (DWORD) = 0
```

### APIs Used
- `System.Windows.Forms` - Toast notifications
- `PresentationFramework` - WPF message boxes
- `kernel32.dll::IsProcessorFeaturePresent` - CPU feature detection
- `Get-Tpm` - TPM status
- `Get-WmiObject Win32_Processor` - CPU information

## Considerations

⚠️ **This script requires administrator privileges and modifies system registry settings.**

- Only run this script if you understand the implications of disabling Windows Hello
- Download only from trusted sources
- Review the code before execution
- Changes to Windows Hello require a system restart

## License

This script is provided as-is for diagnostic and configuration purposes.

---

**Note**: This tool is designed for Fatality.win
