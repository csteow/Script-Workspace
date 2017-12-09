 <#
    .SYNOPSIS
    Remove files that older than x days.

    .DESCRIPTION
    This script will remove files from a path that older than specific days.
    
    .PARAMETER Path
    Specifies the path which contains the file to be removed.

    .PARAMETER FilePattern
    Specifies the file pattern to be included.

    .PARAMETER RetainDays
     Specifying a number of days to retain.

    .EXAMPLE
    PS> .\Remove-Old-File.ps1 -Path D:\RDS\Soft\logs

    This example will remove all the files with file pattern "*.log" older than 7 days from D:\RDS\Soft\logs

    .EXAMPLE
    PS> .\Remove-Old-File.ps1 -RetainDays 30 -FilePatterns "*.log","*.csv" -Path D:\RDS\Soft\logs

    This example will remove all the files with file pattern ".log" or ".csv" from D:\RDS\Soft\logs that older than 30 days.
#>
       
[CmdletBinding()]    
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_}) ]
    # Specify the path
    [string] $Path,
        
    [string []] $FilePatterns = @("*.log"),

    [ValidateRange(1, [int]::MaxValue)]
    [int] $RetainDays = 7
)

$retainDate = (Get-Date).AddDays(-$RetainDays)
    
Write-Verbose "Path: $Path"
Write-Verbose "File Paterns: $FilePatterns"
Write-Verbose "Retain Date: $retainDate"

$totalDeleted = 0

$files = Get-ChildItem -Path $path | Where-Object {$_.LastWriteTime -lt $retainDate -and -not $_.PSIsContainer }

foreach ($file in $files) {
    foreach ($pattern in $FilePatterns) {
        if ($file.Name -like $pattern) {              
            try {  
                Write-Verbose "Removing $($file.FullName)"
                $file.Delete()
                $totalDeleted++
            } catch {
                Write-Warning $_.Exception.Message
            }
        }
    }
}

Write-Verbose "Total deleted file: $totalDeleted"    