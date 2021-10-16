$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'Source', 'Database', 'SourceSqlCredential', 'Destination', 'DestinationDatabase', 'DestinationSqlCredential', 'Credential', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    Context "Should Measure Disk Space Required " {
        $Options = @{
            Source              = $($script:instance1)
            Destination         = $($script:instance2)
            Database            = "Master"
            DestinationDatabase = "Dbatoolsci_DestinationDB"
        }
        $results = Measure-DbaDiskSpaceRequirement @Options
        It "Should have information" {
            $results | Should Not Be $Null
        }
        foreach ($r in $results) {
            It "Should be sourced from Master" {
                $r.SourceDatabase | Should Be "Master"
            }
            It "Should be sourced from the instance $($script:instance1)" {
                $r.SourceSqlInstance | Should Be "$env:COMPUTERNAME\SQL2008R2SP2"
            }
            It "Should be destined for Dbatoolsci_DestinationDB" {
                $r.DestinationDatabase | Should Be "Dbatoolsci_DestinationDB"
            }
            It "Should be destined for the instance $($script:instance2)" {
                $r.DestinationSqlInstance | Should Be "$env:COMPUTERNAME\SQL2016"
            }
            It "Should be have files on source" {
                $r.FileLocation | Should Be "Only on Source"
            }
        }
    }
}