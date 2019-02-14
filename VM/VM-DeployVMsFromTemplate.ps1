<#
    ### Script to deploy VMs ###

    Notes: This script loads a CSV file with the details of the VMs you would like to deploy. 
    Some analysis of the vCenters will be required to fill in columns of the CSV. Other columns 
    will be from the requirements provided by the requester. IPs should be requested via iServe.

    CSV Format:
    Cluster - Cluster/Farm you would like to deploy your VM to. The script with query the cluster and find the host with the least amount of used CPU/RAM and number of VMs
    Name - Name of your VM
    Location - Folder to add the VM to. If the folder is nested or there are multiple folders with the same name, enter the full path using "/" as a separator. e.g. NM DC 02/Citrix/PCI - where "NM DC 02" is the DC and Citrix is the parent of PCI
    Datastore - Datastore name
    Template - Template name
    MemoryGB - RAM
    NumCpu, - CPU
    VDSwitch - Distributed Switch name
    VLAN - VLAN ID (name - e.g. VLAN-015, DMZ-VLAN-224)
    IP - IP Address (Please request for Directory Services in iServe if one has not already been reserved)
    Netmask - Subnet Mask
    Gateway - Default Gateway
    DNS1 - Primary DNS
    DNS2 - Secondary DNS
    Disk1 - Disk size in GB (if greater than 60 GB is requested)
    Disk2 - Disk size in GB (if greater than 40 GB is requested)
    Domain - Domain to join
    OU - OU to be moved to


    Helpful Methods:

    ## Returns a list of the clusters
    Get-Cluster | Select Name
    
    ## Returns a list of folders
    Get-Folder | Where {$_.Type -eq "VM" } | Select Name | Sort-Object Name
    
    ## Returns a list of templates on a cluster (retrieves all hosts and gets the templates on them)
    $Hosts = Get-Cluster -Name "ENTER-CLUSTER-NAME-HERE" | Get-VMHost | %{$_.Extensiondata.MoRef}
    Get-Template | where {$Hosts -contains $_.Extensiondata.Runtime.Host}
    
    ## Returns a list of datastore clusters
    Get-DatastoreCluster

    ## Returns a list of datastores
    Get-Datastore

    ## Returns a list of VLANs
    Get-VDSwitch | Get-VirtualPortGroup | Select Name, @{N="VLANId";E={$_.Extensiondata.Config.DefaultPortCOnfig.Vlan.VlanId}}, Key | Sort-Object Name

#>

<# 
    ## Start here when executing from Section One
#>

# Loads all the PowerCLI modules (Below path is the default)
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores certificate errors
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "ENTER-VCENTER-NAME-HERE"  

# CSV Path
$csv = "CSV\Deployments\CSVFILENAMEHERE.csv"

# This variable is used for disk addition
$NewDiskAdd = $false
    
<#
    ## Helper functions 
    ## Begin 
#>

## This function checks what version of Powershell is installed on the VM
## and uses WMIC or Get-NetAdapter to return the Network adapter name
function Get-NICName($VMName) {    
    # $GetOSNIC = "Get-NetAdapter | Select -ExpandProperty Name" 
    $GetOSNIC = ""

    # Check VM for PowerShell version
    $PSVersion = (Invoke-VMScript -VM $VMName -ScriptText {$PSVersionTable.PSVersion.Major} -GuestCredential $GuestCred).Trim()
    Write-Host "PowerShell Major Version on $VMName is $PSVersion"

    # Get name of NIC from Guest OS
    if ($PSVersion -eq 2) { # Write-Host "Follow path to PS 2"
        # Method will return Network Adapter name using WMIC
        $GetOSNIC = (Invoke-VMScript -VM $VMName -ScriptText {wmic nic netenabled=true get NetConnectionID} -Verbose -GuestCredential $GuestCred).Replace("NetConnectionID","").Replace("`r`n","").Trim()
    }
    else { # Write-Host "Follow path to PS > 2" 
        # Method will return Network Adapter name using PowerShell
        $GetOSNIC = (Invoke-VMScript -VM $VMName -ScriptText {Get-NetAdapter | Select -ExpandProperty Name} -Verbose -GuestCredential $GuestCred).TrimEnd()
    } 
    # Write-Host $GetOSNIC
    return $GetOSNIC
}

## This function takes the VLAN ID from the CSV and returns the numeric ID
function Return-VLANID($VLANName) {
    $len = $VLANName.length
    $ind = $VLANName.LastIndexOf("-",($len-1))
    return [Int64]$VLANName.Remove(0,($ind+1))
}

## This function returns the Folder Object by path - From http://www.lucd.info - http://www.lucd.info/2012/05/18/folder-by-path/
function Get-FolderByPath {
    param(
        [CmdletBinding()]
        [parameter(Mandatory = $true)]
        [System.String[]]${Path},
        [char]${Separator} = '/'
    )
    process {
        if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple") {
            $vcs = $defaultVIServers
        }
        else {
            $vcs = $defaultVIServers[0]
        }
        foreach($vc in $vcs) {
            foreach($strPath in $Path) {
                $root = Get-Folder -Name Datacenters -Server $vc
                $strPath.Split($Separator) | % {
                    $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
                    if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm") {
                        $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
                    }
                }
                $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|% {
                    Get-Folder -Name $_.Name -Location $root.Parent -NoRecursion -Server $vc
                }
            }
        }
    }
}
<#
    ## End Helper Functions
#>

<#
    ## This section creates a new VM from a template, sets the CPU/RAM/VLAN ## 
    ## Notes: 
    1. -RunAsync has been remed out because each method call should complete before moving on to the next
    2. Added ConnectionState filter to host selector line. Some hosts are in maintenance mode and can/should not be deployed to
    3. This section requires the helper functions above
    ## 
    ## Begin section 1 
#>

# Load CSV 
$vms = Import-Csv $csv

# This area checks to see if VMs with the requested names already exists
$vmsexist = 0
$vmsexistlist = ""


foreach ($vm in $vms) { 
    $vmcheck = get-vm -name $vm.Name -ErrorAction SilentlyContinue  
    If ($vmcheck){  
        # Write-Host $vm.Name " already exists" 

# This area checks to see if VMs with the requested names already exist
$vmsexist = 0
$vmsexistlist = ""

foreach ($vm in $vms) { 
    $vmcheck = get-vm -name $vm.Name -ErrorAction SilentlyContinue  
    If ($vmcheck){  
        $vmsexist++
        $vmsexistlist += $vm.Name + " "
    }  
    Else {  
        Write-Host $vm.Name " does not exist" 
    }  
}

# Display a message if any of VMs already exist, otherwise continue with deployment
if ($vmsexist -gt 0) { 
    Write-Host "The script will not continue. VMs with the requested names exist in this vCenter. " $vmsexistlist -ForegroundColor Red -BackgroundColor White
} 
else { 

    foreach ($vm in $vms) {
    
        # Query the cluster to find the host with the most available CPU/RAM and least number of VMs
        $VMHost = (Get-VMHost -Location $vm.Cluster | Select @{N=“Cluster“;E={Get-Cluster -VMHost $_}}, Name, NumCpu, CpuTotalMhz, CpuUsageMhz, @{ n='CPUAvail'; e={ $_.CpuTotalMhz - $_.CpuUsageMhz }}, MemoryUsageGB, MemoryTotalGB, @{ n='MemoryAvail'; e={ $_.MemoryTotalGB - $_.MemoryUsageGB }}, @{N=“NumVM“;E={($_ | Get-VM).Count}}, ConnectionState | Where-Object {$_.ConnectionState -eq "Connected"} | Sort NumVM, CPUAvail, MemoryAvail | Select -ExpandProperty Name -First 1).TrimEnd()

        Write-Host "Deploying to $VMHost"

        # Create VM In Specified Folder
        $location = $vm.Location.Trim()
        if (-not ([string]::IsNullOrEmpty($location))) {
            # Check to see if location name contains "/". If it does, the folder path was specified - necessary if there are nested folders or multiple folders with the same name
            if ($location.Contains("/")) {
                $locationpath = Get-Folder -ID (Get-FolderByPath -Path $location).ID
                New-VM -VMHOST $VMHost -Name $vm.Name -Location $locationpath -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
            }
            else {
                New-VM -VMHOST $VMHost -Name $vm.Name -Location $location -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
            }
        }
        # Create VM not in a folder (Some vCenters do not have folders)
        else {
            New-VM -VMHOST $VMHost -Name $vm.Name -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
        }

        # Set CPU/RAM
        Set-VM -VM $vm.Name -MemoryGB $vm.MemoryGB -NumCpu $vm.NumCpu -Confirm:$false #-RunAsync 

        # Set VLAN
        # Get VM Network Adapter Name
        $VMNIC = Get-NetworkAdapter -VM $vm.Name
        # Set NIC PortGroup variable value Virtual Port Group Object if using a distributed switch or to VLAN ID/Name from CSV 
        $NICPG = if (-not ([string]::IsNullOrEmpty($vm.VDSwitch))) { (Get-VirtualSwitch -Name $vm.VDSwitch | Get-VirtualPortGroup | Where Name -eq $vm.VLAN) } else { $vm.VLAN }

        if (-not ([string]::IsNullOrEmpty($VMNIC))) { 
            # Set VLAN if NIC is found 
            Write-Host "Setting VLAN on Network Adapter of" $vm.Name      
            Set-NetworkAdapter -NetworkAdapter $VMNIC -Portgroup $NICPG -Confirm:$false
        }     
        else {
            # Add a NIC if one is not found 
            Write-Host "Adding Network Adapter to" $vm.Name 
            New-NetworkAdapter -VM $vm.Name -Type Vmxnet3 -Portgroup $NICPG -StartConnected:$true -Confirm:$false
        }     
    
        # Increase disk size if Disk1 and Disk2 columns are not Empty
        if (-not ([string]::IsNullOrEmpty($vm.Disk1.Trim()))) {
            Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 1"} | Set-HardDisk -CapacityGB $vm.Disk1 -Confirm:$false
        }
        if (-not ([string]::IsNullOrEmpty($vm.Disk2.Trim()))) { 
            # Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 2"} | Set-HardDisk -CapacityGB $vm.Disk2 -Confirm:$false

            # Check if the new VM has a second hard drive. Some templates don't include a second disk
            $HardDisk = Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 2"}
            if (-not ([string]::IsNullOrEmpty($HardDisk))) { 
                Set-HardDisk -HardDisk $HardDisk -CapacityGB $vm.Disk2 -Confirm:$false
            } 
            else { 
                New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk2 -StorageFormat Thin -Datastore $vm.Datastore -Confirm:$false
                $NewDiskAdd = $true 
            }
        }
    
        # Query the cluster to find the host with the most available CPU/RAM and least number of VMs
        $VMHost = (Get-VMHost -Location $vm.Cluster | Select @{N=“Cluster“;E={Get-Cluster -VMHost $_}}, Name, NumCpu, CpuTotalMhz, CpuUsageMhz, @{ n='CPUAvail'; e={ $_.CpuTotalMhz - $_.CpuUsageMhz }}, MemoryUsageGB, MemoryTotalGB, @{ n='MemoryAvail'; e={ $_.MemoryTotalGB - $_.MemoryUsageGB }}, @{N=“NumVM“;E={($_ | Get-VM).Count}}, ConnectionState | Where-Object {$_.ConnectionState -eq "Connected"} | Sort NumVM, CPUAvail, MemoryAvail | Select -ExpandProperty Name -First 1).TrimEnd()

        Write-Host "Deploying to $VMHost"

        # Create VM In Specified Folder
        $location = $vm.Location.Trim()
        if (-not ([string]::IsNullOrEmpty($location))) {
            # Check to see if location name contains "/". If it does, the folder path was specified - necessary if there are nested folders or multiple folders with the same name
            if ($location.Contains("/")) {
                $locationpath = Get-Folder -ID (Get-FolderByPath -Path $location).ID
                New-VM -VMHOST $VMHost -Name $vm.Name -Location $locationpath -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
            }
            else {
                New-VM -VMHOST $VMHost -Name $vm.Name -Location $location -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
            }
        }
        # Create VM not in a folder (Some vCenters do not have folders)
        else {
            New-VM -VMHOST $VMHost -Name $vm.Name -Datastore $vm.Datastore -Template $vm.Template -Confirm:$false #-RunAsync 
        }

        # Set CPU/RAM
        Set-VM -VM $vm.Name -MemoryGB $vm.MemoryGB -NumCpu $vm.NumCpu -Confirm:$false #-RunAsync 

        # Set VLAN
        # Get VM Network Adapter Name
        $VMNIC = Get-NetworkAdapter -VM $vm.Name
        # Set NIC PortGroup variable value Virtual Port Group Object if using a distributed switch or to VLAN ID/Name from CSV 
        $NICPG = if (-not ([string]::IsNullOrEmpty($vm.VDSwitch))) { (Get-VirtualSwitch -Name $vm.VDSwitch | Get-VirtualPortGroup | Where Name -eq $vm.VLAN) } else { $vm.VLAN }

        if (-not ([string]::IsNullOrEmpty($VMNIC))) { 
            # Set VLAN if NIC is found 
            Write-Host "Setting VLAN on Network Adapter of" $vm.Name      
            Set-NetworkAdapter -NetworkAdapter $VMNIC -Portgroup $NICPG -Confirm:$false 
        }     
        else {
            # Add a NIC if one is not found
            Write-Host "Adding Network Adapter to" $vm.Name
            New-NetworkAdapter -VM $vm.Name -Type Vmxnet3 -Portgroup $NICPG -StartConnected:$true -Confirm:$false 
        }     
    
        # Increase disk size if Disk1 and Disk2 columns are not Empty
        if (-not ([string]::IsNullOrEmpty($vm.Disk1.Trim()))) {
            Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 1"} | Set-HardDisk -CapacityGB $vm.Disk1 -Confirm:$false # -StorageFormat Thin
        }
        if (-not ([string]::IsNullOrEmpty($vm.Disk2.Trim()))) {
            # Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 2"} | Set-HardDisk -CapacityGB $vm.Disk2 -Confirm:$false # -StorageFormat Thin 

            # Check if the new VM has a second hard drive. Some templates don't include a second disk
            $HardDisk = Get-HardDisk -VM $vm.Name | Where {$_.Name -eq "Hard disk 2"}                 
            if (-not ([string]::IsNullOrEmpty($HardDisk))) { 
                Set-HardDisk -HardDisk $HardDisk -CapacityGB $vm.Disk2 -Confirm:$false # -StorageFormat Thin 
            } 
            else { 
                New-HardDisk -VM $vm.Name -CapacityGB $vm.Disk2 -StorageFormat Thin -Datastore $vm.Datastore -Confirm:$false
                $NewDiskAdd = $true 
            }
        }
    
        # Uncomment next line to power on the VM after provisioning. The script will wait for tools to load before continuing
        Start-VM $vm.Name | Wait-Tools
    
    }

}

<#
    ## End Section 1 
    ## 
    ## This section changes optical drive to E: and sets Hard Disk size/IP/Subnet Mask/Gateway/DNS (Primary and Secondary) ##
    ## 
    ## Notes:
    ## 1. $DiskOnline and $DiskExpand is not indented because multiline ` cannot have leading whitespace
    ##
    ## To do: 
    ## 1. 
    ##
    ## Begin Section 2 
#>

# Prompt for Local Admin Account password
$GuestCred = Get-Credential "Administrator"

# Load CSV 
$vms = Import-Csv $csv

foreach ($vm in $vms) {

    # Method to change drive letter
    $OpticalDrive = "Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='E:'}"
    
    # Change optical drive to E$
    Invoke-VMScript -VM $vm.Name -ScriptText $OpticalDrive -Verbose -GuestCredential $GuestCred 
    
    # Setting the DiskOnline script based on if a new disk was added
if ($NewDiskAdd -eq $true) {
$DiskOnline = @"
`$offlinedisks = Get-Disk | Where OperationalStatus -EQ offline; 
foreach (`$disk in `$offlinedisks) { 
Set-Disk -Number `$disk.Number -IsOffline `$false; 
Set-Disk -Number `$disk.Number -IsReadOnly `$false; 
Initialize-Disk -Number `$disk.Number -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:`$false 
} 
"@
}
else {
$DiskOnline = @"
`$offlinedisks = Get-Disk | Where OperationalStatus -EQ offline; 
foreach (`$disk in `$offlinedisks) { 
Set-Disk -Number `$disk.Number -IsOffline `$false; 
Set-Disk -Number `$disk.Number -IsReadOnly `$false; 
} 
"@
}
    # Bring any offline disks online 
    Invoke-VMScript -VM $vm.Name -ScriptText $DiskOnline -Verbose -GuestCredential $GuestCred 

    # Setting the DiskExpand script to expand each disk to the maximum size
$DiskExpand = @"
`$systemdisks = Get-Disk; 
foreach (`$disk in `$systemdisks) {     
`$driveletter = (Get-Partition -DiskNumber `$disk.Number | where {`$_.DriveLetter}).DriveLetter; 
if (`$driveletter -ne `$null) { 
`$maxsizegb = [math]::Round(`$((Get-PartitionSupportedSize -DriveLetter `$driveletter).SizeMax/1GB),2); 
`$disksize = [math]::Round(`$((Get-Partition -DriveLetter `$driveletter).Size/1GB),2); 
if (`$maxsizegb -gt `$disksize) { 
Write-Host "Expanding `$driveLetter from `$disksize GB to `$maxsizegb GB"; 
Resize-Partition -DriveLetter `$driveLetter -Size (Get-PartitionSupportedSize -DiskNumber `$disk.Number -PartitionNumber (Get-Partition -DriveLetter `$driveletter).PartitionNumber).SizeMax; 
} else { 
Write-Host "No unallocated space on `$driveLetter"; 
} } } 
"@
    # Expand disks volumes in guest
    Invoke-VMScript -VM $vm.Name -ScriptText $DiskExpand -Verbose -GuestCredential $GuestCred
    
    <##>
    # Get name of NIC from Guest OS        
    $OSNIC = Get-NICName($vm.Name) 

    Write-Host $vm.Name "network adapter name is $OSNIC. Configuring settings."        

    # Variables for ScriptText parameter
    $SetIP = "netsh interface ipv4 set address name=`"$OSNIC`" source=static addr="+$vm.IP+" mask="+$vm.Netmask+" gateway="+$vm.Gateway+""
    $SetDNS1 = "netsh interface ipv4 set dns name=`"$OSNIC`" source=static addr="+$vm.DNS1+""
    $SetDNS2 = "netsh interface ipv4 add dns name=`"$OSNIC`" addr="+$vm.DNS2+" index=2"

    # Execute scripts in Guest OS
    Invoke-VMScript -VM $vm.Name -ScriptType Bat -ScriptText $SetIP -Verbose -GuestCredential $GuestCred 
    Invoke-VMScript -VM $vm.Name -ScriptType Bat -ScriptText $SetDNS1 -Verbose -GuestCredential $GuestCred 
    Invoke-VMScript -VM $vm.Name -ScriptType Bat -ScriptText $SetDNS2 -Verbose -GuestCredential $GuestCred     
    
    Start-Sleep 15
    
<#
    ## End 
    ## 
    ## This section renames the server ##
    ## 
    ## Begin 
#>
    <##>

    # Get the current name of the VM 
    $CurrentHostname = (Invoke-VMScript -VM $vm.Name -ScriptText {$env:computername} -GuestCredential $GuestCred).Trim()

    Write-Host "Renaming $CurrentHostname to $vm.Name"

    # Method to rename local computer
    $RenameGuest = "(Get-WmiObject Win32_ComputerSystem).Rename(`""+$vm.Name+"`")"

    # Rename the hostname to match VM name
    Invoke-VMScript -VM $vm.Name -ScriptText $RenameGuest -GuestCredential $GuestCred 
    
    Start-Sleep 15

    Invoke-VMScript -VM $vm.Name -ScriptText {RESTART-COMPUTER -force} -GuestCredential $GuestCred -RunAsync 
    
}

# Disconnect-VIServer -Confirm:$false

<#
    ## End Section 2 
    ## 
    ## This section joins the server to the domain and moves the server to the specified OU ##
    ## 
    ## Notes:
    ## 1. $JoinDomain is not indented because multiline ` cannot have leading whitespace
    ##
    ## To do: 
    ## 1. Add -NewName "servername" parameter to Add-Computer method
    ##
    ## Begin Section 3 
#>

# Prompt for Domain Admin account/password
$Who = whoami
$DomainCred = (Get-Credential $Who -Message "Please Enter your Domain account password.")
$DomainId = $DomainCred.GetNetworkCredential().Domain + "\" + $DomainCred.GetNetworkCredential().UserName
$DomainPw = $DomainCred.GetNetworkCredential().Password

# Load CSV 
$vms = Import-Csv $csv

# This joins the server to the domain specified in the CSV
foreach ($vm in $vms) {   
    
    # Domain/OU Details
    $DomainName = $vm.Domain    
    $OUPath = $vm.OU
    $NewName = $vm.Name

    # Build ScriptText parameter
    if (-not ([string]::IsNullOrEmpty($OUPath.Trim()))) {
$JoinDomain = @"
`$domain = "$DomainName"
`$ou = "$OUPath"
`$password = "$DomainPw" | ConvertTo-SecureString -asPlainText -force;
`$username = "$DomainId";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -OUPath `$ou -Credential `$credential -Restart
"@
    }
    else {
$JoinDomain = @"
`$domain = "$DomainName"
`$ou = "$OUPath"
`$password = "$DomainPw" | ConvertTo-SecureString -asPlainText -force;
`$username = "$DomainId";
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
Add-computer -DomainName `$domain -Credential `$credential -Restart
"@
    }

    Invoke-VMScript -VM $vm.Name -ScriptText $JoinDomain -Verbose -GuestCredential $GuestCred
        
}

<#
    ## End Section 3 
#>

Disconnect-VIServer -Confirm:$false 
