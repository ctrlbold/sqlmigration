#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaCmObject" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCmObject
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "ClassName",
            "Query",
            "ComputerName",
            "Credential",
            "Namespace",
            "DoNotUse",
            "Force",
            "SilentlyContinue",
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

Describe "Get-DbaCmObject" -Tag "IntegrationTests" {
    Context "When querying Win32_TimeZone" {
        BeforeAll {
            $results = Get-DbaCmObject -ClassName Win32_TimeZone
        }

        It "Returns a Bias property that is an integer" {
            $results.Bias | Should -BeOfType [int]
        }
    }
}