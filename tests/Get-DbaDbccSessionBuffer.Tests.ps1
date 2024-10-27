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
        $queryResult = $db.Query('SELECT top 10 object_id, @@Spid as MySpid FROM sys.objects')
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
            $outputProps = @(
                'ComputerName',
                'InstanceName',
                'SqlInstance',
                'SessionId',
                'Buffer',
                'HexBuffer'
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

        It "Has property <_> for OutputBuffer" -ForEach $outputProps {
            $resultOutput[0].PSObject.Properties[$PSItem].Name | Should -Be $PSItem
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
