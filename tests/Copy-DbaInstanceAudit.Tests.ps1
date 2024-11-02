#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Copy-DbaInstanceAudit" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Copy-DbaInstanceAudit
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "Source",
            "SourceSqlCredential",
            "Destination",
            "DestinationSqlCredential",
            "Audit",
            "ExcludeAudit",
            "Path",
            "Force",
            "EnableException",
            "Confirm",
            "WhatIf"
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
