#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0" }
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaRegServer" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaRegServer
            $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
            $expected += @(
                "SqlInstance",
                "SqlCredential",
                "InputObject",
                "Path",
                "FilePath",
                "CredentialPersistenceType",
                "Group",
                "ExcludeGroup",
                "Overwrite",
                "EnableException"
            )
        }

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaRegServer" -Tag "IntegrationTests" {
    BeforeAll {
        $random = Get-Random
        $newDirectory = "C:\temp-$random"

        $splatServer1 = @{
            SqlInstance = $TestConfig.instance2
            ServerName = "dbatoolsci-server1"
            Name = "dbatoolsci-server12"
            Description = "dbatoolsci-server123"
        }

        $splatServer2 = @{
            SqlInstance = $TestConfig.instance2
            ServerName = "dbatoolsci-server2"
            Name = "dbatoolsci-server21"
            Description = "dbatoolsci-server321"
        }

        $splatServer3 = @{
            SqlInstance = $TestConfig.instance2
            ServerName = "dbatoolsci-server3"
            Name = "dbatoolsci-server3"
            Description = "dbatoolsci-server3desc"
        }

        $group1 = Add-DbaRegServerGroup -SqlInstance $TestConfig.instance2 -Name "dbatoolsci-group1"
        $group2 = Add-DbaRegServerGroup -SqlInstance $TestConfig.instance2 -Name "dbatoolsci-group2"

        $server1 = Add-DbaRegServer @splatServer1
        $server2 = Add-DbaRegServer @splatServer2
        $server3 = Add-DbaRegServer @splatServer3
    }

    AfterAll {
        Get-DbaRegServer -SqlInstance $TestConfig.instance2 | Where-Object Name -Match dbatoolsci | Remove-DbaRegServer -Confirm:$false
        Get-DbaRegServerGroup -SqlInstance $TestConfig.instance2 | Where-Object Name -Match dbatoolsci | Remove-DbaRegServerGroup -Confirm:$false

        if (Test-Path $newDirectory) {
            Remove-Item $newDirectory -Recurse -Force
        }
    }

    Context "When exporting registered servers" {
        It "Creates an xml file" {
            $results = $server1 | Export-DbaRegServer
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.Extension | Should -Be '.xml'
        }

        It "Creates a specific xml file when using Path" {
            $results = $group2 | Export-DbaRegServer -Path C:\temp
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.FullName | Should -Match 'C\:\\temp'
            Get-Content -Path $results -Raw | Should -Match 'dbatoolsci-group2'
        }

        It "Creates an importable xml file" {
            $exportPath = $server3 | Export-DbaRegServer -Path C:\temp
            Get-DbaRegServer -SqlInstance $TestConfig.instance2 | Where-Object Name -Match dbatoolsci | Remove-DbaRegServer -Confirm:$false
            Get-DbaRegServerGroup -SqlInstance $TestConfig.instance2 | Where-Object Name -Match dbatoolsci | Remove-DbaRegServerGroup -Confirm:$false

            $importedServer = Import-DbaRegServer -SqlInstance $TestConfig.instance2 -Path $exportPath
            $importedServer.ServerName | Should -Be $splatServer3.ServerName
            $importedServer.Description | Should -Be $splatServer3.Description
        }

        It "Creates an xml file using FilePath" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.xml"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.FullName | Should -Be $outputFile
        }

        It "Creates a regsrvr file using the FilePath alias OutFile" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.regsrvr"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -OutFile $outputFile
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.FullName | Should -Be $outputFile
        }

        It "Fails to create an invalid file using FilePath" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.txt"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile
            $results.Length | Should -Be 0
        }

        It "Creates an xml file in a new directory using FileName" {
            $outputFile = "$newDirectory\dbatoolsci-regsrvr-export-$random.xml"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FileName $outputFile
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.FullName | Should -Be $outputFile
        }

        It "Respects the Overwrite parameter" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.xml"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile
            $results | Should -BeOfType [System.IO.FileInfo]
            $results.FullName | Should -Be $outputFile

            $invalidResults = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile
            $invalidResults.Length | Should -Be 0

            $resultsOverwrite = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile -Overwrite
            $resultsOverwrite | Should -BeOfType [System.IO.FileInfo]
            $resultsOverwrite.FullName | Should -Be $outputFile
        }

        It "Filters by Group parameter" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.xml"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile -Group "dbatoolsci-group1"
            $results | Should -BeOfType [System.IO.FileInfo]
            $fileContent = Get-Content -Path $results -Raw
            $fileContent | Should -Match "dbatoolsci-group1"
            $fileContent | Should -Not -Match "dbatoolsci-group2"
        }

        It "Handles multiple groups" {
            $outputFile = "C:\temp\dbatoolsci-regsrvr-export-$random.xml"
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -FilePath $outputFile -Group @("dbatoolsci-group1", "dbatoolsci-group2")
            $results.Length | Should -Be 2

            $content1 = Get-Content -Path $results[0] -Raw
            $content1 | Should -Match "dbatoolsci-group1"
            $content1 | Should -Not -Match "dbatoolsci-group2"

            $content2 = Get-Content -Path $results[1] -Raw
            $content2 | Should -Not -Match "dbatoolsci-group1"
            $content2 | Should -Match "dbatoolsci-group2"
        }

        It "Respects ExcludeGroup parameter" {
            $results = Export-DbaRegServer -SqlInstance $TestConfig.instance2 -ExcludeGroup "dbatoolsci-group2"
            $results | Should -BeOfType [System.IO.FileInfo]
            $fileContent = Get-Content -Path $results -Raw
            $fileContent | Should -Match "dbatoolsci-group1"
            $fileContent | Should -Not -Match "dbatoolsci-group2"
        }
    }
}
