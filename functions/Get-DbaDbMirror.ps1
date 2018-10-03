﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Get-DbaDbMirror {
    <#
        .SYNOPSIS
            Gets properties of database mirrors.

        .DESCRIPTION
            Gets properties of database mirrors.

        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection and receive pipeline input to allow the function
            to be executed against multiple SQL Server instances.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)
    
        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Mirror, HA
            Author: Chrissy LeMaire (@cl), netnerds.net
            dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
            Copyright (C) 2016 Chrissy LeMaire
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Get-DbaDbMirror

        .EXAMPLE
            Get-DbaDbMirror -SqlInstance localhost

            Returns all Endpoint(s) on the local default SQL Server instance

        .EXAMPLE
            Get-DbaDbMirror -SqlInstance localhost, sql2016

            Returns all Endpoint(s) for the local and sql2016 SQL Server instances
    #>
    [CmdletBinding()]
    param (
        [parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            Get-DbaDatabase -SqlInstance $instance -SqlCredential $SqlCredential | Where-Object IsMirroringEnabled |
            Select-DefaultView -Property ComputerName, InstanceName, SqlInstance, Name, MirroringSafetyLevel, MirroringStatus, MirroringPartner, MirroringPartnerInstance, MirroringFailoverLogSequenceNumber, MirroringID, MirroringRedoQueueMaxSize, MirroringRoleSequence, MirroringSafetySequence, MirroringTimeout, MirroringWitness, MirroringWitnessStatus
        }
    }
}