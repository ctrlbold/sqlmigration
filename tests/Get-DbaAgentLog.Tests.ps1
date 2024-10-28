#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan

Describe "Get-DbaAgentLog" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentLog
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "LogNumber",
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

Describe "Get-DbaAgentLog" -Tags "IntegrationTests" {
    Context "Command gets agent log" {
        BeforeAll {
            $results = Get-DbaAgentLog -SqlInstance $TestConfig.instance2
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Results contain SQLServerAgent version" {
            $results.text -like '[100] Microsoft SQLServerAgent version*' | Should -Be $true
        }

        It "LogDate is a DateTime type" {
            $($results | Select-Object -First 1).LogDate | Should -BeOfType DateTime
        }
    }

    Context "Command gets current agent log using LogNumber parameter" {
        BeforeAll {
            $results = Get-DbaAgentLog -SqlInstance $TestConfig.instance2 -LogNumber 0
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
