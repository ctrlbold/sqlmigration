#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbccUserOption" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbccUserOption
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Option",
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

Describe "Get-DbaDbccUserOption" -Tag "IntegrationTests" {
    BeforeAll {
        $props = @(
            'ComputerName',
            'InstanceName',
            'SqlInstance',
            'Option',
            'Value'
        )
        $result = Get-DbaDbccUserOption -SqlInstance $TestConfig.instance2
    }

    Context "Validate standard output" {
        It "Should return property: <_>" -ForEach $props {
            $p = $result[0].PSObject.Properties[$PSItem]
            $p.Name | Should -BeExactly $PSItem
        }
    }

    Context "Command returns proper info" {
        It "returns results for DBCC USEROPTIONS" {
            $result.Count | Should -BeGreaterThan 0
        }
    }

    Context "Accepts an Option Value" {
        BeforeAll {
            $result = Get-DbaDbccUserOption -SqlInstance $TestConfig.instance2 -Option ansi_nulls
        }

        It "Gets results" {
            $result | Should -Not -BeNullOrEmpty
        }

        It "Returns only one result" {
            $result.Option | Should -BeExactly 'ansi_nulls'
        }
    }
}
