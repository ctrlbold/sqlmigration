#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbccMemoryStatus" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbccMemoryStatus
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

Describe "Get-DbaDbccMemoryStatus" -Tag "IntegrationTests" {
    BeforeAll {
        $result = Get-DbaDbccMemoryStatus -SqlInstance $TestConfig.instance2
        $props = @(
            'ComputerName',
            'InstanceName',
            'RecordSet',
            'RowId',
            'RecordSetId',
            'Type',
            'Name',
            'Value',
            'ValueType'
        )
    }

    Context "Validate standard output" {
        It "Should return property: <_>" -ForEach $props {
            $result[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "Command returns proper info" {
        It "Returns results for DBCC MEMORYSTATUS" {
            $result.Count | Should -BeGreaterThan 0
        }
    }
}
