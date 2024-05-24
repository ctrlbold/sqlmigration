Add-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Running

# Invoke appveyor.common.ps1 to know which tests to run
. "$($env:APPVEYOR_BUILD_FOLDER)\tests\appveyor.common.ps1"
$AllScenarioTests = Get-TestsForBuildScenario -ModuleBase $env:APPVEYOR_BUILD_FOLDER -Silent

if ($AllScenarioTests.Count -eq 0) {
    #Exit early without provisioning if no tests to run
    Write-Host -Object "appveyor.prep: exit early without provisioning (no tests to run)"  -ForegroundColor DarkGreen
    Exit-AppveyorBuild
    return
}


$sw = [system.diagnostics.stopwatch]::startNew()
Write-Host -Object "appveyor.prep: Cloning lab materials"  -ForegroundColor DarkGreen
git clone -q --branch=master --depth=1 https://github.com/dataplat/appveyor-lab.git C:\github\appveyor-lab

#Get codecov (to upload coverage results)
Write-Host -Object "appveyor.prep: Install codecov" -ForegroundColor DarkGreen
choco install codecov | Out-Null

#Get PSScriptAnalyzer (to check warnings)
Write-Host -Object "appveyor.prep: Install PSScriptAnalyzer" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\PSScriptAnalyzer\1.18.2')) {
    Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -MaximumVersion 1.18.2 | Out-Null
}

#Get dbatools.library
Write-Host -Object "appveyor.prep: Install dbatools.library" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\dbatools.library')) {
    Install-Module -Name dbatools.library -Force -AllowPrerelease | Out-Null
}

#Get Pester (to run tests) - choco isn't working on all scenarios, weird
Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\5.5.0')) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -MaximumVersion 5.5.0 | Out-Null
}

#Setup DbatoolsConfig Path.DbatoolsExport path
Write-Host -Object "appveyor.prep: Create Path.DbatoolsExport" -ForegroundColor DarkGreen
if (-not(Test-Path 'C:\Users\appveyor\Documents\DbatoolsExport')) {
    New-Item -Path C:\Users\appveyor\Documents\DbatoolsExport -ItemType Directory | Out-Null
}


#Get opencover.portable (to run DLL tests)
Write-Host -Object "appveyor.prep: Install opencover.portable" -ForegroundColor DarkGreen
choco install opencover.portable | Out-Null

Write-Host -Object "appveyor.prep: Trust SQL Server Cert (now required)" -ForegroundColor DarkGreen
Import-Module dbatools.library
Import-Module C:\github\dbatools\dbatools.psd1
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register
Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -Register
$sw.Stop()
Update-AppveyorTest -Name "appveyor.prep" -Framework NUnit -FileName "appveyor.prep.ps1" -Outcome Passed -Duration $sw.ElapsedMilliseconds