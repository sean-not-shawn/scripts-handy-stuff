<#
  ### Install .Net 3.5 feature on Windows Server 2012+

  Notes:
  Use this script if you are having issues enabling .Net 3.5. It can't be installed with the stand alone web/offline installer.
  It requires you to have the Windows 2012/2012 R2 ISOs available in a shared location.
  Run it directly on the server using PowerShell ISE. Unfortunately it cannot be executed remotely due to a double-hop authentication issue.
#>

Write-Host "Installing .Net 3.5" -ForegroundColor Red
$os = (Get-WmiObject -class Win32_OperatingSystem).Caption
$mounted = $true

# Mount the ISO based on what OS is installed
switch -wildcard ($os) {
  "Microsoft Windows Server 2012 R2*" { 
    "Mounting Windows 2012 R2 ISO"; Mount-DiskImage -ImagePath "\\SERVERNAME\PATH\2012R2.iso"; break
  }
  # For Win Server 2012: 
  "Microsoft Windows Server 2012*" { 
    "Mounting Windows 2012 Non-R2 ISO"; Mount-DiskImage -ImagePath "\\SERVERNAME\PATH\ISOs\2012.iso"; break 
  }
  default { 
    "Non 2012 OS - " + $os; $mounted = $false
  }
}

if ($mounted) {
  #Get Drive Letter
  $Drive = Get-Volume | where {$_.FileSystem -eq "UDF"} | foreach {$_.DriveLetter}

  #Install .Net 3.5
  Start-Process cmd -ArgumentList "/c dism /online /enable-feature /featurename:NetFX3 /all /Source:${drive}:\sources\sxs /LimitAccess" -Wait

  #Unmount the ISO
  switch -wildcard ($os) {
    "Microsoft Windows Server 2012 R2*" { 
      "Unmount Windows 2012 R2 ISO"; Dismount-DiskImage -ImagePath "\\dc01admtt01.molina.mhc\Shared\ISOs\2012R2.iso"; break
    }
    # For Win Server 2012: 
    "Microsoft Windows Server 2012*" { 
      "Unmount Windows 2012 Non-R2 ISO"; Dismount-DiskImage -ImagePath "\\dc01admtt01.molina.mhc\Shared\ISOs\2012.iso"; break 
    }
    default { 
      "Non 2012 OS - " + $os; $mounted = $false
    }
  }
}
