#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaCommand" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaCommand
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'Pattern',
            'Tag',
            'Author',
            'MinimumVersion',
            'MaximumVersion',
            'Rebuild',
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

Describe "Find-DbaCommand" -Tag "IntegrationTests" {
    Context "When searching for commands" {
        It "Should find more than 5 snapshot commands" {
            $results = Find-DbaCommand -Pattern "snapshot"
            $results.Count | Should -BeGreaterThan 5
        }

        It "Should find more than 20 commands tagged as job" {
            $results = Find-DbaCommand -Tag Job
            $results.Count | Should -BeGreaterThan 20
        }

        It "Should find commands with multiple tags (Job and Owner)" {
            $results = Find-DbaCommand -Tag Job, Owner
            $results.CommandName | Should -Contain "Test-DbaAgentJobOwner"
        }

        It "Should find more than 250 commands authored by Chrissy" {
            $results = Find-DbaCommand -Author chrissy
            $results.Count | Should -BeGreaterThan 250
        }

        It "Should find more than 15 AG commands authored by Chrissy" {
            $results = Find-DbaCommand -Author chrissy -Tag AG
            $results.Count | Should -BeGreaterThan 15
        }

        It "Should find more than 5 snapshot commands after rebuilding the index" {
            $results = Find-DbaCommand -Pattern snapshot -Rebuild
            $results.Count | Should -BeGreaterThan 5
        }
    }
}
