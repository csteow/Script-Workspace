Param (
    [ValidateScript( { Test-Path $_} )]
    [string] $ConfigurationFile = $(Join-Path -Path $PSScriptRoot -ChildPath "Config.xml"),

    [switch] $SendMail
)

Import-Module $(Join-Path -Path $PSScriptRoot -Child PSHealthCheck)
#Import-Module PSHealthCheck

function Get-EncryptionKey {
    [CmdletBinding()]
    Param (
        [string] $KeyPath
    )

    if (-not ([System.IO.Path]::IsPathRooted($KeyPath))) {
        $KeyPath = Resolve-Path -Path $KeyPath
    }

    if (Test-Path $KeyPath) {
        $encodedKey = Get-Content $KeyPath -Raw
        $AESKey = [System.Convert]::FromBase64String($encodedKey)
    }

    Write-Output $AESKey
}

$Version = "1.0"

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

Write-Host "System Health Check Version $version"

# Load settings from a XML configuration file
Write-Host "Use configuration file: $ConfigurationFile"
[xml] $configFile = Get-Content $xmlPath

# Collecting the health check status
$systemHealthCheckStatus = @()
$connectionString = $configFile.Settings.Database.ConnectionString
$primarySqlServer = $configFile.Settings.Database.PrimaryServer

$taskToCheck = @()
Write-Verbose "Scheduled Tasks to be checked:"
foreach ($taskName in $configFile.Settings.ScheduledTasks.TaskName) {
    $taskToCheck += $taskName
}

$systemHealthCheckStatus += Get-ScheduledTaskStatus -TaskName $taskToCheck
$systemHealthCheckStatus += Get-LogicalDiskFree -ComputerName $env:COMPUTERNAME
$systemHealthCheckStatus += Get-SQLServerStatus -ConnectionString $connectionString -PrimaryServerName $primarySqlServer

# Generate reports
$overallStatus = Get-OverallStatus -HealthCheckStatus $systemHealthCheckStatus
$reportTitle = "Factset DataFeed Healthcheck - $overallStatus"

$textReportFile = Join-Path -Path $env:TEMP -ChildPath "HealthCheck_$(Get-Date -UFormat `"%Y%m%d`").txt"
Out-TextReport -HealthCheckStatus $systemHealthCheckStatus -FilePath $textReportFile -Title $reportTitle
Write-Host $(Get-Content $textReportFile -Raw)
Remove-Item $textReportFile

if ($SendMail) {
    Write-Host "Sending email ..."

    $htmlReportFile = Join-Path -Path $env:TEMP -ChildPath "HealthCheck_$(Get-Date -UFormat `"%Y%m%d`").html"
    Out-HtmlReport -HealthCheckStatus $systemHealthCheckStatus -FilePath $htmlReportFile -Title $reportTitle

    # Load encryption key
    $keyFile = $configFile.Settings.Encryption.KeyFile
    $AESKey = Get-EncryptionKey -KeyPath $keyFile

    # Email the report
    $awsAccessKey = $configFile.Settings.Mail.SMTPUser
    $awsSecretKey = $configFile.Settings.Mail.SMTPPassword
    $secureStringKey = $(ConvertTo-SecureString $awsSecretKey -Key $AESKey)
    $creds = $(New-Object System.Management.Automation.PSCredential ($awsAccessKey, $secureStringKey))

    $recipients = @()
    foreach ($emailAddress in $configFile.Settings.Mail.Recipients.Recipient) {
        $recipients += $emailAddress
    }

    $emailParam = @{
        SmtpServer = $configFile.Settings.Mail.SMTPServer
        Port       = $configFile.Settings.Mail.SMTPPort
        From       = $configFile.Settings.Mail.MailFrom
        Subject    = $reportTitle
        To         = $recipients
        Body       = Get-Content $htmlReportFile -Raw
        UseSsl     = $true
        BodyAsHtml = $true
        Credential = $creds
    }

    Send-MailMessage @emailParam -ErrorAction Continue
    Remove-Item $htmlReportFile
    Write-Debug "Removed HTML report file"
}

Remove-Module PSHealthCheck

$stopwatch.Stop()
Write-Host "Elapsed Time: $($stopwatch.Elapsed)"
Write-Host "Done!"