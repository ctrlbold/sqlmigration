#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbDbccOpenTran" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbDbccOpenTran
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
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

Describe "Get-DbaDbDbccOpenTran" -Tag "IntegrationTests" {
    Context "When getting open transactions" {
        BeforeAll {
            $results = Get-DbaDbDbccOpenTran -SqlInstance $TestConfig.instance1
            $expectedProps = @(
                'ComputerName',
                'InstanceName',
                'SqlInstance',
                'Database',
                'Cmd',
                'Output',
                'Field',
                'Data'
            )
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns multiple results" {
            $results.Count | Should -BeGreaterThan 0
        }

        It "Has property: <_>" -ForEach $expectedProps {
            $results[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When getting transactions for specific database" {
        BeforeAll {
            $tempDb = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database tempdb
            $results = Get-DbaDbDbccOpenTran -SqlInstance $TestConfig.instance1 -Database tempdb
        }

        It "Returns results for tempdb" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns results only for tempdb" {
            $results.Database | Get-Unique | Should -Be 'tempdb'
            $results.DatabaseId | Get-Unique | Should -Be $tempDb.Id
        }
    }
}
