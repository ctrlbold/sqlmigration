#$FilePath = Get-ExportFilePath -Path $PSBoundParameters.Path -FilePath $PSBoundParameters.FilePath -Type sql -ServerName $instance
function Get-ExportFilePath ($Path, $FilePath, $Type, $ServerName) {
    if ($FilePath) { return $FilePath }
    if (-not $Path) {
        $Path = (Get-DbatoolsConfigValue -FullName 'Path.DbatoolsExport')
    }
    if (-not $Type) {
        Write-Warning "You forgot -Type"
    }
    $type = $type.ToLower()

    if (-not $ServerName) {
        $ServerName = "sqlinstance"
    }

    $ServerName = $ServerName.ToString().Replace('\', '$')
    $timenow = (Get-Date -uformat "%m%d%Y%H%M%S")
    $caller = (Get-PSCallStack)[1].Command.ToString().Replace("Export-Dba", "").ToLower()

    if ($caller -eq "RepServerSetting") {
        $caller = "replication"
    }
    return (Join-DbaPath -Path $Path -Child "$servername-$timenow-$caller.$Type")
}