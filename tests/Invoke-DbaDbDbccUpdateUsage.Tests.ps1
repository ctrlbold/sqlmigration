$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'Table', 'Index', 'NoInformationalMessages', 'CountRows', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}
Describe "$commandname Integration Test" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $script:instance1
        $random = Get-Random
        $tableName = "dbatools_getdbtbl1"

        $dbname = "dbatoolsci_getdbUsage$random"
        $db = New-DbaDatabase -SqlInstance $script:instance1 -Name $dbname
        $null = $db.Query("CREATE TABLE $tableName (id int)", $dbname)
        $null = $db.Query("CREATE CLUSTERED INDEX [PK_Id] ON $tableName ([id] ASC)", $dbname)
        $null = $db.Query("INSERT $tableName(id) SELECT object_id FROM sys.objects", $dbname)
    }
    AfterAll {
        $null = Get-DbaDatabase -SqlInstance $script:instance1 -Database $dbname | Remove-DbaDatabase -Confirm:$false
    }

    Context "Validate standard output" {
        $props = 'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'Cmd', 'Output'
        $result = Invoke-DbaDbDbccUpdateUsage -SqlInstance $script:instance1 -Confirm:$false

        It "returns results" {
            $result.Count -gt 0 | Should Be $true
        }

        foreach ($prop in $props) {
            $p = $result[0].PSObject.Properties[$prop]
            It "Should return property: $prop" {
                $p.Name | Should Be $prop
            }
        }
    }

    Context "Validate returns results " {
        $result = Invoke-DbaDbDbccUpdateUsage -SqlInstance $script:instance1 -Database $dbname -Table $tableName -Confirm:$false

        It "returns results for table" {
            $result.Output -match 'DBCC execution completed. If DBCC printed error messages, contact your system administrator.' | Should Be $true
        }

        $result = Invoke-DbaDbDbccUpdateUsage -SqlInstance $script:instance1 -Database $dbname -Table $tableName -Index 1 -Confirm:$false

        It "returns results for index by id" {
            $result.Output -match 'DBCC execution completed. If DBCC printed error messages, contact your system administrator.' | Should Be $true
        }
    }

}