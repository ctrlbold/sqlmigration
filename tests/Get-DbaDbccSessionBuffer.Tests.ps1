#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaDbccSessionBuffer" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDbccSessionBuffer
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Operation",
            "SessionId",
            "RequestId",
            "All",
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

Describe "Get-DbaDbccSessionBuffer" -Tag "IntegrationTests" {
    BeforeAll {
        $db = Get-DbaDatabase -SqlInstance $TestConfig.instance1 -Database tempdb
        # Create a query that will generate buffer data
        $query = @"
        DECLARE @i INT = 0;
        WHILE @i < 10 BEGIN
            SELECT TOP 100 * FROM sys.objects;
            SET @i = @i + 1;
            WAITFOR DELAY '00:00:01';
        END;
"@
        # Start the query in a background runspace to ensure it's running during our tests
        $script:runspace = [powershell]::Create().AddScript({
            param($instance, $query)
            Import-Module dbatools
            $db = Get-DbaDatabase -SqlInstance $instance -Database tempdb
            $db.Query($query)
        }).AddArgument($TestConfig.instance1).AddArgument($query)

        $script:runspaceHandle = $script:runspace.BeginInvoke()
        Start-Sleep -Seconds 2 # Give the query time to start

        $queryResult = $db.Query('SELECT top 10 object_id, @@Spid as MySpid FROM sys.objects')
    }

    AfterAll {
        if ($script:runspace) {
            if (-not $script:runspaceHandle.IsCompleted) {
                $script:runspace.Stop()
            }
            $script:runspace.Dispose()
        }
    }

    Context "When getting session buffers for all databases" {
        BeforeAll {
            $inputProps = @(
                'ComputerName',
                'InstanceName',
                'SqlInstance',
                'SessionId',
                'EventType',
                'Parameters',
                'EventInfo'
            )
            $resultInput = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation InputBuffer -All
            $resultOutput = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation OutputBuffer -All
        }

        It "Returns results for InputBuffer" {
            $resultInput.Count | Should -BeGreaterThan 0
        }

        It "Has property <_> for InputBuffer" -ForEach $inputProps {
            $resultInput[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
        }

        It "Returns results for OutputBuffer" {
            $resultOutput.Count | Should -BeGreaterThan 0
        }
    }

    Context "When getting session buffers for specific SessionId" {
        BeforeAll {
            $spid = $queryResult[0].MySpid
            $resultInput = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation InputBuffer -SessionId $spid
            $resultOutput = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation OutputBuffer -SessionId $spid
        }

        It "Returns correct SessionId for InputBuffer" {
            $resultInput.SessionId | Should -Be $spid
        }

        It "Returns correct SessionId for OutputBuffer" {
            $resultOutput.SessionId | Should -Be $spid
        }
    }
}
