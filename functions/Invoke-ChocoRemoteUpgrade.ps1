<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Invoke-ChocoRemoteUpgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ComputerName,
        [string[]]$AdditionalPackages,
        [string[]]$ExcludedPackages,
        [switch]$RebootifPending,
        [int]$JobTimeout
       # [System.Management.Automation.ScriptBlock]$Config
    )
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            choco config set virusScannerType VirusTotal | out-null
            choco feature enable -n virusCheck | out-null
            choco config set commandExecutionTimeoutSeconds 1800 | out-null
            choco feature enable -n reduceInstalledPackageSpaceUsage | out-null
            choco feature enable -n reduceOnlyNupkgSize | out-null
            choco feature enable -n useRememberedArgumentsForUpgrades | out-null
            choco feature enable -n adminOnlyExecutionForNewCommand | out-null
            choco feature enable -n adminOnlyExecutionForDownloadCommand  | out-null
           # choco source disable --name=chocolatey | out-null

            #Get list of locally installed packages to upgrade
            $packages = [System.Collections.ArrayList]@(choco outdated -r --ignore-unfound --ignore-pinned  | Foreach-Object {
                ($_.split("|"))[0]})

            foreach ($ExcludedPackage in $ExcludedPackages)
            {
                if ($packages -contains $ExcludedPackage)
                {
                    $packages.Remove($ExcludedPackage) | Out-Null
                }
            }
            foreach ($AddedBasePackage in $AdditionalPackage)
            {
                if ($packages -notcontains $AddedBasePackage)
                {
                    $packages.Add($AddedBasePackage) | Out-Null
                }
            }
            foreach ($package in $packages)
            {
                choco upgrade $package -r -y --timeout=600 | Out-File ("c:\Windows\Temp\choco-" + $package + ".txt")
                if ($LASTEXITCODE -ne 0)
                {
                    $Result = 'Failed'
                }
                else
                {
                    $Result = 'Success'
                }
                [PSCustomObject]@{
                    Name = $Package
                    Result = $Result
                    Computer = $Env:COMPUTERNAME
                }
            }
        }
        #Restart machines with pending Reboot
        Test-PendingReboot -ComputerName $ComputerName -SkipConfigurationManagerClientCheck | Where-Object {$_.IsRebootpending -eq $True } | ForEach-Object {
            Restart-Computer -ComputerName $_.ComputerName -Force
        }

    }
}