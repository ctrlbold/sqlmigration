#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($global:TestConfig = Get-TestConfig).Defaults
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
        # Run a query that will definitely create a session
        $queryResult = $db.Query('SELECT top 10 object_id, @@Spid as MySpid FROM sys.objects')
        # Add a small delay to ensure the session is captured
        Start-Sleep -Seconds 1
    }

    Context "Validate standard output for all databases" {
        BeforeAll {
            $inputBufferProps = 'ComputerName', 'InstanceName', 'SqlInstance', 'SessionId', 'EventType', 'Parameters', 'EventInfo'
            $outputBufferProps = 'ComputerName', 'InstanceName', 'SqlInstance', 'SessionId', 'Buffer', 'HexBuffer'

            # Get results using the SPID we know exists
            $spid = $queryResult[0].MySpid
            $inputBufferResult = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation InputBuffer -SessionId $spid
            $outputBufferResult = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation OutputBuffer -SessionId $spid
        }

        It "returns results for InputBuffer" {
            $inputBufferResult | Should -Not -BeNullOrEmpty
        }

        It "returns results for OutputBuffer" {
            $outputBufferResult | Should -Not -BeNullOrEmpty
        }

        It "Should return property <_> for InputBuffer" -ForEach $inputBufferProps {
            $inputBufferResult[0].PSObject.Properties[$_].Name | Should -Be $_
        }

        It "Should return property <_> for OutputBuffer" -ForEach $outputBufferProps {
            $outputBufferResult[0].PSObject.Properties[$_].Name | Should -Be $_
        }
    }

    Context "Validate returns results for SessionId" {
        BeforeAll {
            $spid = $queryResult[0].MySpid
            $inputBufferResult = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation InputBuffer -SessionId $spid
            $outputBufferResult = Get-DbaDbccSessionBuffer -SqlInstance $TestConfig.instance1 -Operation OutputBuffer -SessionId $spid
        }

        It "returns results for InputBuffer" {
            $inputBufferResult.SessionId | Should -Be $spid
        }

        It "returns results for OutputBuffer" {
            $outputBufferResult.SessionId | Should -Be $spid
        }
    }
}