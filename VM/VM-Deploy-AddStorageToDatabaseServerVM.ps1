<#
    ### Script to add storage to VMs that will be used as Database Servers (Pt. 1) ###

    Notes: 
    This script loads a CSV file with the details of the VMs that require additional disks. Part 2 is VM-Deploy-AddStorageToDatabaseServerGuest.ps1.
    It increases the size of disk one from the default template size (if required) and adds disks to be used as D:, Base E: and mount points.
    This script assumes that the datastores are part of a datastore cluster.

    To do: 
    1. Add the second Paravirtual SCSI controller by script (requires VM to be powered off)
    2. Add error catching in the event the VM datastores are not part of a datastore cluster
    3. Add a function to determine the best datastore for the new disk if number 2 is true
#>

# Loads all the PowerCLI modules (Below path is the default)
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores certificate errors
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "VCENTER-HERE" 

# CSV Path
$csv = "CSV\Deployments\servers_deploy_databasedisks.csv"
   
foreach ($vm in Import-Csv $csv) {
    
    # Get the name of the datastore cluster of the VM
    $dsc = Get-VM -Name $vm.Name | Get-DatastoreCluster
        
    # Increase disk 1 (C:) size if Disk1 column is not Empty
    if (-not ([string]::IsNullOrEmpty($vm.Disk1.Trim()))) {
        Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 1"} | Set-HardDisk -CapacityGB $vm.Disk1 -Confirm:$false
    }    
    
    # Add disk 2 (D:/Data) to controller 1
    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk2 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 0" -Confirm:$false

    # Add all other disks to controller 2
    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk3 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 1" -Confirm:$false

    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk4 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 1" -Confirm:$false

    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk5 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 1" -Confirm:$false

    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk6 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 1" -Confirm:$false

    New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk7 -StorageFormat Thick -Datastore $dsc -Controller "SCSI controller 1" -Confirm:$false            
}

Disconnect-VIServer -Confirm:$false 
