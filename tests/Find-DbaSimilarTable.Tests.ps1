#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaSimilarTable" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaSimilarTable
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential',
            'Database',
            'ExcludeDatabase',
            'SchemaName',
            'TableName',
            'ExcludeViews',
            'IncludeSystemDatabases',
            'MatchPercentThreshold',
            'EnableException'
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

Describe "Find-DbaSimilarTable" -Tag "IntegrationTests" {
    BeforeAll {
        $db = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database tempdb
        $db.Query("CREATE TABLE dbatoolsci_table1 (id int identity, fname varchar(20), lname char(5), lol bigint, whatever datetime)")
        $db.Query("CREATE TABLE dbatoolsci_table2 (id int identity, fname varchar(20), lname char(5), lol bigint, whatever datetime)")
    }

    AfterAll {
        $db.Query("DROP TABLE dbatoolsci_table1")
        $db.Query("DROP TABLE dbatoolsci_table2")
    }

    Context "When finding similar tables" {
        BeforeAll {
            $results = Find-DbaSimilarTable -SqlInstance $TestConfig.instance1 -Database tempdb | Where-Object Table -Match dbatoolsci
        }

        It "Returns at least two matching tables" {
            $results.Count | Should -BeGreaterOrEqual 2
            $results.OriginalDatabaseId | Should -Be $db.ID, $db.ID
            $results.MatchingDatabaseId | Should -Be $db.ID, $db.ID
        }

        It "Shows 100% match for identical test tables" {
            $results | ForEach-Object {
                $PSItem.MatchPercent | Should -Be 100
            }
        }
    }
}
