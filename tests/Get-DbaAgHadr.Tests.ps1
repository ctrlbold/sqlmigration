#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaAgHadr" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgHadr
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

# $TestConfig.instance3 is used for Availability Group tests and needs Hadr service setting enabled

Describe "Get-DbaAgHadr" -Tag "IntegrationTests" {
    BeforeAll {
        $results = Get-DbaAgHadr -SqlInstance $TestConfig.instance3
    }

    Context "Validate output" {
        It "returns the correct properties" {
            $results.IsHadrEnabled | Should -BeTrue
        }
    }
} #$TestConfig.instance2 for appveyor
