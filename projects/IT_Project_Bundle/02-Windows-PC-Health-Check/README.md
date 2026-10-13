# Windows PC Health Check Toolkit

**Requirements:** Windows 10/11 and Windows PowerShell 5.1 or newer. Standard user rights are sufficient for most checks; some details may be unavailable.

## Run
1. Copy the folder to a test Windows computer.
2. Open PowerShell. Review the `.ps1` file first.
3. Run it for this session if your organization's policy permits:
   `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\Windows-PC-Health-Check.ps1`
4. Open the timestamped HTML report and CSV in the `Reports` folder.

The script is designed to be read-only. `CHECK` or `WARNING` means investigate further; it does not necessarily indicate a fault. Do not bypass organizational execution policy.
