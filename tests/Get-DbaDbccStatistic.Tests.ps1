#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbccStatistic" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbccStatistic
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Database",
            "Object",
            "Target",
            "Option",
            "NoInformationalMessages",
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

Describe "Get-DbaDbccStatistic" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $random = Get-Random
        $tableName = "dbatools_getdbtbl1"
        $tableName2 = "dbatools_getdbtbl2"

        $dbname = "dbatoolsci_dbccstat$random"
        $null = $server.Query("CREATE DATABASE $dbname")
        $null = $server.Query("CREATE TABLE $tableName (idTbl1 INT PRIMARY KEY)", $dbname)
        $null = $server.Query("CREATE TABLE $tableName2 (idTbl2 INT, idTbl1 INT, id3 INT)", $dbname)

        $null = $server.Query("INSERT $tableName(idTbl1) SELECT object_id FROM sys.objects", $dbname)
        $null = $server.Query("INSERT $tableName2(idTbl2, idTbl1, id3) SELECT object_id, parent_object_id, schema_id from sys.all_objects", $dbname)

        $null = $server.Query("CREATE STATISTICS [TestStat1] ON $tableName2([idTbl2], [idTbl1], [id3])", $dbname)
        $null = $server.Query("CREATE STATISTICS [TestStat2] ON $tableName2([idTbl1], [idTbl2])", $dbname)
        $null = $server.Query("UPDATE STATISTICS $tableName", $dbname)
    }

    AfterAll {
        $null = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname | Remove-DbaDatabase -Confirm:$false
    }

    Context "When validating StatHeader option output" {
        BeforeAll {
            $props = @(
                'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'Object', 'Target', 'Cmd',
                'Name', 'Updated', 'Rows', 'RowsSampled', 'Steps', 'Density', 'AverageKeyLength',
                'StringIndex', 'FilterExpression', 'UnfilteredRows', 'PersistedSamplePercent'
            )
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Option StatHeader
        }

        It "Returns correct number of results" {
            $result.Count | Should -Be 3
        }

        It "Should return property: <_>" -ForEach $props {
            $result[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When validating DensityVector option output" {
        BeforeAll {
            $props = @(
                'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'Object', 'Target', 'Cmd',
                'AllDensity', 'AverageLength', 'Columns'
            )
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Option DensityVector
        }

        It "Returns results" {
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should return property: <_>" -ForEach $props {
            $result[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When validating Histogram option output" {
        BeforeAll {
            $props = @(
                'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'Object', 'Target', 'Cmd',
                'RangeHiKey', 'RangeRows', 'EqualRows', 'DistinctRangeRows', 'AverageRangeRows'
            )
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Option Histogram
        }

        It "Returns results" {
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should return property: <_>" -ForEach $props {
            $result[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When validating StatsStream option output" {
        BeforeAll {
            $props = @(
                'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'Object', 'Target', 'Cmd',
                'StatsStream', 'Rows', 'DataPages'
            )
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Option StatsStream
        }

        It "Returns results" {
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should return property: <_>" -ForEach $props {
            $result[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When querying a single Object" {
        BeforeAll {
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Object $tableName2 -Option StatsStream
        }

        It "Returns results" {
            $result.Count | Should -BeGreaterThan 0
        }
    }

    Context "When querying a single Object and Target" {
        BeforeAll {
            $result = Get-DbaDbccStatistic -SqlInstance $TestConfig.instance2 -Database $dbname -Object $tableName2 -Target 'TestStat2' -Option DensityVector
        }

        It "Returns results" {
            $result.Count | Should -BeGreaterThan 0
        }
    }
}
