<#
    ### Script to deploy VMs ###

    This script will reconfigure an existing VM's resources to the values in a CSV file.
    It is best to power off the VMs prior to increasing resources. While most current OSes support hot-adding, some software may not recognize the change.
    VMs must be powered off when decreasing resources.
#>

# Loads all the PowerCLI modules
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores the certificate error
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "VCENTER-NAME"  

# CSV Path
$csv = "CSV\Resources\servers_resource_change.csv"

# Load CSV 
$vms = Import-Csv $csv

foreach ($vm in $vms) {
    # Set CPU
    if (-not ([string]::IsNullOrEmpty($vm.NumCpu.Trim()))) {
        Set-VM -VM $vm.Name -NumCpu $vm.NumCpu -Confirm:$false #-RunAsync 
    }

    # Set RAM
    if (-not ([string]::IsNullOrEmpty($vm.MemoryGB.Trim()))) {
        Set-VM -VM $vm.Name -MemoryGB $vm.MemoryGB -Confirm:$false #-RunAsync 
    }
        
    # Uncomment next line to power on the VM after reconfiguring. The script will wait for tools to load before continuing.
    Start-VM $vm.Name    
}

# Disconnect-VIServer -Confirm:$false
