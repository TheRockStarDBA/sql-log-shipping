﻿param (
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName
)

function Get-ConnectionString {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SqlServerName
    )

    return "data source = $SqlServerName; initial catalog = master; trusted_connection = true; application name = sql-log-shipping;"
}

function Get-LogShippingConfiguration {
    
}
function Get-PrimaryDatabases {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SqlServerName
    )

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection(Get-ConnectionString -SqlServerName $SqlServerName)
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandText = "
        select
	        primary_id, primary_database, backup_directory,
	        backup_share, backup_retention_period,
	        backup_job_id, monitor_server,
	        monitor_server_security_mode, last_backup_file,
	        last_backup_date, backup_compression
        from msdb.dbo.log_shipping_primary_databases;"

    $Output = New-Object System.Data.DataTable
    $sda = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmd)
    $sda.Fill($Output) | Out-Null

    $PrimaryDatabases = @()

    foreach ($Row in $Output.Rows) {
        $PrimaryDatabase = New-Object System.Object
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "PrimaryId" -Value ([System.Guid]::Parse($Row["primary_id"]))
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value $Row["primary_database"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "BackupDirectory" -Value $Row["backup_directory"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "BackupShare" -Value $Row["backup_share"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "BackupRetentionPeriod" -Value ([System.Convert]::ToInt32($Row["backup_retention_period"]))
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "MonitorServer" -Value $Row["monitor_server"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "MonitorServerSecurityMode" -Value ([System.Convert]::ToInt32($Row["monitor_server_security_mode"]))
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "LastBackupFile" -Value $Row["last_backup_file"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "LastBackupDate" -Value $Row["last_backup_date"]
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "BackupCompression" -Value ([System.Convert]::ToInt32($Row["backup_compression"]))
        $PrimaryDatabase | Add-Member -MemberType NoteProperty -Name "BackupJob" -Value (Get-AgentJob -SqlServerName $SqlServerName -JobId ([System.Guid]::Parse($Row["backup_job_id"])))

        $PrimaryDatabases += $PrimaryDatabase
    }

    return $PrimaryDatabases
}
function Get-SecondaryDatabases {

}

function Get-AgentJob {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SqlServerName,

        [Parameter(Mandatory = $true)]
        [Guid]$JobId
    )

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection(Get-ConnectionString -SqlServerName $SqlServerName)
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandText = "
        select job_id, name
        from msdb.dbo.sysjobs
        where job_id = @job_id;"

    $JobIdParam = New-Object System.Data.SqlClient.SqlParameter("@job_id", [System.Data.SqlDbType]::UniqueIdentifier)
    $JobIdParam.Value = $JobId

    $SqlCmd.Parameters.Add($JobIdParam) | Out-Null

    $Output = New-Object System.Data.DataTable
    $sda = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCmd)

    $sda.Fill($Output) | Out-Null

    if ($Output.Rows.Count -eq 0) {
        return $null
    }

    $Job = New-Object System.Object
    $Job | Add-Member -MemberType NoteProperty -Name "JobId" -Value ([System.Guid]::Parse($Output.Rows[0]["job_id"]))
    $Job | Add-Member -MemberType NoteProperty -Name "JobName" -Value $Output.Rows[0]["name"]

    return $Job
}

Get-PrimaryDatabases -SqlServerName $SqlServerName