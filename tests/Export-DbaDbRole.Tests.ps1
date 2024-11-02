#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaDbRole" -Tag "UnitTests" {
    Context "Parameter validation" {
        BeforeAll {
            $command = Get-Command Export-DbaDbRole
            $parameterNames = @(
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
            $knownParameters = $TestConfig.CommonParameters + $parameterNames
        }

        It "Has parameter: <_>" -ForEach $knownParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaDbRole" -Tag "IntegrationTests" {
    BeforeAll {
        $AltExportPath = "$env:USERPROFILE\Documents"
        $outputFile1 = "$AltExportPath\Dbatoolsci_DbRole_CustomFile1.sql"

        $random = Get-Random
        $dbname1 = "dbatoolsci_exportdbadbrole$random"
        $login1 = "dbatoolsci_exportdbadbrole_login1$random"
        $user1 = "dbatoolsci_exportdbadbrole_user1$random"
        $dbRole = "dbatoolsci_SpExecute$random"

        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2
        $null = $server.Query("CREATE DATABASE [$dbname1]")
        $null = $server.Query("CREATE LOGIN [$login1] WITH PASSWORD = 'GoodPass1234!'")
        $server.Databases[$dbname1].ExecuteNonQuery("CREATE USER [$user1] FOR LOGIN [$login1]")

        $server.Databases[$dbname1].ExecuteNonQuery("CREATE ROLE [$dbRole]")
        $server.Databases[$dbname1].ExecuteNonQuery("ALTER ROLE [$dbRole] ADD MEMBER [$user1]")
        $server.Databases[$dbname1].ExecuteNonQuery("GRANT SELECT ON SCHEMA::dbo to [$dbRole]")
        $server.Databases[$dbname1].ExecuteNonQuery("GRANT EXECUTE ON SCHEMA::dbo to [$dbRole]")
        $server.Databases[$dbname1].ExecuteNonQuery("GRANT VIEW DEFINITION ON SCHEMA::dbo to [$dbRole]")
    }

    AfterAll {
        Remove-DbaDatabase -SqlInstance $TestConfig.instance2 -Database $dbname1 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-DbaLogin -SqlInstance $TestConfig.instance2 -Login $login1 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item -Path $outputFile1 -ErrorAction SilentlyContinue
    }

    Context "When exporting to file" {
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
        }

        It "Creates one sql file" {
            (Get-ChildItem $outputFile1).Count | Should -Be 1
        }

        It "Creates a file with content" {
            (Get-ChildItem $outputFile1).Length | Should -BeGreaterThan 0
        }

        It "Includes the BatchSeparator" {
            $script:results | Should -Match "GO"
        }

        It "Includes the role creation" {
            $script:results | Should -Match "CREATE ROLE \[$dbRole\]"
        }

        It "Includes GRANT EXECUTE ON SCHEMA" {
            $script:results | Should -Match "GRANT EXECUTE ON SCHEMA::\[dbo\] TO \[$dbRole\];"
        }

        It "Includes GRANT SELECT ON SCHEMA" {
            $script:results | Should -Match "GRANT SELECT ON SCHEMA::\[dbo\] TO \[$dbRole\];"
        }

        It "Includes GRANT VIEW DEFINITION ON SCHEMA" {
            $script:results | Should -Match "GRANT VIEW DEFINITION ON SCHEMA::\[dbo\] TO \[$dbRole\];"
        }

        It "Includes ALTER ROLE ADD MEMBER" {
            $script:results | Should -Match "ALTER ROLE \[$dbRole\] ADD MEMBER \[$user1\];"
        }
    }
}
