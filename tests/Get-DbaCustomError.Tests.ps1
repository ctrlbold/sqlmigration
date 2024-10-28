#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Get-DbaCustomError" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCustomError
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
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

Describe "Get-DbaCustomError" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $sql = "EXEC msdb.dbo.sp_addmessage 54321, 9, N'Dbatools is Awesome!';"
        $server.Query($sql)
    }

    AfterAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $sql = "EXEC msdb.dbo.sp_dropmessage 54321;"
        $server.Query($sql)
    }

    Context "Gets the custom errors" {
        BeforeAll {
            $results = Get-DbaCustomError -SqlInstance $TestConfig.instance1
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }

        It "Returns correct custom error text" {
            $results.Text | Should -Be "Dbatools is Awesome!"
        }

        It "Returns correct language ID" {
            $results.LanguageID | Should -Be 1033
        }

        It "Returns correct custom error ID" {
            $results.ID | Should -Be 54321
        }
    }
}
