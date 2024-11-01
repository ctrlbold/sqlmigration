#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Backup-DbaDatabase Unit Tests" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Backup-DbaDatabase
        $expected = @(
            'SqlInstance', 'SqlCredential', 'Database', 'ExcludeDatabase',
            'Path', 'FilePath', 'ReplaceInName', 'NoAppendDbNameInPath',
            'CopyOnly', 'Type', 'InputObject', 'CreateFolder', 'FileCount',
            'CompressBackup', 'Checksum', 'Verify', 'MaxTransferSize',
            'BlockSize', 'BufferCount', 'AzureBaseUrl', 'AzureCredential',
            'NoRecovery', 'BuildPath', 'WithFormat', 'Initialize',
            'SkipTapeHeader', 'TimeStampFormat', 'IgnoreFileChecks',
            'OutputScriptOnly', 'EnableException', 'EncryptionAlgorithm',
            'EncryptionCertificate', 'IncrementPrefix', 'Description'
        )
        $expected += $TestConfig.CommonParameters
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly $($expected.Count) parameters" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Backup-DbaDatabase Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $DestBackupDir = 'C:\Temp\backups'
        $random = Get-Random
        $DestDbRandom = "dbatools_ci_backupdbadatabase$random"

        if (-Not(Test-Path $DestBackupDir)) {
            New-Item -Type Container -Path $DestBackupDir
        }

        Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database "dbatoolsci_singlerestore" | Remove-DbaDatabase -Confirm:$false
        Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $DestDbRandom | Remove-DbaDatabase -Confirm:$false
    }

    AfterAll {
        Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database "dbatoolsci_singlerestore" | Remove-DbaDatabase -Confirm:$false
        Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $DestDbRandom | Remove-DbaDatabase -Confirm:$false
        if (Test-Path $DestBackupDir) {
            Remove-Item "$DestBackupDir\*" -Force -Recurse
        }
    }

    Context "When backing up all databases to local drive using Path parameter" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory C:\temp\backups
        }

        It "Returns master database in results" {
            $results.DatabaseName | Should -Contain 'master'
        }

        It "Reports successful backup completion" {
            $results.ForEach{ $PSItem.BackupComplete | Should -BeTrue }
        }
    }

    Context "When backing up database that matches exclude filter" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database master -Exclude master
        }

        It "Should not return object" {
            $results | Should -Be $null
        }
    }

    Context "When attempting to back up non-existent database" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database AliceDoesntDBHereAnyMore -WarningVariable warnvar 3> $null
        }

        It "Should not return object" {
            $results | Should -Be $null
        }
        It "Should return a warning" {
            $warnvar | Should -BeLike "*No databases match the request for backups*"
        }
    }

    Context "When backing up single database master" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database master
        }

        It "Database backup object count Should Be 1" {
            $results.DatabaseName.Count | Should -Be 1
            $results.BackupComplete | Should -Be $true
        }
        It "Database ID should be returned" {
            $results.DatabaseID | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master).ID
        }
    }

    Context "When backing up multiple specified databases" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database master, msdb
        }

        It "Database backup object count Should Be 2" {
            $results.DatabaseName.Count | Should -Be 2
            $results.BackupComplete | Should -Be @($true, $true)
        }
    }

    Context "When specifying custom backup path and filename" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database master -BackupFileName 'PesterTest.bak'
        }

        It "Should report it has backed up to the path with the correct name" {
            $results.Fullname | Should -BeLike "$DestBackupDir*PesterTest.bak"
        }
        It "Should have backed up to the path with the correct name" {
            Test-Path "$DestBackupDir\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When piping database objects with Database parameter" {
        BeforeAll {
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 | Backup-DbaDatabase -Database master -BackupFileName PesterTest.bak -BackupDirectory $DestBackupDir
        }

        It "Should report it has backed up to the path with the correct name" {
            $results.Fullname | Should -BeLike "$DestBackupDir*PesterTest.bak"
        }
        It "Should have backed up to the path with the correct name" {
            Test-Path "$DestBackupDir\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When piping database objects with ExcludeDatabase parameter" {
        BeforeAll {
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 | Backup-DbaDatabase -ExcludeDatabase master, tempdb, msdb, model
        }

        It "Should report it has backed up to the path with the correct name" {
            $results.DatabaseName | Should -Not -Contain master
            $results.DatabaseName | Should -Not -Contain tempdb
            $results.DatabaseName | Should -Not -Contain msdb
            $results.DatabaseName | Should -Not -Contain model
        }
    }

    Context "When backup path does not exist" {
        BeforeAll {
            $MissingPathTrailing = "$DestBackupDir\Missing1\Awol2\"
            $MissingPath = "$DestBackupDir\Missing1\Awol2"
            $null = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $MissingPath -WarningVariable warnvar *>$null
        }

        It "Should warn and fail if path doesn't exist and BuildPath not set" {
            $warnvar | Should -BeLike "*$MissingPath*"
        }

        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $MissingPathTrailing -BuildPath
        }

        It "Should have backed up to $MissingPath" {
            $results.BackupFolder | Should -Be "$MissingPath"
            $results.Path | Should -Not -BeLike '*\\*'
        }
    }

    Context "When using CreateFolder switch with single database" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $DestBackupDir -CreateFolder
        }

        It "Should have appended master to the backup path" {
            $results.BackupFolder | Should -Be "$DestBackupDir\master"
        }
    }

    Context "When using CreateFolder switch with striped backups" {
        BeforeAll {
            $backupPaths = "$DestBackupDir\stripewithdb1", "$DestBackupDir\stripewithdb2"
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $backupPaths -CreateFolder
        }

        It "Should have appended master to all backup paths" {
            foreach ($path in $results.BackupFolder) {
                ($results.BackupFolder | Sort-Object) | Should -Be ($backupPaths | Sort-Object | ForEach-Object { [IO.Path]::Combine($_, 'master') })
            }
        }
    }

    Context "When providing fully qualified path that overrides backup folder" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory c:\temp -BackupFileName "$DestBackupDir\PesterTest2.bak"
        }

        It "Should report backed up to $DestBackupDir" {
            $results.FullName | Should -BeLike "$DestBackupDir\PesterTest2.bak"
            $results.BackupFolder | Should Not Be 'c:\temp'
        }
        It "Should have backuped up to $DestBackupDir\PesterTest2.bak" {
            Test-Path "$DestBackupDir\PesterTest2.bak" | Should -Be $true
        }
    }

    Context "When specifying multiple backup folders for striping" {
        BeforeAll {
            $backupPaths = "$DestBackupDir\stripe1", "$DestBackupDir\stripe2", "$DestBackupDir\stripe3"
            $null = New-Item -Path $backupPaths -ItemType Directory
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $backupPaths
        }

        It "Should have created 3 backups" {
            $results.BackupFilesCount | Should -Be 3
        }
        It "Should have written to all 3 folders" {
            $backupPaths | ForEach-Object {
                $_ | Should -BeIn ($results.BackupFolder)
            }
        }
        It "Should have written files with extensions" {
            foreach ($path in $results.BackupFile) {
                [IO.Path]::GetExtension($path) | Should -Be '.bak'
            }
        }

        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $backupPaths -FileCount 2
        }

        It "Should have created 3 backups, even when FileCount is different" {
            $results.BackupFilesCount | Should -Be 3
        }
    }

    Context "When using FileCount parameter for striping" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $DestBackupDir -FileCount 3
        }

        It "Should have created 3 backups" {
            $results.BackupFilesCount | Should -Be 3
        }
    }

    Context "When generating backup filenames" {
        It "Should have 1 period in file extension" {
            foreach ($path in $results.BackupFile) {
                [IO.Path]::GetExtension($path) | Should -Not -BeLike '*..*'
            }
        }
    }

    Context "When using IncrementPrefix parameter" {
        BeforeAll {
            $fileCount = 3
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $DestBackupDir -FileCount $fileCount -IncrementPrefix
        }

        It "Should have created 3 backups" {
            $results.BackupFilesCount | Should -Be 3
        }
        It "Should prefix them correctly" {
            for ($i = 1; $i -le $fileCount; $i++) {
                $results.BackupFile[$i - 1] | Should -BeLike "$i-*"
            }
        }
    }

    Context "When no backup path is specified" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupFileName 'PesterTest.bak'
            $DefaultPath = (Get-DbaDefaultPath -SqlInstance $TestConfig.instance1).Backup
        }

        It "Should report it has backed up to the path with the corrrect name" {
            $results.Fullname | Should -BeLike "$DefaultPath*PesterTest.bak"
        }
        It "Should have backed up to the path with the corrrect name" {
            Test-Path "$DefaultPath\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When performing backup verification" {
        It "Should perform a full backup and verify it" {
            $b = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -Type full -Verify
            $b.BackupComplete | Should -Be $True
            $b.Verified | Should -Be $True
            $b.count | Should -Be 1
        }
        It -Skip "Should perform a diff backup and verify it" {
            $b = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database backuptest -Type diff -Verify
            $b.BackupComplete | Should -Be $True
            $b.Verified | Should -Be $True
        }
        It -Skip "Should perform a log backup and verify it" {
            $b = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database backuptest -Type log -Verify
            $b.BackupComplete | Should -Be $True
            $b.Verified | Should -Be $True
        }
    }

    Context "When piping backup to restore operation" {
        BeforeAll {
            $null = Restore-DbaDatabase -SqlInstance $TestConfig.instance1 -Path "$($TestConfig.appveyorlabrepo)\singlerestore\singlerestore.bak" -DatabaseName "dbatoolsci_singlerestore"
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -BackupDirectory $DestBackupDir -Database "dbatoolsci_singlerestore" | Restore-DbaDatabase -SqlInstance $TestConfig.instance2 -DatabaseName $DestDbRandom -TrustDbBackupHistory -ReplaceDbNameInFile
        }

        It "Should return successful restore" {
            $results.RestoreComplete | Should -Be $true
        }
    }

    Context "When taking database input from pipeline" {
        BeforeAll {
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master | Backup-DbaDatabase -confirm:$false -WarningVariable warnvar 3> $null
        }

        It "Should not warn" {
            $warnvar | Should -BeNullOrEmpty
        }
        It "Should Complete Successfully" {
            $results.BackupComplete | Should -Be $true
        }
    }

    Context "When using NUL as backup destination" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupFileName NUL
        }

        It "Should return succesful backup" {
            $results.BackupComplete | Should -Be $true
        }
        It "Should have backed up to NUL:" {
            $results.FullName[0] | Should -Be 'NUL:'
        }
    }

    Context "When using OutputScriptOnly parameter" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupFileName c:\notexists\file.bak -OutputScriptOnly
        }

        It "Should return a string" {
            $results.GetType().ToString() | Should -Be 'System.String'
        }
        It "Should return BACKUP DATABASE [master] TO  DISK = N'c:\notexists\file.bak' WITH NOFORMAT, NOINIT, NOSKIP, REWIND, NOUNLOAD,  STATS = 1" {
            $results | Should -Be "BACKUP DATABASE [master] TO  DISK = N'c:\notexists\file.bak' WITH NOFORMAT, NOINIT, NOSKIP, REWIND, NOUNLOAD,  STATS = 1"
        }
    }

    Context "When backing up encrypted database with compression" {
        BeforeAll {
            $sqlencrypt =
            @"
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<UseStrongPasswordHere>';
go
CREATE CERTIFICATE MyServerCert WITH SUBJECT = 'My DEK Certificate';
go
CREATE DATABASE encrypted
go
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $sqlencrypt -Database Master
            $createdb =
            @"
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_128
ENCRYPTION BY SERVER CERTIFICATE MyServerCert;
GO
ALTER DATABASE encrypted
SET ENCRYPTION ON;
GO
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $createdb -Database encrypted
        }

        It "Should compress an encrypted db" {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -Database encrypted -Compress
            Invoke-Command2 -ComputerName $TestConfig.instance2 -ScriptBlock { Remove-Item -Path $args[0] } -ArgumentList $results.FullName
            $results.script | Should -BeLike '*D, COMPRESSION,*'
        }

        AfterAll {
            Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database encrypted -confirm:$false
            $sqldrop =
            @"
drop certificate MyServerCert
go
drop master key
go
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $sqldrop -Database Master
        }
    }

    Context "When using custom TimeStamp format" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master -BackupDirectory $DestBackupDir -TimeStampFormat bobob
        }

        It "Should apply the corect custom Timestamp" {
            ($results | Where-Object { $_.BackupPath -like '*bobob*' }).count | Should -Be $results.count
        }
    }

    Context "When using backup filename templating" {
        BeforeAll {
            $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master, msdb -BackupDirectory $DestBackupDir\dbname\instancename\backuptype\  -BackupFileName dbname-backuptype.bak -ReplaceInName -BuildPath
        }

        It "Should have replaced the markers" {
            $results[0].BackupPath | Should -BeLike "$DestBackupDir\master\$(($TestConfig.instance1).split('\')[1])\Full\master-Full.bak"
            $results[1].BackupPath | Should -BeLike "$DestBackupDir\msdb\$(($TestConfig.instance1).split('\')[1])\Full\msdb-Full.bak"
        }
    }

    Context "When piping database objects with filename templating" {
        BeforeAll {
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master,msdb | Backup-DbaDatabase -BackupDirectory $DestBackupDir\db2\dbname\instancename\backuptype\  -BackupFileName dbname-backuptype.bak -ReplaceInName -BuildPath
        }

        It "Should have replaced the markers" {
            $results[0].BackupPath | Should -BeLike "$DestBackupDir\db2\master\$(($TestConfig.instance1).split('\')[1])\Full\master-Full.bak"
            $results[1].BackupPath | Should -BeLike "$DestBackupDir\db2\msdb\$(($TestConfig.instance1).split('\')[1])\Full\msdb-Full.bak"
        }
    }

    Context "When using backup encryption with certificate" {
        BeforeAll {
            $securePass = ConvertTo-SecureString "estBackupDir\master\script:instance1).split('\')[1])\Full\master-Full.bak" -AsPlainText -Force
            New-DbaDbMasterKey -SqlInstance $TestConfig.instance2 -Database Master -SecurePassword $securePass -confirm:$false -ErrorAction SilentlyContinue
            $cert = New-DbaDbCertificate -SqlInstance $TestConfig.instance2 -Database master -Name BackupCertt -Subject BackupCertt
            $encBackupResults = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -Database master -EncryptionAlgorithm AES128 -EncryptionCertificate BackupCertt -BackupFileName 'encryptiontest.bak' -Description "Encrypted backup"
            Invoke-Command2 -ComputerName $TestConfig.instance2 -ScriptBlock { Remove-Item -Path $args[0] } -ArgumentList $encBackupResults.FullName
        }

        It "Should encrypt the backup" {
            $encBackupResults.EncryptorType | Should Be "CERTIFICATE"
            $encBackupResults.KeyAlgorithm | Should Be "aes_128"
        }

        AfterAll {
            Remove-DbaDbCertificate -SqlInstance $TestConfig.instance2 -Database master -Certificate BackupCertt -Confirm:$false
            Remove-DbaDbMasterKey -SqlInstance $TestConfig.instance2 -Database Master -confirm:$false
        }
    }

    if ($env:azurepasswd) {
        Context "When backing up to Azure storage" {
            BeforeAll {
                Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database "dbatoolsci_azure" | Remove-DbaDatabase -Confirm:$false
                $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
                if (Get-DbaCredential -SqlInstance $TestConfig.instance2 -Name "[$TestConfig.azureblob]" ) {
                    $sql = "DROP CREDENTIAL [$TestConfig.azureblob]"
                    $server.Query($sql)
                }
                $sql = "CREATE CREDENTIAL [$TestConfig.azureblob] WITH IDENTITY = N'SHARED ACCESS SIGNATURE', SECRET = N'$env:azurepasswd'"
                $server.Query($sql)
                $server.Query("CREATE DATABASE dbatoolsci_azure")
                if (Get-DbaCredential -SqlInstance $TestConfig.instance2 -name dbatools_ci) {
                    $sql = "DROP CREDENTIAL dbatools_ci"
                    $server.Query($sql)
                }
                $sql = "CREATE CREDENTIAL [dbatools_ci] WITH IDENTITY = N'$TestConfig.azureblobaccount', SECRET = N'$env:azurelegacypasswd'"
                $server.Query($sql)
            }
            AfterAll {
                Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database "dbatoolsci_azure" | Remove-DbaDatabase -Confirm:$false
                $server.Query("DROP CREDENTIAL [$TestConfig.azureblob]")
            }
            It "backs up to Azure properly using SHARED ACCESS SIGNATURE" {
                $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -AzureBaseUrl $TestConfig.azureblob -Database dbatoolsci_azure -BackupFileName dbatoolsci_azure.bak -WithFormat
                $results.Database | Should -Be 'dbatoolsci_azure'
                $results.DeviceType | Should -Be 'URL'
                $results.BackupFile | Should -Be 'dbatoolsci_azure.bak'
            }
            It "backs up to Azure properly using legacy credential" {
                $results = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -AzureBaseUrl $TestConfig.azureblob -Database dbatoolsci_azure -BackupFileName dbatoolsci_azure2.bak -WithFormat -AzureCredential dbatools_ci
                $results.Database | Should -Be 'dbatoolsci_azure'
                $results.DeviceType | Should -Be 'URL'
                $results.BackupFile | Should -Be 'dbatoolsci_azure2.bak'
            }
        }
    }
}
