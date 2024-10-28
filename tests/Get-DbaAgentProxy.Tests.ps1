#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAgentProxy" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentProxy
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Proxy",
            "ExcludeProxy",
            "EnableException"
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

Describe "Get-DbaAgentProxy" -Tag "IntegrationTests" {
    BeforeAll {
        $tPassword = ConvertTo-SecureString "ThisIsThePassword1" -AsPlainText -Force
        $tUserName = "dbatoolsci_proxytest"
        New-LocalUser -Name $tUserName -Password $tPassword -Disabled:$false
        New-DbaCredential -SqlInstance $TestConfig.instance2 -Name "$tUserName" -Identity "$env:COMPUTERNAME\$tUserName" -Password $tPassword
        New-DbaAgentProxy -SqlInstance $TestConfig.instance2 -Name STIG -ProxyCredential "$tUserName"
        New-DbaAgentProxy -SqlInstance $TestConfig.instance2 -Name STIGX -ProxyCredential "$tUserName"
    }

    AfterAll {
        $tUserName = "dbatoolsci_proxytest"
        Remove-LocalUser -Name $tUserName
        $credential = Get-DbaCredential -SqlInstance $TestConfig.instance2 -Name $tUserName
        $credential.DROP()
        $proxy = Get-DbaAgentProxy -SqlInstance $TestConfig.instance2 -Proxy "STIG", "STIGX"
        $proxy.DROP()
    }

    Context "When getting all proxies" {
        BeforeAll {
            $results = Get-DbaAgentProxy -SqlInstance $TestConfig.instance2
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should have the name STIG" {
            $results.name | Should -Contain "STIG"
        }

        It "Should be enabled" {
            $results.isenabled | Should -Contain $true
        }
    }

    Context "When getting a single proxy" {
        BeforeAll {
            $results = Get-DbaAgentProxy -SqlInstance $TestConfig.instance2 -Proxy "STIG"
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should have the name STIG" {
            $results.name | Should -Be "STIG"
        }

        It "Should be enabled" {
            $results.isenabled | Should -Be $true
        }
    }

    Context "When excluding specific proxies" {
        BeforeAll {
            $results = Get-DbaAgentProxy -SqlInstance $TestConfig.instance2 -ExcludeProxy "STIG"
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should not have the name STIG" {
            $results.name | Should -Not -Be "STIG"
        }

        It "Should be enabled" {
            $results.isenabled | Should -Be $true
        }
    }
}
