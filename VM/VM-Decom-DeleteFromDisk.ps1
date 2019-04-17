# Loads all the PowerCLI modules
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores the certificate error
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "ENTER-VCENTER-NAME-HERE"  

$vms = Import-Csv .\CSV\Decommission\servers_decom_template.csv

# This loop 
foreach ($vm in $vms) {

    # New name will be servername_DNPO_ticket#
	$Newname = $vm.name # "{0}_DNPO_{1}" -f ($vm.oldname, $vm.rfc)
    
    # Check if the VM exists in vCenter
    $Exists = get-vm -name $Newname -ErrorAction SilentlyContinue  
    If ($Exists) {
        Remove-VM -VM $Newname -DeletePermanently -Confirm:$false -RunAsync # -WhatIf
    }
}

Disconnect-VIServer -Confirm:$false
