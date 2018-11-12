# Update-SCCMContent

I recently encountered a challenge at one of my customers where the content library on the distribution points had become corrupted.  The result was that we had to update the content of every package, application, driver, image etc. in order to correct the issue in the content library.  If you have ever had to do this before you know that this can be a very time consuming activity depending on how much content you have and the size of the environment.  My solution was to write a PowerShell script to do the heavy lifting for me.  You can download the script below.

The script is designed to maintain a specified number of packages updating at all times.  I didn't want to overwhelm the site or queue up too many updates in case something higher priority needs to be updated.  The script will check for how many content updates on in an "In Progress" state and try not to exceed the number specified.  If the script determines that content can be updated it will update packages based off of a list of PackageIDs specified in a text file.  After updating the packages the script will wait for a specified number of minutes.  After the wait period it will again check for the number of packages in progress and update more content if below the threshold.  The script will continue until it has updated all packages in the file.

Its important to note that the InProgressThreshold parameter only applies to content that is targeted to a number of distribution points greater than the value in the TargetThreshold parameter.  This option was created for large scale distribution where pull DPs may be in use and where there are a some sites that have slower network connections.  If this does not apply to you I would recommend either setting the TargetThreshold parameter to a value higher than the number of DPs you have or set InProgressThreshold to 0.

## Usage

### NAME

Update-SCCMContent.ps1

### SYNOPSIS

Updates Configuration Manager content based on a list of PackageIDs.

### SYNTAX

.\Update-SCCMContent.ps1 [-SiteCode] <String> [-InputFile] <String> [-InProgressThreshold] <Int32> [-TargetThreshold] <Int32> [[-MaxConcurrent] <Int32>] [[-Delay] <Int32>] [<CommonParameters>]

### DESCRIPTION

Using a text file containing a list of PackageIDs this script will gradually update content
while attempting to maintain a specified number of packages in the distribution queue.
Progress will be logged to a file name content_update_yyyymmdd_hhmmss.log in the user's
local AppData temp folder.

### PARAMETERS

**-SiteCode <String>**

The Configuration Manager site code. (example: L01)

Required? true
Position? 1
Default value
Accept pipeline input? false
Accept wildcard characters? false

**-InputFile <String>**

Path to a text file containing a list of PackageIDs to update.

Required? true
Position? 2
Default value
Accept pipeline input? false
Accept wildcard characters? false

**-InProgressThreshold <Int32>**

The number of packages with content distribution in progress. This will be used to help
determine when more updates will occur. This only applies to content that is targeting
a number of distribution points greater than or equal to the value of the TargetThreshold
parameter.

Required? true
Position? 3
Default value 0
Accept pipeline input? false
Accept wildcard characters? false

**-TargetThreshold <Int32>**

The InProgressThreshold value will only apply to content that is targeting at a number
of distribution points greater than or equal to this value.

Required? true
Position? 4
Default value 0
Accept pipeline input? false
Accept wildcard characters? false

**-MaxConcurrent <Int32>**

The number of content updates to run concurrently. If not specified the default is 5.

Required? false
Position? 5
Default value 5
Accept pipeline input? false
Accept wildcard characters? false

**-Delay <Int32>**

Number of minutes to delay between update cycles. If not specified the default is 15.

Required? false
Position? 6
Default value 15
Accept pipeline input? false
Accept wildcard characters? false

*<CommonParameters>*

This cmdlet supports the common parameters: Verbose, Debug,
ErrorAction, ErrorVariable, WarningAction, WarningVariable,
OutBuffer, PipelineVariable, and OutVariable. For more information, see
about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).


**INPUTS**

**OUTPUTS**

#### Example 1

PS C:\>.\Update-SCCMContent.ps1 -SiteCode L01 -InputFile .\packageids.txt -InProgressThreshold 15 -TargetThreshold 100 -MaxConcurrent 25 -Delay 15 
