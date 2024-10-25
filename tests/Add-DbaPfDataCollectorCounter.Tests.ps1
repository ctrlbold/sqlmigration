#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param($ModuleName = "dbatools")
$global:TestConfig = Get-TestConfig

Describe "Add-DbaPfDataCollectorCounter" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Add-DbaPfDataCollectorCounter
            $expectedParameters = $TestConfig.CommonParameters

            $expectedParameters += @(
                "ComputerName",
                "Credential",
                "CollectorSet",
                "Collector",
                "Counter",
                "InputObject",
                "EnableException"
            )
        }

        It "Has parameter: <_>" -ForEach $expectedParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters" {
            $actualParameters = $command.Parameters.Keys | Where-Object { $PSItem -notin "WhatIf", "Confirm" }
            Compare-Object -ReferenceObject $expectedParameters -DifferenceObject $actualParameters | Should -BeNullOrEmpty
        }
    }
}

Describe "Add-DbaPfDataCollectorCounter" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaPfDataCollectorSetTemplate -Template 'Long Running Queries' | Import-DbaPfDataCollectorSetTemplate |
            Get-DbaPfDataCollector | Get-DbaPfDataCollectorCounter -Counter '\LogicalDisk(*)\Avg. Disk Queue Length' | Remove-DbaPfDataCollectorCounter -Confirm:$false
    }

    AfterAll {
        $null = Get-DbaPfDataCollectorSet -CollectorSet 'Long Running Queries' | Remove-DbaPfDataCollectorSet -Confirm:$false
    }

    Context "When adding a counter to a data collector" {
        BeforeAll {
            $splatAddCounter = @{
                CollectorSet = 'Long Running Queries'
                Counter = '\LogicalDisk(*)\Avg. Disk Queue Length'
            }
            $results = Get-DbaPfDataCollectorSet @splatAddCounter | 
                Get-DbaPfDataCollector | 
                Add-DbaPfDataCollectorCounter @splatAddCounter
        }

        It "Returns the correct DataCollectorSet" {
            $results.DataCollectorSet | Should -Be 'Long Running Queries'
        }

        It "Returns the correct counter name" {
            $results.Name | Should -Be '\LogicalDisk(*)\Avg. Disk Queue Length'
        }
    }
}
