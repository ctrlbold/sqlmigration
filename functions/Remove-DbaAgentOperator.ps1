function Remove-DbaAgentOperator {
    <#
    .SYNOPSIS
        Removes a new operator on an instance.

    .DESCRIPTION
        Drop an operator from SQL Agent.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Operator
        Name of the operator in SQL Agent.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Agent, Operator
        Author: Tracy Boggiano (@TracyBoggiano), databasesuperhero.com

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Remove-DbaAgentOperator

    .EXAMPLE
        PS:\> Remove-DbaAgentOperator -SqlInstance sql01 -Operator DBA

        This removes an operator named DBA from the instance.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [parameter(Mandatory)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Operator,
        [switch]$EnableException
    )

    begin {
    }

    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failed" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ((Get-DbaAgentOperator -SqlInstance $server -Operator $Operator).Count -ne 0) {
                if ($Pscmdlet.ShouldProcess($instance, "Dropping operator $operator")) {
                    try {
                        Write-Message -Level Verbose -Message "Dropping Operator $operator"
                        $server.JobServer.Operators[$operator].Drop()

                        Get-DbaAgentOperator -SqlInstance $server -Operator $Operator
                    } catch {
                        Stop-Function -Message "Issue dropping operator" -Category InvalidOperation -ErrorRecord $_ -Target $instance
                    }
                }
            }
        }
    }
}function Remove-DbaAgentOperator {
    <#
    .SYNOPSIS
        Removes a new operator on an instance.

    .DESCRIPTION
        Drop an operator from SQL Agent.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Operator
        Name of the operator in SQL Agent.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Agent, Operator
        Author: Tracy Boggiano (@TracyBoggiano), databasesuperhero.com

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Remove-DbaAgentOperator

    .EXAMPLE
        PS:\> Remove-DbaAgentOperator -SqlInstance sql01 -Operator DBA

        This removes an operator named DBA from the instance.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [parameter(Mandatory)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [parameter(Mandatory)]
        [string]$Operator,
        [switch]$EnableException
    )

    begin {
    }

    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failed" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ((Get-DbaAgentOperator -SqlInstance $server -Operator $Operator).Count -ne 0) {
                if ($Pscmdlet.ShouldProcess($instance, "Dropping operator $operator")) {
                    try {
                        Write-Message -Level Verbose -Message "Dropping Operator $operator"
                        $server.JobServer.Operators[$operator].Drop()

                        Get-DbaAgentOperator -SqlInstance $server -Operator $Operator
                    } catch {
                        Stop-Function -Message "Issue dropping operator" -Category InvalidOperation -ErrorRecord $_ -Target $instance
                    }
                }
            }
        }
    }
}