#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgReplica" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgReplica
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "AvailabilityGroup",
            "Replica",
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

Describe "Get-DbaAgReplica" -Tag "IntegrationTests" {
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
        $ag = New-DbaAvailabilityGroup @splatPrimary
        $replicaName = $ag.PrimaryReplica
    }

    AfterAll {
        $null = Remove-DbaAvailabilityGroup -SqlInstance $TestConfig.instance3 -AvailabilityGroup $primaryAgName -Confirm:$false
    }

    Context "When getting AG replicas" {
        BeforeAll {
            $results = Get-DbaAgReplica -SqlInstance $TestConfig.instance3
        }

        It "Returns results with proper data" {
            $results.AvailabilityGroup | Should -Contain $primaryAgName
            $results.Role | Should -Contain 'Primary'
            $results.AvailabilityMode | Should -Contain 'SynchronousCommit'
        }

        It "Returns just one result when filtering by replica and AG" {
            $splatFilter = @{
                SqlInstance = $TestConfig.instance3
                Replica = $replicaName
                AvailabilityGroup = $primaryAgName
            }
            $filtered = Get-DbaAgReplica @splatFilter

            $filtered.AvailabilityGroup | Should -Be $primaryAgName
            $filtered.Role | Should -Be 'Primary'
            $filtered.AvailabilityMode | Should -Be 'SynchronousCommit'
        }

        # Skipping because this adds like 30 seconds to test times
        It -Skip "Passes EnableException to Get-DbaAvailabilityGroup" {
            $results = Get-DbaAgReplica -SqlInstance invalidSQLHostName -ErrorVariable agerror
            $results | Should -BeNullOrEmpty
            ($agerror | Where-Object Message -match "The network path was not found") | Should -Not -BeNullOrEmpty

            { Get-DbaAgReplica -SqlInstance invalidSQLHostName -EnableException } | Should -Throw
        }
    }
} #$TestConfig.instance2 for appveyor
