#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaAgentJob" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaAgentJob
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential',
            'JobName',
            'ExcludeJobName',
            'StepName',
            'LastUsed',
            'IsDisabled',
            'IsFailed', 
            'IsNotScheduled',
            'IsNoEmailNotification',
            'Category',
            'Owner',
            'Since',
            'EnableException'
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

Describe "Find-DbaAgentJob" -Tags "IntegrationTests" {
    Context "Command finds jobs using all parameters" {
        BeforeAll {
            $srvName = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query "select @@servername as sn" -as PSObject
            
            # Create test job
            $splatJob = @{
                SqlInstance = $TestConfig.instance2
                Job = 'dbatoolsci_testjob'
                OwnerLogin = 'sa'
            }
            $null = New-DbaAgentJob @splatJob

            # Create test job step
            $splatStep = @{
                SqlInstance = $TestConfig.instance2
                Job = 'dbatoolsci_testjob'
                StepId = 1
                StepName = 'dbatoolsci Failed'
                Subsystem = 'TransactSql'
                SubsystemServer = $srvName.sn
                Command = "RAISERROR (15600,-1,-1, 'dbatools_error');"
                CmdExecSuccessCode = 0
                OnSuccessAction = 'QuitWithSuccess'
                OnFailAction = 'QuitWithFailure'
                Database = 'master'
                RetryAttempts = 1
                RetryInterval = 2
            }
            $null = New-DbaAgentJobStep @splatStep
            $null = Start-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job 'dbatoolsci_testjob'

            # Create another test job
            $null = New-DbaAgentJob @splatJob
            $null = New-DbaAgentJobStep @splatStep

            # Create job category
            $null = New-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category 'dbatoolsci_job_category' -CategoryType LocalJob

            # Create disabled test job
            $splatDisabledJob = @{
                SqlInstance = $TestConfig.instance2
                Job = 'dbatoolsci_testjob_disabled'
                Category = 'dbatoolsci_job_category'
                Disabled = $true
            }
            $null = New-DbaAgentJob @splatDisabledJob

            # Create disabled job step
            $splatDisabledStep = @{
                SqlInstance = $TestConfig.instance2
                Job = 'dbatoolsci_testjob_disabled'
                StepId = 1
                StepName = 'dbatoolsci Test Step'
                Subsystem = 'TransactSql'
                SubsystemServer = $srvName.sn
                Command = 'SELECT * FROM master.sys.all_columns'
                CmdExecSuccessCode = 0
                OnSuccessAction = 'QuitWithSuccess'
                OnFailAction = 'QuitWithFailure'
                Database = 'master'
                RetryAttempts = 1
                RetryInterval = 2
            }
            $null = New-DbaAgentJobStep @splatDisabledStep
        }

        AfterAll {
            $null = Remove-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob, dbatoolsci_testjob_disabled -Confirm:$false
            $null = Remove-DbaAgentJobCategory -SqlInstance $TestConfig.instance2 -Category 'dbatoolsci_job_category' -Confirm:$false
        }

        It "Should find a specific job" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job dbatoolsci_testjob
            $results.name | Should -Be "dbatoolsci_testjob"
        }

        It "Should find a specific job but not an excluded job" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -Job *dbatoolsci* -Exclude dbatoolsci_testjob_disabled
            $results.name | Should -Not -Be "dbatoolsci_testjob_disabled"
        }

        It "Should find a specific job with a specific step" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -StepName 'dbatoolsci Test Step'
            $results.name | Should -Be "dbatoolsci_testjob_disabled"
        }

        It "Should find jobs not used in the last 10 days" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -LastUsed 10
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should find jobs disabled from running" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -IsDisabled
            $results.name | Should -Be "dbatoolsci_testjob_disabled"
            $results.Count | Should -Be 1
        }

        It "Should find jobs that have not been scheduled" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -IsNotScheduled
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should find 2 jobs that have no schedule" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -IsNotScheduled -Job *dbatoolsci*
            $results.Count | Should -Be 2
        }

        It "Should find jobs that have no email notification" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -IsNoEmailNotification
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should find jobs that have a category of dbatoolsci_job_category" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -Category 'dbatoolsci_job_category'
            $results.name | Should -Be "dbatoolsci_testjob_disabled"
        }

        It "Should find jobs that are owned by sa" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -Owner 'sa'
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should find jobs that have been failed since July of 2016" {
            $results = Find-DbaAgentJob -SqlInstance $TestConfig.instance2 -IsFailed -Since '2016-07-01 10:47:00'
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
