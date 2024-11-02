#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaAvailabilityGroup" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAvailabilityGroup
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "AvailabilityGroup",
            "IsPrimary",
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

Describe "Get-DbaAvailabilityGroup" -Tag "IntegrationTests" {
    BeforeAll {
        $primaryAgName = "dbatoolsci_agroup"
        $splatPrimary = @{
            Primary = $TestConfig.instance3
            Name = $primaryAgName
            ClusterType = "None"
            FailoverMode = "Manual"
            Certificate = "dbatoolsci_AGCert"
            Confirm = $false
        }
        $null = New-DbaAvailabilityGroup @splatPrimary
    }

    AfterAll {
        $splatRemove = @{
            SqlInstance = $TestConfig.instance3
            AvailabilityGroup = $primaryAgName
            Confirm = $false
        }
        Remove-DbaAvailabilityGroup @splatRemove
    }

    Context "When getting availability groups" {
        BeforeAll {
            $results = Get-DbaAvailabilityGroup -SqlInstance $TestConfig.instance3
        }

        It "Returns results with proper data" {
            $results.AvailabilityGroup | Should -Contain $primaryAgName
        }

        It "Returns a single result when filtering by AG name" {
            $filtered = Get-DbaAvailabilityGroup -SqlInstance $TestConfig.instance3 -AvailabilityGroup $primaryAgName
            $filtered.AvailabilityGroup | Should -Be $primaryAgName
        }
    }
} #$TestConfig.instance2 for appveyor
