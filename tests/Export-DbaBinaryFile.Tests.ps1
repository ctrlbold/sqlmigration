#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaBinaryFile" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaBinaryFile
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "Table",
            "Schema",
            "FileNameColumn",
            "BinaryColumn",
            "Path",
            "FilePath",
            "Query",
            "InputObject",
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

Describe "Export-DbaBinaryFile" -Tag "IntegrationTests" {
    BeforeAll {
        $testDb = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database tempdb
        $testTable = "BunchOFilezz"
        $exportPath = "C:\temp\exports"

        $null = $testDb.Query("CREATE TABLE [dbo].[$testTable]([FileName123] [nvarchar](50) NULL, [TheFile123] [image] NULL)")
        $null = Import-DbaBinaryFile -SqlInstance $TestConfig.instance2 -Database tempdb -Table $testTable -FilePath "$($TestConfig.appveyorlabrepo)\azure\adalsql.msi"
        $null = Get-ChildItem "$($TestConfig.appveyorlabrepo)\certificates" | Import-DbaBinaryFile -SqlInstance $TestConfig.instance2 -Database tempdb -Table $testTable
    }

    AfterAll {
        $null = $testDb.Query("DROP TABLE dbo.$testTable")
        Get-ChildItem -Path $exportPath -File -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue -Force
    }

    Context "When exporting binary files directly" {
        BeforeAll {
            $results = Export-DbaBinaryFile -SqlInstance $TestConfig.instance2 -Database tempdb -Path $exportPath
        }

        It "Should export all files" {
            $results.Name.Count | Should -Be 3
        }

        It "Should export the expected files" {
            $expectedFiles = @('adalsql.msi', 'localhost.crt', 'localhost.pfx')
            $results.Name | Should -Be $expectedFiles
        }
    }

    Context "When exporting binary files through pipeline" {
        BeforeAll {
            $results = Get-DbaBinaryFileTable -SqlInstance $TestConfig.instance2 -Database tempdb |
                Export-DbaBinaryFile -Path $exportPath
        }

        It "Should export all files" {
            $results.Name.Count | Should -Be 3
        }

        It "Should export the expected files" {
            $expectedFiles = @('adalsql.msi', 'localhost.crt', 'localhost.pfx')
            $results.Name | Should -Be $expectedFiles
        }
    }
}
