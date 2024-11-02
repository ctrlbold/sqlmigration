#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\..\private\functions\Invoke-Command2.ps1"

Describe "Get-DbaCredential" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCredential
        $knownParameters = @(
            'SqlInstance',
            'SqlCredential',
            'Credential',
            'ExcludeCredential',
            'Identity',
            'ExcludeIdentity',
            'EnableException'
        )
        $expected = $TestConfig.CommonParameters + $knownParameters
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

Describe "Get-DbaCredential" -Tag "IntegrationTests" {
    BeforeAll {
        $logins = @(
            "dbatoolsci_thor",
            "dbatoolsci_thorsmomma"
        )
        $plaintext = "BigOlPassword!"
        $password = ConvertTo-SecureString $plaintext -AsPlainText -Force

        # Add user
        foreach ($login in $logins) {
            $null = Invoke-Command2 -ScriptBlock {
                net user $args[0] $args[1] /add *>&1
            } -ArgumentList $login, $plaintext -ComputerName $TestConfig.instance2
        }

        $null = New-DbaCredential -SqlInstance $TestConfig.instance2 -Name dbatoolsci_thorcred -Identity dbatoolsci_thor -Password $password
        $null = New-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_thorsmomma -Password $password
    }

    AfterAll {
        try {
            (Get-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_thor, dbatoolsci_thorsmomma -ErrorAction Stop -WarningAction SilentlyContinue).Drop()
        } catch { }

        foreach ($login in $logins) {
            $null = Invoke-Command2 -ScriptBlock {
                net user $args /delete *>&1
            } -ArgumentList $login -ComputerName $TestConfig.instance2
            $null = Invoke-Command2 -ScriptBlock {
                net user $args /delete *>&1
            } -ArgumentList $login -ComputerName $TestConfig.instance2
        }
    }

    Context "When getting credentials by Identity" {
        BeforeAll {
            $results = Get-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_thorsmomma
        }

        It "Should return credential with correct name" {
            $results.Name | Should -Be "dbatoolsci_thorsmomma"
        }

        It "Should return credential with correct identity" {
            $results.Identity | Should -Be "dbatoolsci_thorsmomma"
        }
    }

    Context "When getting credentials by Name" {
        BeforeAll {
            $results = Get-DbaCredential -SqlInstance $TestConfig.instance2 -Name dbatoolsci_thorsmomma
        }

        It "Should return credential with correct name" {
            $results.Name | Should -Be "dbatoolsci_thorsmomma"
        }

        It "Should return credential with correct identity" {
            $results.Identity | Should -Be "dbatoolsci_thorsmomma"
        }
    }

    Context "When getting multiple credentials" {
        BeforeAll {
            $results = Get-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_thor, dbatoolsci_thorsmomma
        }

        It "Should return multiple credentials" {
            $results.Count | Should -BeGreaterThan 1
        }
    }
}
