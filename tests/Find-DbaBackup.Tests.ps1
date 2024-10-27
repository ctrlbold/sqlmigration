#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Find-DbaBackup" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaBackup
        $knownParameters = @(
            'Path'
            'BackupFileExtension'
            'RetentionPeriod'
            'CheckArchiveBit'
            'EnableException'
        )
        $expected = $TestConfig.CommonParameters + $knownParameters
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Find-DbaBackup" -Tag "IntegrationTests" {
    BeforeAll {
        $testPath = "TestDrive:\sqlbackups"
        if (!(Test-Path $testPath)) {
            New-Item -Path $testPath -ItemType Container
        }
    }

    Context "Path validation" {
        It "Throws when path is invalid" {
            { Find-DbaBackup -Path 'funnypath' -BackupFileExtension 'bak' -RetentionPeriod '0d' -EnableException } |
                Should -Throw "not found"
        }
    }

    Context "RetentionPeriod validation" {
        It "Throws when retention period format is invalid" {
            { Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod 'ad' -EnableException } |
                Should -Throw "format invalid"
        }

        It "Throws when retention period units are invalid" {
            { Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '11y' -EnableException } |
                Should -Throw "units invalid"
        }
    }

    Context "BackupFileExtension validation" {
        It "Does not throw with valid extension" {
            { Find-DbaBackup -Path $testPath -BackupFileExtension '.bak' -RetentionPeriod '0d' -EnableException -WarningAction SilentlyContinue } |
                Should -Not -Throw
        }

        It "Outputs correct warning message" {
            $warnMessage = Find-DbaBackup -WarningAction Continue -Path $testPath -BackupFileExtension '.bak' -RetentionPeriod '0d' 3>&1
            $warnMessage | Should -BeLike '*period*'
        }
    }

    Context "Files found match the proper retention" {
        BeforeAll {
            # Create test files with different ages
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_hours.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddHours(-10)
            }
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_days.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5)
            }
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_weeks.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5 * 7)
            }
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_months.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5 * 30)
            }
        }

        It "Should find all files with retention 0d" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '0d'
            $results.Length | Should -Be 20
        }

        It "Should find no files '*hours*' with retention 11h" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '11h'
            $results.Length | Should -Be 15
            ($results | Where-Object FullName -Like '*hours*').Count | Should -Be 0
        }

        It "Should find no files '*days*' with retention 6d" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '6d'
            $results.Length | Should -Be 10
            ($results | Where-Object FullName -Like '*hours*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*days*').Count | Should -Be 0
        }

        It "Should find no files '*weeks*' with retention 6w" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '6w'
            $results.Length | Should -Be 5
            ($results | Where-Object FullName -Like '*hours*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*days*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*weeks*').Count | Should -Be 0
        }

        It "Should find no files '*months*' with retention 6m" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '6m'
            $results.Length | Should -Be 0
            ($results | Where-Object FullName -Like '*hours*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*days*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*weeks*').Count | Should -Be 0
            ($results | Where-Object FullName -Like '*weeks*').Count | Should -Be 0
        }
    }

    Context "Files found match the proper archive bit" {
        BeforeAll {
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_notarchive.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5)
                (Get-ChildItem $filepath).Attributes = "Normal"
            }
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup_archive.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5)
                (Get-ChildItem $filepath).Attributes = "Archive"
            }
        }

        It "Should find all files with retention 0d" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '0d'
            $results.Length | Should -Be 10
        }

        It "Should find only files with the archive bit not set" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '0d' -CheckArchiveBit
            $results.Length | Should -Be 5
            ($results | Where-Object FullName -Like '*_notarchive*').Count | Should -Be 5
            ($results | Where-Object FullName -Like '*_archive*').Count | Should -Be 0
        }
    }

    Context "Files found match the proper extension" {
        BeforeAll {
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup.trn"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5)
            }
            foreach ($i in 1..5) {
                $filepath = Join-Path $testPath "dbatoolsci_$($i)_backup.bak"
                Set-Content $filepath -value "."
                (Get-ChildItem $filepath).LastWriteTime = (Get-Date).AddDays(-5)
            }
        }

        It "Should find 5 files with extension trn" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'trn' -RetentionPeriod '0d'
            $results.Length | Should -Be 5
        }

        It "Should find 5 files with extension bak" {
            $results = Find-DbaBackup -Path $testPath -BackupFileExtension 'bak' -RetentionPeriod '0d'
            $results.Length | Should -Be 5
        }
    }
}
