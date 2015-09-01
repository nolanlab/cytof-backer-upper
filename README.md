cytof-backer-upper
==================

Python script for incrementally backing up CyTOF data to Google Cloud Storage.

Compared to the three earlier versions, this version is simpler and relies more on gsutil's rsync-like functionality. It does not provide versioning like the previous scripts because that was essentially unused. If a file is modified after being backed up initially, the new version will replace whatever was previously backed up.

- Compresses IMD files (only) and deletes the uncompressed IMD immediately after compression. **Caution: All tested versions of the CyTOF software will abort acquisition if *any* IMD is deleted while acquisition is in process.**
- Displays a message after it's done syncing with the date that the sync was started.

Install instructions:
1. Setup a project in the Google Developers Console.
1. Install Python 2.6.x or 2.7.x.
1. Download gsutil from [here](https://storage.googleapis.com/pub/gsutil.zip) and extract to C:\.
1. Setup access by running `python C:\gsutil\gsutil config` and following the prompts. When prompted for the project name, enter the name of the project from step 1.
1. Install 7zip (e.g. this: http://www.7-zip.org/a/7z1506-x64.exe). Note the install location (typically $env:ProgramFiles\7-Zip\7z.exe).
1. Save this script and set the configuration settings in the top section.
6. Set a Windows scheduled task to run the script periodically (e.g. every night).
