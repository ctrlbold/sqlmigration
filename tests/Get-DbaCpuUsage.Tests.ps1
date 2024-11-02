#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaCpuUsage" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCpuUsage
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Credential",
            "Threshold",
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

Describe "Get-DbaCpuUsage" -Tag "IntegrationTests" {
    Context "When getting CPU usage from SQL Server" {
        BeforeAll {
            $results = Get-DbaCPUUsage -SqlInstance $TestConfig.Instance2
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
