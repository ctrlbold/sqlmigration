#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Reset-DbaAdmin" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Reset-DbaAdmin
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Login",
            "SecurePassword",
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

Describe "Reset-DbaAdmin" -Tag "IntegrationTests" {
    BeforeAll {
        $password = ConvertTo-SecureString -Force -AsPlainText resetadmin1
        $testLogin = "dbatoolsci_resetadmin"
    }

    AfterAll {
        Get-DbaProcess -SqlInstance $TestConfig.instance2 -Login $testLogin | Stop-DbaProcess -WarningAction SilentlyContinue
        Get-DbaLogin -SqlInstance $TestConfig.instance2 -Login $testLogin | Remove-DbaLogin -Confirm:$false
    }

    Context "When adding a sql login" {
        BeforeAll {
            $splatReset = @{
                SqlInstance = $TestConfig.instance2
                Login = $testLogin
                SecurePassword = $password
                Confirm = $false
            }
            $results = Reset-DbaAdmin @splatReset
        }

        It "Should add the login as sysadmin" {
            $results.Name | Should -Be $testLogin
            $results.IsMember("sysadmin") | Should -Be $true
        }
    }
}
