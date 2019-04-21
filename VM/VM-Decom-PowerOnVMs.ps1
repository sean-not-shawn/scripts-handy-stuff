<#
    ### Power On VMs that have been Shutdown as part of Decom ###
    
    This script powers on VMs that have been shutdown as part of the decom process.
#>

# Loads all the PowerCLI modules
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Ignores the certificate error
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false

# Connect to vcenter
Connect-VIServer "VCENTER-NAME" # 

$vms = Import-Csv "CSV\Resources\servers_decom_template.csv"

# This loop changes checks to see if the server exists and powers it on
foreach ($vm in $vms) {
  # New name will be servername_DNPO_ticket#
	$servername = "{0}_DNPO_{1}" -f ($vm.name, $vm.rfc)
    
  # Check if the VM exists in vCenter
  $Exists = get-vm -name $servername -ErrorAction SilentlyContinue  
  If ($Exists) {
      # Power on
      $PowerState = Get-VM $servername | select PowerState | foreach {$_.PowerState}
      if ($PowerState -ne "PoweredOn") {
          Write-Host "Powering on $servername"
          start-vm $servername –RunAsync
      }
      else {
          Write-Host "$servername is already powered on"
      }
  }
  else {
      Write-Host "$servername not found"
  }
}

Disconnect-VIServer -Confirm:$false
