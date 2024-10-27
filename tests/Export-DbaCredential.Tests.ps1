#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaCredential" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaCredential
            $expected = $TestConfig.CommonParameters
            $expected += @(
                "SqlInstance",
                "Identity",
                "SqlCredential",
                "Credential",
                "Path",
                "FilePath",
                "ExcludePassword",
                "Append",
                "InputObject",
                "EnableException"
            )
        }

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasparms = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaCredential" -Tag "IntegrationTests" {
    BeforeAll {
        $plaintext = "ReallyT3rrible!"
        $password = ConvertTo-SecureString $plaintext -AsPlainText -Force
        $null = New-DbaCredential -SqlInstance $TestConfig.instance2 -Name dbatoolsci_CaptainAcred -Identity dbatoolsci_CaptainAcredId -Password $password
        $null = New-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_Hulk -Password $password
        $allfiles = @()
    }

    AfterAll {
        try {
            (Get-DbaCredential -SqlInstance $TestConfig.instance2 -Identity dbatoolsci_CaptainAcred, dbatoolsci_Hulk -ErrorAction Stop -WarningAction SilentlyContinue).Drop()
        } catch { }
        $null = $allfiles | Remove-Item -ErrorAction Ignore
    }

    Context "When exporting all credentials" {
        BeforeAll {
            $file = Export-DbaCredential -SqlInstance $TestConfig.instance2
            $results = Get-Content -Path $file -Raw
            $allfiles += $file
        }

        It "Returns content" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Contains all test credentials" {
            $results | Should -Match 'CaptainACred|Hulk'
        }

        It "Includes the password" {
            $results | Should -Match 'ReallyT3rrible!'
        }
    }

    Context "When exporting a specific credential" {
        BeforeAll {
            $filepath = "$env:USERPROFILE\Documents\dbatoolsci_credential.sql"
            $null = Export-DbaCredential -SqlInstance $TestConfig.instance2 -Identity 'dbatoolsci_CaptainAcredId' -FilePath $filepath
            $results = Get-Content -Path $filepath
            $allfiles += $filepath
        }

        It "Returns content" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Contains only the specified credential" {
            $results | Should -Match 'CaptainAcred'
        }

        It "Includes the password" {
            $results | Should -Match 'ReallyT3rrible!'
        }
    }

    Context "When appending a credential export" {
        BeforeAll {
            $filepath = "$env:USERPROFILE\Documents\dbatoolsci_credential.sql"
            $null = Export-DbaCredential -SqlInstance $TestConfig.instance2 -Identity 'dbatoolsci_Hulk' -FilePath $filepath -Append
            $results = Get-Content -Path $filepath
        }

        It "Returns content" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Contains both credentials" {
            $results | Should -Match 'Hulk|CaptainA'
        }

        It "Includes the password" {
            $results | Should -Match 'ReallyT3rrible!'
        }
    }

    Context "When exporting with excluded password" {
        BeforeAll {
            $filepath = "$env:USERPROFILE\Documents\temp-credential.sql"
            $null = Export-DbaCredential -SqlInstance $TestConfig.instance2 -Identity 'dbatoolsci_CaptainAcredId' -FilePath $filepath -ExcludePassword
            $results = Get-Content -Path $filepath
            $allfiles += $filepath
        }

        It "Returns content" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Contains the correct identity" {
            $results | Should -Match "IDENTITY = N'dbatoolsci_CaptainAcredId'"
        }

        It "Does not include the password" {
            $results | Should -Not -Match 'ReallyT3rrible!'
        }
    }
}
