#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaAvailableCollation" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAvailableCollation
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
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

Describe "Get-DbaAvailableCollation" -Tag "IntegrationTests" {
    Context "When getting available collations" {
        BeforeAll {
            $results = Get-DbaAvailableCollation -SqlInstance $TestConfig.Instance2
        }

        It "Finds multiple Slovenian collations" {
            ($results.Name -match 'Slovenian').Count | Should -BeGreaterThan 10
        }
    }
}
