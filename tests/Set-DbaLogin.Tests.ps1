$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('WhatIf', 'Confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Login', 'SecurePassword', 'PasswordHash', 'DefaultDatabase', 'Unlock', 'PasswordMustChange', 'NewName', 'Disable', 'Enable', 'DenyLogin', 'GrantLogin', 'PasswordPolicyEnforced', 'PasswordExpirationEnabled', 'AddRole', 'RemoveRole', 'Force', 'InputObject', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }

        $systemRoles = @(
            @{role = 'bulkadmin' },
            @{role = 'dbcreator' },
            @{role = 'diskadmin' },
            @{role = 'processadmin' },
            @{role = 'public' },
            @{role = 'securityadmin' },
            @{role = 'serveradmin' },
            @{role = 'setupadmin' },
            @{role = 'sysadmin' }
        )
        $command = Get-Command $CommandName

        It "Validates -AddRole contains <role>" -TestCases $systemRoles {
            param ($role)
            $command.Parameters['AddRole'].Attributes.ValidValues | Should -Contain $role
        }

        It "Validates -RemoveRole contains <role>" -TestCases $systemRoles {
            param ($role)
            $command.Parameters['RemoveRole'].Attributes.ValidValues | Should -Contain $role
        }

        It "Validates -Login and -NewName aren't the same" {
            { Set-DbaLogin -SqlInstance $script:instance2 -Login testlogin -NewName testLogin -EnableException } | Should -Throw 'Login name is the same as the value in -NewName'
        }

        It "Validates -Enable and -Disable aren't used together" {
            { Set-DbaLogin -SqlInstance $script:instance2 -Login testlogin -Enable -Disable -EnableException } | Should -Throw 'You cannot use both -Enable and -Disable together'
        }

        It "Validates -GrantLogin and -DenyLogin aren't used together" {
            { Set-DbaLogin -SqlInstance $script:instance2 -Login testlogin -GrantLogin -DenyLogin -EnableException } | Should -Throw 'You cannot use both -GrantLogin and -DenyLogin together'
        }

        It "Validates -Login is required when using -SqlInstance" {
            { Set-DbaLogin -SqlInstance $script:instance2 -EnableException } | Should -Throw 'You must specify a Login when using SqlInstance'
        }

        It "Validates -Password is a SecureString or PSCredential" {
            { Set-DbaLogin -SqlInstance $script:instance2 -Login 'testLogin' -Password 'password' -EnableException } | Should -Throw 'Password must be a PSCredential or SecureString'
        }
    }
}
Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    Context "verify command functions" {
        BeforeAll {
            $SkipLocalTest = $true # Change to $false to run the local-only tests on a local instance. This is being used because the 'locked' test makes assumptions the password policy configuration is enabled for the Windows OS.
            $random = Get-Random
            $testLogin2 = "testlogin2_$random"
            $testLogin1 = "testlogin1_$random"

            # Create the new password
            $password1 = ConvertTo-SecureString -String "password1A@" -AsPlainText -Force
            $password2 = ConvertTo-SecureString -String "password2A@" -AsPlainText -Force
            $passwordHash = '0x02003629A14D633CBDB1AD136D32602F9AC869EEF270426935AC4FCFC2F56CFDE76E438C030CD239A832308F3ABBC9DFB72A9C8E99A00892158E172D78630DCD73D6AE706E9F' ## real password: Password123
            # Create the login
            New-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1, $testLogin2 -Password $password1

            $testDb1 = "testdb1_$random"
            New-DbaDatabase -SqlInstance $script:instance2 -Name $testDb1 -Confirm:$false
        }

        AfterAll {
            Remove-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1, $testLogin2 -Confirm:$false -Force
            Remove-DbaDatabase -SqlInstance $script:instance2 -Database $testDb1 -Confirm:$false
        }

        It "Does test login exist" {
            $logins = Get-DbaLogin -SqlInstance $script:instance2 | Where-Object { $_.Name -eq $testLogin1 } | Select-Object Name
            $logins.Name | Should -Be $testLogin1
        }

        It "Verifies -NewName doesn't already exist when renaming a login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -NewName 'sa' -EnableException

            $result.Notes | Should -Be 'New login name already exists'
        }

        It "Change the password from a PasswordHash" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordHash $passwordHash
            $result.PasswordChanged | Should -Be $true
        }

        It 'Change the password from a SecureString' {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Password $password2
            $result.PasswordChanged | Should -Be $true
        }

        It 'Changes the password from a PSCredential' {
            $cred = New-Object System.Management.Automation.PSCredential ($testLogin1, $password2)
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Password $cred
            $result.PasswordChanged | Should -Be $true
        }

        It "Change the password from piped Login" {
            $login = Get-DbaLogin -Sqlinstance $script:instance2 -Login $testLogin1

            $result = $login | Set-DbaLogin -Password $password2
            $result.PasswordChanged | Should -Be $true
        }

        It "Change the password from InputObject" {
            $login = Get-DbaLogin -Sqlinstance $script:instance2 -Login $testLogin1

            $result = Set-DbaLogin -InputObject $login -Password $password2
            $result.PasswordChanged | Should -Be $true
        }

        It "Disable the login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Disable
            $result.IsDisabled | Should -Be $true
        }

        It "Enable the login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Enable
            $result.IsDisabled | Should -Be $false
        }

        It "Deny access to login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -DenyLogin

            $result.DenyLogin | Should -Be $true
        }

        It "Grant access to login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -GrantLogin

            $result.DenyLogin | Should -Be $false
        }

        It "Enforces password policy on login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced

            $result.PasswordPolicyEnforced | Should Be $true
        }

        It "Catches errors when password can't be changed" {
            # enforce password policy
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced -EnableException
            $result.PasswordPolicyEnforced | Should -Be $true

            # violate policy
            $invalidPassword = ConvertTo-SecureString -String "p" -AsPlainText -Force

            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Password $invalidPassword -WarningAction 'SilentlyContinue'
            $result | Should -Be $null

            { Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Password $invalidPassword -EnableException } | Should -Throw
        }

        It "Disables enforcing password policy on login" {
            $result = Get-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1
            $result.PasswordPolicyEnforced | Should Be $true

            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced:$false
            $result.PasswordPolicyEnforced | Should Be $false
        }

        It "Add roles to login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -AddRole serveradmin, processadmin

            $result.ServerRole | Should -Be "processadmin, serveradmin"
        }

        It "Remove roles from login" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -RemoveRole serveradmin

            $result.ServerRole | Should -Be "processadmin"
        }

        It "Results include multiple changed objects" {
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1, $testLogin2 -DenyLogin
            $results.Count | Should -Be 2
            foreach ($r in $results) {
                $r.DenyLogin | Should -Be $true
            }
        }

        It "DefaultDatabase" {
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -DefaultDatabase $testDb1
            $results.DefaultDatabase | Should -Be $testDb1
        }

        It "PasswordExpirationEnabled" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin2 -PasswordPolicyEnforced
            $result.PasswordPolicyEnforced | Should Be $true

            # testlogin1_$random will get skipped since it does not have PasswordPolicyEnforced set to true (check_policy = ON)
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1, $testLogin2 -PasswordExpirationEnabled -ErrorVariable error
            $result.Count | Should -Be 1
            $result.Name | Should -Be $testLogin2
            $result.PasswordExpirationEnabled | Should Be $true
            $error.Exception | Should -Match "Couldn't set check_expiration = ON because check_policy = OFF for \[testlogin1_$random\]"

            # set both params for this login
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced -PasswordExpirationEnabled
            $result.PasswordExpirationEnabled | Should -Be $true
            $result.PasswordPolicyEnforced | Should Be $true

            # disable the setting for this login
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordExpirationEnabled:$false
            $result.PasswordExpirationEnabled | Should -Be $false
        }

        It "Ensure both password policy settings can be disabled at the same time" {
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced -PasswordExpirationEnabled
            $result.PasswordExpirationEnabled | Should -Be $true
            $result.PasswordPolicyEnforced | Should Be $true

            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced:$false -PasswordExpirationEnabled:$false
            $result.PasswordExpirationEnabled | Should -Be $false
            $result.PasswordPolicyEnforced | Should Be $false
        }

        It -Skip:$SkipLocalTest "Unlock" {
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced -EnableException
            $results.PasswordPolicyEnforced | Should -Be $true

            # simulate a lockout
            $invalidPassword = ConvertTo-SecureString -String 'invalid' -AsPlainText -Force
            $invalidSqlCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $testLogin1, $invalidPassword

            # exceed the lockout count
            for (($i = 0); $i -le 4; $i++) {
                try {
                    Connect-DbaInstance -SqlInstance $script:instance2 -SqlCredential $invalidSqlCredential
                } catch {
                    Write-Message -Level Warning -Message "invalid login credentials used on purpose to lock out account"
                    Start-Sleep -s 5
                }
            }

            $results = Get-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1
            $results.IsLocked | Should -Be $true

            # this will generate a warning since neither the password or the -force param is specified
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Unlock
            $results | Should -BeNullOrEmpty

            # this will use the workaround solution to turn off/on the check_policy
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Unlock -Force
            $results.IsLocked | Should -Be $false

            # exceed the lockout count again
            for (($i = 0); $i -le 4; $i++) {
                try {
                    Connect-DbaInstance -SqlInstance $script:instance2 -SqlCredential $invalidSqlCredential
                } catch {
                    Write-Message -Level Warning -Message "invalid login credentials used on purpose to lock out account"
                    Start-Sleep -s 5
                }
            }

            # unlock by resetting the password
            $results = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -Unlock -SecurePassword $password1
            $results.IsLocked | Should -Be $false
        }

        It "PasswordMustChange" {
            # password is required
            $changeResult = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordMustChange -ErrorVariable error
            $changeResult | Should -BeNullOrEmpty
            $error.Exception | Should -Match "You must specify a password when using the -PasswordMustChange parameter"

            # ensure the policy settings are off
            $result = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordPolicyEnforced:$false -PasswordExpirationEnabled:$false
            $result.PasswordExpirationEnabled | Should -Be $false
            $result.PasswordPolicyEnforced | Should Be $false

            # set the policy options separately for testlogin2
            $changeResult = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin2 -PasswordPolicyEnforced -PasswordExpirationEnabled
            $changeResult.PasswordPolicyEnforced | Should Be $true
            $changeResult.PasswordExpirationEnabled | Should Be $true

            # check_policy and check_expiration must be set on the login
            $changeResult = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1, $testLogin2 -PasswordMustChange -Password $password1 -ErrorVariable error
            $changeResult.Count | Should -Be 1
            $changeResult.Name | Should -Be $testLogin2
            $error.Exception | Should -Match "Unable to change the password and set the must_change option for \[testlogin1_$random\] because check_policy = False and check_expiration = False"

            $changeResult = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin1 -PasswordMustChange -Password $password1 -PasswordPolicyEnforced -PasswordExpirationEnabled
            $changeResult.MustChangePassword | Should -Be $true
            $changeResult.PasswordChanged | Should -Be $true
            $changeResult.PasswordPolicyEnforced | Should Be $true
            $changeResult.PasswordExpirationEnabled | Should Be $true

            # now change the password and set the must_change
            $changeResult = Set-DbaLogin -SqlInstance $script:instance2 -Login $testLogin2 -PasswordMustChange -Password $password1
            $changeResult.MustChangePassword | Should -Be $true
            $changeResult.PasswordChanged | Should -Be $true

            # get a listing of the logins that must change their password
            $result = Get-DbaLogin -SqlInstance $script:instance2 -MustChangePassword
            $result.Name | Should -Contain $testLogin1
            $result.Name | Should -Contain $testLogin2
        }
    }
}