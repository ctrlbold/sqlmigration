#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaBackupDevice" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaBackupDevice
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
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

Describe "Get-DbaBackupDevice" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.Instance2
        $sql = "EXEC sp_addumpdevice 'tape', 'dbatoolsci_tape', '\\.\tape0';"
        $server.Query($sql)
    }

    AfterAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.Instance2
        $sql = "EXEC sp_dropdevice 'dbatoolsci_tape';"
        $server.Query($sql)
    }

    Context "When getting backup devices" {
        BeforeAll {
            $results = Get-DbaBackupDevice -SqlInstance $TestConfig.Instance2
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Should have the name dbatoolsci_tape" {
            $results.Name | Should -Be "dbatoolsci_tape"
        }

        It "Should have a BackupDeviceType of Tape" {
            $results.BackupDeviceType | Should -Be "Tape"
        }

        It "Should have a PhysicalLocation of \\.\Tape0" {
            $results.PhysicalLocation | Should -Be "\\.\Tape0"
        }
    }
}
