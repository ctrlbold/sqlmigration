#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Describe "Get-DbaCmConnection" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaCmConnection
        $expected = [System.Management.Automation.PSCmdlet]::CommonParameters
        $expected += @(
            "ComputerName",
            "UserName",
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

Describe "Get-DbaCmConnection" -Tag "IntegrationTests" {
    BeforeAll {
        New-DbaCmConnection -ComputerName $env:COMPUTERNAME
    }

    AfterAll {
        Remove-DbaCmConnection -ComputerName $env:COMPUTERNAME -Confirm:$false
    }

    Context "When getting connection for computer name" {
        BeforeAll {
            $results = Get-DbaCMConnection -ComputerName $env:COMPUTERNAME
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context "When getting connection for username" {
        BeforeAll {
            $results = Get-DbaCMConnection -ComputerName $env:COMPUTERNAME -UserName *
        }

        It "Returns results" {
            $results | Should -Not -BeNullOrEmpty
        }
    }
}