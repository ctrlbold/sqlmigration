#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param($ModuleName = "dbatools")
$global:TestConfig = Get-TestConfig

Describe "Clear-DbaPlanCache" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Clear-DbaPlanCache
            $expectedParameters = $TestConfig.CommonParameters

            $expectedParameters += @(
                "SqlInstance",
                "SqlCredential",
                "Threshold",
                "InputObject",
                "EnableException"
            )
        }

        It "Has parameter: <_>" -ForEach $expectedParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters" {
            Compare-Object -ReferenceObject $expectedParameters -DifferenceObject $command.Parameters.Keys | Should -BeNullOrEmpty
        }
    }
}

Describe "Clear-DbaPlanCache" -Tag "IntegrationTests" {
    Context "When not clearing plan cache" {
        BeforeAll {
            # Make plan cache way higher than likely for a test rig
            $threshold = 10240
        }

        It "Returns correct datatypes" {
            $results = Clear-DbaPlanCache -SqlInstance $TestConfig.instance1 -Threshold $threshold
            $results.Size | Should -BeOfType [dbasize]
            $results.Status | Should -Match 'below'
        }

        It "Supports piping" {
            $results = Get-DbaPlanCache -SqlInstance $TestConfig.instance1 | Clear-DbaPlanCache -Threshold $threshold
            $results.Size | Should -BeOfType [dbasize]
            $results.Status | Should -Match 'below'
        }
    }
}
