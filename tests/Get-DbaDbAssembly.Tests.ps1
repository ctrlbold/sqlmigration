#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbAssembly" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbAssembly
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Database",
            "Name",
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

Describe "Get-DbaDbAssembly" -Tag "IntegrationTests" {
    Context "When getting assemblies from master database" {
        BeforeAll {
            $instance = $TestConfig.instance2
            $masterDb = Get-DbaDatabase -SqlInstance $instance -Database master
            $results = Get-DbaDbAssembly -SqlInstance $instance | Where-Object { $PSItem.parent.name -eq 'master' }
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
            $results.DatabaseId | Should -Be $masterDb.Id
        }

        It "Should have a name of Microsoft.SqlServer.Types" {
            $results.name | Should -Be "Microsoft.SqlServer.Types"
        }

        It "Should have an owner of sys" {
            $results.owner | Should -Be "sys"
        }

        It "Should have a version matching the instance" {
            $results.Version | Should -Be $masterDb.assemblies.Version
        }
    }
}
