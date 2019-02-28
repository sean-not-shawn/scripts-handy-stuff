<#
  ### Exports Roles and Features from servers in XML format 
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
    $exportpath = "CSV\Installs\Temp\Features\" + $server + "_Features.xml"
    Invoke-Command -ComputerName $server {
        Get-WindowsFeature | ? { $_.Installed -AND $_.SubFeatures.Count -eq 0 } | Export-Clixml $($args[0])
    } -ArgumentList $exportpath
}

<#
  ### Imports Roles and Features to servers from export XML file
#>

Import-Module ServerManager

# CSV Path
$csvimport = "CSV\Installs\Features\ImportServers.csv" 

# Load CSV 
$vms = Import-Csv $csvimport

# Load XML
$ServerFeatures = Import-Clixml "CSV\Installs\Features\SERVER-NAME-HERE_Features.xml"

foreach ($vm in $vms) {    
    $servername = $vm.Name + "." + $vm.Domain
    Write-Host "Enabling features on" $servername    
    
    ## Uncomment for Windows Server 2012+ 
    foreach ($feature in $ServerFeatures) { Install-WindowsFeature -ComputerName $servername -Name $feature.name }
    
    <#
    ## Uncomment for Windows Server 2008 R2
    Invoke-Command -ComputerName $servername -ScriptBlock {
        foreach ($feature in $($args[0])) { Import-Module ServerManager; Add-WindowsFeature -Name $feature.name }
    } -ArgumentList $ServerFeatures
    #>
}
