#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Find-DbaView" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaView
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

Describe "Find-DbaView" -Tags "IntegrationTests" {
    Context "When finding views in a system database" {
        BeforeAll {
            $serverView = @"
CREATE VIEW dbo.v_dbatoolsci_sysadmin
AS
    SELECT [sid],[loginname],[sysadmin]
    FROM [master].[sys].[syslogins];
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'Master' -Query $serverView
        }

        AfterAll {
            $dropView = "DROP VIEW dbo.v_dbatoolsci_sysadmin;"
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'Master' -Query $dropView
        }

        BeforeAll {
            $results = Find-DbaView -SqlInstance $TestConfig.instance2 -Pattern dbatools* -IncludeSystemDatabases
        }

        It "Should find a specific View named v_dbatoolsci_sysadmin" {
            $results.Name | Should -Be "v_dbatoolsci_sysadmin"
        }

        It "Should find v_dbatoolsci_sysadmin in Master" {
            $results.Database | Should -Be "Master"
            $results.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database Master).ID
        }
    }

    Context "When finding views in a user database" {
        BeforeAll {
            $null = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name 'dbatoolsci_viewdb'
            $databaseView = @"
CREATE VIEW dbo.v_dbatoolsci_sysadmin
AS
    SELECT [sid],[loginname],[sysadmin]
    FROM [master].[sys].[syslogins];
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_viewdb' -Query $databaseView
            $resultsInDb = Find-DbaView -SqlInstance $TestConfig.instance2 -Pattern dbatools* -Database 'dbatoolsci_viewdb'
            $resultsExcluded = Find-DbaView -SqlInstance $TestConfig.instance2 -Pattern dbatools* -ExcludeDatabase 'dbatoolsci_viewdb'
        }

        AfterAll {
            $null = Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database 'dbatoolsci_viewdb' -Confirm:$false
        }

        It "Should find a specific view named v_dbatoolsci_sysadmin" {
            $resultsInDb.Name | Should -Be "v_dbatoolsci_sysadmin"
        }

        It "Should find v_dbatoolsci_sysadmin in dbatoolsci_viewdb Database" {
            $resultsInDb.Database | Should -Be "dbatoolsci_viewdb"
            $resultsInDb.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database dbatoolsci_viewdb).ID
        }

        It "Should find no results when Excluding dbatoolsci_viewdb" {
            $resultsExcluded | Should -BeNullOrEmpty
        }
    }
}
