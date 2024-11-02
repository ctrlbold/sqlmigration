### Good Parameter Test

```powershell
Describe "Get-DbaDatabase" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Get-DbaDatabase
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "Database
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
```

But with these parameters:
--PARMZ--