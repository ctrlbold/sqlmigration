#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbCompatibility" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbCompatibility
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Database",
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

Describe "Get-DbaDbCompatibility" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $masterCompatLevel = $server.Databases['master'].CompatibilityLevel
    }

    Context "When getting compatibility for multiple databases" {
        BeforeAll {
            $results = Get-DbaDbCompatibility -SqlInstance $TestConfig.instance1
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns correct compatibility level for database <_.Database>" -ForEach $results {
            # Only test system databases as there might be leftover databases from other tests
            if ($PSItem.DatabaseId -le 4) {
                $PSItem.Compatibility | Should -Be $masterCompatLevel
            }
            $PSItem.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database $PSItem.Database).Id
        }
    }

    Context "When getting compatibility for a single database" {
        BeforeAll {
            $results = Get-DbaDbCompatibility -SqlInstance $TestConfig.instance1 -Database master
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns correct compatibility level for master database" {
            $results.Compatibility | Should -Be $masterCompatLevel
            $results.DatabaseId | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database master).Id
        }
    }
}
