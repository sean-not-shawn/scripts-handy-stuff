# This script will search the entire forest for server. It checks across all trusted domains.
# Adapted from https://carlwebster.com/finding-domain-trusts-active-directory-forest-using-microsoft-powershell/

Import-module ActiveDirectory

$server = "SERVER-NAME-HERE"
$domains = (Get-ADForest).Domains

# Continue if Get-ADForest didn't error and result is not null 
if ($? -and $domains -ne $Null) {
	ForEach($domain in $domains) { 
		Write-output "Get list of AD Domain Trusts in $domain `r"; 
		$ADDomainTrusts = Get-ADObject -Filter {ObjectClass -eq "trustedDomain"} -Server $domain -Properties * -EA 0
        # Continue if Get-ADObject didn't error and result is not null
		if ($? -and $ADDomainTrusts -ne $Null) {
            # If the results are an array then get count. Otherwise return count of one
			if ($ADDomainTrusts -is [array]) {
				[int]$ADDomainTrustsCount = $ADDomainTrusts.Count 
			}
			else {
				[int]$ADDomainTrustsCount = 1
			}			
			Write-Output "Discovered $ADDomainTrustsCount trusts in $domain"
            # Loop through each domain and search for the server
			ForEach($Trust in $ADDomainTrusts) { 
                Write-Host "Checking" $Trust.Name
                try {                
                    $server = Get-ADComputer -Identity $server -Server $Trust.Name
                    Write-Host -ForegroundColor Green "Found in" $Trust.Name
                }
                catch {                    
                    Write-Host -ForegroundColor Red "Not found in" $Trust.Name
                }                
			}
		}
		elseif (!$?) {
			# Error retrieving domain trusts
			Write-output -ForegroundColor Red "Error retrieving domain trusts for $domain"
		}
		else {
			# No domain trust data
			Write-output "No domain trust data for $domain"
		}
	} 
}
elseif (!$?) {
	#error retrieving domains
	Write-output -ForegroundColor Red "Error retrieving domains"
}
else {
	#no domain data
	Write-output "No domain data"
}
