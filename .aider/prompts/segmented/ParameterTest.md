The parameter test should look like this:

Describe "Backup-DbaDbMasterKey" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Backup-DbaDbMasterKey
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential",
            "WhatIf",
            "Confirm"
        )
    }
    Context "Parameter validation" {...

But with these parameters:

--PARMZ--