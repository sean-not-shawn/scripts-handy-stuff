<#
    This script can be used to set the PW of a local account on remote computers
#>

$ErrorActionPreference = "Continue"

# This function checks to see if an account exists on a remote computer
function check-user($servername, $user) {
    $exists = $false
    try {
        $exists = [ADSI]::Exists("WinNT://$servername/$user")
    }
    catch {
        # If an account does not exist, it throws and exception rather than returning false
        # Write-Host "Exception caught"
    }
    return $exists
}

# UserCheck "SERVER-NAME-HERE" "ACCOUNT-NAME-HERE"

# This function resets a local account on a remote computer
function reset-localaccountpw ($servername, $account, $password) { 
    if (check-user $servername $account) {
        # Create computer object
        [ADSI]$server = "WinNT://$servername"
        $user = ([ADSI]"WinNT://$servername/$account")
    
        # Set password and set non-expiring
        write-host "Setting admin pw for server $servername"
        $user.SetPassword($password)
        $user.psbase.InvokeSet("userflags", 66049)
        $user.psbase.commitchanges()
    }    
}

$accountname = "ACCOUNT-NAME-HERE"
$newpassword = "NEW-PW-HERE"

$servers = Import-Csv "CSV\servers_resetpw.csv"

foreach ($server in $servers) {       
    # Set server FQDN
    $fqdn = "{0}.{1}" -f ($server.name, $server.domain)

    # Write-Host $fqdn

    reset-localaccountpw $fqdn $accountname $newpassword
}
