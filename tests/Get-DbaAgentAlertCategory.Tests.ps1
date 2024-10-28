#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAgentAlertCategory" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentAlertCategory
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Category",
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

Describe "Get-DbaAgentAlertCategory" -Tag "IntegrationTests" {
    BeforeAll {
        $categories = @(
            "dbatoolsci_testcategory",
            "dbatoolsci_testcategory2"
        )
        $null = New-DbaAgentAlertCategory -SqlInstance $TestConfig.instance2 -Category $categories
    }

    AfterAll {
        $null = Remove-DbaAgentAlertCategory -SqlInstance $TestConfig.instance2 -Category $categories -Confirm:$false
    }

    Context "When getting all alert categories" {
        BeforeAll {
            $results = Get-DbaAgentAlertCategory -SqlInstance $TestConfig.instance2 | Where-Object Name -match "dbatoolsci"
        }

        It "Returns at least 2 categories" {
            $results.Count | Should -BeGreaterThan 1
        }
    }

    Context "When getting a specific alert category" {
        BeforeAll {
            $results = Get-DbaAgentAlertCategory -SqlInstance $TestConfig.instance2 -Category dbatoolsci_testcategory |
                Where-Object Name -match "dbatoolsci"
        }

        It "Returns exactly one category" {
            $results.Count | Should -Be 1
        }
    }
}
