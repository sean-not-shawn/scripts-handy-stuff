<#
  ### Copy a Config File and Restart a Service ###
  
  Notes:
  This script loads a list of servers and copies a config file from a shared location, and then stops/starts a service.
  This was used specifically for Splunk, but it can be modified for any Windows service that loads settings from a config file. 
  The script generates a CSV file of the results - Server, IP, Service Status, Service Start Type, and Errors.
#>

$servers = Import-Csv .\CSV\servers_config_change.csv
$servicename = "SplunkForwarder"

$results = @()

foreach ($server in $servers) {
    # if ($server.trim() -ne "") { 
        $servername = $server.ServerName
        $serverip = $server.IPAddress   
        $result = "" | Select ServerName , IPAddress , ServiceStatus , ServiceStartType , Errors
        $servicestatus = ""    
        $servicestart = ""
        $errorcapture = ""
        
        # Robocopy the config file to the target server. Don't retry if there's an error.
        RoboCopy \\SERVERNAME\PATH\CONFIGUPDATE \\$servername\C$\PATH /R:0
        
        # Restart the Service If file is successfully copied
        if ($lastexitcode -eq 1 -Or $lastexitcode -eq 3) {    
            Write-Host "Restarting Service"
            Restart-Service -InputObject $(Get-Service -Name $servicename -Computer $servername) -Force
            try {
                $service = (Get-Service -Name $servicename -Computer $servername)
                $servicestatus = $service.Status
                $servicestart = $service.StartType
            }
            catch {
                $servicestatus = "Unknown"
                if ($servicestart -eq "") { $servicestart = "Unknown" }
                $errorcapture += "Could not retrieve $servicename Service details. "
            }

            Write-Host "Service status is now" $servicestatus
        }
        # If the file exists don't restart the service (Exists as in source's and destination's file have same timestamp/file size)
        if ($lastexitcode -eq 0) {
            Write-Host "File already exists. Service will not be restarted"
            $errorcapture = "File already exists. "
            try {
                $service = (Get-Service -Name $servicename -Computer $servername)
                $servicestatus = $service.Status
                $servicestart = $service.StartType
            }
            catch {
                $servicestatus = "Unknown"
                if ($servicestart -eq "") { $servicestart = "Unknown" }
                $errorcapture += "Could not retrieve $servicename Service details"
            }
        }
        # All other errors
        if ($lastexitcode -gt 8) {

            Write-Host "Filecopy error occurred. Service will not be resarted"
            $errorcapture = "Filecopy error occurred. "
        }

        $result.ServerName = $servername
        $result.IPAddress =  $serverip
        $result.ServiceStatus = $servicestatus
        $result.ServiceStartType = $servicestart
        $result.Errors = $errorcapture
        $results += $result
    # }
}

$splunkresults ="CSV\server_config_change_results_.csv"

$results | export-csv -NoTypeInformation $splunkresults
