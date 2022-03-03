$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase', 'AllUserDatabases', 'StatementTimeout', 'MinimumFreeSpace', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Verifying Database is shrunk" {
        BeforeAll {
            $server = Connect-DbaInstance -SqlInstance $script:instance2
            $defaultPath = $server | Get-DbaDefaultPath
        }
        BeforeEach {
            # Create Database with small size and grow it
            $db = New-Object Microsoft.SqlServer.Management.SMO.Database($server, "dbatoolsci_safeshrinktest")

            $primaryFileGroup = New-Object Microsoft.SqlServer.Management.Smo.Filegroup($db, "PRIMARY")
            $db.FileGroups.Add($primaryFileGroup)
            $primaryFile = New-Object Microsoft.SqlServer.Management.Smo.DataFile($primaryFileGroup, $db.Name)
            $primaryFile.FileName = "$($defaultPath.Data)\$($db.Name).mdf"
            $primaryFile.Size = 8 * 1024
            $primaryFile.Growth = 8 * 1024
            $primaryFile.GrowthType = "KB"
            $primaryFileGroup.Files.Add($primaryFile)

            $logFile = New-Object Microsoft.SqlServer.Management.Smo.LogFile($db, "$($db.Name)_log")
            $logFile.FileName = "$($defaultPath.Log)\$($db.Name)_log.ldf"
            $logFile.Size = 8 * 1024
            $logFile.Growth = 8 * 1024
            $logFile.GrowthType = "KB"
            $db.LogFiles.Add($logFile)

            $db.Create()

            # grow the files
            $server.Query("
            ALTER DATABASE [$($db.name)] MODIFY FILE ( NAME = N'$($db.name)', SIZE = 16384KB )
            ALTER DATABASE [$($db.name)] MODIFY FILE ( NAME = N'$($db.name)_log', SIZE = 16384KB )")

            # Save the current file sizes
            $db.Refresh()
            $db.RecalculateSpaceUsage()
            $db.FileGroups[0].Files[0].Refresh()
            $db.LogFiles[0].Refresh()
            $oldLogSize = $db.LogFiles[0].Size
            $oldDataSize = $db.FileGroups[0].Files[0].Size
            $db.Checkpoint()
        }
        AfterEach {
            $db | Remove-DbaDatabase -Confirm:$false
        }

        It "Shrinks just the data file(s)" {
            $result = Invoke-DbaDbSafeShrink $server -Database $db.Name 
            $result.Database | Should -Be $db.Name
            $result.File | Should -Be $db.Name
            $result.Success | Should -Be $true
            $db.Refresh()
            $db.RecalculateSpaceUsage()
            $db.FileGroups[0].Files[0].Refresh()
            $db.LogFiles[0].Refresh()
            $db.FileGroups[0].Files[0].Size | Should BeLessThan $oldDataSize
            $db.LogFiles[0].Size | Should Be $oldLogSize
        }

        It "Does not shrink the database when the MinimumFreeSpace does not exceed the current free space" {
            $result = Invoke-DbaDbSafeShrink $server -Database $db.Name -MinimumFreeSpace 1GB 
            $result.Database | Should -Be $db.Name, $db.Name
            $result.File | Should -Be "$($db.Name)_log", $db.Name
            $result.Success | Should -Be $true, $true
            $db.Refresh()
            $db.RecalculateSpaceUsage()
            $db.FileGroups[0].Files[0].Refresh()
            $db.FileGroups[0].Files[0].Size | Should Be $oldDataSize
        }
    }
}