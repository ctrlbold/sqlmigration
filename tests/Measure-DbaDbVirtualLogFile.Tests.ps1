$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

<#
    Unit test is required for any command added
#>
Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'IncludeSystemDBs', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}
# Get-DbaNoun
Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $db1 = "dbatoolsci_testvlf"
        $server.Query("CREATE DATABASE $db1")
        $needed = Get-DbaDatabase -SqlInstance $script:instance2 -Database $db1
        $setupright = $true
        if ($needed.Count -ne 1) {
            $setupright = $false
            it "has failed setup" {
                Set-TestInconclusive -message "Setup failed"
            }
        }
    }
    AfterAll {
        Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance2 -Database $db1
    }

    Context "Command actually works" {
        $results = Measure-DbaDbVirtualLogFile -SqlInstance $script:instance2 -Database $db1

        It "Should have correct properties" {
            $ExpectedProps = 'ComputerName,InstanceName,SqlInstance,Database,Total,TotalCount,Inactive,Active,LogFileName,LogFileGrowth,LogFileGrowthType'.Split(',')
            ($results.PsObject.Properties.Name | Sort-Object) | Should Be ($ExpectedProps | Sort-Object)
        }

        It "Should have database name of $db1" {
            foreach ($result in $results) {
                $result.Database | Should Be $db1
            }
        }

        It "Should have values for Total property" {
            foreach ($result in $results) {
                $result.Total | Should Not BeNullOrEmpty
                $result.Total | Should BeGreaterThan 0
            }
        }
    }
}