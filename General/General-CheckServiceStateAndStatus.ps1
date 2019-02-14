<#
    This script checks if a service exists and what its current statue and status is on remote computers. It generates a CSV file with the results.
    
    The example is searching for the SNMP Trap and VM Tools services.
#>

# SNMPTRAP
# VMTools

# Path for Result CSV File
$serversandips ="CSV\Services_Check.csv"

# Variable to hold results
$results = @()

# Prompts for a domain account that has access to all the servers that will be checked
$cred = Get-Credential -Message "Please Enter Account Username And Password"

# Path to CSV File of Servers to Check
foreach ($server in Import-Csv "CSV\Test_Servers.csv") { 

    $services = Invoke-Command -ComputerName $server.Host -Credential $cred -ScriptBlock { 
        Get-WmiObject win32_service -Filter "Name = 'SNMPTRAP' Or Name = 'VMTools'"
    }

    if ($services -ne $null) {
    
        $service_one_found = $false
        $service_two_found = $false

        foreach ($service in $services) { 

            if ($service.Name -eq "SNMPTRAP") { $service_one_found = $true } 
            if ($service.Name -eq "VMTools") { $service_two_found = $true } 

            $result = "" | Select Server, Service, State, Status 
            $result.Server = $server.Host 
            $result.Service = $service.Name 
            $result.State = $service.State 
            $result.Status = $service.Status 

            $results += $result 
        } 

        if ($service_one_found -eq $false) { 
            $result = "" | Select Server, Service, State, Status 
            $result.Server = $server.Host 
            $result.Service = "SNMPTRAP" 
            $result.State = "Not found" 
            $result.Status = "" 

            $results += $result 
        } 

        if ($service_two_found -eq $false) { 
            $result = "" | Select Server, Service, State, Status 
            $result.Server = $server.Host 
            $result.Service = "VMTools" 
            $result.State = "Not found" 
            $result.Status = "" 

            $results += $result 
        } 

    }
    else {
        $result = "" | Select Server, Service, State, Status 
        $result.Server = $server.Host 
        $result.Service = "SNMPTRAP" 
        $result.State = "Not found" 
        $result.Status = "" 

        $results += $result 

        $result = "" | Select Server, Service, State, Status 
        $result.Server = $server.Host 
        $result.Service = "VMTools" 
        $result.State = "Not found" 
        $result.Status = "" 

        $results += $result 
    }

}

$results | export-csv -NoTypeInformation $serversandips
