#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaAgentOperator" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaAgentOperator
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Operator",
            "ExcludeOperator",
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

Describe "Get-DbaAgentOperator" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $operatorName = "dbatoolsci_operator"
        $operatorName2 = "dbatoolsci_operator2"

        $splatOperator1 = @{
            Name = $operatorName
            Enabled = 1
            PagerDays = 0
        }
        $splatOperator2 = @{
            Name = $operatorName2
            Enabled = 1
            PagerDays = 0
        }

        $server.Query("EXEC msdb.dbo.sp_add_operator @name=N'$operatorName', @enabled=1, @pager_days=0")
        $server.Query("EXEC msdb.dbo.sp_add_operator @name=N'$operatorName2', @enabled=1, @pager_days=0")
    }

    AfterAll {
        $server.Query("EXEC msdb.dbo.sp_delete_operator @name=N'$operatorName'")
        $server.Query("EXEC msdb.dbo.sp_delete_operator @name=N'$operatorName2'")
    }

    Context "When getting SQL Agent operators" {
        BeforeAll {
            $results = Get-DbaAgentOperator -SqlInstance $TestConfig.instance2
        }

        It "Returns at least two operators" {
            $results.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context "When filtering for a specific operator" {
        BeforeAll {
            $results = Get-DbaAgentOperator -SqlInstance $TestConfig.instance2 -Operator $operatorName
        }

        It "Returns exactly one operator" {
            $results.Count | Should -Be 1
        }

        It "Returns the correct operator" {
            $results.Name | Should -Be $operatorName
        }
    }
}
