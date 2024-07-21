$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'Credential', 'EnableProtocol', 'DisableProtocol', 'DynamicPortForIPAll', 'StaticPortForIPAll', 'IpAddress', 'RestartService', 'InputObject', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}
Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    Context "Command works with piped input" {
        $netConf = Get-DbaNetworkConfiguration -SqlInstance $script:instance2
        $oldKeepAlive = $netConf.TcpIpProperties.KeepAlive
        $newKeepAlive = $oldKeepAlive + 1000
        $netConf.TcpIpProperties.KeepAlive = $newKeepAlive
        $results = $netConf | Set-DbaNetworkConfiguration

        It "Should Return a Result" {
            $results.ComputerName | Should -Be $netConf.ComputerName
        }

        It "Should Return a Change" {
            $results.Changes | Should -Match "Changed TcpIpProperties.KeepAlive to $newKeepAlive"
        }

        $netConf.TcpIpProperties.KeepAlive = $oldKeepAlive
        $null = $netConf | Set-DbaNetworkConfiguration
    }

    Context "Command works with commandline input" {
        $netConf = Get-DbaNetworkConfiguration -SqlInstance $script:instance2
        if ($netConf.NamedPipesEnabled) {
            $results = Set-DbaNetworkConfiguration -SqlInstance $script:instance2 -DisableProtocol NamedPipes
        } else {
            $results = Set-DbaNetworkConfiguration -SqlInstance $script:instance2 -EnableProtocol NamedPipes
        }

        It "Should Return a Result" {
            $results.ComputerName | Should -Be $netConf.ComputerName
        }

        It "Should Return a Change" {
            $results.Changes | Should -Match "Changed NamedPipesEnabled to"
        }

        if ($netConf.NamedPipesEnabled) {
            $null = Set-DbaNetworkConfiguration -SqlInstance $script:instance2 -EnableProtocol NamedPipes
        } else {
            $null = Set-DbaNetworkConfiguration -SqlInstance $script:instance2 -DisableProtocol NamedPipes
        }
    }
}