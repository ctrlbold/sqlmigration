#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaDbRole" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaDbRole
            $expected = $TestConfig.CommonParameters
            $expected += @(
                'SqlInstance',
                'SqlCredential',
                'InputObject',
                'ScriptingOptionsObject',
                'Database',
                'Role',
                'ExcludeRole',
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

        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaDbRole" -Tag "IntegrationTests" {
    BeforeAll {
        $AltExportPath = Join-Path -Path $HOME -ChildPath 'Documents'
        if (-not (Test-Path $AltExportPath)) {
            New-Item -ItemType Directory -Path $AltExportPath
        }
        $outputFile1 = Join-Path -Path $AltExportPath -ChildPath 'Dbatoolsci_DbRole_CustomFile1.sql'

        $random = Get-Random
        $dbname1 = "dbatoolsci_exportdbadbrole$random"
        $login1 = "dbatoolsci_exportdbadbrole_login1$random"
        $user1 = "dbatoolsci_exportdbadbrole_user1$random"
        $dbRole = "dbatoolsci_SpExecute$random"

        # Database setup
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2

        # Create test database and login
        $setupQueries = @(
            "CREATE DATABASE [$dbname1]",
            "CREATE LOGIN [$login1] WITH PASSWORD = 'GoodPass1234!'"
        )

        foreach ($query in $setupQueries) {
            $server.Query($query)
        }

        $dbQueries = @(
            "CREATE USER [$user1] FOR LOGIN [$login1]",
            "CREATE ROLE [$dbRole]",
            "ALTER ROLE [$dbRole] ADD MEMBER [$user1]",
            "GRANT SELECT ON SCHEMA::dbo to [$dbRole]",
            "GRANT EXECUTE ON SCHEMA::dbo to [$dbRole]",
            "GRANT VIEW DEFINITION ON SCHEMA::dbo to [$dbRole]"
        )

        foreach ($query in $dbQueries) {
            $server.Databases[$dbname1].ExecuteNonQuery($query)
        }
    }

    AfterAll {
        try {
            Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname1 -Confirm:$false
            Remove-DbaLogin -SqlInstance $TestConfig.instance2 -Login $login1 -Confirm:$false
        } catch { }
       (Get-ChildItem $outputFile1 -ErrorAction SilentlyContinue) | Remove-Item -ErrorAction SilentlyContinue -Confirm:$false
    }

    Context "When exporting database roles" {
        BeforeAll {
            $null = Export-DbaDbRole -SqlInstance $TestConfig.instance2 -Database msdb -FilePath $outputFile1
        }

        It "Creates one sql file" {
           (Get-ChildItem $outputFile1).Count | Should -Be 1
        }

        It "Creates a file with content" {
           (Get-ChildItem $outputFile1).Length | Should -BeGreaterThan 0
        }
    }

    Context "When using pipeline input" {
        BeforeAll {
            $role = Get-DbaDbRole -SqlInstance $TestConfig.instance2 -Database $dbname1 -Role $dbRole
            $null = $role | Export-DbaDbRole -FilePath $outputFile1
            $script:results = $role | Export-DbaDbRole -Passthru
            if (-not $script:results) {
                # sometimes this happens in testing suite, maybe pester 5 issue?
                $script:results = Get-Content $outputFile1 -Raw
            }
        }

        It "Creates one sql file" {
           (Get-ChildItem $outputFile1).Count | Should -Be 1
        }

        It "Creates a file with content" {
           (Get-ChildItem $outputFile1).Length | Should -BeGreaterThan 0
        }

        Context "Generated SQL script" {
            BeforeAll {
                $expectedPatterns = @{
                    BatchSeparator = '\bGO\b'
                    RoleCreation   = [regex]::Escape("CREATE ROLE [$dbRole]")
                    ExecuteGrant   = [regex]::Escape("GRANT EXECUTE ON SCHEMA::[dbo] TO [$dbRole];")
                    SelectGrant    = [regex]::Escape("GRANT SELECT ON SCHEMA::[dbo] TO [$dbRole];")
                    ViewGrant      = [regex]::Escape("GRANT VIEW DEFINITION ON SCHEMA::[dbo] TO [$dbRole];")
                    MemberAddition = [regex]::Escape("ALTER ROLE [$dbRole] ADD MEMBER [$user1];")
                }
            }

            It "Should include <_>" -ForEach @(
                @{ Pattern = $expectedPatterns.BatchSeparator;  Description = "batch separator" }
                @{ Pattern = $expectedPatterns.RoleCreation;    Description = "role creation" }
                @{ Pattern = $expectedPatterns.ExecuteGrant;    Description = "execute permission" }
                @{ Pattern = $expectedPatterns.SelectGrant;     Description = "select permission" }
                @{ Pattern = $expectedPatterns.ViewGrant;       Description = "view definition permission" }
                @{ Pattern = $expectedPatterns.MemberAddition;  Description = "member addition" }
            ) {
                $script:results | Should -Match $Pattern -Because "SQL script should contain $Description"
            }
        }
    }
}