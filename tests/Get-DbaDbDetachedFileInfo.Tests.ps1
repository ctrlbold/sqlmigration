#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbDetachedFileInfo" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbDetachedFileInfo
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Path",
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

Describe "Get-DbaDbDetachedFileInfo" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $versionName = $server.GetSqlServerVersionName()
        $random = Get-Random
        $dbname = "dbatoolsci_detatch_$random"
        $server.Query("CREATE DATABASE $dbname")
        $path = (Get-DbaDbFile -SqlInstance $TestConfig.instance2 -Database $dbname | Where-Object {$PSItem.PhysicalName -like '*.mdf'}).physicalname
        Detach-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname -Force
    }

    AfterAll {
        $server.Query("CREATE DATABASE $dbname
            ON (FILENAME = '$path')
            FOR ATTACH")
        Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname -Confirm:$false
    }

    Context "When getting detached file information" {
        BeforeAll {
            $results = Get-DbaDbDetachedFileInfo -SqlInstance $TestConfig.instance2 -Path $path
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns the correct database name" {
            $results.name | Should -Be $dbname
        }

        It "Returns the correct SQL Server version" {
            $results.version | Should -Be $versionName
        }

        It "Contains data files information" {
            $results.DataFiles | Should -Not -BeNullOrEmpty
        }

        It "Contains log files information" {
            $results.LogFiles | Should -Not -BeNullOrEmpty
        }
    }
}
