<# 
    Generates a report that shows what Group Policy Objects affect a server and user in HTML format. 
    Begin 
#>
    GPResult /H report.html /S SERVER-NAME-HERE
<# 
    End 
#>


<#
    List group memberships of an account
    Begin
#>    
    Import-Module ActiveDirectory    
    Get-ADPrincipalGroupMembership "ACCOUNT-NAME-HERE"
<# 
    End 
#>


<#
    List AD Group members
    Begin
#>
    Import-Module ActiveDirectory
    Get-ADGroupMember -identity "ADGROUP-NAME-HERE" | Select Name
<# 
    End 
#>


<#
    Get a computer's OU
    Begin
#>
    ([adsisearcher]"(&(name=$env:computername)(objectClass=computer))").findall().path
<# 
    End 
#>


<# 
    Use this for resetting the computer account in AD. Possible solution when a server cannot connect to logon service.
    Begin
#>
    $server = "SERVER-NAME-HERE"
    $domain = "DOMAIN-NAME-HERE"

    netdom reset $server /d: $domain /po: *
<# 
    End 
#>
