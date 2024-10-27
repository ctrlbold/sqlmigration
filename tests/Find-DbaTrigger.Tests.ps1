#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaTrigger" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaTrigger
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential', 
            'Database',
            'ExcludeDatabase',
            'Pattern',
            'TriggerLevel',
            'IncludeSystemObjects',
            'IncludeSystemDatabases',
            'EnableException'
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasparms = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

Describe "Find-DbaTrigger" -Tag "IntegrationTests" {
    Context "Command finds Triggers at the Server Level" {
        BeforeAll {
            ## All Triggers adapted from examples on:
            ## https://docs.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql?view=sql-server-2017

            $ServerTrigger = @"
CREATE TRIGGER dbatoolsci_ddl_trig_database
ON ALL SERVER
FOR CREATE_DATABASE
AS
    PRINT 'dbatoolsci Database Created.'
    SELECT EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]','nvarchar(max)')
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $ServerTrigger
        }

        AfterAll {
            $DropTrigger = @"
DROP TRIGGER dbatoolsci_ddl_trig_database
ON ALL SERVER;
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'Master' -Query $DropTrigger
        }

        BeforeAll {
            $results = Find-DbaTrigger -SqlInstance $TestConfig.instance2 -Pattern dbatoolsci* -IncludeSystemDatabases -IncludeSystemObjects -TriggerLevel Server
        }

        It "Should find a specific Trigger at the Server Level" {
            $results.TriggerLevel | Should -Be "Server"
            $results.DatabaseId | Should -BeNullOrEmpty
        }

        It "Should find a specific Trigger named dbatoolsci_ddl_trig_database" {
            $results.Name | Should -Be "dbatoolsci_ddl_trig_database"
        }

        It "Should find a specific Trigger when TriggerLevel is All" {
            $allResults = Find-DbaTrigger -SqlInstance $TestConfig.instance2 -Pattern dbatoolsci* -TriggerLevel All
            $allResults.Name | Should -Be "dbatoolsci_ddl_trig_database"
        }
    }

    Context "Command finds Triggers at the Database and Object Level" {
        BeforeAll {
            ## All Triggers adapted from examples on:
            ## https://docs.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql?view=sql-server-2017

            $dbatoolsci_triggerdb = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name 'dbatoolsci_triggerdb'
            $DatabaseTrigger = @"
CREATE TRIGGER dbatoolsci_safety
ON DATABASE
FOR DROP_SYNONYM
AS
IF (@@ROWCOUNT = 0)
RETURN;
   RAISERROR ('You must disable Trigger "safety" to drop synonyms!',10, 1)
   ROLLBACK
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_triggerdb' -Query $DatabaseTrigger
            $TableTrigger = @"
CREATE TABLE dbo.Customer (id int, PRIMARY KEY (id));
GO
CREATE TRIGGER dbatoolsci_reminder1
ON dbo.Customer
AFTER INSERT, UPDATE
AS RAISERROR ('Notify Customer Relations', 16, 10);
GO
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_triggerdb' -Query $TableTrigger
        }

        AfterAll {
            $null = Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_triggerdb' -Confirm:$false
        }

        BeforeAll {
            $databaseResults = Find-DbaTrigger -SqlInstance $TestConfig.instance2 -Pattern dbatoolsci* -Database 'dbatoolsci_triggerdb' -TriggerLevel Database
            $objectResults = Find-DbaTrigger -SqlInstance $TestConfig.instance2 -Pattern dbatoolsci* -Database 'dbatoolsci_triggerdb' -ExcludeDatabase Master -TriggerLevel Object
            $allResults = Find-DbaTrigger -SqlInstance $TestConfig.instance2 -Pattern dbatoolsci* -TriggerLevel All
        }

        It "Should find a specific Trigger at the Database Level" {
            $databaseResults.TriggerLevel | Should -Be "Database"
            $databaseResults.DatabaseId | Should -Be $dbatoolsci_triggerdb.ID
        }

        It "Should find a specific Trigger named dbatoolsci_safety" {
            $databaseResults.Name | Should -Be "dbatoolsci_safety"
        }

        It "Should find a specific Trigger at the Object Level" {
            $objectResults.TriggerLevel | Should -Be "Object"
            $objectResults.DatabaseId | Should -Be $dbatoolsci_triggerdb.ID
        }

        It "Should find a specific Trigger named dbatoolsci_reminder1" {
            $objectResults.Name | Should -Be "dbatoolsci_reminder1"
        }

        It "Should find a specific Trigger on the Table [dbo].[Customer]" {
            $objectResults.Object | Should -Be "[dbo].[Customer]"
        }

        It "Should find 2 Triggers when TriggerLevel is All" {
            $allResults.Name | Should -Be @('dbatoolsci_safety', 'dbatoolsci_reminder1')
            $allResults.DatabaseId | Should -Be @($dbatoolsci_triggerdb.ID, $dbatoolsci_triggerdb.ID)
        }
    }
}
