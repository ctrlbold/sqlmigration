function Copy-DbaEndpoint {
    <#
        .SYNOPSIS
            Copy-DbaEndpoint migrates server endpoints from one SQL Server to another.

        .DESCRIPTION
            By default, all endpoints are copied.

            If the endpoint already exists on the destination, it will be skipped unless -Force is used.

        .PARAMETER Source
            Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

        .PARAMETER SourceSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Destination
            Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2000 or higher.

        .PARAMETER DestinationSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Endpoint
            The endpoint(s) to process. This list is auto-populated from the server. If unspecified, all endpoints will be processed.

        .PARAMETER ExcludeEndpoint
            The endpoint(s) to exclude. This list is auto-populated from the server.

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .PARAMETER Force
            If this switch is enabled, existing endpoints on Destination with matching names from Source will be dropped.

        .NOTES
            Tags: Migration, Endpoint
            Author: Chrissy LeMaire (@cl), netnerds.net
            Requires: sysadmin access on SQL Servers

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Copy-DbaEndpoint

        .EXAMPLE
            Copy-DbaEndpoint -Source sqlserver2014a -Destination sqlcluster

            Copies all server endpoints from sqlserver2014a to sqlcluster, using Windows credentials. If endpoints with the same name exist on sqlcluster, they will be skipped.

        .EXAMPLE
            Copy-DbaEndpoint -Source sqlserver2014a -SourceSqlCredential $cred -Destination sqlcluster -Endpoint tg_noDbDrop -Force

            Copies only the tg_noDbDrop endpoint from sqlserver2014a to sqlcluster using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If an endpoint with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

        .EXAMPLE
            Copy-DbaEndpoint -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

            Shows what would happen if the command were executed using force.
    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Source,
        [PSCredential]
        $SourceSqlCredential,
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter[]]$Destination,
        [PSCredential]
        $DestinationSqlCredential,
        [object[]]$Endpoint,
        [object[]]$ExcludeEndpoint,
        [switch]$Force,
        [Alias('Silent')]
        [switch]$EnableException
    )

    begin {
        try {
            Write-Message -Level Verbose -Message "Connecting to $Source"
            $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential -MinimumVersion 9
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $Source
            return
        }
        $serverEndpoints = $sourceServer.Endpoints | Where-Object IsSystemObject -eq $false
    }
    process {
        if (Test-FunctionInterrupt) { return }
        foreach ($destinstance in $Destination) {
            $destServer = Connect-SqlInstance -SqlInstance $destinstance -SqlCredential $DestinationSqlCredential -MinimumVersion 9
            $destEndpoints = $destServer.Endpoints
            
            foreach ($currentEndpoint in $serverEndpoints) {
                $endpointName = $currentEndpoint.Name
                
                $copyEndpointStatus = [pscustomobject]@{
                    SourceServer = $sourceServer.Name
                    DestinationServer = $destServer.Name
                    Name         = $endpointName
                    Type         = "Endpoint"
                    Status       = $null
                    Notes        = $null
                    DateTime     = [DbaDateTime](Get-Date)
                }
                
                if ($Endpoint -and $Endpoint -notcontains $endpointName -or $ExcludeEndpoint -contains $endpointName) {
                    continue
                }
                
                if ($destEndpoints.Name -contains $endpointName) {
                    if ($force -eq $false) {
                        $copyEndpointStatus.Status = "Skipped"
                        $copyEndpointStatus.Notes = "Already exists"
                        $copyEndpointStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                        
                        Write-Message -Level Verbose -Message "Server endpoint $endpointName exists at destination. Use -Force to drop and migrate."
                        continue
                    }
                    else {
                        if ($Pscmdlet.ShouldProcess($destinstance, "Dropping server endpoint $endpointName and recreating.")) {
                            try {
                                Write-Message -Level Verbose -Message "Dropping server endpoint $endpointName."
                                $destServer.Endpoints[$endpointName].Drop()
                            }
                            catch {
                                $copyEndpointStatus.Status = "Failed"
                                $copyEndpointStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                                
                                Stop-Function -Message "Issue dropping server endpoint." -Target $endpointName -ErrorRecord $_ -Continue
                            }
                        }
                    }
                }
                
                if ($Pscmdlet.ShouldProcess($destinstance, "Creating server endpoint $endpointName.")) {
                    try {
                        Write-Message -Level Verbose -Message "Copying server endpoint $endpointName."
                        $destServer.Query($currentEndpoint.Script()) | Out-Null
                        
                        $copyEndpointStatus.Status = "Successful"
                        $copyEndpointStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                    }
                    catch {
                        $copyEndpointStatus.Status = "Failed"
                        $copyEndpointStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                        
                        Stop-Function -Message "Issue creating server endpoint." -Target $endpointName -ErrorRecord $_
                    }
                }
            }
        }
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlEndpoint
    }
}