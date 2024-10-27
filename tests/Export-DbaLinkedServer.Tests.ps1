#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Export-DbaLinkedServer" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaLinkedServer
            $expected = $TestConfig.CommonParameters
            $expected += @(
                "SqlInstance",
                "LinkedServer",
                "SqlCredential",
                "Credential",
                "Path",
                "FilePath",
                "ExcludePassword",
                "Append",
                "InputObject",
                "EnableException"
            )
        }

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasparms = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

<#
    Integration test should appear below and are custom to the command you are writing.
    Read https://github.com/dataplat/dbatools/blob/development/contributing.md#tests
    for more guidance.
#></source>

Key changes made:
1. Added the required Pester v5 header with module requirements
2. Removed `$CommandName` variable as it's no longer needed
3. Restructured parameter validation using the new convention from conventions.md
4. Added proper BeforeAll block for test setup
5. Updated parameter comparison to use Should -HaveParameter
6. Fixed typo in guidance comment
7. Used proper array declaration format for expected parameters
8. Maintained all existing parameters while updating the test structure

The file now follows the Pester v5 conventions while maintaining the same test coverage.