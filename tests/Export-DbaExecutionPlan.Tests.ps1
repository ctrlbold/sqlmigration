#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaExecutionPlan" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaExecutionPlan
            $expected = $TestConfig.CommonParameters
            $expected += @(
                "SqlInstance",
                "SqlCredential", 
                "Database",
                "ExcludeDatabase",
                "Path",
                "SinceCreation",
                "SinceLastExecution",
                "InputObject",
                "EnableException",
                "Confirm",
                "WhatIf"
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
1. Added Pester v5 requirements header
2. Added proper param block with TestConfig
3. Removed old $CommandName assignment
4. Restructured parameter validation using BeforeAll block
5. Updated parameter testing to use -ForEach and proper assertions
6. Maintained the integration test placeholder comment
7. Fixed typo in guidance URL comment
8. Ensured all parameters are included in the expected list
9. Used proper Should -HaveParameter syntax
10. Maintained double quotes for string consistency

The file now follows all the conventions specified in the reference document while maintaining the same testing functionality.