#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaCpuRingBuffer" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCpuRingBuffer
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "CollectionMinutes",
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

Describe "Get-DbaCpuRingBuffer" -Tag "IntegrationTests" {
    Context "Command returns proper info" {
        BeforeAll {
            $results = Get-DbaCpuRingBuffer -SqlInstance $TestConfig.Instance2 -CollectionMinutes 100
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
