#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaDacPackage" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaDacPackage
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "AllUserDatabases",
            "Path",
            "FilePath",
            "DacOption",
            "ExtendedParameters",
            "ExtendedProperties",
            "Type",
            "Table",
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

Describe "Export-DbaDacPackage" -Tag "IntegrationTests" {
    BeforeAll {
        $random = Get-Random
        $dbname = "dbatoolsci_exportdacpac_$random"
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $null = $server.Query("Create Database [$dbname]")
        $db = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database $dbname
        $null = $db.Query("CREATE TABLE dbo.example (id int, PRIMARY KEY (id));
            INSERT dbo.example
            SELECT top 100 object_id
            FROM sys.objects")

        $testFolder = "C:\Temp\dacpacs"

        $dbName2 = "dbatoolsci:2_$random"
        $dbName2Escaped = "dbatoolsci`$2_$random"

        $null = New-DbaDatabase -SqlInstance $TestConfig.instance1 -Name $dbName2
    }

    AfterAll {
        Remove-DbaDatabase -SqlInstance $TestConfig.instance1 -Database $dbname, $dbName2 -Confirm:$false
    }

    Context "When exporting database names in filenames" {
        It "Should include database name in the output filename" {
            $result = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname
            $result.Path | Should -BeLike "*$($dbName)*"
        }

        It "Should handle database names with invalid filesystem chars" {
            $result = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname, $dbName2
            $result.Path.Count | Should -BeExactly 2
            $result.Path[0] | Should -BeLike "*$($dbName)*"
            $result.Path[1] | Should -BeLike "*$($dbName2Escaped)*"
        }
    }

    Context "When extracting dacpac files" {
        BeforeAll {
            New-Item $testFolder -ItemType Directory -Force
            Push-Location $testFolder
        }

        AfterAll {
            Pop-Location
            Remove-Item $testFolder -Force -Recurse
        }

        It "Should export a dacpac successfully" {
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname
            $results.Path | Should -Not -BeNullOrEmpty
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }

        It "Should export to the specified directory" {
            $relativePath = '.\'
            $expectedPath = (Resolve-Path $relativePath).Path
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -Path $relativePath
            $results.Path | Split-Path | Should -BeExactly $expectedPath
            Test-Path $results.Path | Should -BeTrue
        }

        It "Should export dacpac with specified table list" {
            $relativePath = '.\extract.dacpac'
            $expectedPath = Join-Path (Get-Item .) 'extract.dacpac'
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -FilePath $relativePath -Table example
            $results.Path | Should -BeExactly $expectedPath
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }

        It "Should use EXE to extract dacpac with extended properties" {
            $exportProperties = "/p:ExtractAllTableData=True"
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -ExtendedProperties $exportProperties
            $results.Path | Should -Not -BeNullOrEmpty
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }
    }

    Context "When extracting bacpac files" {
        BeforeAll {
            New-Item $testFolder -ItemType Directory -Force
            Push-Location $testFolder
        }

        AfterAll {
            Pop-Location
            Remove-Item $testFolder -Force -Recurse
        }

        It "Should export a bacpac successfully" {
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -Type Bacpac
            $results.Path | Should -Not -BeNullOrEmpty
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }

        It "Should export bacpac with specified table list" {
            $relativePath = '.\extract.bacpac'
            $expectedPath = Join-Path (Get-Item .) 'extract.bacpac'
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -FilePath $relativePath -Table example -Type Bacpac
            $results.Path | Should -BeExactly $expectedPath
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }

        It "Should use EXE to extract bacpac with extended properties" {
            $exportProperties = "/p:TargetEngineVersion=Default"
            $results = Export-DbaDacPackage -SqlInstance $TestConfig.instance1 -Database $dbname -ExtendedProperties $exportProperties -Type Bacpac
            $results.Path | Should -Not -BeNullOrEmpty
            Test-Path $results.Path | Should -BeTrue
            if ($results.Path) {
                Remove-Item -Confirm:$false -Path $results.Path -ErrorAction SilentlyContinue
            }
        }
    }
}
