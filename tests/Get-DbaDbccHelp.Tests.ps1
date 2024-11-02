#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaDbccHelp" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbccHelp
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Statement",
            "IncludeUndocumented",
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

Describe "Get-DbaDbccHelp" -Tag "IntegrationTests" {
    BeforeAll {
        $props = 'Operation', 'Cmd', 'Output'
        $result = Get-DbaDbccHelp -SqlInstance $TestConfig.instance2 -Statement FREESYSTEMCACHE
    }

    Context "Validate standard output" {
        It "Should return property: <_>" -ForEach $props {
            $result.PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }
    }

    Context "When executing DBCC HELP commands" {
        It "Returns the correct results for FREESYSTEMCACHE" {
            $result.Operation | Should -Be 'FREESYSTEMCACHE'
            $result.Cmd | Should -Be 'DBCC HELP(FREESYSTEMCACHE)'
            $result.Output | Should -Not -BeNullOrEmpty
        }

        It "Returns the correct results for PAGE with undocumented info" {
            $pageResult = Get-DbaDbccHelp -SqlInstance $TestConfig.instance2 -Statement PAGE -IncludeUndocumented
            $pageResult.Operation | Should -Be 'PAGE'
            $pageResult.Cmd | Should -Be 'DBCC HELP(PAGE)'
            $pageResult.Output | Should -Not -BeNullOrEmpty
        }
    }
}
