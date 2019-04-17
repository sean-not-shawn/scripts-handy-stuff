# Loads all the PowerCLI modules
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores the certificate error
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "VCENTER-NAME-HERE"

$vms = Import-Csv .\CSV\Decommission\servers_decom_templatecsv

# This loop changes the name, and tries to do a graceful shutdown. Requires VMware Tools to be running
foreach ($vm in $vms) {

	$Oldname = $vm.name
    # New name will be servername_DNPO_ticket#
	$Newname = "{0}_DNPO_{1}" -f ($vm.name, $vm.rfc)
    
    # Check if the VM exists in vCenter
    $Exists = get-vm -name $Oldname -ErrorAction SilentlyContinue  
    If ($Exists) {
        # Rename
        Write-Host "Renaming $Oldname to $Newname"
	    Set-VM -VM $OldName -Name $Newname -Confirm:$false
        
        # Shutdown if powered on
        $PowerState = Get-VM $Newname | select PowerState | foreach {$_.PowerState}
        if ($PowerState -eq "PoweredOn") {      
            Write-Host "Shutting down $Newname"
            Shutdown-VMGuest -VM $Newname -Confirm:$false
        }
    }
    else {
        Write-Host "$Oldname not found"
    }
}

# This loop is to check that all the VMs are powered off. If one is found powered on it does a hard stop.
<#
foreach ($vm in $vms) {

	$Oldname = $vm.oldname
	$Newname = "{0}_DNPO_{1}" -f ($vm.oldname, $vm.rfc)

    write-host $Oldname, $Newname

	# $PowerState = Get-VM $Newname | select PowerState | foreach {$_.PowerState}
	# if ($PowerState -eq 'PoweredOn') {
	# stop-vm -VM $Newname -Confirm:$false
}
#>

Disconnect-VIServer -Confirm:$false
