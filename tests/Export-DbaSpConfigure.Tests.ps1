#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaSpConfigure" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaSpConfigure
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Path",
            "FilePath",
            "EnableException"
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaSpConfigure" -Tag "IntegrationTests" {
    BeforeAll {
        # Setup code for integration tests
    }

    Context "When exporting sp_configure" {
        BeforeAll {
            # Context specific setup
        }

        AfterAll {
            # Context specific cleanup
        }

        It "Exports sp_configure settings successfully" {
            # Test implementation needed
        }
    }
}
