#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbAsymmetricKey" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbAsymmetricKey
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database",
            "ExcludeDatabase",
            "Name",
            "InputObject",
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

Describe "Get-DbaDbAsymmetricKey" -Tag "IntegrationTests" {
    Context "Gets an asymmetric key" {
        BeforeAll {
            $keyname = 'test4'
            $keyname2 = 'test5'
            $algorithm = 'Rsa4096'
            $dbuser = 'keyowner'
            $database = 'GetAsKey'

            $newDB = New-DbaDatabase -SqlInstance $TestConfig.instance2 -Name $database
            $tPassword = ConvertTo-SecureString "ThisIsThePassword1" -AsPlainText -Force
            New-DbaDbMasterKey -SqlInstance $TestConfig.instance2 -Database $database -SecurePassword $tPassword -confirm:$false
            New-DbaDbUser -SqlInstance $TestConfig.instance2 -Database $database -UserName $dbuser
            $null = New-DbaDbAsymmetricKey -SqlInstance $TestConfig.instance2 -Database $database -Name $keyname -Owner keyowner -Algorithm $algorithm -WarningVariable warnvar
            $results = Get-DbaDbAsymmetricKey -SqlInstance $TestConfig.instance2 -Name $keyname -Database $database
        }

        It "Should Create new key in $database called $keyname" {
            $warnvar | Should -BeNullOrEmpty
            $results.database | Should -BeExactly $database
            $results.DatabaseId | Should -BeExactly $newDB.ID
            $results.name | Should -BeExactly $keyname
            $results.Owner | Should -BeExactly $dbuser
            $results | Should -HaveCount 1
        }

        It "Should work with a piped database" {
            $pipeResults = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $database | Get-DbaDbAsymmetricKey
            $pipeResults.database | Should -BeExactly $database
            $pipeResults.name | Should -BeExactly $keyname
            $pipeResults.Owner | Should -BeExactly $dbuser
            $pipeResults | Should -HaveCount 1
        }

        It "Should return 2 keys when multiple keys exist" {
            $null = New-DbaDbAsymmetricKey -SqlInstance $TestConfig.instance2 -Database $database -Name $keyname2 -Owner keyowner -Algorithm $algorithm -WarningVariable warnvar
            $multiResults = Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $database | Get-DbaDbAsymmetricKey
            $multiResults | Should -HaveCount 2
            $multiResults.name | Should -Contain $keyname
            $multiResults.name | Should -Contain $keyname2
        }

        AfterAll {
            $drop = Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $database -confirm:$false
            $drop.Status | Should -BeExactly 'Dropped'
        }
    }
}
