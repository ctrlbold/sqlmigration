Import-Module /workspace/dbatools.psm1
$PSDefaultParameterValues['*:Passthru'] = $true
Invoke-ManualPester -NoReimport -ErrorAction Stop $args -OutVariable testResults #-edit-format diff # -editor-model

if ($testResults.FailedCount -gt 0) {
    exit 1
} else {
    exit 0
}