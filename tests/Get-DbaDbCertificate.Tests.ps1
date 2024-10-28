#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbCertificate" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbCertificate
        $knownParameters = @(
            'SqlInstance'
            'SqlCredential'
            'Database'
            'ExcludeDatabase'
            'Certificate'
            'Subject'
            'InputObject'
            'EnableException'
        )
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters + $knownParameters
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

Describe "Get-DbaDbCertificate" -Tag "IntegrationTests" {
    Context "Can get a database certificate" {
        BeforeAll {
            $masterKey = $null
            $tempdbMasterKey = $null

            if (-not (Get-DbaDbMasterKey -SqlInstance $TestConfig.instance1 -Database master)) {
                $masterKey = New-DbaDbMasterKey -SqlInstance $TestConfig.instance1 -Database master -Password $(ConvertTo-SecureString -String "GoodPass1234!" -AsPlainText -Force) -Confirm:$false
            }

            $tempdbMasterKey = New-DbaDbMasterKey -SqlInstance $TestConfig.instance1 -Database tempdb -Password $(ConvertTo-SecureString -String "GoodPass1234!" -AsPlainText -Force) -Confirm:$false
            $certificateName1 = "Cert_$(Get-Random)"
            $certificateName2 = "Cert_$(Get-Random)"
            $cert1 = New-DbaDbCertificate -SqlInstance $TestConfig.instance1 -Name $certificateName1 -Confirm:$false
            $cert2 = New-DbaDbCertificate -SqlInstance $TestConfig.instance1 -Name $certificateName2 -Database "tempdb" -Confirm:$false
        }

        AfterAll {
            $null = $cert1 | Remove-DbaDbCertificate -Confirm:$false
            $null = $cert2 | Remove-DbaDbCertificate -Confirm:$false
            if ($tempdbMasterKey) { $tempdbMasterKey | Remove-DbaDbMasterKey -Confirm:$false }
            if ($masterKey) { $masterKey | Remove-DbaDbMasterKey -Confirm:$false }
        }

        It "Returns database certificate created in default, master database" {
            $cert = Get-DbaDbCertificate -SqlInstance $TestConfig.instance1 -Certificate $certificateName1
            $cert.Database | Should -Match 'master'
            $cert.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master).Id
        }

        It "Returns database certificate created in tempdb database, looked up by certificate name" {
            $cert = Get-DbaDbCertificate -SqlInstance $TestConfig.instance1 -Database tempdb
            $cert.Name | Should -Match $certificateName2
            $cert.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database tempdb).Id
        }

        It "Returns database certificates excluding those in the master database" {
            $cert = Get-DbaDbCertificate -SqlInstance $TestConfig.instance1 -ExcludeDatabase master
            $cert.Database | Should -Not -Match 'master'
        }
    }
}
