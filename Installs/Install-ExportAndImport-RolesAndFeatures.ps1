<#
  ### Exports Roles and Features from servers in XML format 
  
  Notes:
  This script exports the Roles/Features from servers listed in a text file and saves them as XML files
#>

Import-Module Servermanager

## Windows Server 2012+
foreach ($server in get-content "CSV\Installs\Features\ExportServers.txt") {

    $exportpath = "CSV\Installs\Features\" + $server + "_Features.xml"

    # Get-WindowsFeature | ? { $_.Installed } | Select Name | ForEach-Object { $_.Name } | Out-File .\Features.txt
    Get-WindowsFeature -ComputerName $server | ? { $_.Installed -AND $_.SubFeatures.Count -eq 0 } | Export-Clixml $exportpath

}

## Windows Server 2008 R2
foreach ($server in get-content "CSV\Installs\Features\ExportServers.txt") {
    $exportpath = "CSV\Installs\Features\" + $server + "_Features.xml"
    Invoke-Command -ComputerName $server {
        Get-WindowsFeature | ? { $_.Installed -AND $_.SubFeatures.Count -eq 0 } | Export-Clixml $($args[0])
    } -ArgumentList $exportpath
}


<#
  ### Imports Roles and Features to servers from export XML file
  
  Notes:
  This script loads the exported Roles/Features XML file and enables them in the servers listed in a text file.
#>

Import-Module ServerManager

# Load XML
$ServerFeatures = Import-Clixml "CSV\Installs\Features\SERVER-NAME-HERE_Features.xml"

foreach ($server in get-content "CSV\Installs\Features\ImportServers.txt") {
    Write-Host "Enabling features on" $server    
    
    Invoke-Command -ComputerName $server -ScriptBlock {
        foreach ($feature in $($args[0])) { Import-Module ServerManager; Add-WindowsFeature -Name $feature.name }
    } -ArgumentList $ServerFeatures
}
