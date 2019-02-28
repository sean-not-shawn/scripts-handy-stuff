<#
  ### Returns CPU, RAM, OS Name and SP Major Version
  ### Requires admin access on the remote servers
#>

$servers = get-content "CSV\servers.txt"
$serversandos ="CSV\Info\servers_os.csv"

function Get-CPUs {
    param ($server)    
    $processors = Get-WmiObject Win32_Processor -computername $server    
    if (@($processors)[0].NumberOfCores) {
        $cores = @($processors).count * @($processors)[0].NumberOfCores
    }
    else {
        $cores = @($processors).count
    }
    # $sockets = @(@($processors) |
    # % {$_.SocketDesignation} |
    # select-object -unique).count;        
    return $cores
}

$results = @()
foreach ($server in $servers) {
    $result = "" | Select servername, desc, sp, cpu, ram # , os, architecture
    $os =Get-WmiObject -class Win32_OperatingSystem -computername $server
    $ram = Get-WmiObject CIM_PhysicalMemory -computername $server | Measure-Object -Property capacity -sum | % {[math]::round(($_.sum / 1GB),2)} 
    $cpus = Get-CPUs $server    
    foreach($prop in $os) {
        "{0} {1} {2} {3} {4}" -f $server, $cpus, $ram, $prop.Caption, $prop.ServicePackMajorVersion
        $result.desc = $prop.Caption
        $result.sp = $prop.ServicePackMajorVersion
        # $result.os = $prop.Description
        # $result.architecture = $prop.OSArchitecture
    }

    $result.servername = $server
    $result.cpu = $cpus
    $result.ram = $ram
    $results += $result
}

$results | export-csv -NoTypeInformation $serversandos
