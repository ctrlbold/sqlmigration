#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaDbUnusedIndex" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaDbUnusedIndex
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "IgnoreUptime",
            "Seeks",
            "Scans",
            "Lookups",
            "InputObject",
            "EnableException"
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasparms = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

Describe "Find-DbaDbUnusedIndex" -Tag "IntegrationTests" {
    BeforeAll {
        Write-Message -Level Warning -Message "Find-DbaDbUnusedIndex testing connection to $($TestConfig.instance2)"
        Test-DbaConnection -SqlInstance $TestConfig.instance2

        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2

        $random = Get-Random
        $dbName = "dbatoolsci_$random"

        Write-Message -Level Warning -Message "Find-DbaDbUnusedIndex setting up the new database $dbName"
        Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbName -Confirm:$false
        $newDB = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name $dbName

        $indexName = "dbatoolsci_index_$random"
        $tableName = "dbatoolsci_table_$random"
        $sql = "USE $dbName;
                CREATE TABLE $tableName (ID INTEGER);
                CREATE INDEX $indexName ON $tableName (ID);
                INSERT INTO $tableName (ID) VALUES (1);
                SELECT ID FROM $tableName;
                WAITFOR DELAY '00:00:05'; -- for slower systems allow the query optimizer engine to catch up and update sys.dm_db_index_usage_stats"

        $null = $server.Query($sql)
    }

    AfterAll {
        Write-Message -Level Warning -Message "Find-DbaDbUnusedIndex removing the database $dbName"
        Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbName -Confirm:$false
    }

    Context "When finding unused indexes" {
        BeforeAll {
            $results = Find-DbaDbUnusedIndex -SqlInstance $TestConfig.instance2 -Database $dbName -IgnoreUptime -Seeks 10 -Scans 10 -Lookups 10
        }

        It "Returns results for the test database" {
            $results.Database | Should -Be $dbName
            $results.DatabaseId | Should -Be $newDB.Id
        }

        It "Finds the test index" {
            $foundIndex = $results | Where-Object IndexName -eq $indexName
            $foundIndex | Should -Not -BeNullOrEmpty
        }

        It "Returns all expected properties" {
            $expectedColumns = @(
                'CompressionDescription', 'ComputerName', 'Database', 'DatabaseId',
                'IndexId', 'IndexName', 'IndexSizeMB', 'InstanceName',
                'LastSystemLookup', 'LastSystemScan', 'LastSystemSeek', 'LastSystemUpdate',
                'LastUserLookup', 'LastUserScan', 'LastUserSeek', 'LastUserUpdate',
                'ObjectId', 'RowCount', 'Schema', 'SqlInstance', 'SystemLookup',
                'SystemScans', 'SystemSeeks', 'SystemUpdates', 'Table', 'TypeDesc',
                'UserLookups', 'UserScans', 'UserSeeks', 'UserUpdates'
            )

            $resultColumns = $results[0].PSObject.Properties.Name
            $comparison = Compare-Object -ReferenceObject $expectedColumns -DifferenceObject $resultColumns
            $comparison | Should -BeNullOrEmpty
        }
    }
}