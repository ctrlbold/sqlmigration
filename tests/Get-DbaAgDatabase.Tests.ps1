$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        <#
            Get commands, Default count = 11
            Commands with SupportShouldProcess = 13
        #>
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem function:\Get-DbaAgDatabase).Parameters.Keys
        $knownParameters = 'SqlInstance', 'SqlCredential', 'AvailabilityGroup', 'Database', 'InputObject', 'EnableException'
        $paramCount = $knownParameters.Count
        It "Should contain our specific parameters" {
            ((Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $computername = ($script:instance3).Split("\")[0]
        $null = Get-DbaProcess -SqlInstance $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $server = Connect-DbaInstance -SqlInstance $script:instance3
        $agname = "dbatoolsci_getag_agroup"
        $dbname = "dbatoolsci_getag_agroupdb"
        $server.Query("create database $dbname")
        $backup = Get-DbaDatabase -SqlInstance $script:instance3 -Database $dbname | Backup-DbaDatabase
        $ag = New-DbaAvailabilityGroup -Primary $script:instance3 -Name $agname -ClusterType None -FailoverMode Manual -Database $dbname -Confirm:$false -Certificate dbatoolsci_AGCert
    }
    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $server -AvailabilityGroup $agname -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $server -Database $dbname -Confirm:$false
    }
    Context "gets ag db" {
        It "returns results" {
            $results = Get-DbaAgDatabase -SqlInstance $script:instance3 -Database $dbname
            $results.AvailabilityGroup | Should -Be $agname
            $results.Name | Should -Be $dbname
            $results.Replica | Should -Not -Be $null
        }
    }
} #$script:instance2 for appveyor