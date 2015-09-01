import sys
import os
from subprocess import call
import glob
import ctypes
import datetime

sz = r"C:/Program Failes/7-Zip/7z.exe"
bucket_name = "firedragon"
local_data_path = "F:/data/" # with trailing slash!
log_path = "F:/logs/"

# Scan local_data_path for .imd files
imd_files = glob.glob("{0}*.imd".format(local_data_path))

# 7z each imd file
for f in imd_files:
    return_value = call([sz, "a", "{0}.7z".format(f), f])
    if return_value != 0:
        raise Exception("Failed zipping {0}".format(f))
    else:
        os.remove(f)

# Run rsync, excluding .imd files
start_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
return_value = call(["gsutil", "-m", "rsync", "-x '.*\.imd'", "-r", local_data_path, "gs://{0}".format(bucket_name)])
if return_value != 0:
    raise Exception("rsync exited with code {0}".format(return_value))
else:
    ctypes.windll.user32.MessageBoxA(0, "Backups through {0} complete.".format(start_date), "CyTOF backups", 0)
