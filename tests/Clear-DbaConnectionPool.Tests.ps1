#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Clear-DbaConnectionPool" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Clear-DbaConnectionPool
        $expected = $TestConfig.CommonParameters
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

Describe "Clear-DbaConnectionPool" -Tag "IntegrationTests" {
    Context "When clearing connection pool" {
        It "Doesn't throw" {
            { Clear-DbaConnectionPool } | Should -Not -Throw
        }
    }
}
