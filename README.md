cytof-backer-upper
==================

Powershell script for incrementally backing up CyTOF data. Features compression of IMD files (only), interruptable-resumable backup operations and good logging.

Use the latest _v3.ps1 file. (The previous versions were for earlier versions of PowerShell and Windows XP.)

1. Install WinSCP (known working: 5.5.6)
2. Install 7-Zip (9.20).
3. Ensure your Powershell execution policy is permissive (e.g. run Set-ExecutionPolicy Restricted).
4. Save the ps1 script from this repository.
5. Enter settings in the top lines of the ps1 script.
6. Set a Windows scheduled task to run the script periodically (e.g. every night).
