$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tags "UnitTests" {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'Role', 'Owner', 'InputObject', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $instance = Connect-DbaInstance -SqlInstance $script:instance2
        $dbname = "dbatoolsci_adddb_newrole"
        $instance.Query("create database $dbname")
        $roleExecutor = "dbExecuter"
        $roleSPAccess = "dbSPAccess"
        $owner = 'dbo'
    }
    AfterEach {
        $null = Remove-DbaDbRole -SqlInstance $instance -Database $dbname -Role $roleExecutor, $roleSPAccess -Confirm:$false
    }
    AfterAll {
        $null = Remove-DbaDatabase -SqlInstance $instance -Database $dbname -Confirm:$false
    }

    Context "Functionality" {
        It 'Add new role and returns results' {
            $result = New-DbaDbRole -SqlInstance $instance -Database $dbname -Role $roleExecutor

            $result.Count | Should Be 1
            $result.Name | Should Be $roleExecutor
            $result.Parent | Should Be $dbname
        }

        It 'Add new role with specificied owner' {
            $result = New-DbaDbRole -SqlInstance $instance -Database $dbname -Role $roleExecutor -Owner $owner

            $result.Count | Should Be 1
            $result.Name | Should Be $roleExecutor
            $result.Owner | Should Be $owner
            $result.Parent | Should Be $dbname
        }

        It 'Add two new roles and returns results' {
            $result = New-DbaDbRole -SqlInstance $instance -Database $dbname -Role $roleExecutor, $roleSPAccess

            $result.Count | Should Be 2
            $result.Name | Should Contain $roleExecutor
            $result.Name | Should Contain $roleSPAccess
            $result.Parent | Select-Object -Unique | Should Be $dbname
        }

        It 'Accept database as inputObject' {
            $result = $instance.Databases[$dbname] | New-DbaDbRole -Role $roleExecutor

            $result.Count | Should Be 1
            $result.Name | Should Be $roleExecutor
            $result.Parent | Should Be $dbname
        }
    }
}