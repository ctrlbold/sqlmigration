#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaSysDbUserObject" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaSysDbUserObject
        $expected = $TestConfig.CommonParameters
        $expected += @(
            'SqlInstance',
            'SqlCredential',
            'IncludeDependencies',
            'BatchSeparator',
            'Path',
            'FilePath',
            'NoPrefix',
            'ScriptingOptionsObject',
            'NoClobber',
            'PassThru',
            'EnableException'
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

Describe "Export-DbaSysDbUserObject" -Tag "IntegrationTests" {
    BeforeAll {
        $random = Get-Random
        $tableName = "dbatoolsci_UserTable_$random"
        $viewName = "dbatoolsci_View_$random"
        $procName = "dbatoolsci_SP_$random"
        $triggerName = "[dbatoolsci_Trigger_$random]"
        $tableFunctionName = "[dbatoolsci_TableFunction_$random]"
        $scalarFunctionName = "[dbatoolsci_ScalarFunction_$random]"
        $ruleName = "[dbatoolsci_Rule_$random]"
        
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2 -SqlCredential $SqlCredential
        $server.query("CREATE TABLE dbo.$tableName (Col1 int);", "master")
        $server.query("CREATE VIEW dbo.$viewName AS SELECT 1 as Col1;", "master")
        $server.query("CREATE PROCEDURE dbo.$procName as select 1;", "master")
        $server.query("CREATE TRIGGER $triggerName ON DATABASE FOR DROP_SYNONYM AS RAISERROR ('You must disable Trigger safety to drop synonyms!', 10, 1)", "master")
        $server.query("CREATE FUNCTION dbo.$tableFunctionName () RETURNS TABLE AS RETURN SELECT 1 as test", "master")
        $server.query("CREATE FUNCTION dbo.$scalarFunctionName (@int int) RETURNS INT AS BEGIN RETURN @int END", "master")
        $server.query("CREATE RULE dbo.$ruleName AS @range>= 1 AND @range <10;", "master")
    }

    AfterAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance2 -SqlCredential $SqlCredential
        $server.query("DROP TABLE dbo.$tableName", "master")
        $server.query("DROP VIEW dbo.$viewName", "master")
        $server.query("DROP PROCEDURE dbo.$procName", "master")
        $server.query("DROP TRIGGER $triggerName ON DATABASE", "master")
        $server.query("DROP FUNCTION dbo.$tableFunctionName", "master")
        $server.query("DROP FUNCTION dbo.$scalarFunctionName", "master")
        $server.query("DROP RULE dbo.$ruleName", "master")
    }

    Context "When using PassThru parameter" {
        BeforeAll {
            $script = Export-DbaSysDbUserObject -SqlInstance $TestConfig.instance2 -PassThru | Out-String
        }

        It "Should export text matching table name '$tableName'" {
            $script -match $tableName | Should -Be $true
        }
        It "Should export text matching view name '$viewName'" {
            $script -match $viewName | Should -Be $true
        }
        It "Should export text matching stored procedure name '$procName'" {
            $script -match $procName | Should -Be $true
        }
        It "Should export text matching trigger name '$triggerName'" {
            $script -match $triggerName | Should -Be $true
        }
        It "Should export text matching table function name '$tableFunctionName'" {
            $script -match $tableFunctionName | Should -Be $true
        }
        It "Should export text matching scalar function name '$scalarFunctionName'" {
            $script -match $scalarFunctionName | Should -Be $true
        }
        It "Should export text matching rule name '$ruleName'" {
            $script -match $ruleName | Should -Be $true
        }
    }

    Context "When using FilePath parameter" {
        BeforeAll {
            $null = Export-DbaSysDbUserObject -SqlInstance $TestConfig.instance2 -FilePath "C:\Temp\objects_$random.sql"
            $file = Get-Content "C:\Temp\objects_$random.sql" | Out-String
        }

        It "Should export text matching table name '$tableName'" {
            $file -match $tableName | Should -Be $true
        }
        It "Should export text matching view name '$viewName'" {
            $file -match $viewName | Should -Be $true
        }
        It "Should export text matching stored procedure name '$procName'" {
            $file -match $procName | Should -Be $true
        }
        It "Should export text matching trigger name '$triggerName'" {
            $file -match $triggerName | Should -Be $true
        }
        It "Should export text matching table function name '$tableFunctionName'" {
            $file -match $tableFunctionName | Should -Be $true
        }
        It "Should export text matching scalar function name '$scalarFunctionName'" {
            $file -match $scalarFunctionName | Should -Be $true
        }
        It "Should export text matching rule name '$ruleName'" {
            $file -match $ruleName | Should -Be $true
        }
    }
}
