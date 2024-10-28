#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaPfDataCollectorSetTemplate" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaPfDataCollectorSetTemplate
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "ComputerName",
            "Credential", 
            "CollectorSet",
            "Path",
            "FilePath",
            "InputObject",
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

Describe "Export-DbaPfDataCollectorSetTemplate" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaPfDataCollectorSetTemplate -Template "Long Running Queries" | Import-DbaPfDataCollectorSetTemplate
    }

    AfterAll {
        $null = Get-DbaPfDataCollectorSet -CollectorSet "Long Running Queries" | Remove-DbaPfDataCollectorSet -Confirm:$false
    }

    Context "When exporting collector set templates" {
        It "Returns a file system object when using pipeline input" {
            $results = Get-DbaPfDataCollectorSet -CollectorSet "Long Running Queries" | Export-DbaPfDataCollectorSetTemplate
            $results.BaseName | Should -Be "Long Running Queries"
        }

        It "Returns a file system object when using parameter input" {
            $results = Export-DbaPfDataCollectorSetTemplate -CollectorSet "Long Running Queries"
            $results.BaseName | Should -Be "Long Running Queries"
        }
    }
}
