# name: CyTOF Data Backup Powerscript
# auth: Zach Bjornson
# date: 13-Sep-2013
# ver: 2.0
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
$sessionOptions.HostName = "server.server"
$sessionOptions.UserName = "username"
$sessionOptions.Password = "password"
$sessionOptions.SshHostKey = "ssh-rsa 2048 he:xs:tu:ff"
$LocalDataPath = "E:\Data\"
$RemoteDataPath = "/backup/shared/nolanshare/CyTOF_Data_Archive/Mercury/"
$LogPath = "C:\Documents and Settings\beta37\Desktop\BackupLogs\"

# Begin script
$Status = 130

Try {

    # Get the last backup timepoint from the registry. As each file is synced, the value gets updated to that file's time.
    $StartTime = Get-Date
    $LastBackup = (Get-ItemProperty "hklm:\software" -name LastCyTOFDataBackup).LastCyTOFDataBackup
    $LastBackup = [datetime]::ParseExact($LastBackup, "MM/d/yyyy HH:mm:ss", $null)
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

    Function IsIMDFileQ($file) {
        $file.extension -eq ".imd"
    }
    
    Function GetRemote7zFileName($file) {
        $fname = $file.FullName;
        $name = $fname.SubString($LocalDataPath.length)
        "${name}.7z___${VersionSuffix}"
    }
    
    Function GetRemoteFileName($file) {
        $fname = $file.FullName;
        $name = $fname.SubString($LocalDataPath.length)
        "${name}___${VersionSuffix}"
    }

    Function CompressFile($file) {
        $fname = $file.FullName
        $ZipFile = "${fname}.7z"

        LogAppend("Zipping ${fname}...")
        sz a $ZipFile $fname
        If ($LastExitCode -ne 0) {
          LogAppend("7zip exited with code ${LastExitCode}")
          Throw($LastExitCode)
        }
        
        $ZipFile
    }
    
    Function PrepRemoteDirectories($Dirs) {
        $session = New-Object WinSCP.Session
 
        try {
            # Connect
            LogAppend("Opening SCP connection to prep remote directories")
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

        } finally {
            # Disconnect, clean up
            LogAppend("Closing SCP connection")
            $session.Dispose()
        }
    }
    
    Function SyncFile($file, $RemoteName) {
        $session = New-Object WinSCP.Session
 
        try {
            # Connect
            LogAppend("Opening SCP connection")
            $session.Open($sessionOptions)
            $transferOptions = New-Object WinSCP.TransferOptions
            $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
            # Send file
            $RemoteName = $RemoteName.Replace("\", "/")
            LogAppend("Sending file ${LocalName} -> ${RemoteDataPath}${RemoteName}")
            $transferResult = $session.PutFiles($file, "${RemoteDataPath}${RemoteName}", $FALSE, $transferOptions)
            # Throw on any error
            $transferResult.Check()

        } finally {
            # Disconnect, clean up
            LogAppend("Closing SCP connection")
            $session.Dispose()
        }
    }
    
    Function DeleteFile($file) {
        LogAppend("Deleting temp file: ${file}")
        Remove-Item $file
    }
    
    Function SetLastUpdateTime($time) {
        Set-ItemProperty "hklm:\software" -name LastCyTOFDataBackup -value $time
    }

    LogAppend("")
    
    
    # Get all the directories and prep the remote location with them.
    $Dirs = Get-ChildItem -Path $LocalDataPath -Recurse | Where-Object {$_.PSIsContainer}
    PrepRemoteDirectories($Dirs)
    
    # Get all files modified since $LastBackup.
    $AllFiles = Get-ChildItem -Path $LocalDataPath -Recurse | Where-Object {! $_.PSIsContainer -and $_.lastWriteTime -gt $LastBackup} | Sort-Object -Property LastWriteTime
    if($AllFiles.length -eq $null) { $Status = 0; LogAppend("No new files found."); break }

    # Loop through all the files and sync.
    foreach ($file in $AllFiles) {
        If (IsIMDFileQ($file)) {
            CompressFile $file
            $fname = $file.FullName
            $ZipFile = "${fname}.7z"
            $Remote7zFileName = GetRemote7zFileName $file
            LogAppend "Remote 7z filename is ${Remote7zFileName}"
            SyncFile $ZipFile $Remote7zFileName
            DeleteFile $ZipFile
        } Else {
            LogAppend "Processing ${file}"
            $RemoteFileName = GetRemoteFileName $file
            SyncFile $file.FullName $RemoteFileName
        }
        # Update $LastBackup only if the file's time is greater.
        # This is important because the filesystem has a resolution of about 100 ns.
        # This is checked after every file so that the update can be aborted and
        # restarted without doing redundant work.
        If ($LastBackup -lt $file.lastWriteTime) {
            $lwt = $file.lastWriteTime
            LogAppend "Setting new backup time to ${lwt}"
            SetLastUpdateTime($file.lastWriteTime)
        }
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
        LogAppend("Backup successful!")
    } else {
        LogAppend("Backup unsuccessful.")
    }
    
    Invoke-Item $LogFile
    exit $Status
}

