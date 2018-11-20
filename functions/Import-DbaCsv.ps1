function Import-DbaCsv {
    <#
    .SYNOPSIS
        Efficiently imports very large (and small) CSV files into SQL Server using only the .NET Framework and PowerShell.

    .DESCRIPTION
        Import-DbaCsv takes advantage of .NET's super fast SqlBulkCopy class to import CSV files into SQL Server at up to 90,000 rows a second.

        The entire import is contained within a transaction, so if a failure occurs or the script is aborted, no changes will persist.

        If the table specified does not exist, it will be automatically created using best guessed data types. In addition, the destination table can be truncated prior to import.

        The Query parameter will be used to import only the data returned from a SQL Query executed against the CSV file(s). This function supports a number of bulk copy options. Please see parameter list for details.

    .PARAMETER CSV
        Specifies path to the CSV file(s) to be imported. Multiple files may be imported if they are formatted similarly.

        If no file is specified, a dialog box will appear to select your file(s).

    .PARAMETER FirstRowColumns
        If this switch is enabled, the first row in the file will be used as column names for the data being imported.

        If the first row does not contain column names and -Query is specified, use field names "column1, column2, column3" and so on.

    .PARAMETER Delimiter
        Specifies the delimiter used in the imported file(s). If no delimiter is specified, comma is assumed.

        Valid delimiters are '`t`, '|', ';',' ' and ',' (tab, pipe, semicolon, space, and comma).

    .PARAMETER SingleColumn
        Specifies that the file contains a single column of data

    .PARAMETER SqlInstance
        The SQL Server Instance to import data into.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Specifies the name of the database the CSV will be imported into. Options for this this parameter are  auto-populated from the server.

    .PARAMETER Schema
        Specifies the schema in which the SQL table or view where CSV will be imported into resides. Default is dbo

        If a schema name is not specified, and a CSV name with multiple dots is specified (ie; something.data.csv) then this will be interpreted as a request to import into a table [data] in the schema [something].

        If a schema does not currently exist, it will be created, after a prompt to confirm this. Authorization will be set to dbo by default

    .PARAMETER Table
        Specifies the SQL table or view where CSV will be imported into.

        If a table name is not specified, the table name will be automatically determined from the filename, and a prompt will appear to confirm the table name.

        If a table does not currently exist, it will created.  SQL datatypes are determined from the first row of the CSV that contains data (skips first row if -FirstRowColumns is specified). Datatypes used are: bigint, numeric, datetime and varchar(MAX).

        If the automatically generated table datatypes do not work for you, please create the table prior to import.

    .PARAMETER Truncate
        If this switch is enabled, the destination table will be truncated prior to import.

    .PARAMETER Safe
        If this switch is enabled, OleDb is used to import the records. By default, Import-DbaCsv uses StreamReader for imports. StreamReader is super fast, but may not properly parse some files.

        When using OleDb the import will be slower but more predictable when it comes to parsing CSV files. A schema.ini is automatically generated for best results. If schema.ini currently exists in the directory, it will be moved to a temporary location, then moved back.

        OleDB also enables the script to use the -Query parameter, which enables you to import specific subsets of data within a CSV file. OleDB imports at up to 21,000 rows/sec.

    .PARAMETER Turbo
        If this switch is enabled, a Table Lock will be created for the import to make the import run as fast as possible. Depending upon the number of columns and datatypes, this may be over 90,000 records per second.

        This switch cannot be used in conjunction with -Query.

        Remember the Turbo button? This one actually works. Turbo is mega fast, but may not handle some datatypes as well as other methods.

        If your CSV file is rather vanilla and doesn't have a ton of NULLs, Turbo may work well for you.

    .PARAMETER First
        Specifies the number of rows to import. If this parameter is omitted, the entire file is imported. Row counts start at the top of the file, but skip the first row if -FirstRowColumns is specified.

        Use -Query if you need advanced First (TOP) functionality.

    .PARAMETER Query
        Specifies a query to execute against the CSV data to select/modify the data being imported.

        To make command line queries easy, this module will convert the word "csv" to the actual CSV formatted table name. If the FirstRowColumns switch is not used, the query should use column1, column2, column3, etc.

        Cannot be used in conjunction with -Turbo or -First. When -Query is specified, the slower import method, OleDb, will be used.

    .PARAMETER NotifyAfter
        Specifies the import row count interval for reporting progress. A notification will be shown after each group of this many rows has been imported.

    .PARAMETER BatchSize
        Specifies the batch size for the import. Defaults to 50000.

    .PARAMETER TableLock
        If this switch is enabled, the SqlBulkCopy option to acquire a table lock will be used. This is automatically used if -Turbo is enabled.

        Per Microsoft "Obtain a bulk update lock for the duration of the bulk copy operation. When not
        specified, row locks are used."

    .PARAMETER CheckConstraints
        If this switch is enabled, the SqlBulkCopy option to check constraints will be used.

        Per Microsoft "Check constraints while data is being inserted. By default, constraints are not checked."

    .PARAMETER FireTriggers
        If this switch is enabled, the SqlBulkCopy option to allow insert triggers to be executed will be used.

        Per Microsoft "When specified, cause the server to fire the insert triggers for the rows being inserted into the database."

    .PARAMETER KeepIdentity
        If this switch is enabled, the SqlBulkCopy option to keep identity values from the source will be used.

        Per Microsoft "Preserve source identity values. When not specified, identity values are assigned by the destination."

    .PARAMETER KeepNulls
        If this switch is enabled, the SqlBulkCopy option to keep NULL values in the table will be used.

        Per Microsoft "Preserve null values in the destination table regardless of the settings for default values. When not specified, null values are replaced by default values where applicable."

    .NOTES
        Tags: Migration
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://blog.netnerds.net/2015/09/Import-DbaCsv-super-fast-csv-to-sql-server-import-powershell-module/

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path C:\temp\housing.csv -SqlInstance sql001 -Database markets

        Imports the entire comma-delimited housing.csv to the SQL "markets" database on a SQL Server named sql001.

        Since a table name was not specified, the table name is automatically determined from filename as "housing" and a prompt will appear to confirm table name.

        The first row is not skipped, as it does not contain column names.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path .\housing.csv -SqlInstance sql001 -Database markets -Table housing -First 100000 -Safe -Delimiter "`t" -FirstRowColumns

        Imports the first 100,000 rows of the tab delimited housing.csv file to the "housing" table in the "markets" database on a SQL Server named sql001. Since -Safe was specified, the OleDB method will be used for the bulk import. The first row is skipped, as it contains column names.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path C:\temp\huge.txt -SqlInstance sqlcluster -Database locations -Table latitudes -Delimiter "|" -Turbo

        Imports all records from the pipe delimited huge.txt file using the fastest method possible into the latitudes table within the locations database. Obtains a table lock for the duration of the bulk copy operation. This specific command has been used
        to import over 10.5 million rows in 2 minutes.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path C:\temp\housing.csv, .\housing2.csv -SqlInstance sql001 -Database markets -Table housing -Delimiter "`t" -query "select top 100000 column1, column3 from csv" -Truncate

        Truncates the "housing" table, then imports columns 1 and 3 of the first 100000 rows of the tab-delimited housing.csv in the C:\temp directory, and housing2.csv in the current directory. Since the query is executed against both files, a total of 200,000 rows will be imported.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path C:\temp\housing.csv -SqlInstance sql001 -Database markets -Table housing -query "select address, zip from csv where state = 'Louisiana'" -FirstRowColumns -Truncate -FireTriggers

        Uses the first line to determine CSV column names. Truncates the "housing" table on the SQL Server, then imports the address and zip columns from all records in the housing.csv where the state equals Louisiana.

        Triggers are fired for all rows. Note that this does slightly slow down the import.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path c:\temp\SingleColumn.csv -SqlInstance sql001 -Database markets -Table TempTable -SingleColumn

        Upload the single column Csv SingleColumn.csv to Temptable which has just one column

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path "\\FileServer\To Import\housing.csv" -SqlInstance sql001 -Database markets

        Imports the entire comma-delimited housing.csv located in the share named "To Import" on FileServer to the SQL "markets" database on a SQL Server named sql001.

    .EXAMPLE
        PS C:\> Import-DbaCsv -Path '\\FileServer\R$\To Import\housing.csv' -SqlInstance sql001 -Database markets

        Imports the entire comma-delimited housing.csv located in the directory R:\To Import on FileServer using the administrative share to the SQL "markets" database on a SQL Server named sql001.

       #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Internal functions are ignored")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Justification = "For Parameters SQLCredential and SQLCredentialPath")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "line", Justification = "Variable line is used, False Positive on line 330")]
    param (
        [parameter(ValueFromPipeline)]
        [Alias("Csv", "FullPath")]
        [string[]]$Path,
        [Parameter(Mandatory)]
        [DbaInstanceParameter[]]$SqlInstance,
        [pscredential]$SqlCredential,
        [Parameter(Mandatory)]
        [string]$Database,
        [string]$Table,
        [string]$Schema = "dbo",
        [switch]$Truncate,
        [ValidateSet("`t", "|", ";", " ", ",")]
        [string]$Delimiter = ",",
        [switch]$SingleColumn,
        [switch]$FirstRowColumns,
        [int]$BatchSize = 50000,
        [int]$NotifyAfter = 50000,
        [switch]$TableLock,
        [switch]$CheckConstraints,
        [switch]$FireTriggers,
        [switch]$KeepIdentity,
        [switch]$KeepNulls,
        [switch]$AutoCreateTable,
        [switch]$EnableException
    )
    begin {
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        
        function Get-Columns {
            <#
                .SYNOPSIS
                    TextFieldParser will be used instead of an OleDbConnection.
                    This is because the OleDbConnection driver may not exist on x64.

                .EXAMPLE
                    $columns = Get-Columns -Path .\myfile.csv -Delimiter "," -FirstRowColumns $true

                .OUTPUTS
                    Array of column names
            #>
            
            param (
                [Parameter(Mandatory)]
                [string[]]$Path,
                [Parameter(Mandatory)]
                [string]$Delimiter,
                [Parameter(Mandatory)]
                [bool]$FirstRowColumns
            )
            
            $columnparser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($Path)
            $columnparser.TextFieldType = "Delimited"
            $columnparser.SetDelimiters($Delimiter)
            $rawcolumns = $columnparser.ReadFields()
            
            if ($FirstRowColumns -eq $true) {
                $columns = ($rawcolumns | ForEach-Object {
                        $_ -Replace '"'
                    } | Select-Object -Property @{
                        Name   = "name"; Expression = {
                            "[$_]"
                        }
                    }).name
            } else {
                $columns = @()
                foreach ($number in 1 .. $rawcolumns.count) {
                    $columns += "[column$number]"
                }
            }
            
            $columnparser.Close()
            $columnparser.Dispose()
            return $columns
        }
        
        function Get-ColumnText {
            <#
                .SYNOPSIS
                    Returns an array of data, which can later be parsed for potential datatypes.

                .EXAMPLE
                    $columns = Get-Columns -Path .\myfile.csv -Delimiter ","

                .OUTPUTS
                    Array of column data
             #>
            param (
                [Parameter(Mandatory)]
                [string[]]$Path,
                [Parameter(Mandatory)]
                [string]$Delimiter
            )
            $columnparser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($Path)
            $columnparser.TextFieldType = "Delimited"
            $columnparser.SetDelimiters($Delimiter)
            $line = $columnparser.ReadLine()
            # Skip a line, in case first line are column names
            $line = $columnparser.ReadLine()
            $datatext = $columnparser.ReadFields()
            $columnparser.Close()
            $columnparser.Dispose()
            return $datatext
        }
        
        function New-SqlTable {
            <#
                .SYNOPSIS
                    Creates new Table using existing SqlCommand.

                    SQL datatypes based on best guess of column data within the -ColumnText parameter.
                    Columns parameter determine column names.

                .EXAMPLE
                    New-SqlTable -Path $Path -Delimiter $Delimiter -Columns $columns -ColumnText $columntext -SqlConn $sqlconn -Transaction $transaction

                .OUTPUTS
                    Creates new table
            #>
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
            param (
                [Parameter(Mandatory)]
                [string[]]$Path,
                [Parameter(Mandatory)]
                [string]$Delimiter,
                [string[]]$Columns,
                [string[]]$ColumnText,
                [System.Data.SqlClient.SqlConnection]$sqlconn,
                [System.Data.SqlClient.SqlTransaction]$transaction
            )
            # Get SQL datatypes by best guess on first data row
            $sqldatatypes = @(); $index = 0
            
            foreach ($column in $columntext) {
                $sqlcolumnname = $Columns[$index]
                $index++
                
                # bigint, float, and datetime are more accurate, but it didn't work
                # as often as it should have, so we'll just go for a smaller datatype
                if ([int64]::TryParse($column, [ref]0) -eq $true) {
                    $sqldatatype = "varchar(255)"
                } elseif ([double]::TryParse($column, [ref]0) -eq $true) {
                    $sqldatatype = "varchar(255)"
                } elseif ([datetime]::TryParse($column, [ref]0) -eq $true) {
                    $sqldatatype = "varchar(255)"
                } else {
                    $sqldatatype = "varchar(MAX)"
                }
                
                $sqldatatypes += "$sqlcolumnname $sqldatatype"
            }
            
            $sql = "BEGIN CREATE TABLE [$schema].[$table] ($($sqldatatypes -join ' NULL,')) END"
            $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
            try {
                $null = $sqlcmd.ExecuteNonQuery()
            } catch {
                $errormessage = $_.Exception.Message.ToString()
                Stop-Function -Continue -Message "Failed to execute $sql. `nDid you specify the proper delimiter? `n$errormessage"
            }
            
            Write-Message -Level Warning -Message "[*] Successfully created table $schema.$table with the following column definitions:`n $($sqldatatypes -join "`n ")"
            # Write-Message -Level Warning -Message "All columns are created using a best guess, and use their maximum datatype."
            Write-Message -Level Warning -Message "This is inefficient but allows the script to import without issues."
            Write-Message -Level Warning -Message "Consider creating the table first using best practices if the data will be used in production."
        }
        
        Write-Message -Level Verbose -Message "[*] Started at $(Get-Date)"
        
        # Load the basics
        [void][Reflection.Assembly]::LoadWithPartialName("System.Data")
        [void][Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
        
        # Getting the total rows copied is a challenge. Use SqlBulkCopyExtension.
        # http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete
        
        $source = 'namespace System.Data.SqlClient
        {
            using Reflection;

            public static class SqlBulkCopyExtension
            {
                const String _rowsCopiedFieldName = "_rowsCopied";
                static FieldInfo _rowsCopiedField = null;

                public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
                {
                    if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);
                    return (int)_rowsCopiedField.GetValue(bulkCopy);
                }
            }
        }
    '
        Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source -ErrorAction SilentlyContinue
        Add-Type -Path "$script:PSModuleRoot\bin\csv\LumenWorks.Framework.IO.dll" -ErrorAction SilentlyContinue
    }
    process {
        foreach ($filename in $Path) {
            $file = (Resolve-Path -Path $filename).ProviderPath
            
            if (-not (Test-Path -Path $file)) {
                Stop-Function -Continue -Message "$file cannot be found"
            }
            
            # Do the first few lines contain the specified delimiter?
            try {
                $firstfewlines = Get-Content $file -TotalCount 3 -ErrorAction Stop
            } catch {
                Stop-Function -Continue -Message "$file is in use."
            }
            if (-not $SingleColumn) {
                foreach ($line in $firstfewlines) {
                    if (($line -match $Delimiter) -eq $false) {
                        Stop-Function -Message "Delimiter ($Delimiter) not found in first row of $file"
                        return
                    }
                }
            }
            
            # Automatically generate Table name if not specified, then prompt user to confirm
            if (-not $table) {
                $table = [IO.Path]::GetFileNameWithoutExtension($file)
                Write-Message -Level Verbose -Message "[*] Table name not specified, using $table"
            }
            
            # Create columns based on first data row of first csv.
            if (-not $SingleColumn) {
                Write-Message -Level Verbose -Message "[*] Calculating column names and datatypes"
                $columns = Get-Columns -Path $file -Delimiter $Delimiter -FirstRowColumns $FirstRowColumns
                if ($columns.count -gt 255 -and $safe -eq $true) {
                    Stop-Function -Continue -Message "CSV must contain fewer than 256 columns."
                }
                $columntext = Get-ColumnText -Path $file -Delimiter $Delimiter
            }
            
            foreach ($instance in $SqlInstance) {
                # Open Connection to SQL Server
                try {
                    $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
                    $sqlconn = $server.ConnectionContext.SqlConnectionObject
                    $sqlconn.Open()
                } catch {
                    Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
                }
                                
                # Everything will be contained within 1 transaction, even creating a new table if required
                # and truncating the table, if specified.
                $transaction = $sqlconn.BeginTransaction()
                
                # Ensure database exists
                $sql = "select count(*) from master.dbo.sysdatabases where name = '$Database'"
                $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                if (($sqlcmd.ExecuteScalar()) -eq 0) {
                    Stop-Function -Continue -Message "Database does not exist on $instance"
                }
                Write-Message -Level Verbose -Message "[*] Database exists"
                $sqlconn.ChangeDatabase($Database)
                
                # Ensure Schema exists
                $sql = "select count(*) from $Database.sys.schemas where name='$schema'"
                $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                
                # If Schema doesn't exist create it
                # Defaulting to dbo.
                if (($sqlcmd.ExecuteScalar()) -eq 0) {
                    if (-not $AutoCreateTable) {
                        Stop-Function -Continue -Message "Schema $Schema does not exist and AutoCreateTable was not specified"
                    }
                    Write-Message -Level Verbose -Message "[*] Creating schema $schema"
                    $sql = "CREATE SCHEMA [$schema] AUTHORIZATION dbo"
                    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                    try {
                        $null = $sqlcmd.ExecuteNonQuery()
                    } catch {
                        Write-Message -Level Warning -Message "Could not create $schema"
                    }
                }
                
                # Ensure table exists
                $sql = "select count(*) from $Database.sys.tables where name = '$table' and schema_id=schema_id('$schema')"
                $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                
                # Create the table if required. Remember, this will occur within a transaction, so if the script fails, the
                # new table will no longer exist.
                if (($sqlcmd.ExecuteScalar()) -eq 0) {
                    if (-not $AutoCreateTable) {
                        Stop-Function -Continue -Message "Table $table does not exist and AutoCreateTable was not specified"
                    }
                    Write-Message -Level Verbose -Message "[*] Table does not exist"
                    Write-Message -Level Verbose -Message "[*] Creating table"
                    New-SqlTable -Path $file -Delimiter $Delimiter -Columns $columns -ColumnText $columntext -SqlConn $sqlconn -Transaction $transaction
                } else {
                    Write-Message -Level Verbose -Message "[*] Table exists"
                }
                
                # Truncate if specified. Remember, this will occur within a transaction, so if the script fails, the
                # truncate will not be committed.
                if ($truncate -eq $true) {
                    Write-Message -Level Verbose -Message "[*] Truncating table"
                    $sql = "TRUNCATE TABLE [$schema].[$table]"
                    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                    try {
                        $null = $sqlcmd.ExecuteNonQuery()
                    } catch {
                        Stop-Function -Continue -Message "Could not truncate $schema.$table" -ErrorRecord $_
                    }
                }
                
                # Get columns for column mapping
                if ($null -eq $columnMappings) {
                    $olecolumns = ($columns | ForEach-Object {
                            $_ -Replace "\[|\]"
                        })
                    $sql = "select name from sys.columns where object_id = object_id('$schema.$table') order by column_id"
                    $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                    $sqlcolumns = New-Object System.Data.DataTable
                    $sqlcolumns.Load($sqlcmd.ExecuteReader())
                }
                
                # Setup bulk copy
                Write-Message -Level Verbose -Message "[*] Starting bulk copy for $(Split-Path $file -Leaf)"
                
                # Setup bulk copy options
                $bulkCopyOptions = @()
                $options = "TableLock", "CheckConstraints", "FireTriggers", "KeepIdentity", "KeepNulls", "Default", "Truncate"
                foreach ($option in $options) {
                    $optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
                    if ($optionValue -eq $true) {
                        $bulkCopyOptions += "$option"
                    }
                }
                $bulkCopyOptions = $bulkCopyOptions -join " & "
                
                try {
                    # Create SqlBulkCopy using default options, or options specified in command line.
                    if ($bulkCopyOptions) {
                        $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($oleconnstring, $bulkCopyOptions, $transaction)
                    } else {
                        $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($sqlconn, "Default", $transaction)
                    }
                    
                    $bulkcopy.DestinationTableName = "[$schema].[$table]"
                    $bulkcopy.BulkCopyTimeout = 0
                    $bulkCopy.BatchSize = $BatchSize
                    $bulkCopy.NotifyAfter = $NotifyAfter
                    $bulkCopy.EnableStreaming  = $true
                } catch {
                    Stop-Function -Continue -Message "Failure" -ErrorRecord $_
                }
                
                # Write to server :D
                try {
                    # Open the text file from disk
                    # // or using (CsvReader csv = new CsvReader(File.OpenRead(path), false, Encoding.UTF8, addMark))
                    # When addMark is true, consecutive null bytes will be replaced by [removed x null bytes] to indicate the removal
                    $reader = New-Object LumenWorks.Framework.IO.Csv.CsvReader((New-Object System.IO.StreamReader($file)), $FirstRowColumns, $Delimiter, 1)
                    
                    # Add rowcount output
                    $bulkCopy.Add_SqlRowsCopied({
                            $script:totalrows = $args[1].RowsCopied
                            if ($resultcount -is [int]) {
                                $percent = [int](($script:totalrows / $resultcount) * 100)
                                $timetaken = [math]::Round($elapsed.Elapsed.TotalSeconds, 2)
                                Write-Progress -id 1 -Activity "Inserting $resultcount rows" -percentcomplete $percent -status ([System.String]::Format("Progress: {0} rows ({1}%) in {2} seconds", $script:totalrows, $percent, $timetaken))
                            } else {
                                Write-Message -FunctionName Import-DbaCsv -Level Verbose -Message "$($script:totalrows) rows copied in $([math]::Round($elapsed.Elapsed.TotalSeconds, 2)) seconds"
                            }
                        })
                    
                    $bulkCopy.WriteToServer($reader)
                    if ($resultcount -is [int]) {
                        Write-Progress -id 1 -activity "Inserting $resultcount rows" -status "Complete" -Completed
                    }
                    
                    $reader.Close()
                    $reader.Dispose()
                    $completed = $true
                } catch {
                    $completed = $false
                    
                    if ($resultcount -is [int]) {
                        Write-Progress -id 1 -activity "Inserting $resultcount rows" -status "Failed" -Completed
                    }
                    
                    # If possible, give more information about common errors.
                    $errormessage = $_.Exception.Message.ToString()
                    if ($errormessage -like "*for one or more required parameters*") {
                        
                        Stop-Function -Continue -Message -Message "Looks like your SQL syntax may be invalid. `nCheck the documentation for more information or start with a simple -Query 'select top 10 * from csv'."
                        Stop-Function -Continue -Message -Message "Valid CSV columns are $columns."
                        
                    } elseif ($errormessage -match "invalid column length") {
                        
                        # Get more information about malformed CSV input
                        $pattern = @("\d+")
                        $match = [regex]::matches($errormessage, @("\d+"))
                        $index = [int]($match.groups[1].Value) - 1
                        $sql = "select name, max_length from sys.columns where object_id = object_id('$table') and column_id = $index"
                        $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                        $datatable = New-Object System.Data.DataTable
                        $datatable.load($sqlcmd.ExecuteReader())
                        $column = $datatable.name
                        $length = $datatable.max_length
                        
                        if ($safe -eq $true) {
                            Write-Message -Level Warning -Message "Column $index ($column) contains data with a length greater than $length."
                            Write-Message -Level Warning -Message "SqlBulkCopy makes it pretty much impossible to know which row caused the issue, but it's somewhere after row $($script:totalrows)."
                        }
                    } elseif ($errormessage -match "does not allow DBNull" -or $errormessage -match "The given value of type") {
                        
                        if ($tablexists -eq $false) {
                            Stop-Function -Continue -Message "Looks like the datatype prediction didn't work out. Please create the table manually with proper datatypes then rerun the import script."
                        } else {
                            $sql = "select name from sys.columns where object_id = object_id('$table') order by column_id"
                            $sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
                            $datatable = New-Object System.Data.DataTable
                            $datatable.Load($sqlcmd.ExecuteReader())
                            $olecolumns = ($columns | ForEach-Object {
                                    $_ -Replace "\[|\]"
                                }) -join ', '
                            Write-Message -Level Warning -Message "Datatype mismatch."
                            Write-Message -Level Warning -Message "This is sometimes caused by null handling in SqlBulkCopy, quoted data, or the first row being column names and not data (-FirstRowColumns)."
                            Write-Message -Level Warning -Message "This could also be because the data types don't match or the order of the columns within the CSV/SQL statement "
                            Write-Message -Level Warning -Message "do not line up with the order of the table within the SQL Server.`n"
                            Write-Message -Level Warning -Message "CSV order: $olecolumns`n"
                            Write-Message -Level Warning -Message "SQL order: $($datatable.rows.name -join ', ')`n"
                            Write-Message -Level Warning -Message "If this is the case, you can reorder columns by using the -Query parameter or execute the import against a view.`n"
                            Write-Message -Level Warning -Message "[*] You can also try running this import using the -Safe parameter, which handles quoted text well.`n"
                            Stop-Function -Continue -Message "`n$errormessage"
                        }
                    } elseif ($errormessage -match "Input string was not in a correct format" -or $errormessage -match "The given ColumnName") {
                        Stop-Function -Continue -Message "CSV contents may be malformed. $errormessage"
                    } else {
                        Stop-Function -Continue -Message $errormessage
                    }
                }
            }
            
            if ($completed) {
                # "Note: This count does not take into consideration the number of rows actually inserted when Ignore Duplicates is set to ON."
                $null = $transaction.Commit()
                $rowscopied = [System.Data.SqlClient.SqlBulkCopyExtension]::RowsCopiedCount($bulkcopy)
                Write-Message -Level Verbose -Message "[*] $rowscopied total rows copied"
            } else {
                Write-Message -Level Verbose -Message "[*] Transaction rolled back."
                Write-Message -Level Verbose -Message "[*] Was the proper parameter specified? Is the first row the column name?"
            }
            
            [pscustomobject]@{
                ComputerName = $server.ComputerName
                InstanceName = $server.ServiceName
                SqlInstance  = $server.DomainInstanceName
                Database     = $Database
                Table        = $table
                Schema       = $schema
                RowsCopied   = $rowscopied
                Elapsed      = [prettytimespan]$elapsed.Elapsed
                Path         = $File
            }
            
            # Close everything just in case & ignore errors
            try {
                $null = $sqlconn.close(); $null = $sqlconn.Dispose();
                $null = $bulkCopy.close(); $bulkcopy.dispose();
                $null = $reader.close(); $null = $reader.dispose()
            } catch {
                #here to avoid an empty catch
                $null = 1
            }
        }
    }
    end {
        # Close everything just in case & ignore errors
        try {
            $null = $sqlconn.close(); $null = $sqlconn.Dispose();
            $null = $bulkCopy.close(); $bulkcopy.dispose();
            $null = $reader.close(); $null = $reader.dispose()
        } catch {
            #here to avoid an empty catch
            $null = 1
        }
        
        # Script is finished. Show elapsed time.
        $totaltime = [math]::Round($elapsed.Elapsed.TotalSeconds, 2)
        Write-Message -Level Verbose -Message "[*] Total Elapsed Time for everything: $totaltime seconds"
        
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -Alias Import-DbaCsvtoSql
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Import-CsvToSql
    }
}