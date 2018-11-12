# Author: Sam Roberts

<#
.SYNOPSIS
Updates Configuration Manager content based on a list of PackageIDs.
.DESCRIPTION
Using a text file containing a list of PackageIDs this script will gradually update content
while attempting to maintain a specified number of packages in the distribution queue.
Progress will be logged to a file name content_update_yyyymmdd_hhmmss.log in the user's
local AppData temp folder.
.EXAMPLE
.\Update-SCCMContent.ps1 -SiteCode L01 -InputFile .\packageids.txt -InProgressThreshold 15 -TargetThreshold 100 -MaxConcurrent 25 -Delay 15
.PARAMETER SiteCode
The Configuration Manager site code.  (example:  L01)
.PARAMETER InputFile
Path to a text file containing a list of PackageIDs to update.
.PARAMETER InProgressThreshold
The number of packages with content distribution in progress.  This will be used to help
determine when more updates will occur.  This only applies to content that is targeting
a number of distribution points greater than or equal to the value of the TargetThreshold
parameter.
.PARAMETER TargetThreshold
The InProgressThreshold value will only apply to content that is targeting at a number
of distribution points greater than or equal to this value.
.PARAMETER MaxConcurrent
The number of content updates to run concurrently.  If not specified the default is 5.
.PARAMETER Delay
Number of minutes to delay between update cycles.  If not specified the default is 15.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,
               Position=0)]
    [string]
    $SiteCode,
    [Parameter(Mandatory=$true,
               Position=1)]
    [string]
    $InputFile,   
    [Parameter(Mandatory=$true,
               Position=2)]
    [int]
    $InProgressThreshold,
    [Parameter(Mandatory=$true,
               Position=3)]
    [int]
    $TargetThreshold,
    [Parameter(Mandatory=$false,
               Position=4)]
    [int]
    $MaxConcurrent=5,
    [Parameter(Mandatory=$false,
               Position=5)]
    [int]
    $Delay=15
)

function Import-SCCMPsModule {
    try {
		Import-Module "$(Split-Path $env:SMS_ADMIN_UI_PATH)\ConfigurationManager"
	} catch {
		Write-Host "Error trying to import ConfigurationManager module." -ForegroundColor Red
		Write-Host "Script will exit." -ForegroundColor Red
		pause
		Exit
	}
}

function Test-SCCMModule {
    $count = (Get-Module -Name "ConfigurationManager").Count
    if ($count -eq 0) {
        Import-SCCMPsModule
    }
}

function Test-SCCMSiteConnection {
    if ((Get-Location).Path -ne $($SiteCode + "\")) {
        try {
            if ($SiteCode -like "*:") {
                Set-Location $SiteCode
            } else {
                Set-Location $($SiteCode + ":")
            }
        } catch {
            Write-Host "Unable to connect to Site" -ForegroundColor Red
            Exit
        }
    }
}

function Get-SCCMDeploymentTypeName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                  Position=0)]
        [string]
        $ApplicationName
    )
    begin {
        Test-SCCMModule
        Test-SCCMSiteConnection
        $out = "Getting deployment type name(s) for $ApplicationName..."
        Write-Log -Message $out
    }
    process {
        $deploymentTypeName = (Get-CMDeploymentType -ApplicationName $ApplicationName -ErrorAction Stop).LocalizedDisplayName
    }
    end {
        $out = "Found deployment type name(s)."
        Write-Log -Message $out
        return $deploymentTypeName
    }
}

function Get-SCCMContentType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false,
                   ValueFromPipeline=$true)]
        [string]
        $Value,
        [Parameter(Mandatory=$true,
                   ParameterSetName = "Name")]
        [switch]
        $Name,
        [Parameter(Mandatory=$false,
                   ParameterSetName = "Id")]
        [switch]
        $Id
    )
    begin {
        Test-SCCMModule
        Test-SCCMSiteConnection
        $properties = @()
        $count = 0
        $out = "Beginning to process content info..."
        Write-Log -Message $out
        $out = "Querying for list of applications..."
        Write-Log -Message $out
        $apps = Get-CMApplication
        $out = "Querying for list of packages..."
        Write-Log -Message $out
        $packages = Get-CMPackage
        $out = "Querying for list of drivers packages..."
        Write-Log -Message $out
        $drivers = Get-CMDriverPackage
        $out = "Querying for list of software update deployment packages..."
        Write-Log -Message $out
        $updates = Get-CMSoftwareUpdateDeploymentPackage
        $out = "Querying for list of OS images..."
        Write-Log -Message $out
        $osImages = Get-CMOperatingSystemImage
        $out = "Querying for list of boot images..."
        Write-Log -Message $out
        $bootImages = Get-CMBootImage
    }
    process {
        $count++
        $out = "Processing $Value..."
        Write-Log -Message $out
        $found = $false
        $appTest = $null
        $packageTest = $null
        $driverTest = $null
        $updateTest = $null
        $imageTest = $null
        $bootTest = $null
        if ($Name) {
            if ($found -eq $false) {$appTest = $apps | Where-Object {$_.LocalizedDisplayName -eq $Value}}
            if ($appTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Application"
                    Id = $appTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
            if ($found -eq $false) {$packageTest = $packages | Where-Object {$_.Name -eq $Value}}
            if ($packageTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Package"
                    Id = $packageTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
            if ($found -eq $false) {$driverTest = $drivers | Where-Object {$_.Name -eq $Value}}
            if ($driverTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Driver"
                    Id = $driverTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
            if ($found -eq $false) {$updateTest = $updates | Where-Object {$_.Name -eq $Value}}
            if ($updateTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "SoftwareUpdate"
                    Id = $updateTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
            if ($found -eq $false) {$imageTest = $images | Where-Object {$_.Name -eq $Value}}
            if ($iamgeTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "OSImage"
                    Id = $imageTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
            if ($found -eq $false) {$bootTest = $bootImages | Where-Object {$_.Name -eq $Value}}
            if ($bootTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "BootImage"
                    Id = $bootTest.PackageId
                    Name = $Value
                    Index = $count
                }
            }
        }
        if ($Id) {
            if ($found -eq $false) {$appTest = $apps | Where-Object {$_.PackageID -eq $Value}}
            if ($appTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Application"
                    Id = $Value
                    Name = $appTest.LocalizedDisplayName
                    Index = $count
                }
            }
            if ($found -eq $false) {$packageTest = $packages | Where-Object {$_.PackageID -eq $Value}}
            if ($packageTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Package"
                    Id = $Value
                    Name = $packageTest.Name
                    Index = $count
                }
            }
            if ($found -eq $false) {$driverTest = $drivers | Where-Object {$_.PackageID -eq $Value}}
            if ($driverTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "Driver"
                    Id = $Value
                    Name = $driverTest.Name
                    Index = $count
                }
            }
            if ($found -eq $false) {$updateTest = $updates | Where-Object {$_.PackageID -eq $Value}}
            if ($updateTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "SoftwareUpdate"
                    Id = $Value
                    Name = $updateTest.Name
                    Index = $count
                }
            }
            if ($found -eq $false) {$imageTest = $images | Where-Object {$_.PackageID -eq $Value}}
            if ($imageTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "OSImage"
                    Id = $Value
                    Name = $imageTest.Name
                    Index = $count
                }
            }
            if ($found -eq $false) {$bootTest = $bootImages | Where-Object {$_.PackageID -eq $Value}}
            if ($bootTest -ne $null) {
                $found = $true
                $property = @{
                    Type = "BootImage"
                    Id = $Value
                    Name = $bootTest.Name
                    Index = $count
                }
            }
        }
        $content = New-Object -Property $property -TypeName psobject
        $properties += $content           
    }
    end {
        $out = "Completed processing $count items."
        Write-Log -Message $out
        return $properties
    }
}

function Update-SCCMContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   Position=0)]
        $ContentInfo
    )
    begin {
        Test-SCCMModule
        Test-SCCMSiteConnection
        $count = 1
        $out = "Starting to update content..."
        Write-Log -Message $out
    }
    process {        
        do {
            $available = Test-SCCMDistributionQueueAvailable
            if ($available -gt 0) {
                $out = "Updating $available packages..."
                Write-Log -Message $out
                for ($x = $count; $x -lt ($count + $available); $x++) {
                    $content = $ContentInfo | Where-Object {$_.Index -eq $count}
                    switch ($content.Type) {
                        "Application" {
                            $deploymentTypeNames = Get-SCCMDeploymentTypeName -ApplicationName $content.Name
                            foreach ($deploymentTypeName in $deploymentTypeNames) {
                                $out = "Updating $($content.Name) : $($content.Id) : $deploymentTypeName..."
                                Write-Log -Message $out
                                try {
                                    Update-CMDistributionPoint -ApplicationName $content.Name -DeploymentTypeName $deploymentTypeName
                                } catch {
                                    $out = "Error updating content."
                                    Write-Log -Message $out
                                }
                                $x++
                            }
                            $count++
                        }
                        "Driver" {
                            $out = "Updating $($content.Name) : $($content.Id)..."
                            Write-Log -Message $out
                            try {
                                Update-CMDistributionPoint -DriverPackageId $content.Id
                            } catch {
                                $out = "Error updating content."
                                Write-Log -Message $out
                            }
                            $x++
                            $count++
                        }
                        "Package" {
                            $out = "Updating $($content.Name) : $($content.Id)..."
                            Write-Log -Message $out
                            try {
                                Update-CMDistributionPoint -PackageId $content.Id
                            } catch {
                                $out = "Error updating content."
                                Write-Log -Message $out
                            }
                            $x++
                            $count++
                        }
                        "OSImage" {
                            $out = "Updating $($content.Name) : $($content.Id)..."
                            Write-Log -Message $out
                            try {
                                Update-CMDistributionPoint -OperatingSystemImageId $content.Id
                            } catch {
                                $out = "Error updating content."
                                Write-Log -Message $out
                            }
                            $x++
                            $count++
                        }
                        "SoftwareUpdate" {
                            $out = "Updating $($content.Name) : $($content.Id)..."
                            Write-Log -Message $out
                            try {
                                Update-CMDistributionPoint -SoftwareUpdateDeploymentPackageId $content.Id
                            } catch {
                                $out = "Error updating content."
                                Write-Log -Message $out
                            }
                            $x++
                            $count++
                        }
                        "BootImage" {
                            $out = "Updating $($content.Name) : $($content.Id)..."
                            Write-Log -Message $out
                            try {
                                Update-CMDistributionPoint -BootImageId $content.Id
                            } catch {
                                $out = "Error updating content."
                                Write-Log -Message $out
                            }
                            $x++
                            $count++
                        }
                        default {}
                    }
                }                            
            }
            else
            {
                $out = "Maximum content updates reached."
                Write-Log -Message $out
            }            
            if ($count -lt $ContentInfo.Count) {
                $out = "Waiting for $Delay minutes..."
                Write-Log -Message $out
                sleep -Seconds ($Delay * 60)
            } 
        } while ($count -lt $ContentInfo.Count)
    }
    end {
        $out = "Done updating content."
        Write-Log -Message $out
    }
}

function Test-SCCMDistributionQueueAvailable {
    [CmdletBinding()]
    param()
    begin{
        Test-SCCMModule
        Test-SCCMSiteConnection
        $inProgress = 0
    }
    process {        
        $inProgress = (Get-CMDistributionStatus | Where-Object {(($_.Targeted -gt $TargetThreshold) -and ($_.NumberInProgress -gt $InProgressThreshold)) -or (($_.Targeted -le $TargetThreshold) -and ($_.NumberInProgress -gt 0))}).Count
        $total = $MaxConcurrent - $inProgress
        if ($total -lt 0) {
            $total = 0
        }
    }
    end {
        $out = "$inProgress of $MaxConcurrent concurrent content updates in progress."
        Write-Log -Message $out
        return $total
    }
}

function Write-Log {
    param([string]$Message)
    $file = "$($env:LOCALAPPDATA)\Temp\content_update_$($Global:DateTime).log"
    Out-File -FilePath $file -Append -InputObject $((Get-Date -Format HH:mm:ss.fff) + "    " + $Message)
    Write-Host $Message
}

$Global:DateTime = Get-Date -Format "yyyyMMdd_HHmmss"
$startLocation = (Get-Location).Path

$ids = Get-Content -Path $InputFile
$contentInfo = $ids | Get-SCCMContentType -Id

Update-SCCMContent -ContentInfo $contentInfo

Set-Location $startLocation