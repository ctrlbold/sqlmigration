$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"
$base = (Get-Module -Name dbatools | Where-Object ModuleBase -notmatch net).ModuleBase

# Add-Type -Path "$base\bin\smo\Microsoft.SqlServer.XE.Core.dll"
# Add-Type -Path "$base\bin\smo\Microsoft.SqlServer.XEvent.Configuration.dll"
# Add-Type -Path "$base\bin\smo\Microsoft.SqlServer.XEvent.dll"
# Add-Type -Path "$base\bin\smo\Microsoft.SqlServer.XEvent.Linq.dll"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'Path', 'Raw', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Verifying command output" {
        # THIS WORKS, I SWEAR
        It "returns some results" {
            $results = Get-DbaXESession -SqlInstance $script:instance2 | Read-DbaXEFile -Raw -WarningAction SilentlyContinue
            [System.Linq.Enumerable]::Count($results) -gt 1 | Should Be $true
        }
        It "returns some results" {
            $results = Get-DbaXESession -SqlInstance $script:instance2 | Read-DbaXEFile -WarningAction SilentlyContinue
            $results.Count -gt 1 | Should Be $true
        }
    }
}