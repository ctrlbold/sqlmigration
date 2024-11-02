#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaScript" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaScript
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "InputObject",
            "ScriptingOptionsObject",
            "Path",
            "FilePath",
            "Encoding",
            "BatchSeparator",
            "NoPrefix",
            "Passthru",
            "NoClobber",
            "Append",
            "EnableException",
            "Confirm",
            "WhatIf"
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

Describe "Export-DbaScript" -Tag "IntegrationTests" {
    Context "When exporting database objects" {
        BeforeAll {
            $table = Get-DbaDbTable -SqlInstance $TestConfig.instance2 -Database msdb | Select-Object -First 1
            $results = $table | Export-DbaScript -Passthru
        }

        It "Should export text matching CREATE TABLE" {
            $results | Should -Match "CREATE TABLE"
        }

        It "Should include BatchSeparator based on the Formatting.BatchSeparator configuration" {
            $results | Should -Match "(Get-DbatoolsConfigValue -FullName 'Formatting.BatchSeparator')"
        }

        It "Should include the defined BatchSeparator when specified" {
            $customResults = $table | Export-DbaScript -Passthru -BatchSeparator "MakeItSo"
            $customResults | Should -Match "MakeItSo"
        }
    }

    Context "When handling invalid input" {
        It "Should not accept non-SMO objects" {
            $invalidObject = [pscustomobject]@{ Invalid = $true }
            $invalidObject | Export-DbaScript -WarningVariable invalid -WarningAction Continue
            $invalid | Should -Match "not a SQL Management Object"
        }
    }

    Context "When using NoPrefix parameter" {
        BeforeAll {
            $testPath = "C:\temp"
            if (-not (Test-Path $testPath)) {
                $null = New-Item -ItemType Directory -Path $testPath
            }
            $outputFile = Join-Path $testPath "msdb.txt"
            $table = Get-DbaDbTable -SqlInstance $TestConfig.instance2 -Database msdb | Select-Object -First 1
        }

        It "Should not append content by default with NoPrefix" {
            $null = $table | Export-DbaScript -NoPrefix -FilePath $outputFile
            $linecount1 = (Get-Content $outputFile).Count
            $null = $table | Export-DbaScript -NoPrefix -FilePath $outputFile
            $linecount2 = (Get-Content $outputFile).Count
            $linecount1 | Should -Be $linecount2
        }

        It "Should append content when Append parameter is used with NoPrefix" {
            $null = $table | Export-DbaScript -NoPrefix -FilePath $outputFile
            $linecount1 = (Get-Content $outputFile).Count
            $null = $table | Export-DbaScript -NoPrefix -FilePath $outputFile -Append
            $linecount2 = (Get-Content $outputFile).Count
            $linecount2 | Should -BeGreaterThan $linecount1
        }
    }
}
