# name: CyTOF Data Backup Powerscript
# auth: Zach Bjornson
# date: 5-May-2012
# reqs: WinSCP 5.x or later with the automation dll in same directory as WinSCP.exe
# reqs: 7-zip
#
# desc: Copies all files located in E:\Data that were modified between
# the date stored in hklm:\software\LastCyTOFDataBackup and now to firedragon.
# IMD files (only) are compressed first.
#
# note: Before running this script for the first time, set the last backup timepoint
# using something like this:
#$Date = Get-Date "May 1 2012"
#Set-ItemProperty "hklm:\software" -name LastCyTOFDataBackup -value $Date

# Alias for 7-zip
if (-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {throw "$env:ProgramFiles\7-Zip\7z.exe needed"}
set-alias sz "$env:ProgramFiles\7-Zip\7z.exe"

# Load WinSCP .NET assembly
[Reflection.Assembly]::LoadFrom("C:\Program Files\WinSCP\WinSCP.dll") | Out-Null
$sessionOptions = New-Object WinSCP.SessionOptions

# SETTINGS
$sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
$sessionOptions.HostName = "hostname"
$sessionOptions.UserName = "username"
$sessionOptions.Password = "password"
$sessionOptions.SshHostKey = "ssh-rsa 2048 he:xs:tu:ff"
$LocalDataPath = "C:\CyTOF DATA\"
#$RemoteDataPath = "/backup/users/bjornson/personal-backup/"
$RemoteDataPath = "/backup/shared/nolanshare/CyTOF_Data_Archive/Winehouse/"
$LogPath = "C:\Documents and Settings\beta6\Desktop\BackupLogs\"

# Begin script
$Status = 130

Try {

    # Get the last backup timepoint from the registry. If the script completes successfully, value gets set to $Now.
    $StartTime = Get-Date
    $LastBackup = (Get-ItemProperty "hklm:\software" -name LastCyTOFDataBackup).LastCyTOFDataBackup
    # Versioning suffix, gets appended to file names
    $VersionSuffix = Get-Date $StartTime -format d.MMM.yyyy

    $LogFile = "${LogPath}${VersionSuffix}.txt"
    Function Log($message) {
        $message | out-file $LogFile
        Write-Host $message
    }
    Function LogAppend($message) {
        $message | out-file $LogFile -Append
        Write-Host $message
    }
    Log("CyTOF data backup started on ${StartTime}")
    LogAppend("Last successful backup was on ${LastBackup}")
    LogAppend("")

    # Get all files modified between the last backup and now.
    $Dirs = Get-ChildItem -Path $LocalDataPath -Recurse | Where-Object {$_.PSIsContainer}
    $AllFiles = Get-ChildItem -Path $LocalDataPath -Recurse | Where-Object {! $_.PSIsContainer -and $_.lastWriteTime -gt $LastBackup}
    
    if($AllFiles.length -eq $null) { $Status = 0; LogAppend("No new files found."); break }

    # Keep track of files to copy
    $FilesToCopy = @() # @(Local Full Path, Remote Versioned Name)
    $NonIMDFiles = $Allfiles | Where-Object {$_.extension -ne ".imd"}
    $NonIMDFiles | ForEach-Object -Process {
        $fname = $_.FullName;
        $name = $fname.SubString($LocalDataPath.length)
        $remoteFile ="${name}___${VersionSuffix}"
        $FilesToCopy += ,@($fname, $remoteFile)
        LogAppend("New file to copy: ${fname}")
      }

    # Compress IMD files only
    LogAppend("")

    # Pick out the IMD files
    $IMDFiles = $Allfiles | Where-Object {$_.extension -eq ".imd"}

    # Keep track of temp files to delete on completion
    $TempFiles = @()
    # Zip each IMD file and add it to the list of files to copy and the list of files to delete
    If ($IMDFiles.length -gt 0) {
        $IMDFiles | ForEach-Object -Process {
            $fname = $_.FullName;
            $ZipFile = "${fname}.7z"

            $name = $fname.SubString($LocalDataPath.length)
            $remoteFile ="${name}.7z___${VersionSuffix}"

            LogAppend("Zipping ${fname}...")
            sz a $ZipFile $fname
            If ($LastExitCode -ne 0) {
              LogAppend("7zip exited with code ${LastExitCode}")
              Throw($LastExitCode)
            }
            
            $TempFiles += $ZipFile
            $FilesToCopy += ,@($ZipFile, $remoteFile)
            LogAppend("New file to copy: ${ZipFile}")
         }
    }

    # Transfer the compressed IMDs, and the uncompressed everything-else.
    LogAppend("")
 
    $session = New-Object WinSCP.Session
 
    try {
        # Connect
        "Opening SCP connection" | out-file $LogFile -Append
        $session.Open($sessionOptions)
 
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
    
        # Match the directory structure
        ForEach ($Dir in $Dirs) {
            $v = $Dir.FullName.SubString($LocalDataPath.length).Replace("\", "/")
            if (! $session.FileExists("${RemoteDataPath}${v}")) {
                $transferResult = $session.PutFiles("/", "${RemoteDataPath}${v}", $FALSE, $transferOptions)
                # Throw on any error
                $transferResult.Check()
            }
        }
    
        # Send files
        ForEach ($File in $FilesToCopy) {
            $LocalName = $File[0]
            $RemoteName = $File[1].Replace("\", "/")
            LogAppend("Sending file ${LocalName} -> ${RemoteDataPath}${RemoteName}")
            $transferResult = $session.PutFiles($LocalName, "${RemoteDataPath}${RemoteName}", $FALSE, $transferOptions)
            # Throw on any error
            $transferResult.Check()
        }

    } finally {
        # Disconnect, clean up
        LogAppend("Closing SCP connection")
        $session.Dispose()
    }

    # Delete temp files
    LogAppend("")
    $TempFiles | ForEach-Object -Process {
        $fname = $_
        LogAppend("Deleting temp file: ${fname}")
        Remove-Item $fname
      }

    $Status = 0
    
} Catch {

    $Status = -1
    $ErrorMessage = $_.Exception.Message
    LogAppend("")   
    LogAppend("ERROR: ${ErrorMessage}")
    
} Finally {

    LogAppend("")
    if ($Status -eq 0) {
        # The script completed successfully, so set the last backup time to the time when we queried modified files
        Set-ItemProperty "hklm:\software" -name LastCyTOFDataBackup -value $StartTime
        LogAppend("Backup successful!")
    } else {
        LogAppend("Backup unsuccessful.")
    }
    
    Invoke-Item $LogFile
    exit $Status
}
