<#
  ### Enables/Configure SNMP ###
  
  Notes:
  This script enables the SNMP feature if it is not already enabled. It also configures the settings as defined in the variables.
  This is a slightly modified version of a script found here: https://social.technet.microsoft.com/Forums/office/en-US/ee1630da-06bb-4c15-9427-b55e4ec8f0e1/how-to-configure-snmp-community-string-and-snmp-server-ip-through-a-scriptshell-scriptpower?forum=winserverpowershell
#>

$destination = @("IPADDRESS","HOSTNAME") 
$commstring = @("molina1shore") # ADD YOUR COMMUNITY STRING(s) in format @("Community1","Community2")
# Do not modify the next line
$permittedmanagerpath = "\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers"

#Import ServerManger Module
Import-Module ServerManager

#Check if SNMP-Service is already installed
$check = Get-WindowsFeature -Name SNMP-Service

if ($check.Installed -ne "True") {
    # Install/Enable SNMP-Service
    Write-Host "SNMP Service Installing..."
    Get-WindowsFeature -name SNMP* | Add-WindowsFeature -IncludeManagementTools | Out-Null
}

$check = Get-WindowsFeature -Name SNMP-Service
##Verify Windows Services Are Enabled
if ($check.Installed -eq "True") {
    Write-Host "Configuring SNMP Services..."
    
    # Set SNMP Permitted Manager(s) - These are the IPs/Hostnames listed under the "Accept SNMP packets from these hosts" option.
    # Uncomment the next line if you want to only accept packets from these hosts.
    # reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v 1 /t REG_SZ /d localhost /f | Out-Null
    # Comment out the next if statement if you want to only accept packets from the above hosts. Leaving the if statement will select the "Accept SNMP packets from any host" option.
    if (Test-Path -Path "HKLM:$permittedmanagerpath") {
        Write-Host "Deleting default Security host"
        reg delete "HKEY_LOCAL_MACHINE$permittedmanagerpath" /v 1 /f | Out-Null
    }

    # Set SNMP Traps and SNMP Community String(s)
    Foreach ($string in $commstring) {
        reg add ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $string) /f | Out-Null
        # Set the Default value to be null
        reg delete ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $string) /ve /f | Out-Null
        reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" /v $string /t REG_DWORD /d 4 /f | Out-Null
        $i = 2
        Foreach ($manager in $destination) {
            # reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" /v $i /t REG_SZ /d $manager /f | Out-Null
            reg add ("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration\" + $string) /v $i /t REG_SZ /d $manager /f | Out-Null
            $i++
        }
    }
}
else {
    Write-Host "Error: SNMP Services Not Installed"
}
