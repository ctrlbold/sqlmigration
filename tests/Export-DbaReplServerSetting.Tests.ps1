#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Add-ReplicationLibrary

Describe "Export-DbaReplServerSetting" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaReplServerSetting
            $expected = $TestConfig.CommonParameters
            $expected += @(
                "SqlInstance",
                "SqlCredential",
                "Path",
                "FilePath",
                "ScriptOption",
                "InputObject",
                "Encoding",
                "Passthru",
                "NoClobber",
                "Append",
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
1. Added Pester v5 required header with param block
2. Removed old $CommandName variable usage
3. Added proper BeforeAll block in Context
4. Updated parameter validation to use the new standard approach
5. Used proper -ForEach syntax for parameter testing
6. Maintained the integration test placeholder comment
7. Used $PSItem instead of $_
8. Kept the Add-ReplicationLibrary call as it appears to be required
9. Maintained Write-Host for running path information

The structure now follows the conventions.md guidelines while maintaining the essential functionality of the tests.