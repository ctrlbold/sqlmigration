#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Find-DbaDbGrowthEvent" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaDbGrowthEvent
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "EventType",
            "FileType",
            "UseLocalTime",
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

Describe "Find-DbaDbGrowthEvent" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $random = Get-Random
        $databaseName = "dbatoolsci1_$random"
        $database = New-DbaDatabase -SqlInstance $server -Name $databaseName

        $sqlGrowthAndShrink = @"
CREATE TABLE Tab1 (ID INTEGER);

INSERT INTO Tab1 (ID)
SELECT
    1
FROM
    sys.all_objects a
CROSS JOIN
    sys.all_objects b;

TRUNCATE TABLE Tab1;
DBCC SHRINKFILE ($databaseName, TRUNCATEONLY);
DBCC SHRINKFILE ($($databaseName)_Log, TRUNCATEONLY);
"@

        $null = $database.Query($sqlGrowthAndShrink)
    }

    AfterAll {
        $database | Remove-DbaDatabase -Confirm:$false
    }

    Context "When finding growth events" {
        BeforeAll {
            $results = Find-DbaDbGrowthEvent -SqlInstance $server -Database $databaseName -EventType Growth
        }

        It "Returns growth events from default trace" {
            ($results | Where-Object { $PSItem.EventClass -in (92, 93) }).Count | Should -BeGreaterThan 0
        }

        It "Returns results for correct database" {
            $results.DatabaseName | Select-Object -Unique | Should -Be $databaseName
            $results.DatabaseId | Select-Object -Unique | Should -Be $database.ID
        }
    }

    <# Leaving this commented out since the background process for auto shrink cannot be triggered

    Context "When finding shrink events" {
        BeforeAll {
            $results = Find-DbaDbGrowthEvent -SqlInstance $server -Database $databaseName -EventType Shrink
        }

        It "Returns shrink events from default trace" {
            $results.EventClass | Should -Contain 94 # data file shrink
            $results.EventClass | Should -Contain 95 # log file shrink
        }

        It "Returns results for correct database" {
            $results.DatabaseName | Select-Object -Unique | Should -Be $databaseName
            $results.DatabaseId | Select-Object -Unique | Should -Be $database.ID
        }
    }
    #>
}
