$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object {$_ -notin ('whatif', 'confirm')}
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Credential', 'Database', 'SecurePassword', 'InputObject', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object {$_}) -DifferenceObject $params).Count ) | Should Be 0
        }
    }
}
<#
    Integration test should appear below and are custom to the command you are writing.
    Read https://github.com/sqlcollaborative/dbatools/blob/development/contributing.md#tests
    for more guidence.
#>

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $PSDefaultParameterValues["*:Confirm"] = $false
        $passwd = ConvertTo-SecureString "dbatools.IO" -AsPlainText -Force
        $masterkey = Get-DbaDbMasterKey -SqlInstance $script:instance1 -Database master
        if (-not $masterkey) {
            $delmasterkey = $true
            $masterkey = New-DbaServiceMasterKey -SqlInstance $script:instance1 -SecurePassword $passwd
        }
        $mastercert = Get-DbaDbCertificate -SqlInstance $script:instance1 -Database master | Where-Object Name -notmatch "##" | Select-Object -First 1
        if (-not $mastercert) {
            $delmastercert = $true
            $mastercert = New-DbaDbCertificate -SqlInstance $script:instance1
        }
        $db = New-DbaDatabase -SqlInstance $script:instance1
    }

    AfterAll {
        if ($delmasterkey) {
            $masterkey | Remove-DbaDbMasterKey
        }
        if ($delmastercert) {
            $mastercert | Remove-DbaDbCertificate
        }
        if ($db) {
            $db | Remove-DbaDatabase
        }
    }

    Context "Command actually works" {
        It "should create master key on a database using piping" {
            $db.Refresh()
            $results = $db | New-DbaDbMasterKey -SecurePassword $passwd
            $results.IsEncryptedByServer | Should -Be $true
        }
        It "should create master key on a database" {
            $db.Refresh()
            $null = $results | Remove-DbaDbMasterKey
            $results = New-DbaDbMasterKey -SqlInstance $script:instance1 -Database $db.Name -SecurePassword $passwd
            $results.IsEncryptedByServer | Should -Be $true
        }
    }
}