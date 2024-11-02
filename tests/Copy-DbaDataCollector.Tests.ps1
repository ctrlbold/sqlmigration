#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Copy-DbaDataCollector" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Copy-DbaDataCollector
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'Source',
            'SourceSqlCredential',
            'Destination',
            'DestinationSqlCredential',
            'CollectionSet',
            'ExcludeCollectionSet',
            'NoServerReconfig',
            'Force',
            'EnableException',
            'Confirm',
            'WhatIf'
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
