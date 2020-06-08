function Invoke-DbaDbTransfer {
    <#
    .SYNOPSIS
        Invokes database transfer using a transfer object that clones objects from one database to another.

    .DESCRIPTION
        Invokes database transfer by either accepting an object generated by New-DbaDbTransfer, or generates such object
        on the fly when provided with enough parameters. The transfer would follow the rules defined in the transfer object;
        the list of such rules could be displayed when listing members of the transfer object:

        $transfer = New-DbaDbTransfer -SqlInstance MyInstance -Database MyDB
        $transfer | Get-Member

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

    .PARAMETER ScriptOnly
        Generate the script without moving any objects. Does not include any data - just object definitions.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Migration
        Author: Kirill Kravtsov (@nvarscar)

        Website: https://dbatools.io
        Copyright: (c) 2020 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Invoke-DbaDbTransfer

    .EXAMPLE
        PS C:\> Invoke-DbaDbTransfer -SqlInstance sql1 -DestinationSqlInstance sql2 -Database mydb -CopyAll Tables -DestinationDatabase newdb

        Copies all tables from database mydb on sql1 to database newdb on sql2.

    .EXAMPLE
        PS C:\> Invoke-DbaDbTransfer -SqlInstance sql1 -DestinationSqlInstance sql2 -Database mydb -CopyAllObjects

        Copies all objects from database mydb on sql1 to database mydb on sql2.

    .EXAMPLE
        PS C:\> $transfer = New-DbaDbTransfer -SqlInstance sql1 -DestinationSqlInstance sql2 -Database mydb -CopyAllObjects
        PS C:\> $transfer.Options.ScriptDrops = $true
        PS C:\> $transfer.SchemaOnly = $true
        PS C:\> $transfer | Invoke-DbaDbTransfer

        Copies object schema from database mydb on sql1 to database mydb on sql2 using customized transfer parameters.

    .EXAMPLE
        PS C:\> $options = New-DbaScriptingOption
        PS C:\> $options.ScriptDrops = $true
        PS C:\> $transfer = New-DbaDbTransfer -SqlInstance sql1 -DestinationSqlInstance sql2 -Database mydb -CopyAll StoredProcedures -ScriptingOption $options
        PS C:\> $transfer | Invoke-DbaDbTransfer

        Copies procedures from database mydb on sql1 to database mydb on sql2 using custom scripting parameters.

    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param (
        [Parameter(ParameterSetName = "Default")]
        [DbaInstanceParameter]$SqlInstance,

        [Parameter(ParameterSetName = "Default")]
        [PSCredential]$SqlCredential,

        [Parameter(ParameterSetName = "Default")]
        [DbaInstanceParameter]$DestinationSqlInstance,

        [Parameter(ParameterSetName = "Default")]
        [PSCredential]$DestinationSqlCredential,

        [Parameter(ParameterSetName = "Default")]
        [string]$Database,

        [Parameter(ParameterSetName = "Default")]
        [string]$DestinationDatabase = $Database,

        [Parameter(ParameterSetName = "Default")]
        [int]$BatchSize = 50000,

        [Parameter(ParameterSetName = "Default")]
        [int]$BulkCopyTimeOut = 5000,

        [Parameter(ParameterSetName = "Default")]
        [Microsoft.SqlServer.Management.Smo.ScriptingOptions]$ScriptingOption,

        [Parameter(ValueFromPipeline, ParameterSetName = "Default")]
        [Microsoft.SqlServer.Management.Smo.Transfer]$InputObject,

        [Parameter(ParameterSetName = "Default")]
        [switch]$CopyAllObjects,

        [Parameter(ParameterSetName = "Default")]
        [ValidateSet(
            'FullTextCatalogs',
            'FullTextStopLists',
            'SearchPropertyLists',
            'Tables',
            'Views',
            'StoredProcedures',
            'UserDefinedFunctions',
            'UserDefinedDataTypes',
            'UserDefinedTableTypes',
            'PlanGuides',
            'Rules',
            'Defaults',
            'Users',
            'Roles',
            'PartitionSchemes',
            'PartitionFunctions',
            'XmlSchemaCollections',
            'SqlAssemblies',
            'UserDefinedAggregates',
            'UserDefinedTypes',
            'Schemas',
            'Synonyms',
            'Sequences',
            'DatabaseTriggers',
            'DatabaseScopedCredentials',
            'ExternalFileFormats',
            'ExternalDataSources',
            'Logins',
            'ExternalLibraries'
        )]
        [string[]]$CopyAll,

        [Parameter(ParameterSetName = "Default")]
        [switch]$SchemaOnly,

        [Parameter(ParameterSetName = "Default")]
        [switch]$DataOnly,

        [switch]$ScriptOnly,

        [switch]$EnableException
    )
    begin {
        $newTransferParams = (Get-Command New-DbaDbTransfer).Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters }
    }
    process {
        if ($InputObject) {
            $transfer = $InputObject
        } else {
            $paramSet = @{ }
            # generate transfer object by adding all applicable parameters to the New-DbaDbTransfer call
            foreach ($key in $PSBoundParameters.Keys) {
                if ($key -in $newTransferParams) {
                    $paramSet[$key] = $PSBoundParameters[$key]
                }
            }
            Write-Message -Message "Generating a transfer object based on current parameters" -Level Verbose
            $transfer = New-DbaDbTransfer @paramSet
        }
        # add event handling
        $events = Register-ObjectEvent -InputObject $transfer -EventName DataTransferEvent -Action {
            "[$(Get-Date)] [$($args[1].DataTransferEventType)] $($args[1].Message)"
        }
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            if ($ScriptOnly) {
                return $transfer.ScriptTransfer()
            } else {
                $transfer.TransferData()
            }
        } catch {
            Stop-Function -ErrorRecord $_ -Message "Transfer failed"
            return
        }

        return [pscustomobject]@{
            SourceInstance      = $transfer.Database.Parent.Name
            SourceDatabase      = $transfer.Database.Name
            DestinationInstance = $transfer.DestinationServer
            DestinationDatabase = $transfer.DestinationDatabase
            Status              = 'Success'
            Elapsed             = [prettytimespan]$elapsed.Elapsed
            Log                 = $events.Output
        }
    }
    end { }
}