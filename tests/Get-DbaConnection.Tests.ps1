#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaConnection" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaConnection
        $expected = $TestConfig.CommonParameters
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
            $hasparms = $command.Parameters.Values.Name | Where-Object { $PSItem -notin "WhatIf", "Confirm" }
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

Describe "Get-DbaConnection" -Tag "IntegrationTests" {
    Context "When connecting to SQL Server" {
        BeforeAll {
            $results = Get-DbaConnection -SqlInstance $TestConfig.instance1
        }

        It "Returns results with valid authentication scheme" {
            foreach ($result in $results) {
                $result.AuthScheme | Should -BeIn @('ntlm', 'Kerberos')
            }
        }
    }
}
