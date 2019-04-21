<#
    ### Script to add storage to VMs that will be used as Database Servers (Pt. 2) ###

    Notes: 
    This script increases the size of disk one from the default template size (if required) and initializes/formats disks to be used as D:, Base E: and mount points. Part 1 is VM-Deploy-AddStorageToDatabaseServerVM.ps1
    It also changes the optical drive to F:
    Run this script directly on the server with the PowerShell ISE.
    To do: 
    1. Add error catching. The script should not continue if it encounters an error.
    2. Modify the script so it can be run remotely.
#>

# Method to change optical drive letter
$OpticalDrive = "Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='F:'}"

# Initialize/Format/Label D:
Initialize-Disk -Number 1 -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false 

# Initialize/Format/Label Base E:
Initialize-Disk -Number 2 -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "SQL" -Confirm:$false 

# Initialize/Format/Set Access Path/Label Mount Point
Initialize-Disk -Number 3 -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize 
New-Item -ItemType Directory -Path "E:\E_MP_DB01"
Add-PartitionAccessPath -DiskNumber 3 -PartitionNumber 2 -AccessPath "E:\E_MP_DB01" –Confirm:$false
Get-Partition –Disknumber 3 –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel "E_MP_DB01" –Confirm:$false

# Initialize/Format/Set Access Path/Label Mount Point
Initialize-Disk -Number 4 -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize 
New-Item -ItemType Directory -Path "E:\E_MP_LOG01"
Add-PartitionAccessPath -DiskNumber 4 -PartitionNumber 2 -AccessPath "E:\E_MP_LOG01" –Confirm:$false
Get-Partition –Disknumber 4 –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel "E_MP_LOG01" –Confirm:$false

# Initialize/Format/Set Access Path/Label Mount Point
Initialize-Disk -Number 5 -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize 
New-Item -ItemType Directory -Path "E:\E_MP_SYSDB01"
Add-PartitionAccessPath -DiskNumber 5 -PartitionNumber 2 -AccessPath "E:\E_MP_SYSDB01" –Confirm:$false
Get-Partition –Disknumber 5 –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel "E_MP_SYSDB01" –Confirm:$false

# Initialize/Format/Set Access Path/Label Mount Point
Initialize-Disk -Number 6 -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize 
New-Item -ItemType Directory -Path "E:\E_MP_TMP01"
Add-PartitionAccessPath -DiskNumber 6 -PartitionNumber 2 -AccessPath "E:\E_MP_TMP01" –Confirm:$false
Get-Partition –Disknumber 6 –PartitionNumber 2 | Format-Volume –FileSystem NTFS –NewFileSystemLabel "E_MP_TMP01" –Confirm:$false




