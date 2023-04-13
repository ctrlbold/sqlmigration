function Get-DbaReplPublisher {
    <#
    .SYNOPSIS
        Gets publisher for the target SQL instances.

    .DESCRIPTION
        Gets publisher for the target SQL instances.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Tags: Replication
        Author: Mikey Bronowski (@MikeyBronowski), bronowski.it

        Website: https://dbatools.io
        Copyright: (c) 2022 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaReplPublisher

    .EXAMPLE
        PS C:\> Get-DbaReplPublisher -SqlInstance mssql1

        Gets publisher for the mssql1 instance.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
                $replServer = Get-DbaReplServer -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $server -Continue
            }
            Write-Message -Level Verbose -Message "Getting publisher for $server"

            try {
                if ($PSCmdlet.ShouldProcess($server, "Getting publisher for $server")) {
                    $publisher = $replServer.DistributionPublishers
                }
            } catch {
                Stop-Function -Message "Unable to get publisher for" -ErrorRecord $_ -Target $server -Continue
            }

            # fails if there isn't any
            if ($publisher) {
                $publisher | Add-Member -Type NoteProperty -Name ComputerName -Value $server.ComputerName -Force
                $publisher | Add-Member -Type NoteProperty -Name InstanceName -Value $server.ServiceName -Force
                $publisher | Add-Member -Type NoteProperty -Name SqlInstance -Value $server.DomainInstanceName -Force
            }


            Select-DefaultView -InputObject $publisher -Property ComputerName, InstanceName, SqlInstance, Status, WorkingDirectory, DistributionDatabase, DistributionPublications, PublisherType, Name

        }
    }
}
