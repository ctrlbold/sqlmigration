#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaComputerCertificate" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaComputerCertificate
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "ComputerName",
            "Credential",
            "Store",
            "Folder",
            "Type",
            "Path",
            "Thumbprint",
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

Describe "Get-DbaComputerCertificate" -Tag "IntegrationTests" {
    Context "When getting a specific certificate" {
        BeforeAll {
            $thumbprint = "29C469578D6C6211076A09CEE5C5797EEA0C2713"
            $null = Add-DbaComputerCertificate -Path "$($TestConfig.appveyorlabrepo)\certificates\localhost.crt" -Confirm:$false
            $cert = Get-DbaComputerCertificate -Thumbprint $thumbprint
        }

        AfterAll {
            Remove-DbaComputerCertificate -Thumbprint $thumbprint -Confirm:$false
        }

        It "Returns a single certificate with the specified thumbprint" {
            $cert.Thumbprint | Should -Be $thumbprint
        }
    }

    Context "When getting all certificates" {
        BeforeAll {
            $allCerts = Get-DbaComputerCertificate
        }

        It "Returns all certificates including one with the specified thumbprint" {
            "$($allCerts.Thumbprint)" | Should -Match "29C469578D6C6211076A09CEE5C5797EEA0C2713"
        }

        It "Returns certificates with the expected enhanced key usage" {
            "$($allCerts.EnhancedKeyUsageList)" | Should -Match '1\.3\.6\.1\.5\.5\.7\.3\.1'
        }
    }
}
