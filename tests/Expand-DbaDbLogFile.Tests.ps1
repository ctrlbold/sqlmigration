#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Expand-DbaDbLogFile" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Expand-DbaDbLogFile
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential',
            'Database',
            'ExcludeDatabase',
            'TargetLogSize',
            'IncrementSize',
            'LogFileId',
            'ShrinkLogFile',
            'ShrinkSize',
            'BackupDirectory',
            'ExcludeDiskSpaceValidation',
            'EnableException',
            'Confirm',
            'WhatIf'
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

Describe "Expand-DbaDbLogFile" -Tag "IntegrationTests" {
    BeforeAll {
        $dbName = "dbatoolsci_expand"
        $db = New-DbaDatabase -SqlInstance $TestConfig.Instance1 -Name $dbName
    }

    AfterAll {
        Remove-DbaDatabase -Confirm:$false -SqlInstance $TestConfig.Instance1 -Database $dbName
    }

    Context "When expanding database log files" {
        BeforeAll {
            $splatExpand = @{
                SqlInstance = $TestConfig.Instance1
                Database = $dbName
                TargetLogSize = 128
            }
            $results = Expand-DbaDbLogFile @splatExpand
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns correct data types" {
            $results | Should -BeOfType System.Management.Automation.PSCustomObject
        }

        It "Has required properties" {
            $required = 'ComputerName', 'InstanceName', 'SqlInstance', 'Database', 'ID', 'Name',
                       'LogFileCount', 'InitialSize', 'CurrentSize', 'InitialVLFCount', 'CurrentVLFCount'
            $results[0].PSObject.Properties.Name | Should -Contain $_  -ForEach $required
        }

        It "Returns correct database name" {
            $results.Database | Should -Be $dbName
        }

        It "Successfully expands the log file" {
            $results.CurrentSize | Should -BeGreaterThan $results.InitialSize
        }
    }
}
