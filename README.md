cytof-backer-upper
==================

Python script for incrementally backing up CyTOF data to Google Cloud Storage.

Compared to the three earlier versions, this version is simpler and relies heavily on gsutil's rsync-like functionality.

- It does not provide versioning like the previous scripts because that was essentially unused. If a file is modified after being backed up initially, the new version will replace whatever was previously backed up. (If this is an issue, versioning can be configured. File an issue.)

- Compresses IMD files (only) and deletes the original IMD immediately after successful compression. Files that are still being written to by the CyTOF software will be skipped, but... *Caution: The CyTOF software* **may** *abort acquisition if any IMD file is deleted during acquisition.* (This happens on some occasions, but not all.) Note that you will see several (perhaps startling) messages in the console when the script skips an active file. [Don't you worry child](https://www.youtube.com/watch?v=1y6smkh6c-0).

- Displays a message after it's done syncing with the date that the sync was started.

Install instructions:

1. Setup a project in the Google Developers Console.
1. Install Python 2.7.x (x86 or x64, doesn't matter) -- e.g. https://www.python.org/ftp/python/2.7.10/python-2.7.10.msi. **Important: During the installation, make sure you select "Add Python to the path."**
1. Download gsutil from [here](https://storage.googleapis.com/pub/gsutil.zip) and extract to C:\.
1. Configure access to Google cloud by running `python C:\gsutil\gsutil config` and following the prompts. When prompted for the project name, enter the name of the project from step 1.
1. Install 7zip (e.g. this: http://www.7-zip.org/a/7z1506-x64.exe). Note the install location (typically $env:ProgramFiles\7-Zip\7z.exe).
1. Save this script and set the configuration settings in the top section.
1. Set a Windows scheduled task to run the script periodically.
  1. Click the start menu and start typing "Task Scheduler". Select "Task Scheduler."
  1. Click "Task Scheduler Library" in the left sidebar.
  1. Download `CyTOF Backup.xml` from this repository, then click "Import..." in the right sidebar. In the dialog that opens afterward, in these tabs:
    1. General: Click "Change User or Group...", type in the username you use for running the CyTOF, click "Check Names", then click OK.
    1. Triggers: Optionally change the start time.
    1. Actions: Change the "Start a program" action so that it uses the path to where the backup script is saved.
    1. Conditions and Settings, change if you desire.
  1. You can manually invoke the script from the Task Scheduler by clicking "Task Scheduler Library" in the left sidebar, selecting "CyTOF Backup" and clicking "Run" in the right sidebar.
