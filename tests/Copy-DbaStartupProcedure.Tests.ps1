$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'Source', 'SourceSqlCredential', 'Destination', 'DestinationSqlCredential', 'Procedure', 'ExcludeProcedure', 'Force', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}
Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $procName = "dbatoolsci_test_startup"
        $server.Query("CREATE OR ALTER PROCEDURE $procName
                        AS
                        SELECT @@SERVERNAME
                        GO")
        $server.Query("EXEC sp_procoption @ProcName = N'$procName'
                            , @OptionName = 'startup'
                            , @OptionValue = 'on'")
    }

    AfterAll {
        Invoke-DbaQuery -SqlInstance $script:instance2, $script:instance3 -Database "master" -Query "DROP PROCEDURE dbatoolsci_test_startup"
    }

    Context "Command actually works" {
        $results = Copy-DbaStartupProcedure -Source $script:instance2 -Destination $script:instance3
        It "Should include test procedure: $procName" {
            ($results | Where-Object Name -eq $procName).Name | Should -Be $procName
        }
        It "Should be successful" {
            ($results | Where-Object Name -eq $procName).Status | Should -Be 'Successful'
        }
    }
}