﻿#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function New-DbaEndpoint {
    <#
        .SYNOPSIS
            Creates SQL Server endpoints.

        .DESCRIPTION
            Creates SQL Server endpoints.
    
        .PARAMETER SqlInstance
            SQL Server name or SMO object representing the SQL Server to connect to. This can be a collection and receive pipeline input to allow the function
            to be executed against multiple SQL Server instances.

        .PARAMETER SqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .PARAMETER Name
            The name of the endpoint. If a name is not specified, one will be auto-generated.
    
        .PARAMETER Type
            The type of endpoint. Defaults to DatabaseMirroring. Options: DatabaseMirroring, ServiceBroker, Soap, TSql

        .PARAMETER Protocol
            The type of protocol. Defaults to tcp. Options: Tcp, NamedPipes, Http, Via, SharedMemory

        .PARAMETER Role
            The type of role. Defaults to All. Options: All, None, Partner, Witness
    
        .PARAMETER Port
            Port for TCP. If one is not provided, it will be autogenerated.
    
        .PARAMETER SslPort
            Port for SSL

        .NOTES
            Tags: Endpoint
            Author: Chrissy LeMaire (@cl), netnerds.net
            dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
            Copyright (C) 2016 Chrissy LeMaire
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/New-DbaEndpoint

        .EXAMPLE
            New-DbaEndpoint -SqlInstance localhost

            Returns all Endpoint(s) on the local default SQL Server instance

        .EXAMPLE
            Net-DbaEndpoint -SqlInstance localhost, sql2016

            Returns all Endpoint(s) for the local and sql2016 SQL Server instances
    #>
    [CmdletBinding()]
    param (
        [parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string]$Name,
        [ValidateSet('DatabaseMirroring', 'ServiceBroker', 'Soap', 'TSql')]
        [string]$Type = 'DatabaseMirroring',
        [ValidateSet('Tcp', 'NamedPipes', 'Http', 'Via', 'SharedMemory')]
        [string]$Protocol = 'Tcp',
        [ValidateSet('All', 'None', 'Partner', 'Witness')]
        [string]$Role = 'All',
        [int]$Port,
        [int]$SslPort,
        [switch]$EnableException
    )
    
    process {
        if ((Test-Bound -ParameterName Name -Not)) {
            $name = "endpoint-" + [DateTime]::Now.ToString('s').Replace(":", "-")
        }
        
        foreach ($instance in $SqlInstance) {
            Write-Message -Level Verbose -Message "Connecting to $instance"
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
            
            # Thanks to https://github.com/mmessano/PowerShell/blob/master/SQL-ConfigureDatabaseMirroring.ps1
            if (Test-Bound -ParameterName Port) {
                $tcpPort = $port
            }
            else {
                $thisport = (Get-DbaEndPoint -SqlInstance $server).Protocol.Tcp
                $measure = $thisport | Measure-Object ListenerPort -Maximum
                
                if ($null -eq $thisport) {
                    $tcpPort = 5022
                }
                elseif ($measure.Maximum) {
                    $maxPort = $measure.Maximum
                    #choose a random port that is greater than the current max port
                    $tcpPort = $maxPort + (New-Object Random).Next(1, 500)
                }
                else {
                    $maxPort = 5000
                    #choose a random port that is greater than the current max port
                    $tcpPort = $maxPort + (New-Object Random).Next(1, 500)
                }
            }
            
            try {
                $endpoint = New-Object Microsoft.SqlServer.Management.Smo.EndPoint $server, $Name
                $endpoint.ProtocolType = [Microsoft.SqlServer.Management.Smo.ProtocolType]::$Protocol
                $endpoint.EndpointType = [Microsoft.SqlServer.Management.Smo.EndpointType]::$Type
                if ($Protocol -eq "TCP") {
                    $endpoint.Protocol.Tcp.ListenerPort = $tcpPort
                    $endpoint.Payload.DatabaseMirroring.ServerMirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::$Role
                    if (Test-Bound -ParameterName SslPort) {
                        $endpoint.Protocol.Tcp.SslPort = $SslPort
                    }
                }
                $null = $endpoint.Create()
                $server.Endpoints.Refresh()
                Get-DbaEndpoint -SqlInstance $server -Endpoint $name
            }
            catch {
                Stop-Function -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
    }
}