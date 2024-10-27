#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAgentJobStep" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentJobStep
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Job",
            "ExcludeJob",
            "ExcludeDisabledJobs",
            "InputObject",
            "EnableException"
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

Describe "Get-DbaAgentJobStep" -Tag "IntegrationTests" {
    BeforeAll {
        $jobName = "dbatoolsci_job_$(Get-Random)"
        $null = New-DbaAgentJob -SqlInstance $TestConfig.Instance2 -Job $jobName
        $null = New-DbaAgentJobStep -SqlInstance $TestConfig.Instance2 -Job $jobName -StepName dbatoolsci_jobstep1 -Subsystem TransactSql -Command 'select 1'
    }
    
    AfterAll {
        $null = Remove-DbaAgentJob -SqlInstance $TestConfig.Instance2 -Job $jobName -Confirm:$false
    }

    Context "When getting job steps" {
        It "Returns job steps without using Job parameter" {
            $results = Get-DbaAgentJobStep -SqlInstance $TestConfig.Instance2
            $results.Name | Should -Contain 'dbatoolsci_jobstep1'
        }

        It "Returns job steps when using Job parameter" {
            $results = Get-DbaAgentJobStep -SqlInstance $TestConfig.Instance2 -Job $jobName
            $results.Name | Should -Contain 'dbatoolsci_jobstep1'
        }

        It "Returns job steps when excluding specific jobs" {
            $results = Get-DbaAgentJobStep -SqlInstance $TestConfig.Instance2 -ExcludeJob 'syspolicy_purge_history'
            $results.Name | Should -Contain 'dbatoolsci_jobstep1'
        }

        It "Excludes disabled jobs when specified" {
            $null = Set-DbaAgentJob -SqlInstance $TestConfig.Instance2 -Job $jobName -Disabled
            $results = Get-DbaAgentJobStep -SqlInstance $TestConfig.Instance2 -ExcludeDisabledJobs
            $results.Name | Should -Not -Contain 'dbatoolsci_jobstep1'
        }
    }
}
