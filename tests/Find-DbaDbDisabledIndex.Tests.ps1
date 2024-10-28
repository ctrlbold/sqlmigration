#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaDbDisabledIndex" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaDbDisabledIndex
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "NoClobber",
            "Append",
            "EnableException",
            "Confirm",
            "WhatIf"
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

Describe "Find-DbaDbDisabledIndex" -Tag "IntegrationTests" {
    Context "Command actually works" {
        BeforeAll {
            $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
            $random = Get-Random
            $databaseName1 = "dbatoolsci1_$random"
            $databaseName2 = "dbatoolsci2_$random"
            $db1 = New-DbaDatabase -SqlInstance $server -Name $databaseName1
            $db2 = New-DbaDatabase -SqlInstance $server -Name $databaseName2
            $indexName = "dbatoolsci_index_$random"
            $tableName = "dbatoolsci_table_$random"
            $sql = "create table $tableName (col1 int)
                    create index $indexName on $tableName (col1)
                    ALTER INDEX $indexName ON $tableName DISABLE;"
            $null = $db1.Query($sql)
            $null = $db2.Query($sql)
        }

        AfterAll {
            $db1, $db2 | Remove-DbaDatabase -Confirm:$false
        }

        It "Should find disabled index: <indexName> across all databases" {
            $results = Find-DbaDbDisabledIndex -SqlInstance $TestConfig.instance1
            ($results | Where-Object { $PSItem.IndexName -eq $indexName }).Count | Should -Be 2
            ($results | Where-Object { $PSItem.DatabaseName -in $databaseName1, $databaseName2 }).Count | Should -Be 2
            ($results | Where-Object { $PSItem.DatabaseId -in $db1.Id, $db2.Id }).Count | Should -Be 2
        }

        It "Should find disabled index: <indexName> for specific database" {
            $results = Find-DbaDbDisabledIndex -SqlInstance $TestConfig.instance1 -Database $databaseName1
            $results.IndexName | Should -Be $indexName
            $results.DatabaseName | Should -Be $databaseName1
            $results.DatabaseId | Should -Be $db1.Id
        }

        It "Should exclude specific database" {
            $results = Find-DbaDbDisabledIndex -SqlInstance $TestConfig.instance1 -ExcludeDatabase $databaseName1
            $results.IndexName | Should -Be $indexName
            $results.DatabaseName | Should -Be $databaseName2
            $results.DatabaseId | Should -Be $db2.Id
        }
    }
}
