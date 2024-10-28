#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaClientAlias" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaClientAlias
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

Describe "Get-DbaClientAlias" -Tag "IntegrationTests" {
    BeforeAll {
        $newalias = New-DbaClientAlias -ServerName sql2016 -Alias dbatoolscialias -Verbose:$false
    }

    AfterAll {
        $newalias | Remove-DbaClientAlias
    }

    Context "When getting client aliases" {
        BeforeAll {
            $results = Get-DbaClientAlias
        }

        It "Returns the expected alias" {
            $results.AliasName | Should -Contain 'dbatoolscialias'
        }
    }
}