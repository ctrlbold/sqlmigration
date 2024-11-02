#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAgentJob" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentJob
        $knownParameters = @(
            'SqlInstance'
            'SqlCredential'
            'Job'
            'ExcludeJob'
            'Database'
            'Category'
            'ExcludeCategory'
            'ExcludeDisabledJobs'
            'IncludeExecution'
            'Type'
            'EnableException'
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $knownParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters ($($knownParameters.Count))" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Get-DbaAgentJob" -Tag "IntegrationTests" {
    Context "When getting jobs" {
        BeforeAll {
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_disabled -Disabled
        }

        AfterAll {
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob, dbatoolsci_testjob_disabled -Confirm:$false
        }

        It "Returns 2 dbatoolsci jobs" {
            $results = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 | Where-Object Name -Match "dbatoolsci_testjob"
            $results.Count | Should -Be 2
        }

        It "Returns a specific job by name" {
            $results = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob
            $results.Name | Should -Be "dbatoolsci_testjob"
        }
    }

    Context "When excluding disabled jobs" {
        BeforeAll {
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_disabled -Disabled
        }

        AfterAll {
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob, dbatoolsci_testjob_disabled -Confirm:$false
        }

        It "Returns only enabled jobs" {
            $results = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -ExcludeDisabledJobs | Where-Object Name -Match "dbatoolsci_testjob"
            $results.Enabled -contains $false | Should -Be $false
        }
    }

    Context "When excluding specific jobs" {
        BeforeAll {
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_disabled -Disabled
        }

        AfterAll {
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob, dbatoolsci_testjob_disabled -Confirm:$false
        }

        It "Does not return excluded jobs" {
            $results = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -ExcludeJob dbatoolsci_testjob | Where-Object Name -Match "dbatoolsci_testjob"
            $results.Name -contains "dbatoolsci_testjob" | Should -Be $false
        }
    }

    Context "When excluding job categories" {
        BeforeAll {
            $null = New-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category 'Cat1'
            $null = New-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category 'Cat2'
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_cat1 -Category 'Cat1'
            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_cat2 -Category 'Cat2'
        }

        AfterAll {
            $null = Remove-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category 'Cat1', 'Cat2' -Confirm:$false
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob_cat1, dbatoolsci_testjob_cat2 -Confirm:$false
        }

        It "Does not return jobs from excluded categories" {
            $results = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -ExcludeCategory 'Cat2' | Where-Object Name -Match "dbatoolsci_testjob"
            $results.Name -contains "dbatoolsci_testjob_cat2" | Should -Be $false
        }
    }

    Context "When filtering by database" {
        BeforeAll {
            $jobName1 = "dbatoolsci_dbfilter_$(Get-Random)"
            $jobName2 = "dbatoolsci_dbfilter_$(Get-Random)"

            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job $jobName1 -Disabled
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName1 -StepName "TSQL-x" -Subsystem TransactSql -Database "msdb"
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName1 -StepName "TSQL-y" -Subsystem TransactSql -Database "tempdb"
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName1 -StepName "TSQL-z" -Subsystem TransactSql -Database "master"

            $null = New-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job $jobName2 -Disabled
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName2 -StepName "TSQL-x" -Subsystem TransactSql -Database "msdb"
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName2 -StepName "TSQL-y" -Subsystem TransactSql -Database "model"
            $null = New-DbaAgentJobStep -SqlInstance $TestConfig.instance2 -Job $jobName2 -StepName "TSQL-z" -Subsystem TransactSql -Database "master"
        }

        AfterAll {
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job $jobName1, $jobName2 -Confirm:$false
        }

        It "Returns jobs for a single database" {
            $resultSingleDatabase = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -Database tempdb
            $resultSingleDatabase.Count | Should -BeGreaterOrEqual 1
            $resultSingleDatabase.Name -contains $jobName1 | Should -BeTrue
        }

        It "Returns jobs for multiple databases" {
            $resultMultipleDatabases = Get-DbaAgentJob -SqlInstance $TestConfig.instance2 -Database tempdb, model
            $resultMultipleDatabases.Count | Should -BeGreaterOrEqual 2
            $resultMultipleDatabases.Name -contains $jobName2 | Should -BeTrue
        }
    }
}
