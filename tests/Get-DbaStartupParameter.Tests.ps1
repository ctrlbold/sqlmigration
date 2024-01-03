$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance', 'Credential', 'Simple', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Command actually works" {
        $results = Get-DbaStartupParameter -SqlInstance $script:instance2
        $resultsSimple = Get-DbaStartParameter -SqlInstance $script:instance2 -Simple
        It "Results return anything" {
            $results | Should -Not -Be $null
        }
        It "Only outputs results for Simple parameter" {
            # Picking property that will not exist on Simple object output
            # Only check for property name because it may not have a value even when you don't use -Simple parameter
            $resultSimple.PSObject.Properties.Name -notmatch "CommandPromptStart" | Should -BeTrue
        }
    }
}