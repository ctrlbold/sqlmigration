﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Remove-DbaDbMirrorMonitor {
 <#
    .SYNOPSIS
            Stops and deletes the mirroring monitor job for all the databases on the server instance.
    
    .DESCRIPTION
            Stops and deletes the mirroring monitor job for all the databases on the server instance.
    
            Basically executes sp_dbmmonitordropmonitoring.
    
    .PARAMETER SqlInstance
            The target SQL Server instance
    
    .PARAMETER SqlCredential
            Login to the target instance using alternate Windows or SQL Login Authentication. Accepts credential objects (Get-Credential).

    .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
        
    .NOTES
            Author: Chrissy LeMaire (@cl), netnerds.net
            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
-           License: MIT https://opensource.org/licenses/MIT
    
        .LINK
            https://dbatools.io/Remove-DbaDbMirrorMonitor
    
        .EXAMPLE
            PS C:\> Remove-DbaDbMirrorMonitor -SqlInstance sql2008, sql2012
            
            Stops and deletes the mirroring monitor job for all the databases on sql2008 and sql2012.
#>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential -MinimumVersion 9
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            
            try {
                $server.Query("msdb.dbo.sp_dbmmonitordropmonitoring")
            }
            catch {
                Stop-Function -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
    }
}