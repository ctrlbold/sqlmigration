#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaDbTableData" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaDbTableData
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'InputObject',
            'Path',
            'FilePath',
            'Encoding',
            'BatchSeparator',
            'NoPrefix',
            'Passthru',
            'NoClobber',
            'Append',
            'EnableException',
            'Confirm',
            'WhatIf'
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

Describe "Export-DbaDbTableData" -Tags "IntegrationTests" {
    BeforeAll {
        $db = Get-DbaDatabase -SqlInstance $TestConfig.Instance1 -Database tempdb
        $null = $db.Query("CREATE TABLE dbo.dbatoolsci_example (id int);
            INSERT dbo.dbatoolsci_example
            SELECT top 10 1
            FROM sys.objects")
        $null = $db.Query("Select * into dbatoolsci_temp from sys.databases")
    }

    AfterAll {
        try {
            $null = $db.Query("DROP TABLE dbo.dbatoolsci_example")
            $null = $db.Query("DROP TABLE dbo.dbatoolsci_temp")
        } catch {
            $null = 1
        }
    }

    Context "When exporting a single table" {
        BeforeAll {
            $escaped = [regex]::escape('INSERT [dbo].[dbatoolsci_example] ([id]) VALUES (1)')
            $secondEscaped = [regex]::escape('INSERT [dbo].[dbatoolsci_temp] ([name], [database_id],')
            $results = Get-DbaDbTable -SqlInstance $TestConfig.Instance1 -Database tempdb -Table dbatoolsci_example |
                Export-DbaDbTableData -Passthru
        }

        It "Should export table data with correct INSERT statement" {
            "$results" | Should -Match $escaped
        }
    }

    Context "When exporting multiple tables" {
        BeforeAll {
            $escaped = [regex]::escape('INSERT [dbo].[dbatoolsci_example] ([id]) VALUES (1)')
            $secondEscaped = [regex]::escape('INSERT [dbo].[dbatoolsci_temp] ([name], [database_id],')
            $results = Get-DbaDbTable -SqlInstance $TestConfig.Instance1 -Database tempdb -Table dbatoolsci_example, dbatoolsci_temp |
                Export-DbaDbTableData -Passthru
        }

        It "Should export first table data correctly" {
            "$results" | Should -Match $escaped
        }

        It "Should export second table data correctly" {
            "$results" | Should -Match $secondEscaped
        }
    }
}
