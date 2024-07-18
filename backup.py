import sys
import os
from subprocess import call
import glob
import ctypes
import datetime
import fnmatch

sz = r"C:\\Program Files\\7-Zip\\7z.exe"
gsutil = r"C:\\Program Files (x86)\\Google\\Cloud SDK\\google-cloud-sdk\\bin\\bootstrapping\\gsutil.py"
bucket_name = "janis_joplin"
local_data_path = r"E:\\Data\\" # with trailing slash!
## IMPORTANT! Due to a bug in boto, you must have data in something
## like E:\Data\<month> instead of just E:\<month>. The first directory
## is ignored.
## Update 2024 - not sure if that's still a relevant bug.

# Scan local_data_path for .imd files
imd_files = []
for root, dirs, filenames in os.walk(local_data_path, topdown=True):
  dirs[:] = [d for d in dirs if d not in set(["$RECYCLE.BIN"])]
  for filename in fnmatch.filter(filenames, "*.imd"):
    imd_files.append(os.path.join(root, filename))

# 7z each imd file
for f in imd_files:
  return_value = call([sz, "a", "{0}.7z".format(f), f])
  if return_value != 0:
    print("Skipped zipping {0}, probably because it is in use by another process".format(f))
    os.remove("{0}.7z".format(f)) # remove the empty archive
  else:
    os.remove(f)

# Run rsync, excluding .imd files
start_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
return_value = call(["python", gsutil, "-m", "rsync", "-x", ".*\.imd$", "-r", local_data_path, "gs://{0}".format(bucket_name)])
if return_value != 0:
  ctypes.windll.user32.MessageBoxA(0, "rsync exited with code {0}".format(return_value), "CyTOF backups", 0)
else:
  ctypes.windll.user32.MessageBoxA(0, "Backups through {0} complete.".format(start_date), "CyTOF backups", 0)
