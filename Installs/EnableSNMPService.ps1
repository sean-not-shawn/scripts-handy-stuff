<#
  ### Powershell Script To Install SNMP Services (SNMP Service, SNMP WMI Provider) and configure to sepcific settings
#>

#Variables
$PManagers = @("IP-OR-HOSTNAME-HERE","IP-OR-HOSTNAME-HERE") # Permitted Manager(s) (Trap Destinations) in format @("manager1","manager2")
$CommString = @("COMMUNITY-STRING-HERE") # Community string(s) in format @("Community1","Community2")
$PermittedKey = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers"

#Import ServerManger Module
Import-Module ServerManager

#Check If SNMP Services Are Already Installed
$check = Get-WindowsFeature | Where-Object {$_.Name -eq "SNMP-Service"}
If ($check.Installed -ne "True") {
    #Install/Enable SNMP Services
    Add-WindowsFeature RSAT-SNMP,SNMP-Service,SNMP-WMI-Provider | Out-Null
}

$check = Get-WindowsFeature -Name SNMP-Service

 ##Verify Windows Services Are Enabled
 if ($check.Installed -eq "True"){
     Write-Host "Configuring SNMP Services..."
     
     # Set SNMP Permitted Manager(s) ** WARNING : This will over write current settings **
     
     # Uncomment the next line if you want to only except SNMP Packets from the Permitted Manager(s) (Trap Destinations). Be sure to comment out the "SNMP Packets from any host" lines
     # reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v 1 /t REG_SZ /d localhost /f | Out-Null
     
     # Uncomment the following lines if you want to accept SNMP Packets from any host
     # Begin "SNMP Packets from any host"
     if (Test-Path -Path $PermittedKey) {
        reg delete ($PermittedKey) /v 1 /f | Out-Null
     }
     # End "SNMP Packets from any host"

     #Set SNMP Traps and SNMP Community String(s)
     Foreach ($String in $CommString){
         reg add ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $String) /f | Out-Null
         # Set the Default value to be null
         reg delete ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $String) /ve /f | Out-Null
         reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" /v $String /t REG_DWORD /d 4 /f | Out-Null
         $i = 2
         Foreach ($Manager in $PManagers){
             # reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v $i /t REG_SZ /d $manager /f | Out-Null
             reg add ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $String) /v $i /t REG_SZ /d $manager /f | Out-Null
             $i++
         }
     }
 }
 else {
    Write-Host "Error: SNMP Services Not Installed"
 }
