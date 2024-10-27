#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgentJobOutputFile" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentJobOutputFile
        $knownParameters = @(
            'SqlInstance',
            'SqlCredential', 
            'Job',
            'ExcludeJob',
            'EnableException'
        )
        $knownParameters += $TestConfig.CommonParameters
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

Describe "Get-DbaAgentJobOutputFile Integration Tests" -Tag "UnitTests" {
    BeforeAll {
        Mock Connect-DbaInstance -MockWith {
            [PSCustomObject]@{
                Name         = 'SQLServerName'
                ComputerName = 'SQLServerName'
                JobServer    = @{
                    Jobs = @(
                        @{
                            Name     = 'Job1'
                            JobSteps = @(
                                @{
                                    Id             = 1
                                    Name           = 'Job1Step1'
                                    OutputFileName = 'Job1Output1'
                                },
                                @{
                                    Id             = 2
                                    Name           = 'Job1Step2'
                                    OutputFileName = 'Job1Output2'
                                }
                            )
                        },
                        @{
                            Name     = 'Job2'
                            JobSteps = @(
                                @{
                                    Id             = 1
                                    Name           = 'Job2Step1'
                                    OutputFileName = 'Job2Output1'
                                },
                                @{
                                    Id   = 2
                                    Name = 'Job2Step2'
                                }
                            )
                        },
                        @{
                            Name     = 'Job3'
                            JobSteps = @(
                                @{
                                    Id   = 1
                                    Name = 'Job3Step1'
                                },
                                @{
                                    Id   = 2
                                    Name = 'Job3Step2'
                                }
                            )
                        }
                    )
                }
            }
        } -ModuleName dbatools

        Context "Return values" {
            It "Gets only steps with output files" {
                $results = Get-DbaAgentJobOutputFile -SqlInstance 'SQLServerName'
                $results.Count | Should -Be 3
                $results.Job | Should -Match 'Job[12]'
                $results.JobStep | Should -Match 'Job[12]Step[12]'
                $results.OutputFileName | Should -Match 'Job[12]Output[12]'
                $results.RemoteOutputFileName | Should -Match '\\\\SQLServerName\\Job[12]Output[12]'
            }

            It "Honors the Job parameter" {
                $results = Get-DbaAgentJobOutputFile -SqlInstance 'SQLServerName' -Job 'Job1'
                $results.Job | Should -Match 'Job1'
                $results.JobStep | Should -Match 'Job1Step[12]'
                $results.OutputFileName | Should -Match 'Job1Output[12]'
            }

            It "Honors the ExcludeJob parameter" {
                $results = Get-DbaAgentJobOutputFile -SqlInstance 'SQLServerName' -ExcludeJob 'Job1'
                $results.Count | Should -Be 1
                $results.Job | Should -Match 'Job2'
                $results.OutputFileName | Should -Be 'Job2Output1'
                $results.StepId | Should -Be 1
            }

            It "Does not return even with a specific job without outputfiles" {
                $results = Get-DbaAgentJobOutputFile -SqlInstance 'SQLServerName' -Job 'Job3'
                $results.Count | Should -Be 0
            }
        }
    }
}
