#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgentJobCategory" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentJobCategory
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Category",
            "CategoryType",
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

Describe "Get-DbaAgentJobCategory" -Tag "IntegrationTests" {
    Context "Command gets job categories" {
        BeforeAll {
            $null = New-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category dbatoolsci_testcategory, dbatoolsci_testcategory2
            $results = Get-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 | Where-Object Name -Match "dbatoolsci"
            $singleResult = Get-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category dbatoolsci_testcategory | Where-Object Name -Match "dbatoolsci"
            $typeResults = Get-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -CategoryType LocalJob | Where-Object Name -Match "dbatoolsci"
        }

        AfterAll {
            $null = Remove-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category dbatoolsci_testcategory, dbatoolsci_testcategory2 -Confirm:$false
        }

        It "Should get at least 2 categories" {
            $results.Count | Should -BeGreaterThan 1
        }

        It "Should get the dbatoolsci_testcategory category" {
            $singleResult.Count | Should -Be 1
        }

        It "Should get at least 1 LocalJob" {
            $typeResults.Count | Should -BeGreaterThan 1
        }
    }
}
