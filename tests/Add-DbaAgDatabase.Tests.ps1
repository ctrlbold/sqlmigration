#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param($ModuleName = 'dbatools')
$global:TestConfig = Get-TestConfig

Describe "Add-DbaAgDatabase" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Add-DbaAgDatabase
            $expectedParameters = $TestConfig.CommonParameters

            $expectedParameters += @(
                "SqlInstance",
                "SqlCredential",
                "AvailabilityGroup",
                "Database",
                "Secondary",
                "SecondarySqlCredential",
                "InputObject",
                "SeedingMode",
                "SharedPath",
                "UseLastBackup",
                "AdvancedBackupParams",
                "EnableException"
            )
        }

        It "Should have exactly the expected parameters" {
            $actualParameters = $command.Parameters.Keys | Where-Object { $PSItem -notin "WhatIf", "Confirm" }
            Compare-Object -ReferenceObject $expectedParameters -DifferenceObject $actualParameters | Should -BeNullOrEmpty
        }

        It "Has parameter: <_>" -ForEach $expectedParameters {
            $command | Should -HaveParameter $PSItem
        }
    }
}

Describe "Add-DbaAgDatabase" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaProcess -SqlInstance $TestConfig.instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance3
        $agname = "dbatoolsci_addagdb_agroup"
        $dbname = "dbatoolsci_addagdb_agroupdb"
        $newdbname = "dbatoolsci_addag_agroupdb_2"
        $server.Query("create database $dbname")
        $backup = Get-DbaDatabase -SqlInstance $TestConfig.instance3 -Database $dbname | Backup-DbaDatabase
        $splat = @{
            Primary       = $TestConfig.instance3
            Name          = $agname
            ClusterType   = "None"
            FailoverMode  = "Manual"
            Database      = $dbname
            Confirm       = $false
            Certificate   = "dbatoolsci_AGCert"
        }
        $ag = New-DbaAvailabilityGroup @splat
    }

    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $server -AvailabilityGroup $agname -Confirm:$false
        $null = Remove-DbaDatabase -SqlInstance $server -Database $dbname, $newdbname -Confirm:$false
    }

    Context "When adding a database to an availability group" {
        BeforeAll {
            $server.Query("create database $newdbname")
            $backup = Get-DbaDatabase -SqlInstance $TestConfig.instance3 -Database $newdbname | Backup-DbaDatabase
            $results = Add-DbaAgDatabase -SqlInstance $TestConfig.instance3 -AvailabilityGroup $agname -Database $newdbname -Confirm:$false
        }

        It "Adds the database to the availability group" {
            $results.AvailabilityGroup | Should -Be $agname
            $results.Name | Should -Be $newdbname
            $results.IsJoined | Should -Be $true
        }
    }
}

#$TestConfig.instance2 for appveyor
