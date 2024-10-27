#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaOrphanedFile" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaOrphanedFile
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential',
            'Path',
            'FileType',
            'LocalOnly',
            'RemoteOnly',
            'EnableException',
            'Recurse'
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

Describe "Find-DbaOrphanedFile" -Tag "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_orphanedfile_$(Get-Random)"
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $db1 = New-DbaDatabase -SqlInstance $server -Name $dbname

        $dbname2 = "dbatoolsci_orphanedfile_$(Get-Random)"
        $db2 = New-DbaDatabase -SqlInstance $server -Name $dbname2

        $tmpdir = "c:\temp\orphan_$(Get-Random)"
        if (-not(Test-Path $tmpdir)) {
            $null = New-Item -Path $tmpdir -type Container
        }
        $tmpdirInner = Join-Path $tmpdir "inner"
        $null = New-Item -Path $tmpdirInner -type Container
        $tmpBackupPath = Join-Path $tmpdirInner "backup"
        $null = New-Item -Path $tmpBackupPath -type Container

        $tmpdir2 = "c:\temp\orphan_$(Get-Random)"
        if (-not(Test-Path $tmpdir2)) {
            $null = New-Item -Path $tmpdir2 -type Container
        }
        $tmpdirInner2 = Join-Path $tmpdir2 "inner"
        $null = New-Item -Path $tmpdirInner2 -type Container
        $tmpBackupPath2 = Join-Path $tmpdirInner2 "backup"
        $null = New-Item -Path $tmpBackupPath2 -type Container

        $result = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname
        if ($result.count -eq 0) {
            Set-TestInconclusive -message "Setup failed"
            throw "Setup failed"
        }

        $backupFile = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname -Path $tmpBackupPath -Type Full
        $backupFile2 = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname2 -Path $tmpBackupPath2 -Type Full
        Copy-Item -Path $backupFile.BackupPath -Destination "C:\" -Confirm:$false

        $tmpBackupPath3 = Join-Path (Get-SqlDefaultPaths $server data) "dbatoolsci_$(Get-Random)"
        $null = New-Item -Path $tmpBackupPath3 -type Container
    }

    AfterAll {
        Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname, $dbname2 | Remove-DbaDatabase -Confirm:$false
        Remove-Item $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpdir2 -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "C:\$($backupFile.BackupFile)" -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpBackupPath3 -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context "When checking orphaned file properties" {
        BeforeAll {
            $null = Detach-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname -Force
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2
        }

        It "Returns results with the correct properties" {
            $ExpectedStdProps = 'ComputerName,InstanceName,SqlInstance,Filename,RemoteFilename'.Split(',')
            ($results[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames | Sort-Object) | Should -Be ($ExpectedStdProps | Sort-Object)
            $ExpectedProps = 'ComputerName,InstanceName,SqlInstance,Filename,RemoteFilename,Server'.Split(',')
            ($results[0].PsObject.Properties.Name | Sort-Object) | Should -Be ($ExpectedProps | Sort-Object)
        }

        It "Finds two orphaned files" {
            $results.Filename.Count | Should -Be 2
        }

        It "Finds zero files after cleaning up" {
            $results.FileName | Remove-Item
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2
            $results.Filename.Count | Should -Be 0
        }
    }

    Context "When using recursive search" {
        BeforeAll {
            "a" | Out-File (Join-Path $tmpdir "out.mdf")
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Path $tmpdir
        }

        It "Finds one file in root path" {
            $results.Filename.Count | Should -Be 1
        }

        It "Finds file after moving to inner directory with -Recurse" {
            Move-Item "$tmpdir\out.mdf" -destination $tmpdirInner
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Path $tmpdir
            $results.Filename.Count | Should -Be 0
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Path $tmpdir -Recurse
            $results.Filename.Count | Should -Be 1
        }

        It "Finds all expected files with multiple paths" {
            Copy-Item -Path "$tmpdirInner\out.mdf" -Destination $tmpBackupPath3 -Confirm:$false

            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Path $tmpdir, $tmpdir2 -Recurse -FileType bak
            $results.Filename | Should -Contain $backupFile.BackupPath
            $results.Filename | Should -Contain $backupFile2.BackupPath
            $results.Filename | Should -Contain "$tmpdirInner\out.mdf"
            $results.Filename | Should -Contain "$tmpBackupPath3\out.mdf"
            $results.Count | Should -Be 4
        }

        It "Works with default recursive search" {
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Recurse
            $results.Filename | Should -Be "$tmpBackupPath3\out.mdf"
        }
    }

    Context "When using specific paths" {
        It "Finds backup file in C: drive" {
            $results = Find-DbaOrphanedFile -SqlInstance $TestConfig.instance2 -Path "C:" -FileType bak
            $results.Filename | Should -Contain "C:\$($backupFile.BackupFile)"
        }
    }
}
