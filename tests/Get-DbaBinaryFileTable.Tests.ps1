#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaBinaryFileTable" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaBinaryFileTable
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "Table",
            "Schema",
            "InputObject",
            "EnableException"
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Get-DbaBinaryFileTable" -Tag "IntegrationTests" {
    BeforeAll {
        $database = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database tempdb
        $null = $database.Query("CREATE TABLE [dbo].[BunchOFilez]([FileName123] [nvarchar](50) NULL, [TheFile123] [image] NULL)")

        # Import test files
        $null = Import-DbaBinaryFile -SqlInstance $TestConfig.instance2 -Database tempdb -Table BunchOFilez -FilePath "$($TestConfig.appveyorlabrepo)\azure\adalsql.msi"
        $null = Get-ChildItem "$($TestConfig.appveyorlabrepo)\certificates" | Import-DbaBinaryFile -SqlInstance $TestConfig.instance2 -Database tempdb -Table BunchOFilez
    }

    AfterAll {
        try {
            $null = $database.Query("DROP TABLE dbo.BunchOFilez")
        } catch {
            $null = 1
        }
    }

    Context "When getting binary file tables" {
        It "Returns at least one table" {
            $results = Get-DbaBinaryFileTable -SqlInstance $TestConfig.instance2 -Database tempdb
            $results.Name.Count | Should -BeGreaterOrEqual 1
        }

        It "Supports piping database tables" {
            $results = Get-DbaDbTable -SqlInstance $TestConfig.instance2 -Database tempdb | Get-DbaBinaryFileTable
            $results.Name.Count | Should -BeGreaterOrEqual 1
        }
    }
}
