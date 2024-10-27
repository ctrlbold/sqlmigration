#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaXESession" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaXESession
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "InputObject",
            "Session",
            "Path",
            "FilePath",
            "Encoding",
            "Passthru",
            "BatchSeparator",
            "NoPrefix",
            "NoClobber",
            "Append",
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

Describe "Export-DbaXESession" -Tag "IntegrationTests" {
    BeforeAll {
        $AltExportPath = "$env:USERPROFILE\Documents"
        $outputFile = "$AltExportPath\Dbatoolsci_XE_CustomFile.sql"
    }
    
    AfterAll {
        Get-ChildItem $outputFile -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
    }

    Context "When exporting XE sessions to file" {
        BeforeAll {
            $null = Export-DbaXESession -SqlInstance $TestConfig.Instance2 -FilePath $outputFile
        }

        It "Creates a single SQL file" {
            (Get-ChildItem $outputFile).Count | Should -Be 1
        }

        It "Creates a non-empty file" {
            (Get-ChildItem $outputFile).Length | Should -BeGreaterThan 0
        }
    }

    Context "When exporting specific XE session" {
        BeforeAll {
            $null = Export-DbaXESession -SqlInstance $TestConfig.Instance2 -FilePath $outputFile -Session system_health
        }

        It "Creates a single SQL file" {
            (Get-ChildItem $outputFile).Count | Should -Be 1
        }

        It "Creates a non-empty file" {
            (Get-ChildItem $outputFile).Length | Should -BeGreaterThan 0
        }
    }

    Context "When using pipeline input" {
        BeforeAll {
            $null = Get-DbaXESession -SqlInstance $TestConfig.Instance2 -Session system_health | 
                Export-DbaXESession -FilePath $outputFile
        }

        It "Creates a single SQL file" {
            (Get-ChildItem $outputFile).Count | Should -Be 1
        }

        It "Creates a non-empty file" {
            (Get-ChildItem $outputFile).Length | Should -BeGreaterThan 0
        }
    }
}
