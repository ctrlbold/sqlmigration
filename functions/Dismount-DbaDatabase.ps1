﻿function Dismount-DbaDatabase {
	<#
		.SYNOPSIS
			Detach a SQL Server Database

		.DESCRIPTION
			This command will detach a SQL Server database

		.PARAMETER SqlInstance
			The target SQL Server

		.PARAMETER SqlCredential
			PSCredential object to connect as. If not specified, current Windows login will be used

		.PARAMETER Database
			A string value that specifies the name of the database to be detached

		.PARAMETER FileStructure
			A StringCollection object value that contains a list database files
	
		.PARAMETER DatabaseOwner
			Returns list of SQL Server databases owned by the specified logins
	
		.PARAMETER DatabaseCollection
			A collection of databases (such as returned by Get-DbaDatabase), to be deetached.

		.PARAMETER AttachOption
			A AttachOptions object value that contains the attachment options. Valid options include 
			None, RebuildLog, EnableBroker, NewBroker and ErrorBrokerConversations
		
		.PARAMETER UpdateStatistics
			A switch that specifies whether to update the statistics for the database before detaching it
	
		.PARAMETER Force
			If database is part of a mirror, it will break the mirror. If it is part of an Availability Group, it will remove it from the Availability Group.
	
		.PARAMETER WhatIf
			Shows what would happen if the command were to run. No actions are actually performed

		.PARAMETER Confirm
			Prompts you for confirmation before executing any changing operations within the command

		.PARAMETER Silent
			Use this switch to disable any kind of verbose messages

		.NOTES
			Tags: Database
			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Dismount-DbaDatabase

		.EXAMPLE
			Detach-DbaDatabase -SqlInstance sql2016b -Database SharePoint_Config

			Incomplete example, hold on

		.EXAMPLE
			Get-DbaDatabase -SqlInstance sql2016b -Database 'PerformancePoint Service Application_10032db0fa0041df8f913f558a5dc0d4' | Detach-DbaDatabase -Force

			Incomplete example, hold on
	
			.EXAMPLE
			Get-DbaDatabase -SqlInstance sql2016b -Database 'PerformancePoint Service Application_10032db0fa0041df8f913f558a5dc0d4' | Detach-DbaDatabase -Force -WhatIf

			Incomplete example, hold on
	
	#>
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Default")]
	Param (
		[parameter(Mandatory, ParameterSetName = 'SqlInstance')]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[PSCredential][System.Management.Automation.CredentialAttribute()]
		$SqlCredential,
		[parameter(Mandatory, ParameterSetName = 'SqlInstance')]
		[string]$Database,
		[parameter(Mandatory, ParameterSetName = 'Pineline', ValueFromPipeline)]
		[Microsoft.SqlServer.Management.Smo.Database[]]$DatabaseCollection,
		[Switch]$UpdateStatistics,
		[switch]$Force,
		[switch]$Silent
	)
	process {
		foreach ($instance in $SqlInstance) {
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}
			
			if ($Database) {
				$DatabaseCollection += $server.Databases | Where-Object Name -in $Database
			}
			else {
				$DatabaseCollection += $server.Databases
			}
			
			if ($ExcludeDatabase) {
				$DatabaseCollection = $DatabaseCollection | Where-Object Name -NotIn $ExcludeDatabase
			}
		}
		
		foreach ($db in $DatabaseCollection) {
			$server = $db.Parent
			Write-Message -Level Verbose -Message "Checking replication status"
			if ($db.ReplicationOptions -ne "None") {
				Stop-Function -Message "Skipping $db  on $server because it is replicated" -Target $db -Continue
			}
			
			Write-Message -Level Verbose -Message "Checking mirror status"
			if ($db.IsMirroringEnabled -and !$Force) {
				Stop-Function -Message "$db on $server is being mirrored. Use -Force to break mirror or use the safer backup/restore method." -Target $db -Continue
			}
			
			Write-Message -Level Verbose -Message "Checking Availability Group status"
			
			if ($db.AvailabilityGroupName -and !$Force) {
				$ag = $db.AvailabilityGroupName
				Stop-Function -Message "$db on $server is part of an Availability Group ($ag). Use -Force to drop from $ag availability group to detach. Alternatively, you can use the safer backup/restore method." -Target $db -Continue
			}
			
			$sessions = Get-DbaProcess -SqlInstance $db.Parent -Database $db.Name
			
			if ($sessions -and !$Force) {
				Stop-Function -Message "$db on $server currently has connected users and cannot be dropped. Use -Force to kill all connections and detach the database." -Target $db -Continue
			}
			
			if ($force) {
				
				if ($sessions) {
					$sessions | Stop-DbaProcess
				}
				
				if ($db.IsMirroringEnabled) {
					If ($Pscmdlet.ShouldProcess($server, "Breaking mirror for $db on $server")) {
						try {
							Write-Message -Level Warning -Message "Breaking mirror for $db on $server"
							$db.ChangeMirroringState([Microsoft.SqlServer.Management.Smo.MirroringOption]::Off)
							$db.Alter()
							$db.Refresh()
						}
						catch {
							Stop-Function -Message "Could not break mirror for $db on $server - not detaching" -Target $db -ErrorRecord $_ -Continue
						}
					}
				}
				
				if ($db.AvailabilityGroupName) {
					$ag = $db.AvailabilityGroupName
					If ($Pscmdlet.ShouldProcess($server, "Attempting remove $db on $server from Availability Group $ag")) {
						try {
							$server.AvailabilityGroups[$ag].AvailabilityDatabases[$db.name].Drop()
							Write-Message -Level Verbose -Message "Successfully removed $db from  detach from $ag on $server"
						}
						catch {
							if ($_.Exception.InnerException) {
								$exception = $_.Exception.InnerException.ToString() -Split "System.Data.SqlClient.SqlException: "
								$exception = " | $(($exception[1] -Split "at Microsoft.SqlServer.Management.Common.ConnectionManager")[0])".TrimEnd()
							}
							
							Stop-Function -Message "Could not remove $db from $ag on $server $exception" -Target $db -ErrorRecord $_ -Continue
						}
					}
				}
				
				# try again w/e
				if ($sessions) {
					$sessions | Stop-DbaProcess
				}
			}
			
			If ($Pscmdlet.ShouldProcess($server, "Detaching $db on $server")) {
				try {
					$server.DetachDatabase($db.Name, $UpdateStatistics)
					
					[pscustomobject]@{
						ComputerName = $server.NetName
						InstanceName = $server.ServiceName
						SqlInstance = $server.DomainInstanceName
						Database = $db.name
						DetachStatus = "Success"
					}
				}
				catch {
					Stop-Function -Message "Failure" -Target $db -ErrorRecord $_ -Continue
				}
			}
		}
	}
}