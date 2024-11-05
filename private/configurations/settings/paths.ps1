<#
This is designed for all paths you need configurations for.
#>

#region Weird Path Calculation Thingy
$temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
$docs = $([Environment]::GetFolderPath("MyDocuments"))

# get crazy here to support multiple enviornments

if (-not $temp) {
    if ($psVersionTable.Platform -eq 'Unix') {
        $temp = "/tmp"
    } else {
        $temp = "C:\windows\temp"
    }
}

if (-not $docs) {
    $docs = $temp
}

if (-not $home) {
    Set-Variable -Name home -Value $ $temp -Scope Script
}

if (-not (Test-Path -Path $temp)) {
    $null = New-Item -Path $temp -ItemType Directory -Force
}

if (-not (Test-Path -Path $home)) {
    $null = New-Item -Path $home -ItemType Directory -Force
}

if (-not (Test-Path -Path $docs)) {
    $null = New-Item -Path $docs -ItemType Directory -Force
}

if (-not $script:AppData) {
    $script:AppData = "$temp\AppData"
}

if (-not (Test-Path -Path $script:AppData)) {
    $null = New-Item -Path $script:AppData -ItemType Directory -Force
}
#endregion Weird Path Calculation Thingy

# The default path where dbatools stores persistent data
Set-DbatoolsConfig -FullName 'Path.DbatoolsData' -Value (Join-DbaPath $script:AppData "PowerShell" "dbatools") -Initialize -Validation string -Handler { } -Description "The path where dbatools stores persistent data on a per user basis."

# The default path where dbatools stores temporary data
Set-DbatoolsConfig -FullName 'Path.DbatoolsTemp' -Value $temp -Initialize -Validation string -Handler { } -Description "The path where dbatools stores temporary data."

# The default path for writing logs
Set-DbatoolsConfig -FullName 'Path.DbatoolsLogPath' -Value (Join-DbaPath $script:AppData "PowerShell" "dbatools") -Initialize -Validation string -Handler { [Dataplat.Dbatools.Message.LogHost]::LoggingPath = $args[0] } -Description "The path where dbatools writes all its logs and debugging information."

# The default Path for where the tags Json is stored
Set-DbatoolsConfig -FullName 'Path.TagCache' -Value (Resolve-Path "$script:PSModuleRoot\bin\dbatools-index.json") -Initialize -Validation string -Handler { } -Description "The file in which dbatools stores the tag cache. That cache is used in Find-DbaCommand for more comfortable autocomplete"

# The default Path for the server list (Get-DbaInstanceList, etc)
Set-DbatoolsConfig -FullName 'Path.Servers' -Value (Join-DbaPath $script:AppData "PowerShell" "dbatools" "servers.xml") -Initialize -Validation string -Handler { } -Description "The file in which dbatools stores the current user's server list, as managed by Get/Add/Update-DbaInstanceList"

# The default path for writing exported SQL scripts
Set-DbatoolsConfig -FullName 'Path.DbatoolsExport' -Value (Join-DbaPath -Path $docs -Child "DbatoolsExport") -Initialize -Validation string -Handler { [Dataplat.Dbatools.Message.LogHost]::LoggingPath = $args[0] } -Description "The default path where dbatools writes scripts generated by Export-* functions."

#region Managed Path Stuff
#region $Path_Temp
$path_Temp = $Env:TEMP
if (-not $path_Temp) { $path_Temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\/") }
if (-not $path_Temp) { $path_Temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\/") }
if (-not $path_Temp) {
    if ($IsLinux -or $IsMacOs) { $path_Temp = '/tmp' }
    else { $path_Temp = 'C:\windows\temp' }
}
#endregion $Path_Temp

#region $path_localAppData
if ($IsLinux -or $IsMacOs) {
    # Defaults to $Env:XDG_CONFIG_HOME on Linux or MacOS ($HOME/.config/)
    $path_LocalAppData = $Env:XDG_CONFIG_HOME
    if (-not $path_LocalAppData) { $path_LocalAppData = Join-Path $HOME .config/ }
} else {
    # Defaults to [System.Environment]::GetFolderPath("LocalApplicationData") on Windows
    $path_LocalAppData = [System.Environment]::GetFolderPath("LocalApplicationData")
    if (-not $path_LocalAppData) { $path_LocalAppData = [Environment]::GetFolderPath("LocalApplicationData") }
}
#endregion $path_localAppData

#region $path_AppData
if ($IsLinux -or $IsMacOs) {
    # Defaults to the first value in $Env:XDG_CONFIG_DIRS on Linux or MacOS (or $HOME/.local/share/)
    $path_AppData = @($Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator))[0]
    if (-not $path_AppData) { $path_AppData = Join-Path $HOME .local/share/ }
} else {
    # Defaults to [System.Environment]::GetFolderPath("ApplicationData") on Windows
    $path_AppData = [System.Environment]::GetFolderPath("ApplicationData")
    if (-not $path_AppData) { $path_AppData = [Environment]::GetFolderPath("ApplicationData") }
}
#endregion $path_AppData

#region $path_ProgramData
if ($IsLinux -or $IsMacOs) {
    # Defaults to /etc/xdg elsewhere
    $XdgConfigDirs = $Env:XDG_CONFIG_DIRS -split ([IO.Path]::PathSeparator) | Where-Object { $_ -and (Test-Path $_) }
    if ($XdgConfigDirs.Count -gt 1) { $path_ProgramData = $XdgConfigDirs[1] }
    else { $path_ProgramData = "/etc/xdg/" }
} else {
    # Defaults to $Env:ProgramData on Windows
    $path_ProgramData = $env:ProgramData
    if (-not $path_ProgramData) { $path_ProgramData = [Environment]::GetFolderPath("CommonApplicationData") }
}
#endregion $path_ProgramData

Set-DbatoolsConfig -FullName 'Path.Managed.Temp' -Value $path_Temp -Initialize -Validation 'string' -Description "Path pointing at the temp path. Used with Get-DbatoolsPath."
Set-DbatoolsConfig -FullName 'Path.Managed.LocalAppData' -Value $path_LocalAppData -Initialize -Validation 'string' -Description "Path pointing at the LocalAppData path. Used with Get-DbatoolsPath."
Set-DbatoolsConfig -FullName 'Path.Managed.AppData' -Value $path_AppData -Initialize -Validation 'string' -Description "Path pointing at the AppData path. Used with Get-DbatoolsPath."
Set-DbatoolsConfig -FullName 'Path.Managed.ProgramData' -Value $path_ProgramData -Initialize -Validation 'string' -Description "Path pointing at the ProgramData path. Used with Get-DbatoolsPath."
#endregion Managed Path Stuff