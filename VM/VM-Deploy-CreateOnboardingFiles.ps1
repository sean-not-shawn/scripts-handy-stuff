<#
    ### Script to create Onboarding Text Files ###
    This script creates text files for the access management tool. It loads hostnames from a text file and creates a new text file in a shared folder.
    This can be modified for any use where you need to create a text document in a network share.
#>

$path = "\\SERVERNAME\SHARED-FOLDER\"
$email = "name@example.com"

foreach ($server in get-content "CSV\servers.txt") {
    if ($server.trim() -ne "") { 
        
        # Set file name and full path to file
        $file = "servers-"+$server+".txt"
        $pathandfile = $path+$file

        if ((Test-Path $pathandfile -PathType Leaf) -eq $false) {
            # The file does not already exist so create it
            Write-Host "Writing file - $file" -ForegroundColor Green
            New-Item -Path $path -Name $file -ItemType "file" -Value $server","$email
        }
        else {
            # The file already exists so warn and do nothing
            Write-Host "File $file already exists" -ForegroundColor Red
        }
    }
}
