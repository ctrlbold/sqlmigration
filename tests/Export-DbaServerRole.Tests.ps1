#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaServerRole" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaServerRole
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential', 
            'InputObject',
            'ScriptingOptionsObject',
            'ServerRole',
            'ExcludeServerRole',
            'ExcludeFixedRole',
            'IncludeRoleMember',
            'Path',
            'FilePath',
            'Passthru',
            'BatchSeparator',
            'NoClobber',
            'Append',
            'NoPrefix',
            'Encoding',
            'EnableException'
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaServerRole" -Tags "IntegrationTests" {
    BeforeAll {
        $AltExportPath = "$env:USERPROFILE\Documents"
        $outputFile = "$AltExportPath\Dbatoolsci_ServerRole.sql"
        
        $random = Get-Random
        $login1 = "dbatoolsci_exportdbaserverrole_login1$random"
        $svRole = "dbatoolsci_ScriptPermissions$random"

        $server = Connect-DbaInstance -SqlInstance $TestConfig.Instance2
        $null = $server.Query("CREATE LOGIN [$login1] WITH PASSWORD = 'GoodPass1234!'")
        $null = $server.Query("CREATE SERVER ROLE [$svRole] AUTHORIZATION [$login1]")
        $null = $server.Query("ALTER SERVER ROLE [dbcreator] ADD MEMBER [$svRole]")
        $null = $server.Query("GRANT CREATE TRACE EVENT NOTIFICATION TO [$svRole]")
        $null = $server.Query("DENY SELECT ALL USER SECURABLES TO [$svRole]")
        $null = $server.Query("GRANT VIEW ANY DEFINITION TO [$svRole]")
        $null = $server.Query("GRANT VIEW ANY DATABASE TO [$svRole]")
    }

    AfterAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.Instance2
        Remove-DbaServerRole -SqlInstance $server -ServerRole $svRole -Confirm:$false -ErrorAction SilentlyContinue
        Remove-DbaLogin -SqlInstance $server -Login $login1 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -Path $outputFile -ErrorAction SilentlyContinue
    }

    Context "When exporting to file" {
        BeforeAll {
            $null = Export-DbaServerRole -SqlInstance $TestConfig.Instance2 -FilePath $outputFile
        }

        It "Creates exactly one output file" {
            (Get-ChildItem $outputFile).Count | Should -BeExactly 1
        }

        It "Creates a non-empty file" {
            (Get-ChildItem $outputFile).Length | Should -BeGreaterThan 0
        }
    }

    Context "When using pipeline input" {
        BeforeAll {
            $role = Get-DbaServerRole -SqlInstance $TestConfig.Instance2 -ServerRole $svRole
            $null = $role | Export-DbaServerRole -FilePath $outputFile
            $results = $role | Export-DbaServerRole -Passthru
        }

        It "Creates exactly one output file" {
            (Get-ChildItem $outputFile).Count | Should -BeExactly 1
        }

        It "Creates a non-empty file" {
            (Get-ChildItem $outputFile).Length | Should -BeGreaterThan 0
        }

        It "Includes the BatchSeparator" {
            $results | Should -Match "GO"
        }

        It "Includes the role creation" {
            $results | Should -Match "CREATE SERVER ROLE \[$svRole\]"
        }

        It "Includes role membership" {
            $results | Should -Match "ALTER SERVER ROLE \[dbcreator\] ADD MEMBER \[$svRole\]"
        }

        It "Includes trace event notification permission" {
            $results | Should -Match "GRANT CREATE TRACE EVENT NOTIFICATION TO \[$svRole\]"
        }

        It "Includes user securables denial" {
            $results | Should -Match "DENY SELECT ALL USER SECURABLES TO \[$svRole\]"
        }

        It "Includes view any definition permission" {
            $results | Should -Match "GRANT VIEW ANY DEFINITION TO \[$svRole\];"
        }

        It "Includes view any database permission" {
            $results | Should -Match "GRANT VIEW ANY DATABASE TO \[$svRole\];"
        }
    }
}
