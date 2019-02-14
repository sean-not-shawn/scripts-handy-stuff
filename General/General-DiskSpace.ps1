<#
    ### Script to check free space available on a remote computer's C drive  ###
#>

$serversdiskspace ="CSV\servers_diskspace.csv"

$results = @()
foreach ($server in get-content "CSV\servers_diskspace.txt") {
    if ($server.trim() -ne "") {
        $result = "" | Select servername , freespace

        $freespace = [math]::round((Invoke-Command -ComputerName $server {Get-PSDrive C}).Free/1GB)

        $result.servername = $server
        $result.freespace = $freespace
        $results += $result
    }
}

$results | export-csv -NoTypeInformation $serversdiskspace
