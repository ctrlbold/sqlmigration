#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)
$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
$global:TestConfig = Get-TestConfig

Describe "Backup-DbaDatabase" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Backup-DbaDatabase
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "Path",
            "FilePath",
            "IncrementPrefix",
            "ReplaceInName",
            "NoAppendDbNameInPath",
            "CopyOnly",
            "Type",
            "InputObject",
            "CreateFolder",
            "FileCount",
            "CompressBackup",
            "Checksum",
            "Verify",
            "MaxTransferSize",
            "BlockSize",
            "BufferCount",
            "AzureBaseUrl",
            "AzureCredential",
            "NoRecovery",
            "BuildPath",
            "WithFormat",
            "Initialize",
            "SkipTapeHeader",
            "TimeStampFormat",
            "IgnoreFileChecks",
            "OutputScriptOnly",
            "EncryptionAlgorithm",
            "EncryptionCertificate",
            "Description",
            "EnableException",
            "Verbose",
            "Debug",
            "ErrorAction",
            "WarningAction",
            "InformationAction",
            "ProgressAction",
            "ErrorVariable",
            "WarningVariable",
            "InformationVariable",
            "OutVariable",
            "OutBuffer",
            "PipelineVariable",
            "WhatIf",
            "Confirm"
        )
    }
    Context "When validating parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $PSItem -notin "WhatIf", "Confirm" }
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($expected | Where-Object { $PSItem }) -DifferenceObject $params).Count) | Should Be 0
        }
    }
}

Describe "Backup-DbaDatabase" -Tag "IntegrationTests" {
    BeforeAll {
        $DestBackupDir = "C:\Temp\backups"
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

    Context "When restoring a database on the local drive using Path" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = "C:\temp\backups"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should return a database name, specifically master" {
            ($results.DatabaseName -contains "master") | Should -Be $true
        }
        It "Should return successful restore" {
            $results.ForEach{ $PSItem.BackupComplete | Should -Be $true }
        }
    }

    Context "When database and exclude match" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "master"
                Exclude = "master"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should not return object" {
            $results | Should -Be $null
        }
    }

    Context "When no database found to backup" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "AliceDoesntDBHereAnyMore"
                WarningVariable = warnvar
            }
            $results = Backup-DbaDatabase @splatBackup 3> $null
        }
        It "Should not return object" {
            $results | Should -Be $null
        }
        It "Should return a warning" {
            $warnvar | Should -BeLike "*No databases match the request for backups*"
        }
    }

    Context "When backing up a single database" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "master"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Database backup object count Should Be 1" {
            $results.DatabaseName.Count | Should -Be 1
            $results.BackupComplete | Should -Be $true
        }
        It "Database ID should be returned" {
            $results.DatabaseID | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master).ID
        }
    }

    Context "When backing up multiple databases" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "master", "msdb"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Database backup object count Should Be 2" {
            $results.DatabaseName.Count | Should -Be 2
            $results.BackupComplete | Should -Be @($true, $true)
        }
    }

    Context "When specifying path and filename" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "master"
                BackupFileName = "PesterTest.bak"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should report it has backed up to the path with the correct name" {
            $results.Fullname | Should -BeLike "$DestBackupDir*PesterTest.bak"
        }
        It "Should have backed up to the path with the correct name" {
            Test-Path "$DestBackupDir\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When using pipes for database parameter" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupFileName = "PesterTest.bak"
                BackupDirectory = $DestBackupDir
            }
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 | Backup-DbaDatabase @splatBackup
        }
        It "Should report it has backed up to the path with the correct name" {
            $results.Fullname | Should -BeLike "$DestBackupDir*PesterTest.bak"
        }
        It "Should have backed up to the path with the correct name" {
            Test-Path "$DestBackupDir\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When excluding databases using pipes" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                ExcludeDatabase = "master", "tempdb", "msdb", "model"
            }
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 | Backup-DbaDatabase @splatBackup
        }
        It "Should report it has backed up to the path with the correct name" {
            $results.DatabaseName | Should -Not -Contain "master"
            $results.DatabaseName | Should -Not -Contain "tempdb"
            $results.DatabaseName | Should -Not -Contain "msdb"
            $results.DatabaseName | Should -Not -Contain "model"
        }
    }

    Context "When handling non-existent backup paths" {
        BeforeEach {
            $MissingPathTrailing = "$DestBackupDir\Missing1\Awol2\"
            $MissingPath = "$DestBackupDir\Missing1\Awol2"
            $null = Backup-DbaDatabase -SqlInstance $TestConfig.instance1 -Database "master" -BackupDirectory $MissingPath -WarningVariable warnvar *>$null
        }
        It "Should warn and fail if path doesn't exist and BuildPath not set" {
            $warnvar | Should -BeLike "*$MissingPath*"
        }
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $MissingPathTrailing
                BuildPath = $true
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have backed up to $MissingPath" {
            $results.BackupFolder | Should -Be "$MissingPath"
            $results.Path | Should -Not -BeLike "*\\*"
        }
    }

    Context "When using CreateFolder switch" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $DestBackupDir
                CreateFolder = $true
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have appended master to the backup path" {
            $results.BackupFolder | Should -Be "$DestBackupDir\master"
        }
    }

    Context "When using CreateFolder switch with striping" {
        BeforeEach {
            $backupPaths = "$DestBackupDir\stripewithdb1", "$DestBackupDir\stripewithdb2"
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $backupPaths
                CreateFolder = $true
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have appended master to all backup paths" {
            foreach ($path in $results.BackupFolder) {
                ($results.BackupFolder | Sort-Object) | Should -Be ($backupPaths | Sort-Object | ForEach-Object { [IO.Path]::Combine($PSItem, "master") })
            }
        }
    }

    Context "When using a fully qualified path" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = "c:\temp"
                BackupFileName = "$DestBackupDir\PesterTest2.bak"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should report backed up to $DestBackupDir" {
            $results.FullName | Should -BeLike "$DestBackupDir\PesterTest2.bak"
            $results.BackupFolder | Should Not Be "c:\temp"
        }
        It "Should have backed up to $DestBackupDir\PesterTest2.bak" {
            Test-Path "$DestBackupDir\PesterTest2.bak" | Should -Be $true
        }
    }

    Context "When multiple backup folders specified" {
        BeforeEach {
            $backupPaths = "$DestBackupDir\stripe1", "$DestBackupDir\stripe2", "$DestBackupDir\stripe3"
            $null = New-Item -Path $backupPaths -ItemType Directory
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $backupPaths
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have created 3 backups" {
            $results.BackupFilesCount | Should -Be 3
        }
        It "Should have written to all 3 folders" {
            $backupPaths | ForEach-Object {
                $PSItem | Should -BeIn ($results.BackupFolder)
            }
        }
        It "Should have written files with extensions" {
            foreach ($path in $results.BackupFile) {
                [IO.Path]::GetExtension($PSItem) | Should -Be ".bak"
            }
        }
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $backupPaths
                FileCount = 2
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have created 3 backups, even when FileCount is different" {
            $results.BackupFilesCount | Should -Be 3
        }
    }

    Context "When file count is greater than 1" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $DestBackupDir
                FileCount = 3
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have created 3 backups" {
            $results.BackupFilesCount | Should -Be 3
        }
    }

    Context "When building filenames" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $DestBackupDir
                FileCount = 3
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have 1 period in file extension" {
            foreach ($path in $results.BackupFile) {
                [IO.Path]::GetExtension($path) | Should -Not -BeLike '*..*'
            }
        }
    }

    Context "When IncrementPrefix is set" {
        BeforeEach {
            $fileCount = 3
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $DestBackupDir
                FileCount = $fileCount
                IncrementPrefix = $true
            }
            $results = Backup-DbaDatabase @splatBackup
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
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupFileName = "PesterTest.bak"
            }
            $results = Backup-DbaDatabase @splatBackup
            $DefaultPath = (Get-DbaDefaultPath -SqlInstance $TestConfig.instance1).Backup
        }
        It "Should report it has backed up to the path with the correct name" {
            $results.Fullname | Should -BeLike "$DefaultPath*PesterTest.bak"
        }
        It "Should have backed up to the path with the correct name" {
            Test-Path "$DefaultPath\PesterTest.bak" | Should -Be $true
        }
    }

    Context "When verifying backup" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                Type = "full"
                Verify = $true
            }
            $b = Backup-DbaDatabase @splatBackup
        }
        It "Should perform a full backup and verify it" {
            $b.BackupComplete | Should -Be $true
            $b.Verified | Should -Be $true
            $b.count | Should -Be 1
        }
        It -Skip $true "Should perform a diff backup and verify it" {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "backuptest"
                Type = "diff"
                Verify = $true
            }
            $b = Backup-DbaDatabase @splatBackup
            $b.BackupComplete | Should -Be $true
            $b.Verified | Should -Be $true
        }
        It -Skip $true "Should perform a log backup and verify it" {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "backuptest"
                Type = "log"
                Verify = $true
            }
            $b = Backup-DbaDatabase @splatBackup
            $b.BackupComplete | Should -Be $true
            $b.Verified | Should -Be $true
        }
    }

    Context "When piping backup to restore" {
        BeforeEach {
            $null = Restore-DbaDatabase -SqlInstance $TestConfig.instance1 -Path "$($TestConfig.appveyorlabrepo)\singlerestore\singlerestore.bak" -DatabaseName "dbatoolsci_singlerestore"
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                BackupDirectory = $DestBackupDir
                Database = "dbatoolsci_singlerestore"
            }
            $results = Backup-DbaDatabase @splatBackup | Restore-DbaDatabase -SqlInstance $TestConfig.instance2 -DatabaseName $DestDbRandom -TrustDbBackupHistory -ReplaceDbNameInFile
        }
        It "Should return successful restore" {
            $results.RestoreComplete | Should -Be $true
        }
    }

    Context "When Backup-DbaDatabase can take pipe input" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                Confirm = $false
                WarningVariable = warnvar
            }
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database "master" | Backup-DbaDatabase @splatBackup 3> $null
        }
        It "Should not warn" {
            $warnvar | Should -BeNullOrEmpty
        }
        It "Should Complete Successfully" {
            $results.BackupComplete | Should -Be $true
        }
    }

    Context "When handling NUL as an input path" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupFileName = "NUL"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should return successful backup" {
            $results.BackupComplete | Should -Be $true
        }
        It "Should have backed up to NUL:" {
            $results.FullName[0] | Should -Be "NUL:"
        }
    }

    Context "When OutputScriptOnly is specified" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupFileName = "c:\notexists\file.bak"
                OutputScriptOnly = $true
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should return a string" {
            $results.GetType().ToString() | Should -Be "System.String"
        }
        It "Should return BACKUP DATABASE [master] TO  DISK = N'c:\notexists\file.bak' WITH NOFORMAT, NOINIT, NOSKIP, REWIND, NOUNLOAD,  STATS = 1" {
            $results | Should -Be "BACKUP DATABASE [master] TO  DISK = N'c:\notexists\file.bak' WITH NOFORMAT, NOINIT, NOSKIP, REWIND, NOUNLOAD,  STATS = 1"
        }
    }

    Context "When handling an encrypted database with compression" {
        BeforeEach {
            $sqlencrypt =
            @"
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<UseStrongPasswordHere>';
go
CREATE CERTIFICATE MyServerCert WITH SUBJECT = 'My DEK Certificate';
go
CREATE DATABASE encrypted
go
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $sqlencrypt -Database "Master"
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
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $createdb -Database "encrypted"
        }
        It "Should compress an encrypted db" {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance2
                Database = "encrypted"
                Compress = $true
            }
            $results = Backup-DbaDatabase @splatBackup
            Invoke-Command2 -ComputerName $TestConfig.instance2 -ScriptBlock { Remove-Item -Path $args[0] } -ArgumentList $results.FullName
            $results.script | Should -BeLike "*D, COMPRESSION,*"
        }
        AfterAll {
            Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database "encrypted" -confirm:$false
            $sqldrop =
            @"
drop certificate MyServerCert
go
drop master key
go
"@
            $null = Invoke-DbaQuery -SqlInstance $TestConfig.instance2 -Query $sqldrop -Database "Master"
        }
    }

    Context "When applying custom TimeStamp" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master"
                BackupDirectory = $DestBackupDir
                TimeStampFormat = "bobob"
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should apply the correct custom Timestamp" {
            ($results | Where-Object { $PSItem.BackupPath -like "*bobob*" }).count | Should -Be $results.Status.Count
        }
    }

    Context "When testing backup templating" {
        BeforeEach {
            $splatBackup = @{
                SqlInstance = $TestConfig.instance1
                Database = "master", "msdb"
                BackupDirectory = "$DestBackupDir\dbname\instancename\backuptype\"
                BackupFileName = "dbname-backuptype.bak"
                ReplaceInName = $true
                BuildPath = $true
            }
            $results = Backup-DbaDatabase @splatBackup
        }
        It "Should have replaced the markers" {
            $results[0].BackupPath | Should -BeLike "$DestBackupDir\master\$(($TestConfig.instance1).split('\')[1])\Full\master-Full.bak"
            $results[1].BackupPath | Should -BeLike "$DestBackupDir\msdb\$(($TestConfig.instance1).split('\')[1])\Full\msdb-Full.bak"
        }
    }

    Context "When testing backup templating with piped db object" {
        BeforeEach {
            $splatBackup = @{
                BackupDirectory = "$DestBackupDir\db2\dbname\instancename\backuptype\"
                BackupFileName = "dbname-backuptype.bak"
                ReplaceInName = $true
                BuildPath = $true
            }
            $results = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database "master", "msdb" | Backup-DbaDatabase @splatBackup
        }
        It "Should have replaced the markers" {
            $results[0].BackupPath | Should -BeLike "$DestBackupDir\db2\master\$(($TestConfig.instance1).split('\')[1])\Full\master-Full.bak"
            $results[1].BackupPath | Should -BeLike "$DestBackupDir\db2\msdb\$(($TestConfig.instance1).split('\')[1])\Full\msdb-Full.bak"
        }
    }

    Context "When testing backup encryption with certificate" {
        BeforeEach {
            $securePass = ConvertTo-SecureString "estBackupDir\master\script:instance1).split('\')[1])\Full\master-Full.bak" -AsPlainText -Force
            New-DbaDbMasterKey -SqlInstance $TestConfig.instance2 -Database "Master" -SecurePassword $securePass -confirm:$false -ErrorAction SilentlyContinue
            $cert = New-DbaDbCertificate -SqlInstance $TestConfig.instance2 -Database "master" -Name "BackupCertt" -Subject "BackupCertt"
            $splatBackup = @{
                SqlInstance = $TestConfig.instance2
                Database = "master"
                EncryptionAlgorithm = "AES128"
                EncryptionCertificate = "BackupCertt"
                BackupFileName = "encryptiontest.bak"
                Description = "Encrypted backup"
            }
            $encBackupResults = Backup-DbaDatabase @splatBackup
        }
        It "Should encrypt the backup" {
            $encBackupResults.EncryptorType | Should Be "CERTIFICATE"
            $encBackupResults.KeyAlgorithm | Should Be "aes_128"
        }
        AfterAll {
            Remove-DbaDbCertificate -SqlInstance $TestConfig.instance2 -Database "master" -Certificate "BackupCertt" -Confirm:$false
            Remove-DbaDbMasterKey -SqlInstance $TestConfig.instance2 -Database "Master" -confirm:$false
        }
    }

    # Context "Test Backup Encryption with Asymmetric Key" {
    #     $key = New-DbaDbAsymmetricKey -SqlInstance $TestConfig.instance2 -Database "master" -Name "BackupKey"
    #     $encBackupResults = Backup-DbaDatabase -SqlInstance $TestConfig.instance2 -Database "master" -EncryptionAlgorithm "AES128" -EncryptionKey "BackupKey"
    #     It "Should encrypt the backup" {
    #         $encBackupResults.EncryptorType | Should Be "CERTIFICATE"
    #         $encBackupResults.KeyAlgorithm | Should Be "aes_128"
    #     }
    #     remove-DbaDbCertificate -SqlInstance $TestConfig.instance2 -Database "master" -Certificate "BackupCertt" -Confirm:$false
    # }

    if ($env:azurepasswd) {
        Context "When backing up to Azure" {
            BeforeAll {
                Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database "dbatoolsci_azure" | Remove-DbaDatabase -Confirm:$false
                $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
                if (Get-DbaCredential -SqlInstance $TestConfig.instance2 -Name "[$TestConfig.azureblob]") {
                    $sql = "DROP CREDENTIAL [$TestConfig.azureblob]"
                    $server.Query($sql)
                }
                $sql = "CREATE CREDENTIAL [$TestConfig.azureblob] WITH IDENTITY = N'SHARED ACCESS SIGNATURE', SECRET = N'$env:azurepasswd'"
                $server.Query($sql)
                $server.Query("CREATE DATABASE dbatoolsci_azure")
                if (Get-DbaCredential -SqlInstance $TestConfig.instance2 -name "dbatools_ci") {
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
                $splatBackup = @{
                    SqlInstance = $TestConfig.instance2
                    AzureBaseUrl = $TestConfig.azureblob
                    Database = "dbatoolsci_azure"
                    BackupFileName = "dbatoolsci_azure.bak"
                    WithFormat = $true
                }
                $results = Backup-DbaDatabase @splatBackup
                $results.Database | Should -Be "dbatoolsci_azure"
                $results.DeviceType | Should -Be "URL"
                $results.BackupFile | Should -Be "dbatoolsci_azure.bak"
            }
            It "backs up to Azure properly using legacy credential" {
                $splatBackup = @{
                    SqlInstance = $TestConfig.instance2
                    AzureBaseUrl = $TestConfig.azureblob
                    Database = "dbatoolsci_azure"
                    BackupFileName = "dbatoolsci_azure2.bak"
                    WithFormat = $true
                    AzureCredential = "dbatools_ci"
                }
                $results = Backup-DbaDatabase @splatBackup
                $results.Database | Should -Be "dbatoolsci_azure"
                $results.DeviceType | Should -Be "URL"
                $results.BackupFile | Should -Be "dbatoolsci_azure2.bak"
            }
        }
    }
}
