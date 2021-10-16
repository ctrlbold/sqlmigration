$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [array]$params = ([Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand($CommandName, 'Function')).Parameters.Keys
        [object[]]$knownParameters = 'ComputerName', 'Credential', 'Turbo', 'EnableException'

        It "Should only contain our specific parameters" {
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
    Context "Testing basic name resolution" {
        It "should test env:computername" {
            $result = Resolve-DbaNetworkName $env:computername -EnableException
            $result.InputName | Should -Be $env:computername
            $result.ComputerName | Should -Be $env:computername
            $result.IPAddress | Should -Not -BeNullOrEmpty
            $result.DNSHostName | Should -Be $env:computername
            if ($result.DNSDomain) {
                $result.FullComputerName | Should -Be ($result.ComputerName + "." + $result.DNSDomain)
            } else {
                $result.FullComputerName | Should -Be $env:computername
            }
        }
        It "should test localhost" {
            $result = Resolve-DbaNetworkName localhost -EnableException
            $result.InputName | Should -Be localhost
            $result.ComputerName | Should -Be $env:computername
            $result.IPAddress | Should -Not -BeNullOrEmpty
            $result.DNSHostName | Should -Be $env:computername
            if ($result.DNSDomain) {
                $result.FullComputerName | Should -Be ($result.ComputerName + "." + $result.DNSDomain)
            } else {
                $result.FullComputerName | Should -Be $env:computername
            }
        }
        It "should test 127.0.0.1" {
            $result = Resolve-DbaNetworkName 127.0.0.1 -EnableException
            $result.InputName | Should -Be 127.0.0.1
            $result.ComputerName | Should -Be $env:computername
            $result.IPAddress | Should -Not -BeNullOrEmpty
            $result.DNSHostName | Should -Be $env:computername
            if ($result.DNSDomain) {
                $result.FullComputerName | Should -Be ($result.ComputerName + "." + $result.DNSDomain)
            } else {
                $result.FullComputerName | Should -Be $env:computername
            }
        }
        foreach ($turbo in $true, $false) {
            It -Skip "should test 8.8.8.8 with Turbo = $turbo" {
                $result = Resolve-DbaNetworkName 8.8.8.8 -EnableException -Turbo:$turbo
                $result.InputName | Should -Be 8.8.8.8
                $result.ComputerName | Should -Be google-public-dns-a
                $result.IPAddress | Should -Be 8.8.8.8
                $result.DNSHostName | Should -Be google-public-dns-a
                $result.DNSDomain | Should -Be google.com
                $result.Domain | Should -Be google.com
                $result.DNSHostEntry | Should -Be google-public-dns-a.google.com
                $result.FQDN | Should -Be google-public-dns-a.google.com
                $result.FullComputerName | Should -Be 8.8.8.8
            }
        }
    }
}