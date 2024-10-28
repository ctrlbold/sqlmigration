#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgentServer" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentServer
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
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

Describe "Get-DbaAgentServer" -Tag "IntegrationTests" {
    Context "Command gets server agent" {
        BeforeAll {
            $results = Get-DbaAgentServer -SqlInstance $TestConfig.Instance2
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns exactly one agent server" {
            $results.Count | Should -Be 1
        }
    }
}
