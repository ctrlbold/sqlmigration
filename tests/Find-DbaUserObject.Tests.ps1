#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaUserObject" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaUserObject
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Pattern",
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

Describe "Find-DbaUserObject" -Tag "IntegrationTests" {
    Context "When finding User Objects for SA" {
        BeforeAll {
            $null = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name 'dbatoolsci_userObject' -Owner 'sa'
            $results = Find-DbaUserObject -SqlInstance $TestConfig.instance2 -Pattern sa
        }

        AfterAll {
            $null = Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_userObject' -Confirm:$false
        }

        It "Should find a specific Database Owned by sa" {
            $results.Where({ $PSItem.name -eq 'dbatoolsci_userobject' }).Type | Should -BeExactly "Database"
        }

        It "Should find more than 10 objects Owned by sa" {
            $results.Count | Should -BeGreaterThan 10
        }
    }

    Context "When finding all User Objects" {
        BeforeAll {
            $results = Find-DbaUserObject -SqlInstance $TestConfig.instance2
        }

        It "Should find results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
