#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Find-DbaDatabase" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaDatabase
        $knownParameters = @(
            "SqlInstance",
            "SqlCredential",
            "Property",
            "Pattern",
            "Exact",
            "EnableException"
        )
        $knownParameters += $TestConfig.CommonParameters
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $knownParameters {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of parameters ($($knownParameters.Count))" {
            $params = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params | Should -BeNullOrEmpty
        }
    }
}

Describe "Find-DbaDatabase" -Tag "IntegrationTests" {
    Context "Command actually works" {
        BeforeAll {
            $expectedProps = @(
                "ComputerName",
                "InstanceName",
                "SqlInstance",
                "Name",
                "Id",
                "Size",
                "Owner",
                "CreateDate",
                "ServiceBrokerGuid",
                "Tables",
                "StoredProcedures",
                "Views",
                "ExtendedProperties"
            )
            $results = Find-DbaDatabase -SqlInstance $TestConfig.instance2 -Pattern Master
        }

        It "Should return correct properties" {
            ($results[0].PsObject.Properties.Name | Sort-Object) | Should -BeExactly ($expectedProps | Sort-Object)
        }

        It "Should return true if Database Master is Found" {
            $results | Where-Object Name -match 'Master' | Should -BeTrue
            $results.Id | Should -Be (Get-DbaDatabase -SqlInstance $TestConfig.instance2 -Database Master).Id
        }

        It "Should return true if Creation Date of Master is '4/8/2003 9:13:36 AM'" {
            $results.CreateDate.ToFileTimeutc()[0] | Should -Be 126942668163900000
        }

        It "Should return true if Executed Against 2 instances: $($TestConfig.instance1) and $($TestConfig.instance2)" {
            $multiResults = Find-DbaDatabase -SqlInstance $TestConfig.instance1, $TestConfig.instance2 -Pattern Master
            ($multiResults.InstanceName | Select-Object -Unique).Count | Should -Be 2
        }

        It "Should return true if Database Found via Property Filter" {
            $propertyResults = Find-DbaDatabase -SqlInstance $TestConfig.instance2 -Property ServiceBrokerGuid -Pattern -0000-0000-000000000000
            $propertyResults.ServiceBrokerGuid | Should -BeLike '*-0000-0000-000000000000'
        }
    }
}
