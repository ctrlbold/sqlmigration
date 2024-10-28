#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

# no params to test

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
