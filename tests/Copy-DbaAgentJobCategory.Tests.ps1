#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Copy-DbaAgentJobCategory" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Copy-DbaAgentJobCategory
            $expected = $TestConfig.CommonParameters
            $expected += @(
                'Source',
                'SourceSqlCredential',
                'Destination',
                'DestinationSqlCredential',
                'CategoryType',
                'JobCategory',
                'AgentCategory',
                'OperatorCategory',
                'Force',
                'EnableException'
            )
        }

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Copy-DbaAgentJobCategory" -Tag "IntegrationTests" {
    BeforeAll {
        $categoryName = 'dbatoolsci test category'
        $newCategoryParams = @{
            SqlInstance = $TestConfig.instance2
            Category    = $categoryName
        }
        $null = New-DbaAgentJobCategory @newCategoryParams
    }

    AfterAll {
        $removeCategoryParams = @{
            SqlInstance = $TestConfig.instance2
            Category    = $categoryName
            Confirm     = $false
        }
        $null = Remove-DbaAgentJobCategory @removeCategoryParams
    }

    Context "When copying job categories" {
        BeforeAll {
            $copyParams = @{
                Source      = $TestConfig.instance2
                Destination = $TestConfig.instance3
                JobCategory = $categoryName
            }
            $results = Copy-DbaAgentJobCategory @copyParams
        }

        It "Should copy category successfully" {
            $results.Name | Should -Be $categoryName
            $results.Status | Should -Be "Successful"
        }

        It "Should skip existing category on second copy" {
            $results = Copy-DbaAgentJobCategory @copyParams
            $results.Name | Should -Be $categoryName
            $results.Status | Should -Be "Skipped"
        }
    }
}