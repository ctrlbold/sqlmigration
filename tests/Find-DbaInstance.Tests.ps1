#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Find-DbaInstance" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaInstance
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "ComputerName",
            "DiscoveryType",
            "Credential",
            "SqlCredential",
            "ScanType",
            "IpAddress",
            "DomainController",
            "TCPPort",
            "MinimumConfidence",
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

Describe "Find-DbaInstance" -Tag "IntegrationTests" {
    Context "When finding SQL Server instances" {
        BeforeAll {
            $results = Find-DbaInstance -ComputerName $TestConfig.instance3 -ScanType Browser, SqlConnect | Select-Object -First 1
        }

        It "Returns an object of type [Dataplat.Dbatools.Discovery.DbaInstanceReport]" {
            $results | Should -BeOfType [Dataplat.Dbatools.Discovery.DbaInstanceReport]
        }

        It "Returns results with populated FullName" {
            $results.FullName | Should -Not -BeNullOrEmpty
        }

        It "Successfully connects to SQL Server" {
            $results.SqlConnected | Should -Be $true
        }

        It "Has TCP connection when testing remote instance" {
            if (([DbaInstanceParameter]$TestConfig.instance3).IsLocalHost -eq $false) {
                $results.TcpConnected | Should -Be $true
            }
        }
    }
}
