#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Export-DbatoolsConfig" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbatoolsConfig
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "FullName",
            "Module",
            "Name",
            "Config",
            "ModuleName",
            "ModuleVersion",
            "Scope",
            "OutPath",
            "SkipUnchanged",
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