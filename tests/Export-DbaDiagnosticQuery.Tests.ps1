#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaDiagnosticQuery" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaDiagnosticQuery
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "InputObject",
            "ConvertTo",
            "Path",
            "Suffix",
            "NoPlanExport",
            "NoQueryExport",
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

Describe "Export-DbaDiagnosticQuery" -Tag "IntegrationTests" {
    BeforeAll {
        $testPath = "C:\temp\dbatoolsci"
    }

    AfterAll {
        Get-ChildItem $testPath -Recurse -ErrorAction Ignore | Remove-Item -ErrorAction Ignore
        Get-Item $testPath -ErrorAction Ignore | Remove-Item -ErrorAction Ignore
    }

    Context "When exporting diagnostic query results" {
        BeforeAll {
            $null = Invoke-DbaDiagnosticQuery -SqlInstance $TestConfig.Instance2 -QueryName "Memory Clerk Usage" |
                Export-DbaDiagnosticQuery -Path $testPath
        }

        It "Should create output directory and export results to one file" {
            (Get-ChildItem $testPath).Count | Should -Be 1
        }
    }
}
