#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Export-DbaXESessionTemplate" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Export-DbaXESessionTemplate
        $expectedParams = $TestConfig.CommonParameters
        $expectedParams += @(
            'SqlInstance',
            'SqlCredential', 
            'Session',
            'Path',
            'FilePath',
            'InputObject',
            'EnableException'
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expectedParams {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expectedParams.Count))" {
            $hasParams = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expectedParams -DifferenceObject $hasParams | Should -BeNullOrEmpty
        }
    }
}

Describe "Export-DbaXESessionTemplate" -Tag "IntegrationTests" {
    BeforeAll {
        $null = Get-DbaXESession -SqlInstance $TestConfig.instance2 -Session 'Profiler TSQL Duration' | Remove-DbaXESession
    }
    
    AfterAll {
        $null = Get-DbaXESession -SqlInstance $TestConfig.instance2 -Session 'Profiler TSQL Duration' | Remove-DbaXESession
        Remove-Item -Path 'C:\windows\temp\Profiler TSQL Duration.xml' -ErrorAction SilentlyContinue
    }
    
    Context "When exporting session template" {
        BeforeAll {
            $session = Import-DbaXESessionTemplate -SqlInstance $TestConfig.instance2 -Template 'Profiler TSQL Duration'
            $results = $session | Export-DbaXESessionTemplate -Path C:\windows\temp
        }

        It "Should export session to disk with correct name" {
            $results.Name | Should -Be 'Profiler TSQL Duration.xml'
        }
    }
}
