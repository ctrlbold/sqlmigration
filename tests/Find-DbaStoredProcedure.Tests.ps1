#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaStoredProcedure" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaStoredProcedure
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "Pattern",
            "IncludeSystemObjects",
            "IncludeSystemDatabases",
            "EnableException"
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

Describe "Find-DbaStoredProcedure" -Tag "IntegrationTests" {
    Context "When finding procedures in system databases" {
        BeforeAll {
            $systemProcedureQuery = @"
CREATE PROCEDURE dbo.cp_dbatoolsci_sysadmin
AS
    SET NOCOUNT ON;
    SELECT [sid],[loginname],[sysadmin]
    FROM [master].[sys].[syslogins];
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'Master' -Query $systemProcedureQuery
        }

        AfterAll {
            $dropProcedureQuery = "DROP PROCEDURE dbo.cp_dbatoolsci_sysadmin;"
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'Master' -Query $dropProcedureQuery
        }

        BeforeAll {
            $systemResults = Find-DbaStoredProcedure -SqlInstance $TestConfig.instance2 -Pattern dbatools* -IncludeSystemDatabases
        }

        It "Should find procedure named cp_dbatoolsci_sysadmin" {
            $systemResults.Name | Should -Contain "cp_dbatoolsci_sysadmin"
            $systemResults.DatabaseId | Should -BeExactly (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database master).ID
        }
    }

    Context "When finding procedures in user databases" {
        BeforeAll {
            $null = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name 'dbatoolsci_storedproceduredb'
            $userProcedureQuery = @"
CREATE PROCEDURE dbo.sp_dbatoolsci_custom
AS
    SET NOCOUNT ON;
    PRINT 'Dbatools Rocks';
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_storedproceduredb' -Query $userProcedureQuery
            $userResults = Find-DbaStoredProcedure -SqlInstance $TestConfig.instance2 -Pattern dbatools* -Database 'dbatoolsci_storedproceduredb'
            $excludeResults = Find-DbaStoredProcedure -SqlInstance $TestConfig.instance2 -Pattern dbatools* -ExcludeDatabase 'dbatoolsci_storedproceduredb'
        }

        AfterAll {
            $null = Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_storedproceduredb' -Confirm:$false
        }

        It "Should find procedure named sp_dbatoolsci_custom" {
            $userResults.Name | Should -Contain "sp_dbatoolsci_custom"
            $userResults.DatabaseId | Should -BeExactly (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database dbatoolsci_storedproceduredb).ID
        }

        It "Should find sp_dbatoolsci_custom in dbatoolsci_storedproceduredb" {
            $userResults.Database | Should -Contain "dbatoolsci_storedproceduredb"
        }

        It "Should find no results when excluding dbatoolsci_storedproceduredb" {
            $excludeResults | Should -BeNullOrEmpty
        }
    }
}
