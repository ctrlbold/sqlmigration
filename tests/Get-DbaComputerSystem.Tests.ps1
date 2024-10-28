#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaComputerSystem" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaComputerSystem
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "ComputerName",
            "Credential",
            "IncludeAws",
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

    Context "Input validation" {
        BeforeAll {
            Mock -CommandName Resolve-DbaNetworkName -MockWith { $null }
        }

        It "Throws when hostname cannot be resolved" {
            { Get-DbaComputerSystem -ComputerName 'DoesNotExist142' -WarningAction Stop 3> $null } |
                Should -Throw
        }
    }
}

Describe "Get-DbaComputerSystem" -Tag "IntegrationTests" {
    BeforeAll {
        $result = Get-DbaComputerSystem -ComputerName $TestConfig.Instance1
        $expectedProps = @(
            'ComputerName',
            'Domain',
            'IsDaylightSavingsTime',
            'Manufacturer',
            'Model',
            'NumberLogicalProcessors',
            'NumberProcessors',
            'IsHyperThreading',
            'SystemFamily',
            'SystemSkuNumber',
            'SystemType',
            'IsSystemManagedPageFile',
            'TotalPhysicalMemory'
        )
    }

    Context "When getting computer system information" {
        It "Returns property: <_>" -ForEach $expectedProps {
            $result.PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }
}
