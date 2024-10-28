#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaConnectedInstance" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaConnectedInstance
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
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

Describe "Get-DbaConnectedInstance" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaDatabase -SqlInstance $TestConfig.Instance1
    }

    Context "When getting connected instances" {
        BeforeAll {
            $results = Get-DbaConnectedInstance
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
