
# For Native AD
Import-Module ActiveDirectory

# For DRA
# Import-Module NetIQ.DRA.DRAPowerShellExtensions

# Prompt for credentials with permission to unjoin a computer from the domain
$credential = Get-Credential

# Load servers from CSV
$servers = Import-Csv "CSV\servers_decom.csv"

# Loop through server list
foreach ($server in $servers) {    
    # Set server FQDN
    $fqdn = "{0}.{1}" -f ($server.name, $server.domain)

    # Remove from domain (Native AD)
    Remove-Computer -ComputerName $fqdn -UnjoinDomainCredential $credential -Workgroup WORKGROUP -PassThru -Verbose -Restart 

    # Remove from domain (Native DRA)
    # Remove-DRAComputer -Domain $server.domain -Identifier $server.name
}
