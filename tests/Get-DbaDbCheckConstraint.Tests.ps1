#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}

param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbCheckConstraint" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbCheckConstraint
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "ExcludeSystemTable",
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

Describe "Get-DbaDbCheckConstraint" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $random = Get-Random
        $tableName = "dbatools_getdbtbl1"
        $tableName2 = "dbatools_getdbtbl2"
        $ckName = "dbatools_getdbck"
        $dbname = "dbatoolsci_getdbfk$random"
        $server.Query("CREATE DATABASE $dbname")
        $server.Query("CREATE TABLE $tableName (idTbl1 INT PRIMARY KEY)", $dbname)
        $server.Query("CREATE TABLE $tableName2 (idTbl2 INT, idTbl1 INT, id3 INT)", $dbname)
        $server.Query("ALTER TABLE $tableName2 ADD CONSTRAINT $ckName CHECK (id3 > 10)", $dbname)
    }

    AfterAll {
        $null = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname | Remove-DbaDatabase -Confirm:$false
    }

    Context "Command actually works" {
        It "returns no check constraints from excluded DB with -ExcludeDatabase" {
            $results = Get-DbaDbCheckConstraint -SqlInstance $TestConfig.instance2 -ExcludeDatabase master
            $results.where( { $PSItem.Database -eq 'master' }).Count | Should -Be 0
        }

        It "returns only check constraints from selected DB with -Database" {
            $results = Get-DbaDbCheckConstraint -SqlInstance $TestConfig.instance2 -Database $dbname
            $results.where( { $PSItem.Database -ne 'master' }).Count | Should -Be 1
            $results.DatabaseId | Get-Unique | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname).Id
        }

        It "Should include test check constraint: $ckName" {
            $results = Get-DbaDbCheckConstraint -SqlInstance $TestConfig.instance2 -Database $dbname -ExcludeSystemTable
            ($results | Where-Object Name -eq $ckName).Name | Should -Be $ckName
        }

        It "Should exclude system tables" {
            $results = Get-DbaDbCheckConstraint -SqlInstance $TestConfig.instance2 -Database master -ExcludeSystemTable
            ($results | Where-Object Name -eq 'spt_fallback_db') | Should -BeNullOrEmpty
        }
    }
}
