$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"
$sourcePath = [IO.Path]::Combine((Split-Path $PSScriptRoot -Parent), 'src')
. "$sourcePath\private\functions\Invoke-DbaDbCorruption.ps1"

Describe "$commandname Unit Tests" -Tags "UnitTests" {

    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'Table', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
    Context "Validate Confirm impact" {
        It "Confirm Impact should be high" {
            $metadata = [System.Management.Automation.CommandMetadata](Get-Command $CommandName)
            $metadata.ConfirmImpact | Should Be 'High'
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_InvokeDbaDatabaseCorruptionTest"
        $Server = Connect-DbaInstance -SqlInstance $script:instance2
        $TableName = "Example"
        # Need a clean empty database
        $null = $Server.Query("Create Database [$dbname]")
        $db = Get-DbaDatabase -SqlInstance $script:instance2 -Database $dbname
    }

    AfterAll {
        # Cleanup
        Remove-DbaDatabase -SqlInstance $script:instance2 -Database $dbname -Confirm:$false
    }

    Context "Validating Database Input" {
        Invoke-DbaDbCorruption -SqlInstance $script:instance2 -Database "master" -WarningAction SilentlyContinue -WarningVariable systemwarn
        It "Should not allow you to corrupt system databases." {
            $systemwarn -match 'may not corrupt system databases' | Should Be $true
        }
        It "Should fail if more than one database is specified" {
            { Invoke-DbaDbCorruption -SqlInstance $script:instance2 -Database "Database1", "Database2" -EnableException } | Should Throw
        }
    }

    It "Require at least a single table in the database specified" {
        { Invoke-DbaDbCorruption -SqlInstance $script:instance2 -Database $dbname -EnableException } | Should Throw
    }

    # Creating a table to make sure these are failing for different reasons
    It "Fail if the specified table does not exist" {
        { Invoke-DbaDbCorruption -SqlInstance $script:instance2 -Database $dbname -Table "DoesntExist$(New-Guid)" -EnableException } | Should Throw
    }

    $null = $db.Query("
        CREATE TABLE dbo.[$TableName] (id int);
        INSERT dbo.[Example]
        SELECT top 1000 1
        FROM sys.objects")

    It "Corrupt a single database" {
        Invoke-DbaDbCorruption -SqlInstance $script:instance2 -Database $dbname -Confirm:$false | Select-Object -ExpandProperty Status | Should be "Corrupted"
    }

    It "Causes DBCC CHECKDB to fail" {
        $result = Start-DbccCheck -Server $server -dbname $dbname
        $result | Should Not Be 'Success'
    }
}