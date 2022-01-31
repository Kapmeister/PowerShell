#
$TimeStamp = [System.String]::Format("$(Get-Date -Format "yyMMddHHmmss")")
$LogFile = "$env:temp\WriteLog_$TimeStamp.log"
function Write-Log {
    Param(
		[parameter(Mandatory=$true)]
		[string]$Text,

		[parameter(Mandatory=$False)]
		[ValidateSet("Warning","Error","Info")]
		[String] $Type = "Info"
    )
    [string]$logMessage = [System.String]::Format("[$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")] -"),$Type, $Text
    Add-Content -Path $LogFile -Value $logMessage
}
#


Write-Log "Test" Info
Write-Log "Test" Error
Write-Log "Test" Warning
Write-Log "Test"
