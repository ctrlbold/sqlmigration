#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaClientProtocol" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaClientProtocol
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "ComputerName",
            "Credential",
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

Describe "Get-DbaClientProtocol" -Tag "IntegrationTests" {
    Context "When getting client protocols" {
        BeforeAll {
            $results = Get-DbaClientProtocol
        }

        It "Returns multiple protocols" {
            $results.Count | Should -BeGreaterThan 1
        }

        It "Includes TCP/IP protocol" {
            $tcpip = $results | Where-Object { $PSItem.ProtocolDisplayName -eq 'TCP/IP' }
            $tcpip | Should -Not -BeNullOrEmpty
        }
    }
}