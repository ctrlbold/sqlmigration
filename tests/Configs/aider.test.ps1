Import-Module /workspace/dbatools.psm1
$error.Clear()
$PSDefaultParameterValues['*:Passthru'] = $true
Invoke-ManualPester -TestIntegration -NoReimport -ErrorAction Stop $args |
Select-Object -ExpandProperty Failed |
    Select-Object Name, ExpandedPath, ScriptBlock, ErrorRecord -OutVariable testResults |
    Format-List

if (($testResults).Count -gt 0) {
    # export the test results using clixml to a path that works in both linux and windows
    $testResults | Export-Clixml /tmp/testResults.clixml
    Write-Warning "$(($testResults).Count) tests failed from aider.test.ps1"
    $error | Select-Object Exception, ScriptStackTrace
    exit 1
} else {
    exit 0
}