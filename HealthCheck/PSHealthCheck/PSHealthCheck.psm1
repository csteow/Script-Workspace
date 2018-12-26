# Constants
$StatusOK = "OK"
$StatusFailed = "FAILED"

function Format-PadCenter {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [int] $Length
    )

    if ($Message.Length -gt $Length) {
        $_ = $Message.Length
    }

    $padLeft = [int] (($Length - $Message.Length) / 2)
    if ($padLeft -lt 0) {
        $padLeft = 0
    }

    $padRight = $Length - $padLeft - $Message.Length
    if ($padRight -lt 0) {
        $padRight = 0
    }

    return $("{0}{1}{2}" -f (" " * $padLeft), $Message, (" " * $padRight))
}

function Out-TextReport {
    [CmdletBinding()]
    Param (
        [PSObject []] $HealthCheckStatus,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string] $Title = "Health Check Report"
    )

    $nl = [Environment]::NewLine

    $textReport += $("=" * 80) + "$nl"
    $textReport += $Title + "$nl"
    $textReport += $("-" * 80) + "$nl"
    
    foreach ($status in $systemHealthCheckStatus) {
        $statusText = Format-PadCenter -Message $status.Status -Length 6
        $message = "{0}[{1}]$nl" -f $status.Description.PadRight(72, "."), $statusText
        $textReport += $Message
        if ($status.Remark) {
            foreach ($line in $status.Remark) {
                $textReport += "|-- $line$nl"
            }
        }
        $textReport += "$nl"
    }

    $textReport += $("-" * 80) + "$nl"
    $textReport += "Created Time: $(Get-Date -UFormat `"%Y-%m-%d %H:%M:%S`")$nl"
    $textReport += "Created From: $($env:COMPUTERNAME)$nl"
    $textReport += $("=" * 80)
    $textReport | Out-File -FilePath $FilePath
}

function Out-HtmlReport {
    [CmdletBinding()]
    Param (
        [PSObject []] $HealthCheckStatus,

        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string] $Title
    )

    $htmlBody = ""
    foreach ($status in $HealthCheckStatus) {
        if ($status.Status -eq "OK") {
            $statusStyle = "status-success"
        }
        else {
            $statusStyle = "status-error"
        }
     
        if ($status.Remark) {
            $remark = "<ul>"
            foreach ($line in $status.Remark) {
                $remark += "<li>" + $line + "</li>"
            }
            $remark += "</ul>"
        }
        else {
            $remark = ""
        }
     
        $htmlBody += $("<tr><td><b>{0}</b>{1}</td><td><div class=`"{2}`">{3}</div></td></tr>" -f $status.Description, $remark, $statusStyle, $status.Status)
    }

    # HTML header
    $htmlHeader = @"
<html>
<head>
    <style>
    body {
        font-family: Verdana;
        color: #5F6062;
    }
    h1 {
        color: #0B236B;
        font-size: 110%;
    }
    ul {
        list-style-type: square;
    }
    small {
        font-size: 9px;
    }
    .status-success {
        border: 1px solid transparent;
        border-radius: 3px;
        width: 48px;
        height: 16px;
        background-color: #89C341;
        text-align: center;
        color: white;
    }
    .status-error {
        border: 1px solid transparent;
        border-radius: 3px;
        background-color: red;
        width: 48px;
        height: 16px;
        text-align: center;
        color: white;
    }
    table, td, tr, th {
        border: 1px solid #9C9E9F;
        border-collapse: collapse;
        font-size: 11px;
        padding: 5px;
    }
    th {
        text-align: left;
        background-color: #5F6062;
        color: white;
    }
    </style>
</head>
<body>
    <h1>${Title}</h1>
    <table>
    <tr>
        <th>Checked Item</th>
        <th>Status</th>
    </tr>
"@

    $createdTime = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $createdFrom = $env:COMPUTERNAME
    # HTML footer
    $htmlFooter = @"
    </table>
    <small>Created Time: ${createdTime} | Created From: ${createdFrom}</small>
</body>
</html>
"@

    $htmlHeader + $htmlbody + $htmlFooter | Out-File -FilePath $FilePath
}

function Get-OverallStatus {
    [CmdletBinding()]
    Param (
        [PSObject []] $HealthCheckStatus
    )

    $overallStatus = "OK"
    foreach ($status in $HealthCheckStatus) {
        if ($status.Status -ne "OK") {
            $overallStatus = "Failed"
        }
    }

    Write-Output $overallStatus
}

function Get-LogicalDiskFree {
    [CmdletBinding()]
    Param (
        [ValidateRange(1, 100)]
        [decimal] $Threshold = 80,

        [string []] $ComputerName = $env:COMPUTERNAME
    )

    $healthStatus = @{
        Status      = $StatusOK
        Description = "Check Disk Free less than ${Threshold}%"
        Remark      = @()
    }

    foreach ($computer in $ComputerName) {
        $drives = Get-WmiObject Win32_LogicalDisk -ComputerName $computer

        foreach ($drive in $drives) {
            $usedSpace = $drive.Size - $drive.FreeSpace
            $usedSpacePercentage = ($usedSpace / $drive.Size) * 100

            # Check the threshold
            if ($usedSpacePercentage -ge $Threshold) {
                $indicator = "!"
                $healthStatus.Status = $StatusFailed
            }
            else {
                $indicator = ""
            }

            $message = "{0,-13} ({1}): Size {2:N1} GB, Used {3:N1}% {4}" -f $computer, $drive.DeviceID, ($drive.Size / 1GB), $usedSpacePercentage, $indicator
            $healthStatus.Remark += $message
        }
    }

    New-Object PSObject -Property $healthStatus
}

function Get-ScheduledTaskStatus {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string []] $TaskName,

        [string []] $ComputerName = $env:COMPUTERNAME
    )

    $healthStatus = @{
        Status      = $statusOK
        Description = "Check Scheduled Task Status"
        Remark      = @()
    }

    $so = New-CimSessionOption -Protocol Default

    foreach ($computer in $ComputerName) {
        $cimSession = New-CimSession -ComputerName $computer -SessionOption $so
        $taskInfo = Get-ScheduledTask -CimSession $cimSession | Where-Object { $_.TaskName -in $TaskName } | Get-ScheduledTaskInfo

        foreach ($info in $taskInfo) {
            if ($info.LastTaskResult -eq 0) {
                $healthStatus.Remark += "$($info.TaskName) in $computer completed successfully on $($info.LastRunTime)"
            }
            else {
                $healthStatus.Status = $StatusFailed
                $healthStatus.Remark += "$($info.TaskName) in $computer failed with status $($info.LastTaskResult) !"
            }
        }
    }

    New-Object PSObject -Property $healthStatus
}

function Get-SQLServerStatus {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string] $ConnectionString,

        [securestring] $Password,

        [string] $PrimaryServerName
    )

    $healthStatus = @{
        Status      = $statusOK
        Description = "Check SQL Server"
        Remark      = @()
    }

    $conn = New-Object System.Data.SqlClient.SqlConnection

    $conn.ConnectionString = $ConnectionString
    if ($Password) {
        $conn.Credential.Password = $Password
    }

    Write-Verbose "Checking SQL server status ..."

    $connected = $false

    try {
        $conn.Open()
        #$databaseName = $conn.Database()

        # Check the primary server is up
        if ($PrimaryServerName) {
            $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $sqlCmd.Connection = $conn

            $sqlCmd.CommandText = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS ComputerName"

            $reader = $sqlCmd.ExecuteReader()
            while ($reader.Read()) {
                $databaseComputerName = $reader['ComputerName']

                Write-Verbose "MSSQL is running on $databaseComputerName"

                if ($PrimaryServerName -icontains $databaseComputerName) {
                    $healthStatus.Remark += "MSSQL is running on Primary: $PrimaryServerName"
                }
                else {
                    $healthStatus.Status = $StatusFailed
                    $healthStatus.Remark += "MSSQL is not running on $PrimaryServerName but $databaseComputerName"
                }
            }
        }

    }
    catch {
        $healthStatus.Status = $StatusFailed
        $healthStatus.Remark += $_.Exception.Message.Split("`n")
    }
    finally {
        if ($connected) {
            $conn.Close()
        }
    }

    New-Object PSObject -Property $healthStatus
}

Export-ModuleMember -Function 'Get-*'
Export-ModuleMember -Function 'Format-PadCenter'
Export-ModuleMember -Function 'Out-*'