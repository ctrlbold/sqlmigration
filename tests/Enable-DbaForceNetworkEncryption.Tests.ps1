#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Enable-DbaForceNetworkEncryption" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Enable-DbaForceNetworkEncryption
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "Credential",
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
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Enable-DbaForceNetworkEncryption" -Tag "IntegrationTests" {
    Context "When enabling force network encryption" {
        BeforeAll {
            $results = Enable-DbaForceNetworkEncryption -SqlInstance $TestConfig.instance1 -EnableException
        }

        It "Should enable force encryption" {
            $results.ForceEncryption | Should -BeTrue
        }
    }
}
