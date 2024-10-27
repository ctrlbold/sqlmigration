#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgListener" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgListener
        $knownParameters = @(
            'SqlInstance',
            'SqlCredential', 
            'AvailabilityGroup',
            'Listener',
            'InputObject',
            'EnableException'
        )
        $knownParameters += $TestConfig.CommonParameters
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $knownParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters ($($knownParameters.Count))" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Get-DbaAgListener" -Tag "IntegrationTests" {
    BeforeAll {
        $agname = "dbatoolsci_ag_listener"
        $splatAg = @{
            Primary = $TestConfig.instance3
            Name = $agname
            ClusterType = "None"
            FailoverMode = "Manual"
            Certificate = "dbatoolsci_AGCert"
            Confirm = $false
        }
        $ag = New-DbaAvailabilityGroup @splatAg

        $splatListener = @{
            IPAddress = "127.0.20.1"
            Port = 14330
            Confirm = $false
        }
        $ag | Add-DbaAgListener @splatListener
    }

    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $TestConfig.instance3 -AvailabilityGroup $agname -Confirm:$false
    }

    Context "When getting availability group listeners" {
        BeforeAll {
            $results = Get-DbaAgListener -SqlInstance $TestConfig.instance3
        }

        It "Returns results with proper port number" {
            $results.PortNumber | Should -Contain 14330
        }
    }
} #$TestConfig.instance2 for appveyor
