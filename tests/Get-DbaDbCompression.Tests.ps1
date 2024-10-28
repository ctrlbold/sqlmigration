#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbCompression" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbCompression
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "Table",
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

Describe "Get-DbaDbCompression" -Tag "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_test_$(Get-Random)"
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $null = $server.Query("Create Database [$dbname]")
        $null = $server.Query("select * into syscols from sys.all_columns
                                select * into sysallparams from sys.all_parameters
                                create clustered index CL_sysallparams on sysallparams (object_id)
                                create nonclustered index NC_syscols on syscols (precision) include (collation_name)", $dbname)
    }

    AfterAll {
        Get-DbaProcess -SqlInstance $TestConfig.instance2 -Database $dbname | Stop-DbaProcess -WarningAction SilentlyContinue
        Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname -Confirm:$false
    }

    Context "When getting compression information" {
        BeforeAll {
            $results = Get-DbaDbCompression -SqlInstance $TestConfig.instance2 -Database $dbname
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
            $results.Database | Select-Object -Unique | Should -Be $dbname
            $results.DatabaseId | Select-Object -Unique | Should -Be $server.Query("SELECT database_id FROM sys.databases WHERE name = '$dbname'").database_id
        }

        It "Returns correct compression level for object <TableName>" -ForEach @($results | Where-Object { $PSItem.IndexId -le 1 }) {
            $PSItem.DataCompression | Should -BeIn @('None', 'Row', 'Page')
        }

        It "Returns correct compression level for nonclustered index <IndexName>" -ForEach @($results | Where-Object { $PSItem.IndexId -gt 1 }) {
            $PSItem.DataCompression | Should -BeIn @('None', 'Row', 'Page')
        }
    }

    Context "When excluding databases" {
        It "Should not return results for excluded database" {
            $excludedResults = Get-DbaDbCompression -SqlInstance $TestConfig.instance2 -Database $dbname -ExcludeDatabase $dbname
            $excludedResults | Should -Not -Match $dbname
        }
    }
}
