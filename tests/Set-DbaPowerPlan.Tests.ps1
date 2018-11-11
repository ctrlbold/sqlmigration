$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 4
        $defaultParamCount = 13
        [object[]]$params = (Get-ChildItem function:\Set-DbaPowerPlan).Parameters.Keys
        $knownParameters = 'ComputerName','PowerPlan','CustomPowerPlan','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}
<#
    Integration test should appear below and are custom to the command you are writing.
    Read https://github.com/sqlcollaborative/dbatools/blob/development/contributing.md#tests
    for more guidence.
#>
Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Command actually works" {
        It "Should return result for the server" {
            $results = Set-DbaPowerPlan -ComputerName $script:instance2
            $results | Should Not Be Null
            $results.ReturnValue | Should Be $true
        }
        It "Should skip if already set" {
            $results = Set-DbaPowerPlan -ComputerName $script:instance2
            $results.ActivePowerPlan -eq 'High Performance' | Should Be $true
            $results.ActivePowerPlan -eq $results.PreviousPowerPlan | Should Be $true
        }
        It "Should return result for the server when setting defined PowerPlan" {
            $results = Set-DbaPowerPlan -ComputerName $script:instance2 -PowerPlan Balanced
            $results | Should Not Be Null
            $results.ReturnValue | Should Be $true
        }
        It "Should return result for the server when using CustomPowerPlan" {
            $results = Set-DbaPowerPlan -ComputerName $script:instance2 -CustomPowerPlan Balanced
            $results | Should Not Be Null
            $results.ActivePowerPlan -eq 'Balanced' | Should Be $true
        }
        It "Should accept Piped input from Test-DbaPowerPlan" {
            $results = Test-DbaPowerPlan -ComputerName $script:instance2 | Set-DbaPowerPlan
            $results | Should Not Be Null
            $results.ReturnValue | Should Be $true
        }
    }
}

