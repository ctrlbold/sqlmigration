function New-DbaDbTransfer {
    <#
    .SYNOPSIS
        Creates a transfer object to clone objects from one database to another.

    .DESCRIPTION
        Returns an SMO Transfer object that controls the process of copying database objects from one database to another.
        Does not perform any actions unless explicitly called with .TransferData() or piped into Invoke-DbaDbTransfer.

    .PARAMETER SqlInstance
        Source SQL Server instance name.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER DestinationSqlInstance
        Destination Sql Server. You must have appropriate access to create objects on the target server.

    .PARAMETER DestinationSqlCredential
        Login to the source instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).
        Only SQL authentication is supported. When not specified, uses Trusted Authentication.

    .PARAMETER Database
        The database to copy the objects from.

    .PARAMETER DestinationDatabase
        The database to copy the objects to. If not specified, it is assumed to be same as the source database.

    .PARAMETER BatchSize
        The BatchSize for the data copy defaults to 5000.

    .PARAMETER BulkCopyTimeOut
        Value in seconds for the BulkCopy operations timeout. The default is 30 seconds.

    .PARAMETER ScriptingOption
        Custom scripting rules, generated by New-DbaScriptingOption

    .PARAMETER InputObject
        Enables piping of database SMO objects into the command.

    .PARAMETER CopyAllObjects
        Transfer all objects of the source database

    .PARAMETER CopyAll
        Object types to be transferred from a database. Allowed values:
        FullTextCatalogs
        FullTextStopLists
        SearchPropertyLists
        Tables
        Views
        StoredProcedures
        UserDefinedFunctions
        UserDefinedDataTypes
        UserDefinedTableTypes
        PlanGuides
        Rules
        Defaults
        Users
        Roles
        PartitionSchemes
        PartitionFunctions
        XmlSchemaCollections
        SqlAssemblies
        UserDefinedAggregates
        UserDefinedTypes
        Schemas
        Synonyms
        Sequences
        DatabaseTriggers
        DatabaseScopedCredentials
        ExternalFileFormats
        ExternalDataSources
        Logins
        ExternalLibraries

    .PARAMETER SchemaOnly
        Transfers only object schema.

    .PARAMETER DataOnly
        Transfers only data without copying schema.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: General, Transfer, Object
        Author: Kirill Kravtsov (@nvarscar)

        Website: https://dbatools.io
        Copyright: (c) 2020 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaDbTransfer

    .EXAMPLE
        PS C:\> New-DbaDbTransfer -SqlInstance sql1 -Destination sql2 -Database mydb -CopyAll Tables

        Creates a transfer object that, when invoked, would copy all tables from database sql1.mydb to sql2.mydb

    .EXAMPLE
        PS C:\> Get-DbaDbTable -SqlInstance sql1 -Database MyDb -Table a, b, c | New-DbaDbTransfer -SqlInstance sql1 -Destination sql2 -Database mydb

        Creates a transfer object to copy specific tables from database sql1.mydb to sql2.mydb
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [OutputType([Microsoft.SqlServer.Management.Smo.Transfer])]
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param (
        [DbaInstanceParameter]$SqlInstance,
        [PSCredential]$SqlCredential,
        [DbaInstanceParameter]$DestinationSqlInstance,
        [PSCredential]$DestinationSqlCredential,
        [string]$Database,
        [string]$DestinationDatabase = $Database,
        [int]$BatchSize = 50000,
        [int]$BulkCopyTimeOut = 5000,
        [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOption,
        [Parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.NamedSmoObject[]]$InputObject,
        [switch]$CopyAllObjects,
        [ValidateSet('FullTextCatalogs', 'FullTextStopLists', 'SearchPropertyLists', 'Tables',
            'Views', 'StoredProcedures', 'UserDefinedFunctions', 'UserDefinedDataTypes', 'UserDefinedTableTypes',
            'PlanGuides', 'Rules', 'Defaults', 'Users', 'Roles', 'PartitionSchemes', 'PartitionFunctions',
            'XmlSchemaCollections', 'SqlAssemblies', 'UserDefinedAggregates', 'UserDefinedTypes', 'Schemas',
            'Synonyms', 'Sequences', 'DatabaseTriggers', 'DatabaseScopedCredentials', 'ExternalFileFormats',
            'ExternalDataSources', 'Logins', 'ExternalLibraries')]
        [string[]]$CopyAll,
        [switch]$SchemaOnly,
        [switch]$DataOnly,
        [switch]$EnableException
    )
    begin {
        $objectCollection = New-Object System.Collections.ArrayList
    }
    process {
        if (Test-Bound -Not SqlInstance) {
            Stop-Function -Message "Source instance was not specified"
            return
        }
        if (Test-Bound -Not Database) {
            Stop-Function -Message "Source database was not specified"
            return
        }
        foreach ($object in $InputObject) {
            if (-not $object) {
                Stop-Function -Message "Object is empty"
                return
            }
            $objectCollection.Add($object) | Out-Null
        }

    }
    end {
        try {
            $sourceDb = Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -EnableException
        } catch {
            Stop-Function -Message "Failed to retrieve database from the source instance $SqlInstance" -ErrorRecord $_
            return
        }
        if (-not $sourceDb) {
            Stop-Function -Message "Database $Database not found on $SqlInstance"
            return
        } elseif ($sourceDb.Count -gt 1) {
            Stop-Function -Message "More than one database found on $SqlInstanced with the parameters provided"
            return
        }
        # Create transfer object and define properties based on parameters
        $transfer = New-Object Microsoft.SqlServer.Management.Smo.Transfer($sourceDb)
        foreach ($object in $objectCollection) {
            $transfer.ObjectList.Add($object) | Out-Null
        }
        $transfer.BatchSize = $BatchSize
        $transfer.BulkCopyTimeOut = $BulkCopyTimeOut
        $transfer.CopyAllObjects = $CopyAllObjects
        foreach ($copyType in $CopyAll) {
            $transfer."CopyAll$copyType" = $true
        }
        if ($ScriptingOption) { $transfer.Options = $ScriptingOption }

        # Add destination connection parameters
        if ($DestinationSqlInstance.IsConnectionString) {
            $connString = $DestinationSqlInstance.InputObject
        } elseif ($DestinationSqlInstance.Type -eq 'RegisteredServer' -and $DestinationSqlInstance.InputObject.ConnectionString) {
            $connString = $DestinationSqlInstance.InputObject.ConnectionString
        } elseif ($DestinationSqlInstance.Type -eq 'Server' -and $DestinationSqlInstance.InputObject.ConnectionContext.ConnectionString) {
            $connString = $DestinationSqlInstance.InputObject.ConnectionContext.ConnectionString
        } else {
            $transfer.DestinationServer = $DestinationSqlInstance.InputObject
            $transfer.DestinationLoginSecure = $true
        }
        if ($connString) {
            $connStringBuilder = New-Object Microsoft.Data.SqlClient.SqlConnectionStringBuilder $connString
            if ($srv = $connStringBuilder['Data Source']) { $transfer.DestinationServer = $srv }
            else { $transfer.DestinationServer = 'localhost' }
            if ($uName = $connStringBuilder['User ID']) { $transfer.DestinationLogin = $uName }
            if ($pwd = $connStringBuilder['Password']) { $transfer.DestinationPassword = $pwd }
            if (($db = $connStringBuilder['Initial Catalog']) -and (Test-Bound -Not -Parameter DestinationDatabase)) {
                $transfer.DestinationDatabase = $db
            } else {
                $transfer.DestinationDatabase = $DestinationDatabase
            }
            $transfer.DestinationLoginSecure = $connStringBuilder['Integrated Security']
        } else {
            $transfer.DestinationDatabase = $DestinationDatabase
        }
        if ($DestinationSqlCredential) {
            $transfer.DestinationLoginSecure = $false
            $transfer.DestinationLogin = $DestinationSqlCredential.UserName
            $transfer.DestinationPassword = $DestinationSqlCredential.GetNetworkCredential().Password
        }
        if (Test-Bound -Parameter SchemaOnly) { $transfer.CopyData = -not $SchemaOnly }
        if (Test-Bound -Parameter DataOnly) { $transfer.CopySchema = -not $DataOnly }

        return $transfer
    }
}