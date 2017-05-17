Function Get-DbaTrigger {
<#
.SYNOPSIS
Get all existing triggers on one or more SQL instances.

.DESCRIPTION
Get all existing triggers on one or more SQL instances.

Default output includes columns ComputerName, SqlInstance, Database, TriggerName, IsEnabled and DateLastMofied.

.PARAMETER SqlInstance
The SQL Instance that you're connecting to.

.PARAMETER SqlCredential
SqlCredential object used to connect to the SQL Server as a different user.
	
.PARAMETER Database
The database(s) to process - this list is autopopulated from the server. If unspecified, all databases will be processed.

.PARAMETER Exclude
The database(s) to exclude - this list is autopopulated from the server

.NOTES
Author: Klaas Vandenberghe ( @PowerDBAKlaas )
Website: https://dbatools.io
Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
 https://dbatools.io/Get-DbaTrigger

.EXAMPLE
Get-DbaTrigger -SqlInstance ComputerA\sql987

Returns a custom object displaying ComputerName, SqlInstance, Database, TriggerName, IsEnabled and DateLastMofied.

.EXAMPLE
Get-DbaTrigger -SqlInstance 'ComputerA\sql987','ComputerB'

Returns a custom object displaying ComputerName, SqlInstance, Database, TriggerName, IsEnabled and DateLastMofied from two instances.

.EXAMPLE
Get-DbaTrigger -SqlInstance ComputerA\sql987 | Out-Gridview

Returns a gridview displaying ComputerName, SqlInstance, Database, TriggerName, IsEnabled and DateLastMofied.

.EXAMPLE
'ComputerA\sql987','ComputerB' | Get-DbaTrigger | Out-Gridview

Returns a custom object displaying ComputerName, SqlInstance, Database, TriggerName, IsEnabled and DateLastMofied from two instances.

#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer", "instance")]
		[string[]]$SqlInstance,
		[Alias("Credential")]
		[PSCredential][System.Management.Automation.CredentialAttribute()]
		$SqlCredential,
		[Alias("Databases")]
		[object[]]$Database,
		[object[]]$Exclude
	)
	
	process {
		foreach ($Instance in $SqlInstance) {
			Write-Verbose "Connecting to $Instance"
			try {
				$server = Connect-SqlServer -SqlServer $Instance -SqlCredential $SqlCredential -Erroraction SilentlyContinue
			}
			catch {
				Write-Warning "Can't connect to $Instance"
				continue
			}
			
			Write-Verbose "Getting Server Level Triggers on $Instance"
			$server.Triggers |
			ForEach-Object {
				[PSCustomObject]@{
					ComputerName = $server.NetName
					InstanceName = $server.ServiceName
					SqlInstance = $server.DomainInstanceName
					TriggerLevel = "Server"
					Database = $null
					TriggerName = $_.Name
					Status = switch ($_.IsEnabled) { $true { "Enabled" } $false { "Disabled" } }
					DateLastModified = $_.DateLastModified
				}
			}
			
			Write-Verbose "Getting Database Level Triggers on $Instance"
			$dbs = $server.Databases | Where-Object { $_.status -eq 'Normal' }
			
			if ($database) {
				$dbs = $dbs | Where-Object Name -in $database
			}
			if ($exclude) {
				$dbs = $dbs | Where-Object Name -notin $exclude
			}
			
			$dbs |
			ForEach-Object {
				$DatabaseName = $_.Name
				Write-Verbose "Getting Database Level Triggers on Database $DatabaseName on $Instance"
				$_.Triggers |
				ForEach-Object {
					[PSCustomObject]@{
						ComputerName = $server.NetName
						InstanceName = $server.ServiceName
						SqlInstance = $server.DomainInstanceName
						TriggerLevel = "Database"
						Database = $DatabaseName
						TriggerName = $_.Name
						Status = switch ($_.IsEnabled) { $true { "Enabled" } $false { "Disabled" } }
						DateLastModified = $_.DateLastModified
					}
				}
			}
		}
	}
}
Register-DbaTeppArgumentCompleter -Command Get-DbaTrigger -Parameter Database, Exclude