function Invoke-ManualPester {
<#
.SYNOPSIS
    Runs dbatools tests with support for both Pester v4 and v5.

.DESCRIPTION
    This is a helper function to automate running tests locally. It supports both Pester v4 and v5 tests,
    automatically detecting which version to use based on the test file requirements. For Pester v5 tests,
    it uses the new configuration system while maintaining backward compatibility with v4 tests.

.PARAMETER Path
    The Path to the test files to run. It accepts multiple test file paths passed in (e.g. .\Find-DbaOrphanedFile.Tests.ps1) as well
    as simple strings (e.g. "orphaned" will run all files matching .\*orphaned*.Tests.ps1)

.PARAMETER Show
    Gets passed down to Pester's -Show parameter (useful if you want to reduce verbosity)
    Valid values are: None, Default, Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header, All, Fails

.PARAMETER PassThru
    Gets passed down to Pester's -PassThru parameter (useful if you want to return an object to analyze)

.PARAMETER TestIntegration
    dbatools's suite has unittests and integrationtests. This switch enables IntegrationTests, which need live instances
    see Get-TestConfig for customizations

.PARAMETER Coverage
    Enables measuring code coverage on the tested function. For Pester v5 tests, this will generate coverage in JaCoCo format.

.PARAMETER DependencyCoverage
    Enables measuring code coverage also of "lower level" (i.e. called) functions

.PARAMETER ScriptAnalyzer
    Enables checking the called function's code with Invoke-ScriptAnalyzer, with dbatools's profile

.PARAMETER NoReimport
    By default, dbatools is reimported to ensure the latest version is used. This switch disables reimporting.

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -TestIntegration -Coverage -DependencyCoverage -ScriptAnalyzer

    The most complete number of checks:
    - Runs both unittests and integrationtests
    - Gathers and shows code coverage measurement for Find-DbaOrphanedFile and all its dependencies
    - Checks Find-DbaOrphanedFile with Invoke-ScriptAnalyzer
    - Automatically detects and uses the appropriate Pester version

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1

    Runs tests stored in Find-DbaOrphanedFile.Tests.ps1, automatically detecting whether to use Pester v4 or v5

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -PassThru

    Runs tests stored in Find-DbaOrphanedFile.Tests.ps1 and returns an object that can be analyzed

.EXAMPLE
    Invoke-ManualPester -Path orphan

    Runs tests for all tests matching in `*orphan*.Tests.ps1

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -Show Normal

    Runs tests stored in Find-DbaOrphanedFile.Tests.ps1, with reduced verbosity

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -TestIntegration

    Runs both unittests and integrationtests stored in Find-DbaOrphanedFile.Tests.ps1

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -TestIntegration -Coverage

    Gathers and shows code coverage measurement for Find-DbaOrphanedFile.
    For Pester v5 tests, this will generate coverage in JaCoCo format.

.EXAMPLE
    Invoke-ManualPester -Path Find-DbaOrphanedFile.Tests.ps1 -TestIntegration -Coverage -DependencyCoverage

    Gathers and shows code coverage measurement for Find-DbaOrphanedFile and all its dependencies.
    For Pester v5 tests, this will generate coverage in JaCoCo format.

.NOTES
    For Pester v5 tests, include the following requirement in your test file:
    #Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

    Tests without this requirement will be run using Pester v4.4.2.
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,
        [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$Show = "Normal",
        [switch]$PassThru,
        [switch]$TestIntegration,
        [switch]$Coverage,
        [switch]$DependencyCoverage,
        [switch]$ScriptAnalyzer,
        [switch]$NoReimport
    )
    begin {
        Write-Verbose "Starting"
        Remove-Module -Name Pester -ErrorAction SilentlyContinue
        $stopProcess = $false


        # Go up the folder structure until we find the root of the module, where dbatools.psd1 is located
        function Get-ModuleBase {
            $startOfSearch = $PSScriptRoot
            for ($i = 0; $i -lt 10; $i++) {
                if (Test-Path (Join-Path $startOfSearch 'dbatools.psd1')) {
                    $ModuleBase = $startOfSearch
                    break
                }
                $startOfSearch = Split-Path -Path $startOfSearch -Parent
            }
            return $ModuleBase
        }

        $ModuleBase = Get-ModuleBase

        if (-not $NoReimport) {
            Remove-Module dbatools -ErrorAction Ignore
            $splat = @{
                Name                = "$ModuleBase\dbatools.psm1"
                DisableNameChecking = $true
                Force               = $true
                NoClobber           = $true
                ErrorAction         = "SilentlyContinue"
                WarningAction       = "SilentlyContinue"
                Global              = $true
            }
            Import-Module @splat *> $null
        }

        function Get-CoverageIndications($Path, $ModuleBase) {
            # takes a test file path and figures out what to analyze for coverage (i.e. dependencies)
            $CBHRex = [regex]'(?smi)<#(.*)#>'
            $everything = (Get-Module dbatools).ExportedCommands.Values
            $everyfunction = $everything.Name
            $funcs = @()
            $leaf = Split-Path $path -Leaf
            # assuming Get-DbaFoo.Tests.ps1 wants coverage for "Get-DbaFoo"
            # but allowing also Get-DbaFoo.one.Tests.ps1 and Get-DbaFoo.two.Tests.ps1
            $func_name += ($leaf -replace '^([^.]+)(.+)?.Tests.ps1', '$1')
            if ($func_name -in $everyfunction) {
                $funcs += $func_name
                $f = $everything | Where-Object Name -eq $func_name
                $source = $f.Definition
                $CBH = $CBHRex.match($source).Value
                $cmdonly = $source.Replace($CBH, '')
                foreach ($e in $everyfunction) {
                    # hacky, I know, but every occurrence of any function plus a space kinda denotes usage !?
                    $searchme = "$e "
                    if ($cmdonly.contains($searchme)) {
                        $funcs += $e
                    }
                }
            }
            $testpaths = @()
            $allfiles = Get-ChildItem -File -Path "$ModuleBase\private\functions", "$ModuleBase\public" -Filter '*.ps1'
            foreach ($f in $funcs) {
                # exclude always used functions ?!
                if ($f -in ('Connect-DbaInstance', 'Select-DefaultView', 'Stop-Function', 'Write-Message')) { continue }
                # can I find a correspondence to a physical file (again, on the convenience of having Get-DbaFoo.ps1 actually defining Get-DbaFoo)?
                $res = $allfiles | Where-Object { $PSItem.Name.Replace('.ps1', '') -eq $f }
                if ($res.count -gt 0) {
                    $testpaths += $res.FullName
                }
            }
            return @() + ($testpaths | Select-Object -Unique)
        }

        function Get-PesterTestVersion($testFilePath) {
            $testFileContent = Get-Content -Path $testFilePath -Raw
            if ($testFileContent -match '#Requires\s+-Module\s+@\{\s+ModuleName="Pester";\s+ModuleVersion="5\.')
            {
                return '5'
            }
            return '4'
        }

        function Write-DetailedMessage($message) {
            if ($Show -in @('Normal', 'Detailed', 'Diagnostic')) {
                Write-Host -Object $message
            }
        }

        # Version requirements
        $ScriptAnalyzerRequiredVersion = '1.18.2'
        $MinimumPesterVersion = [Version]'4.0.0.0'
        $MaximumPesterVersion = [Version]'6.0.0.0'
        $TargetPesterVersion = [Version]'5.3.3'

        # Get all required modules at once (single expensive operation)
        $availableModules = @{}
        $foundModules = Get-Module -Name Pester, PSScriptAnalyzer -ListAvailable

        foreach ($module in $foundModules) {
            if (!$availableModules[$module.Name]) {
                $availableModules[$module.Name] = @()
            }
            $availableModules[$module.Name] += $module
        }

        # Sort versions once
        $moduleNames = @($availableModules.Keys)
        foreach ($name in $moduleNames) {
            $availableModules[$name] = $availableModules[$name] | Sort-Object Version -Descending
        }

        # If target Pester not found, use highest 5.x version
        if (-not ($availableModules.Pester | Where-Object Version -eq $TargetPesterVersion)) {
            $TargetPesterVersion = ($availableModules.Pester | Where-Object { $_.Version.Major -eq 5 } | Select-Object -First 1).Version
        }

        # PSScriptAnalyzer checks
        if (-not $availableModules.PSScriptAnalyzer) {
            Write-Warning "PSScriptAnalyzer not found. Please install with:"
            Write-Warning "Install-Module -Name PSScriptAnalyzer -RequiredVersion '$ScriptAnalyzerRequiredVersion'"
            Write-Warning "or go to https://github.com/PowerShell/PSScriptAnalyzer"
            return
        }

        $importedAnalyzerModule = Get-Module -Name PSScriptAnalyzer
        if (-not $importedAnalyzerModule -or $importedAnalyzerModule.Version.ToString() -ne $ScriptAnalyzerRequiredVersion) {
            if ($importedAnalyzerModule) { Remove-Module PSScriptAnalyzer -Force }
            try {
                Import-Module PSScriptAnalyzer -RequiredVersion $ScriptAnalyzerRequiredVersion -ErrorAction Stop
            } catch {
                if ($PSItem -notmatch "already loaded") {
                    Write-Warning "Failed to import PSScriptAnalyzer $ScriptAnalyzerRequiredVersion"
                    Write-Warning "Please install correct version: Install-Module -Name PSScriptAnalyzer -RequiredVersion '$ScriptAnalyzerRequiredVersion'"
                    return
                }
            }
        }

        # Pester checks
        if (-not $availableModules.Pester) {
            Write-Warning "Pester not found. Please install with:"
            Write-Warning "Install-Module -Name Pester -Force -SkipPublisherCheck"
            Write-Warning "or go to https://github.com/pester/Pester"
            return
        }

        $importedPesterModule = Get-Module -Name Pester
        $highestVersion = $availableModules.Pester[0].Version

        if ($highestVersion -lt $MinimumPesterVersion -or $highestVersion -gt $MaximumPesterVersion) {
            Write-Warning "Pester version must be between $MinimumPesterVersion and $MaximumPesterVersion"
            Write-Warning "Install-Module -Name Pester -RequiredVersion $TargetPesterVersion -Force -SkipPublisherCheck"
            return
        }

        if ($importedPesterModule -and $importedPesterModule.Version -ne $TargetPesterVersion) {
            Remove-Module Pester -Force
            Import-Module Pester -RequiredVersion $TargetPesterVersion -Force
        }
    }
    process  {
        if ($stopProcess) {
            return
        }

        $gitPath = Join-Path $ModuleBase '.git'
        if (-not(Test-Path $gitPath -Type Container)) {
            $null = New-Item -Type Container -Path $gitPath -Force
        }

        $ScriptAnalyzerRulesExclude = @('PSUseOutputTypeCorrectly', 'PSAvoidUsingPlainTextForPassword', 'PSUseBOMForUnicodeEncodedFile')

        $testInt = $false
        if ($config_TestIntegration) {
            $testInt = $true
        }
        if ($TestIntegration) {
            $testInt = $true
        }

        $files = @()

        if ($Path) {
            foreach ($item in $path) {
                if (Test-Path $item) {
                    $files += Get-ChildItem -Path $item
                } else {
                    $files += Get-ChildItem -Path "$ModuleBase\tests\*$item*.Tests.ps1"
                }
            }
        }

        if ($files.Length -eq 0) {
            Write-Warning "No tests to be run"
        }

        $AllTestsWithinScenario = $files



        foreach ($f in $AllTestsWithinScenario) {
            $pesterVersionToUse = Get-PesterTestVersion -testFilePath $f.FullName

            #opt-in
            $HeadFunctionPath = $f.FullName

            if ($Coverage -or $ScriptAnalyzer) {
                Write-DetailedMessage "Getting coverage indications for $f"
                $CoverFiles = Get-CoverageIndications -Path $f -ModuleBase $ModuleBase
                $HeadFunctionPath = $CoverFiles | Select-Object -First 1

            }
            if ($Coverage) {
                if ($DependencyCoverage) {
                    $CoverFilesPester = $CoverFiles
                    Write-DetailedMessage "We're going to target these files for coverage:"
                    foreach ($cf in $CoverFiles) {
                        Write-DetailedMessage "$cf"
                    }
                } else {
                    $CoverFilesPester = $HeadFunctionPath
                }
            }

            if ($pesterVersionToUse -eq '5') {
                Write-DetailedMessage "Running Pester 5 tests $($f.Name)"
                Remove-Module -Name pester -ErrorAction SilentlyContinue
                Import-Module pester -MinimumVersion 5.6.1 -ErrorAction Stop
                $pester5Config = New-PesterConfiguration
                $pester5Config.Run.Path = $f.FullName
                if ($PassThru){
                    $pester5config.Run.PassThru = [bool]$PassThru
                }
                $pester5config.Output.Verbosity = $show
                if ($Coverage) {
                    $pester5Config.CodeCoverage.Enabled = $true
                    $pester5Config.CodeCoverage.Path = $CoverFilesPester
                }
                if (!($testInt)) {
                    $pester5Config.Filter.ExcludeTag = "IntegrationTests"
                }
                Invoke-Pester -Configuration $pester5config
            }
            else {
                Write-DetailedMessage "Running Pester 4 tests $($f.FullName)"
                $pester4Show = 'Default'
                switch ($Show) {
                    'None' { $pester4Show = 'None' }
                    'Normal' { $pester4Show = 'Default' }
                    'Detailed' { $pester4Show = 'All' }
                    'Diagnostic' { $pester4Show = 'All' }
                }
                $PesterSplat = @{
                    'Script'   = $f.FullName
                    'Show'     = $pester4Show
                    'PassThru' = $passThru
                }
                if ($Coverage)
                {
                    $PesterSplat['CodeCoverage'] = $CoverFilesPester
                }
                if (!($testInt)) {
                    $PesterSplat['ExcludeTag'] = "IntegrationTests"
                }
                Invoke-Pester @PesterSplat
            }



            if ($ScriptAnalyzer) {
                if ($Show -ne "None") {
                    Write-Host -ForegroundColor green -Object "ScriptAnalyzer check for $HeadFunctionPath"
                }
                Invoke-ScriptAnalyzer -Path $HeadFunctionPath -ExcludeRule $ScriptAnalyzerRulesExclude
            }
        }
    }
}