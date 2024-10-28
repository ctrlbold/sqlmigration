#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAgBackupHistory" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgBackupHistory
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "AvailabilityGroup",
            "Database",
            "ExcludeDatabase",
            "IncludeCopyOnly",
            "Force",
            "Since",
            "RecoveryFork",
            "Last",
            "LastFull",
            "LastDiff",
            "LastLog",
            "DeviceType",
            "Raw",
            "LastLsn",
            "Type",
            "EnableException",
            "IncludeMirror",
            "LsnSort"
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

# No Integration Tests, because we don't have an availability group running in AppVeyor
