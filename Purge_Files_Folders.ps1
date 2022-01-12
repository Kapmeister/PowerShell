<#
.SYNOPSIS
This Script will delete files with a predefined file spec from specific directories that are old than a specfied period. 
  
.DESCRIPTION
This Script is deleting files from specific directories.
You can specify the age of the files to be deleted and choose file types and directories.
  
.PARAMETER Settings
Point to the locaton of the settings.ini file. This file has the format: 

[General]
ReportOnly=
Input=

[Email]
SMTP=
From=
SendTo=
BCC=

[Genral]
ReportOnly:
- True: will generate a report and not actually delete any files or folders
- False: will delete the files & folders as per spec. 

Input:
- the full path of the csv file. Format of csv file = path,filespec,days. 

[Email]
SMTP: FQDN or IP Address of the SMTP server
From: The email address of the account that will send the mail. 
SentTo: A comma separated list of email address that will receive the log file. 
BBC: A comma separated list of email address that will receive a blind copy of the log file. 

.EXAMPLE
    
    At Powershell Prompt
    C:\PS> .\Purge_Files_Folders.ps1 -Settings c:\ProgramData\Purge\Settings.ini
 
    As a scheduled task
    Program: Powershell.exe
    Parameters: -executionpolicy bypass -NoLogo -NonInteractive -WindowStyle Hidden -file "C:\Scripts\Purge_Files_Folders.ps1" -Settings C:\AutoPurge\Settings.ini

.LINK
https://cyberkap.com.au
 
.NOTES
Author: John Kapaniris
Last Edit: 13/1/22

Reference: Philippe Tschumi - https://techblog.ptschumi.ch/automation-scripting/powershell-clean-script/
 
.INPUTS
None.
 
.OUTPUTS
None.
 
#>

[CmdletBinding()]
Param (
    [Parameter(Position = 0, Mandatory = $true, HelpMessage = 'Require the location of the settings.ini file')]
    [String[]]
    [ValidateScript(
        {
            $_ | Foreach-Object {
                if (-not (Test-Path $_)) {
                    throw "Path '$_' does not exist!"
                }
                return $_
            }
             
        }
    )]
    $Settings
)

$Lines = Get-Content $settings
$param=@()
foreach ($Line in $Lines){
    $k = [regex]::split($Line,'=')
    if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True) -and ($k[0].StartsWith("#") -ne $True)) { 
        $param.Add($k[0], $k[1]) 
    } 
}

<#
    Set Variables
#>
$InputFile = $param.input
$SendTo = $param.SendTo
$From = $param.from
$BCC = $param.BCC
$ReportOnly = $Param.ReportOnly
$SMTPServer = $Param.SMTP

$tempFolder = "$($env:TEMP)"
$timestamp = [System.String]::Format("$(Get-Date -Format "yyMMddHHmmss")")
$logfile = "$tempFolder\Purge_Files_Folders_$timestamp.log"
$Version = "0.3"
$Spacer = "-" * 80

<#
    Logging function
#>
function Write-Log {
    Param(
		[parameter(Mandatory=$true)]
		[string]$Text,
		[parameter(Mandatory=$false)]
		[ValidateSet("Warning","Error","Info")]
		[String] $Type = "Info"
    )
    [string]$logMessage = [System.String]::Format("[$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")] -"),$Type, $Text
    Add-Content -Path $LogFile -Value $logMessage
}

<#
    Function to remove files meeting the specified path & file type older than a specific number of days
#>
function removeOldFiles {
    param(
		[parameter(Mandatory=$true)]
        [string]$Path,
		[parameter(Mandatory=$true)]
        [string]$FileSpec,
		[parameter(Mandatory=$true)]
        [int]$Days
    )
    $FileNames = Get-ChildItem -recurse $Path -Include $FileSpec -File | Where-Object {$_.lastwritetime -lt (get-date).addDays(-$Days)}
    foreach ($fileName in $FileNames){
        $FullFileName = $fileName.FullName
        try{
            if ($ReportOnly -eq $False){
                Remove-Item -Force -LiteralPath $FullfileName -Confirm:$false -ErrorAction SilentlyContinue
            }
            Write-Log "Delete: $FullFileName." Info
            $Script:FilesDeleted++
        } catch {
            Write-Log "Failed to delete: $FullFileName." Warning
        }
    }
}

<#
    Function to delete empty folders - recursive from deepest to shallowest by calling itself 
#>
function removeEmptyFolders {
    param(
		[parameter(Mandatory=$true)]
        [string]$Path
    )
    foreach ($childDirectory in Get-ChildItem -Force -LiteralPath $Path -Directory) {
        removeEmptyFolders -Path $childDirectory.FullName
    }
    $currentChildren = Get-ChildItem -Force -LiteralPath $Path
    $isEmpty = $null -eq $currentChildren
    if ($isEmpty) {
        try {
            if ($ReportOnly -eq $False){
                Remove-Item -Force -LiteralPath $Path -Confirm:$false -ErrorAction SilentlyContinue
            }
            Write-Log "Removing empty folder at path: '${Path}'." Info
            $Script:FoldersDeleted++
        } catch {
            Write-Log "Could not remove folder: '${Path}'." Warning
        }
    }
}

<#
    Function to send email notification 
#>
Function NotifyPurgeResult {
    # email configuration
    If ($SendTo.Count + $BCC.Count -gt 0){
        $smtp = new-object system.net.mail.smtpClient($SMTPServer)
        $mail = new-object System.Net.Mail.MailMessage

        $subject="$env:ComputerName Automatic Purge Results"

        if ($ReportOnly -eq $True){
            $Body = "REPORT ONLY - you need to change the setting in the config file to actually delete the files / folders.`n`nThe attached file contains what would be deleted."
        } else {
            $body = "### Files & Folders as per attached have been deleted."
        }
        $mail.attachments.add($LogFile)

        # List of emails to receive a notification 
        $mail.from = $From

        If ($SendTo){
            $SendTo.Split(",") | ForEach-Object {
            $mail.to.Add($_)
            }
        }
        If ($BCC){
            $BCC.Split(",") | ForEach-Object {
                $mail.bcc.add($_)
            }
        }
        $mail.subject = $subject
        $mail.body = $body
        $mail.IsBodyHtml = $False
        $smtp.send($mail)

        # Cleanup
        $mail.Dispose()
        $smtp.Dispose()
    } else {
        Write-Log "There was noone to send the email to" Error
    }
}

<#
    MainLine
#>
Write-Log "### Start ###" Info
Write-Log "Version: $Version" Info
Write-Log "Settings File: $Settings" Info
Write-Log "Input File: $InputFile" Info
Write-Log "SendTo: $SendTo" Info
Write-Log "From: $From" Info
Write-Log "Report Only: $ReportOnly" Info
Write-Log "SMTP Server: $SMTPServer" Info
Write-Log "Temp Folder: $tempFolder" Info
Write-Log "Log File: $logfile" Info

If (Test-Path -Path $InputFile){
    foreach ($line in Get-Content $InputFile){
        $FilesDeleted = 0
        $FoldersDeleted = 0
        Write-Log $Spacer Info
        $Path,$FileSpec,$Days = $line.split(",")
        Write-Log "Path:$Path FileSpec:$FileSpec Days:$Days" Info
        Write-Log $Spacer Info

        If (($Path.StartsWith("c:\Windows","CurrentCultureIgnoreCase") -eq $True) -or ($Path.StartsWith("c:\Program","CurrentCultureIgnoreCase") -eq $True)){ # Try to protect system files
            Write-Log "You cannot specify $Path as an imput parameter" Error
        } else {
            If (Test-Path -Path $Path){
                If ($Days -match "^\d+$"){
                    If ($FileSpec -eq ""){
                        $FileSpec = "*"
                    }
                    removeOldFiles -Path $Path -FileSpec $FileSpec -Days $Days
                    removeEmptyFolders -Path $Path
                } else {
                    Write-Log "$Days is not a positive integer to work with" Error
                }
            } else {
                Write-Log "The Path $Path does not exist" Error
            }
        }
        Write-Log "Removed $FilesDeleted files and $FoldersDeleted folders." Info
    }
} else {
    Write-Log "Unable to find $InputFile" Error
}
Write-Log $Spacer Info
Write-Log "#### End ####" Info
NotifyPurgeResult

<#
    Clean up this scripts log files
#>
removeOldFiles -Path $tempFolder -FileSpec "Purge_Files_Folders*.log" -Days 7
