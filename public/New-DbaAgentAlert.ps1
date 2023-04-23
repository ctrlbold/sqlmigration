function New-DbaAgentAlert {
    <#
    .SYNOPSIS
        Creates a new SQL Server Agent alert

    .DESCRIPTION
        Creates a new SQL Server Agent alert

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Alert
        The name of the alert to create

    .PARAMETER CategoryName
        The name of the category for the alert

    .PARAMETER DatabaseName
        The name of the database to which the alert applies

    .PARAMETER DelayBetweenResponses
        The delay (in seconds) between responses to the alert

    .PARAMETER Disabled
        Whether the alert is disabled

    .PARAMETER EventDescriptionKeyword
        The keyword to search for in the event description

    .PARAMETER NotifyMethod
        The method to use to notify the user of the alert. Valid values are 'None', 'NotifyEmail', 'Pager', 'NetSend', 'NotifyAll'. It is NotifyAll by default.

    .PARAMETER EventSource
        The source of the event

    .PARAMETER JobId
        The GUID ID of the job to execute when the alert is triggered

    .PARAMETER MessageId
        The message ID for the alert

    .PARAMETER NotificationMessage
        The message to send when the alert is triggered

    .PARAMETER PerformanceCondition
        The performance condition for the alert

    .PARAMETER Severity
        The severity level for the alert. Valid values are 'Information', 'Warning', and 'Critical'

    .PARAMETER WmiEventNamespace
        The namespace of the WMI event to use in the alert

    .PARAMETER WmiEventQuery
        The WMI query to use in the alert

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Agent, Alert
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2023 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaAgentAlert

    .EXAMPLE
        PS C:\> New-DbaAgentAlert -SqlInstance sql1 -Alert "Severity 018 - Nonfatal Internal Error"

        Creates a new alert with the name Severity 018 - Nonfatal Internal Error.

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Alert,
        [string]$CategoryName,
        [string]$DatabaseName,
        [int]$DelayBetweenResponses,
        [switch]$Disabled,
        [string]$EventDescriptionKeyword,
        [string]$EventSource,
        [string]$JobId = "00000000-0000-0000-0000-000000000000",
        [int]$MessageId,
        [string]$NotificationMessage,
        [string]$PerformanceCondition,
        [ValidateSet('Information', 'Warning', 'Critical')]
        [string]$Severity,
        [string]$WmiEventNamespace,
        [string]$WmiEventQuery,
        [ValidateSet('None', 'NotifyEmail', 'Pager', 'NetSend', 'NotifyAll')]
        [string]$NotifyMethod = "NotifyAll",
        [switch]$EnableException
    )
    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            foreach ($name in $Alert) {
                if ($name -in $server.JobServer.Alerts.Name) {
                    Stop-Function -Message "Alert $name already exists on $instance" -Target $instance -Continue
                } else {
                    if ($PSCmdlet.ShouldProcess($instance, "Adding the alert $name")) {
                        try {
                            # Supply either a non-zero message ID, non-zero severity, non-null performance condition, or non-null WMI namespace and query.
                            $newalert = New-Object Microsoft.SqlServer.Management.Smo.Agent.Alert($server.JobServer, $name)
                            $list = "CategoryName", "DatabaseName", "DelayBetweenResponses", "EventDescriptionKeyword", "EventSource", "JobID", "MessageID", "Name", "NotificationMessage", "PerformanceCondition", "WmiEventNamespace", "WmiEventQuery", "IncludeEventDescription", "IsEnabled", "Severity", "NotifyMethods"

                            foreach ($item in $list) {
                                $value = (Get-Variable -Name $item -ErrorAction Ignore).Value
                                if ($value) {
                                    $newalert.$item = $value
                                }
                            }
                            #$newAlert.CategoryName = $CategoryName
                            #$newAlert.DatabaseName = $DatabaseName
                            #$newAlert.DelayBetweenResponses = $DelayBetweenResponses
                            #$newAlert.EventDescriptionKeyword = $EventDescriptionKeyword
                            # I dont get it but this is NotifyMethods
                            $newAlert.IncludeEventDescription = $NotifyMethod
                            #$newAlert.IsEnabled = ($Disabled -eq $false)
                            $newAlert.JobID = $JobID
                            #$newAlert.MessageID = $MessageID
                            #$newAlert.Name = $name
                            #$newAlert.NotificationMessage = $NotificationMessage
                            #$newAlert.PerformanceCondition = $PerformanceCondition
                            $newAlert.Severity = $Severity
                            #$newAlert.WmiEventNamespace = $WmiEventNamespace
                            #$newAlert.WmiEventQuery = $WmiEventQuery
                            $newalert.Create()
                            $server.JobServer.Refresh()
                        } catch {
                            Stop-Function -Message "Something went wrong creating the alert $name on $instance" -Target $name -Continue -ErrorRecord $_
                        }
                    }
                }
                Get-DbaAgentAlert -SqlInstance $server -Category $name
            }
        }
    }
}