function New-DbaReplSubscription {
    <#
    .SYNOPSIS
        Creates a subscription for the database on the target SQL instances.

    .DESCRIPTION
        Creates a subscription for the database on the target SQL instances.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Database
        The database that will be replicated.

    .PARAMETER PublisherSqlInstance
        The publisher SQL instance.

    .PARAMETER PublisherSqlCredential
        Login to the publisher instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER PublicationDatabase
        The database on the publisher that is replicated.

    .PARAMETER PublicationName
        The name of the replication publication

    .PARAMETER SubscriptionSqlCredential
        Credential object that will be saved as the 'subscriber credential' in the subscription properties.

    .PARAMETER Type
        The flavour of the subscription. Push or Pull.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .PARAMETER WhatIf
        If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

    .PARAMETER Confirm
        If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

    .NOTES
        Tags: repl, Replication
        Author: Jess Pomfret (@jpomfret), jesspomfret.com

        Website: https://dbatools.io
        Copyright: (c) 2023 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaReplSubscription

    .EXAMPLE
        PS C:\> New-DbaReplicationSubscription -SqlInstance sql2017 -Database pubs -PublisherSqlInstance sql2016 -PublicationDatabase pubs -PublicationName testPub -Type Push

        Creates a push subscription for the pubs database on sql2017 to the testPub publication on sql2016

    .EXAMPLE
        PS C:\> New-DbaReplicationSubscription -SqlInstance sql2017 -Database pubs -PublisherSqlInstance sql2016 -PublicationDatabase pubs -PublicationName testPub -Type Pull

        Creates a pull subscription for the pubs database on sql2017 to the testPub publication on sql2016

    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [String]$Database,
        [Parameter(Mandatory)]
        [DbaInstanceParameter]$PublisherSqlInstance,
        [PSCredential]$PublisherSqlCredential,
        [String]$PublicationDatabase,
        [Parameter(Mandatory)]
        [String]$PublicationName,
        [PSCredential]
        $SubscriptionSqlCredential,
        [Parameter(Mandatory)]
        [ValidateSet("Push", "Pull")]
        [String]$Type,
        [Switch]$EnableException
    )
    begin {
        Write-Message -Level Verbose -Message "Connecting to publisher: $PublisherSqlInstance"

        # connect to publisher and get the publication
        try {
            $pubReplServer = Get-DbaReplServer -SqlInstance $PublisherSqlInstance -SqlCredential $PublisherSqlCredential
        } catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $PublisherSqlInstance -Continue
        }

        try {
            $pub = Get-DbaReplPublication -SqlInstance $PublisherSqlInstance -SqlCredential $PublisherSqlCredential -Name $PublicationName -EnableException
        } catch {
            Stop-Function -Message ("Publication {0} not found on {1}" -f $PublicationName, $PublisherSqlInstance) -ErrorRecord $_ -Target $PublisherSqlInstance -Continue
        }
    }

    process {

        # for each subscription SqlInstance we need to create a subscription
        foreach ($instance in $SqlInstance) {

            try {
                $subReplServer = get-DbaReplServer -SqlInstance $instance -SqlCredential $SqlCredential

                if (-not (Get-DbaDatabase -SqlInstance $instance -SqlCredential $SqlCredential -Database $Database)) {
                    Write-Message -Level Verbose -Message "Subscription database $Database not found on $instance - will create it - but you should check the settings!"

                    if ($PSCmdlet.ShouldProcess($instance, "Creating subscription database")) {

                        $newSubDb = @{
                            SqlInstance     = $instance
                            SqlCredential   = $SqlCredential
                            Name            = $Database
                            EnableException = $EnableException
                        }
                        $null = New-DbaDatabase @newSubDb
                    }
                }
            } catch {
                Stop-Function -Message ("Couldn't create the subscription database {0}.{1}" -f $instance, $Database) -ErrorRecord $_ -Target $instance -Continue
            }

            try {
                Write-Message -Level Verbose -Message "Creating subscription on $instance"
                if ($PSCmdlet.ShouldProcess($instance, "Creating subscription on $instance")) {

                    if ($pub.Type -in ('Transactional', 'Snapshot')) {

                        $transPub = New-Object Microsoft.SqlServer.Replication.TransPublication
                        $transPub.ConnectionContext = $pubReplServer.ConnectionContext
                        $transPub.DatabaseName = $PublicationDatabase
                        $transPub.Name = $PublicationName

                        # if LoadProperties returns then the publication was found
                        if ( $transPub.LoadProperties() ) {

                            if ($type -eq 'Push') {

                                # Perform a bitwise logical AND (& in Visual C# and And in Visual Basic) between the Attributes property and AllowPush.
                                if (($transPub.Attributes -band [Microsoft.SqlServer.Replication.PublicationAttributes]::AllowPush) -ne [Microsoft.SqlServer.Replication.PublicationAttributes]::AllowPush) {

                                    # # Perform a bitwise logical AND (& in Visual C# and And in Visual Basic) between the Attributes property and AllowPush.
                                    # if ($transPub.Attributes -band 'AllowPush' -eq 'None' ) {

                                    # If the result is None, set Attributes to the result of a bitwise logical OR (| in Visual C# and Or in Visual Basic) between Attributes and AllowPush.
                                    $transPub.Attributes = $transPub.Attributes -bor 'AllowPush'

                                    # Then, call CommitPropertyChanges to enable push subscriptions.
                                    $transPub.CommitPropertyChanges()
                                }
                            } else {
                                # Perform a bitwise logical AND (& in Visual C# and And in Visual Basic) between the Attributes property and AllowPull.
                                if (($transPub.Attributes -band [Microsoft.SqlServer.Replication.PublicationAttributes]::AllowPull) -ne [Microsoft.SqlServer.Replication.PublicationAttributes]::AllowPull) {
                                    # If the result is None, set Attributes to the result of a bitwise logical OR (| in Visual C# and Or in Visual Basic) between Attributes and AllowPull.
                                    $transPub.Attributes = $transPub.Attributes -bor 'AllowPull'

                                    # Then, call CommitPropertyChanges to enable pull subscriptions.
                                    $transPub.CommitPropertyChanges()
                                }
                            }

                            # create the subscription
                            $transSub = New-Object Microsoft.SqlServer.Replication.TransSubscription
                            $transSub.ConnectionContext = $pubReplServer.ConnectionContext
                            $transSub.SubscriptionDBName = $Database
                            $transSub.SubscriberName = $instance
                            $transSub.DatabaseName = $PublicationDatabase
                            $transSub.PublicationName = $PublicationName

                            #TODO:

                            <#
                            The Login and Password fields of SynchronizationAgentProcessSecurity to provide the credentials for the
                            Microsoft Windows account under which the Distribution Agent runs at the Distributor. This account is used to make local connections to the Distributor and to make
                            remote connections by using Windows Authentication.

                            Note
                            Setting SynchronizationAgentProcessSecurity is not required when the subscription is created by a member of the sysadmin fixed server role, but we recommend it.
                            In this case, the agent will impersonate the SQL Server Agent account. For more information, see Replication Agent security model.

                            (Optional) A value of true (the default) for CreateSyncAgentByDefault to create an agent job that is used to synchronize the subscription.
                            If you specify false, the subscription can only be synchronized programmatically.

                            #>

                            if ($SubscriptionSqlCredential) {
                                $transSub.SubscriberSecurity.WindowsAuthentication = $false
                                $transSub.SubscriberSecurity.SqlStandardLogin = $SubscriptionSqlCredential.UserName
                                $transSub.SubscriberSecurity.SecureSqlStandardPassword = $SubscriptionSqlCredential.Password
                            }

                            $transSub.Create()
                        } else {
                            Stop-Function -Message ("Publication {0} not found on {1}" -f $PublicationName, $instance) -ErrorRecord $_ -Target $instance -Continue
                        }

                    } elseif ($pub.Type -eq 'Merge') {

                        $mergePub = New-Object Microsoft.SqlServer.Replication.MergePublication
                        $mergePub.ConnectionContext = $pubReplServer.ConnectionContext
                        $mergePub.DatabaseName = $PublicationDatabase
                        $mergePub.Name = $PublicationName

                        if ( $mergePub.LoadProperties() ) {

                            if ($type = 'Push') {
                                # Perform a bitwise logical AND (& in Visual C# and And in Visual Basic) between the Attributes property and AllowPush.
                                if ($mergePub.Attributes -band 'AllowPush' -eq 'None' ) {
                                    # If the result is None, set Attributes to the result of a bitwise logical OR (| in Visual C# and Or in Visual Basic) between Attributes and AllowPush.
                                    $mergePub.Attributes = $mergePub.Attributes -bor 'AllowPush'

                                    # Then, call CommitPropertyChanges to enable push subscriptions.
                                    $mergePub.CommitPropertyChanges()
                                }

                            } else {
                                # Perform a bitwise logical AND (& in Visual C# and And in Visual Basic) between the Attributes property and AllowPull.
                                if ($mergePub.Attributes -band 'AllowPull' -eq 'None' ) {
                                    # If the result is None, set Attributes to the result of a bitwise logical OR (| in Visual C# and Or in Visual Basic) between Attributes and AllowPull.
                                    $mergePub.Attributes = $mergePub.Attributes -bor 'AllowPull'

                                    # Then, call CommitPropertyChanges to enable pull subscriptions.
                                    $mergePub.CommitPropertyChanges()
                                }
                            }

                            # create the subscription
                            if ($type = 'Push') {
                                $mergeSub = New-Object Microsoft.SqlServer.Replication.MergeSubscription
                            } else {
                                $mergeSub = New-Object Microsoft.SqlServer.Replication.MergePullSubscription
                            }

                            $mergeSub.ConnectionContext = $pubReplServer.ConnectionContext
                            $mergeSub.SubscriptionDBName = $Database
                            $mergeSub.SubscriberName = $instance
                            $mergeSub.DatabaseName = $PublicationDatabase
                            $mergeSub.PublicationName = $PublicationName

                            #TODO:

                            <#
                            The Login and Password fields of SynchronizationAgentProcessSecurity to provide the credentials for the
                            Microsoft Windows account under which the Distribution Agent runs at the Distributor. This account is used to make local connections to the Distributor and to make
                            remote connections by using Windows Authentication.

                            Note
                            Setting SynchronizationAgentProcessSecurity is not required when the subscription is created by a member of the sysadmin fixed server role, but we recommend it.
                            In this case, the agent will impersonate the SQL Server Agent account. For more information, see Replication Agent security model.

                            (Optional) A value of true (the default) for CreateSyncAgentByDefault to create an agent job that is used to synchronize the subscription.
                            If you specify false, the subscription can only be synchronized programmatically.

                            #>
                            if ($SubscriptionSqlCredential) {
                                $mergeSub.SubscriberSecurity.WindowsAuthentication = $false
                                $mergeSub.SubscriberSecurity.SqlStandardLogin = $SubscriptionSqlCredential.UserName
                                $mergeSub.SubscriberSecurity.SecureSqlStandardPassword = $SubscriptionSqlCredential.Password
                            }

                            $mergeSub.Create()
                        }

                    } else {
                        Stop-Function -Message ("Publication {0} not found on {1}" -f $PublicationName, $instance) -ErrorRecord $_ -Target $instance -Continue
                    }
                }
            } catch {
                Stop-Function -Message ("Unable to create subscription - {0}" -f $_) -ErrorRecord $_ -Target $instance -Continue
            }
            #TODO: call Get-DbaReplSubscription when it's done
        }
    }
}