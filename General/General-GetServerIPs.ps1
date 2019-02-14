<#
    ### Script to lookup or reverse lookup Server Hostnames/IPs  ###

    The following looks up IP by Hostname
    
    Begin
#>

$serversandips ="CSV\servers_ips.csv"

$results = @()
foreach ($server in get-content "CSV\servers.txt") 
{
    if ($server.trim() -ne "") 
    {
        $result = "" | Select ServerName , ipaddress
        $result.ipaddress = [System.Net.Dns]::GetHostAddresses($server)
        $addresses = [System.Net.Dns]::GetHostAddresses($server)

        foreach($a in $addresses) 
        {
            "{0} ({1})" -f $server.ToString().ToUpper(), $a.IPAddressToString
            $result.ipaddress = [System.Net.Dns]::GetHostAddresses($server)
        }

        $result.servername = $server
        $result.ipaddress = $a.IPAddressToString
        $results += $result
    }
}

$results | export-csv -NoTypeInformation $serversandips

<#
    End
#>


<#
    The following looks up Hostname by IP

    Begin
#>

$ipsandservers ="CSV\ips_servers.csv"

$results = @()
foreach ($address in get-content "CSV\ips.txt") 
{
    if ($address.trim() -ne "") 
    {
        $result = "" | Select ServerName , IPAddress
        try
        {
            $servername = [System.Net.Dns]::GetHostEntry($address).HostName.ToString().ToUpper()
        }
        catch
        {
            $servername = $_.Exception.Message
        }

        "{0} ({1})" -f $servername, $address

        $result.servername = $servername
        $result.ipaddress = $address
        $results += $result
    }
}

$results | export-csv -NoTypeInformation $ipsandservers

<#
    End
#>
