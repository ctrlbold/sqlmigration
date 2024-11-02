function Update-PesterTest {
    <#
    .SYNOPSIS
        Updates Pester tests to v5 format for dbatools commands.

    .DESCRIPTION
        Updates existing Pester tests to v5 format for dbatools commands. This function processes test files
        and converts them to use the newer Pester v5 parameter validation syntax. It skips files that have
        already been converted or exceed the specified size limit.

    .PARAMETER InputObject
        Array of objects that can be either file paths, FileInfo objects, or command objects (from Get-Command).
        If not specified, will process commands from the dbatools module.

    .PARAMETER First
        Specifies the maximum number of commands to process.

    .PARAMETER Skip
        Specifies the number of commands to skip before processing.

    .PARAMETER PromptFilePath
        The path to the template file containing the prompt structure.
        Defaults to "/workspace/.aider/prompts/template.md".

    .PARAMETER CacheFilePath
        The path to the file containing cached conventions.

    .PARAMETER MaxFileSize
        The maximum size of test files to process in a single pass, in bytes. Files larger than this will be processed
        in segmented passes using prompts from the segmented directory. Defaults to 7.5kb.

    .PARAMETER Model
        The AI model to use (e.g., azure/gpt-4o, gpt-4o-mini, claude-3-5-sonnet).

    .PARAMETER LargeFileModel
        The AI model to use for files exceeding the MaxFileSize limit. Defaults to "gpt-4o-mini".

    .PARAMETER EditFormat
        Specifies the format for edits. Choices include "whole", "diff", "diff-fenced", "unified diff", "editor-diff", "editor-whole".

    .EXAMPLE
        PS C:\> Update-PesterTest
        Updates all eligible Pester tests to v5 format using default parameters.

    .EXAMPLE
        PS C:\> Update-PesterTest -First 10 -Skip 5
        Updates 10 test files starting from the 6th command, skipping the first 5.

    .EXAMPLE
        PS C:\> "C:\tests\Get-DbaDatabase.Tests.ps1", "C:\tests\Get-DbaBackup.Tests.ps1" | Update-PesterTest
        Updates the specified test files to v5 format.

    .EXAMPLE
        PS C:\> Get-Command -Module dbatools -Name "*Database*" | Update-PesterTest
        Updates test files for all commands in dbatools module that match "*Database*".

    .EXAMPLE
        PS C:\> Get-ChildItem ./tests/Add-DbaRegServer.Tests.ps1 | Update-PesterTest -Verbose
        Updates the specific test file from a Get-ChildItem result.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ValueFromPipeline)]
        [PSObject[]]$InputObject,
        [int]$First = 10000,
        [int]$Skip,
        [string[]]$PromptFilePath = "/workspace/.aider/prompts/template.md",
        [string[]]$CacheFilePath = @("/workspace/.aider/prompts/conventions.md", "/workspace/private/testing/Get-TestConfig.ps1"),
        [int]$MaxFileSize = 7.5kb,
        [string]$Model,
        [string]$LargeFileModel = "azure/gpt-4o-mini",
        [ValidateSet("whole", "diff", "diff-fenced", "unified diff", "editor-diff", "editor-whole")]
        [string]$EditFormat = "whole"
    )
    begin {
        $commandsToProcess = @()
    }

    process {
        # Populate commandsToProcess based on InputObject or fallback to default
        if ($InputObject) {
            foreach ($item in $InputObject) {
                Write-Verbose "Processing input object of type: $($item.GetType().FullName)"

                if ($item -is [System.Management.Automation.CommandInfo]) {
                    $commandsToProcess += $item
                } elseif ($item -is [System.IO.FileInfo]) {
                    $path = $item.FullName
                    if (Test-Path $path) {
                        $cmdName = [System.IO.Path]::GetFileNameWithoutExtension($path) -replace '\.Tests$', ''
                        $cmd = Get-Command -Name $cmdName -ErrorAction SilentlyContinue
                        if ($cmd) { $commandsToProcess += $cmd }
                        else { Write-Warning "No command found for test file: $path" }
                    }
                } elseif ($item -is [string]) {
                    if (Test-Path $item) {
                        $cmdName = [System.IO.Path]::GetFileNameWithoutExtension($item) -replace '\.Tests$', ''
                        $cmd = Get-Command -Name $cmdName -ErrorAction SilentlyContinue
                        if ($cmd) { $commandsToProcess += $cmd }
                        else { Write-Warning "No command found for test file: $item" }
                    }
                } else {
                    Write-Warning "Unsupported input type: $($item.GetType().FullName)"
                }
            }
        }
    }

    end {
        # Get default commands if no specific InputObject provided
        if (-not $commandsToProcess) {
            $commandsToProcess = Get-Command -Module dbatools -Type Function, Cmdlet | Select-Object -First $First -Skip $Skip
        }

        foreach ($command in $commandsToProcess) {
            $cmdName = $command.Name
            $filename = "/workspace/tests/$cmdName.Tests.ps1"
            $parameters = $command.Parameters.Values | Where-Object Name -notin $commonParameters

            if (-not (Test-Path $filename)) {
                Write-Warning "No tests found for $cmdName"
                continue
            }

            if (Select-String -Path $filename -Pattern "HaveParameter") {
                Write-Warning "Skipping $cmdName, already converted to Pester v5"
                continue
            }

            # Determine processing mode based on file size
            if ((Get-Item $filename).Length -gt $MaxFileSize) {
                # Process large files in segmented passes
                if ($PSBoundParameters.ContainsKey("PromptFilePath")) {
                    Write-Verbose "Using specified prompt file for segmented pass"
                    $files = Get-ChildItem -Path $PSBoundParameters.PromptFilePath
                } else {
                    Write-Verbose "Using default prompt files for segmented pass"
                    $files = Get-ChildItem -Path "/workspace/.aider/prompts/segmented" -Filter "*.md"
                }

                foreach ($file in $files) {
                    $cmdPrompt = (Get-Content $file.FullName) -join "`n"
                    $cmdPrompt = $cmdPrompt -replace "--CMDNAME--", $cmdName
                    $cmdPrompt = $cmdPrompt -replace "--PARMZ--", ($parameters.Name -join "`n")

                    if ($PSCmdlet.ShouldProcess($filename, "Update Pester test to v5 format - Segmented Pass")) {
                        $aiderParams = @{
                            Message      = $cmdPrompt
                            File         = $filename
                            YesAlways    = $true
                            NoStream     = $true
                            CachePrompts = $true
                            Model        = $LargeFileModel
                            EditFormat   = $EditFormat
                        }

                        Write-Verbose "Invoking Aider for segmented pass on $filename using $($file.Name)"
                        Invoke-Aider @aiderParams
                    }
                }
            } else {
                # Process smaller files normally
                $cmdPrompt = (Get-Content $PromptFilePath) -join "`n"
                $cmdPrompt = $cmdPrompt -replace "--CMDNAME--", $cmdName
                $cmdPrompt = $cmdPrompt -replace "--PARMZ--", ($parameters.Name -join "`n")

                if ($PSCmdlet.ShouldProcess($filename, "Update Pester test to v5 format")) {
                    $aiderParams = @{
                        Message      = $cmdPrompt
                        File         = $filename
                        YesAlways    = $true
                        NoStream     = $true
                        CachePrompts = $true
                        ReadFile     = $CacheFilePath
                        Model        = $Model
                        EditFormat   = $EditFormat
                    }

                    Write-Verbose "Invoking Aider to update test file normally"
                    Invoke-Aider @aiderParams
                }
            }
            if (-not $NoTest) {
                if ($script:xplat -contains $cmdName) {
                    Write-Warning "Running integration and unit tests for $filename"
                    aider --test --test-cmd "/workspace/tests/Configs/aider.test.ps1 -TestIntegration -ScriptAnalyzer $filename"
                } else {
                    Write-Warning "Running unit tests for $filename"
                    aider --test --test-cmd "/workspace/tests/Configs/aider.test.ps1 $filename"
                }
            }
        }
    }
}



function Repair-Error {
    <#
    .SYNOPSIS
        Repairs errors in dbatools Pester test files.

    .DESCRIPTION
        Processes and repairs errors found in dbatools Pester test files. This function reads error
        information from a JSON file and attempts to fix the identified issues in the test files.

    .PARAMETER First
        Specifies the maximum number of commands to process.

    .PARAMETER Skip
        Specifies the number of commands to skip before processing.

    .PARAMETER PromptFilePath
        The path to the template file containing the prompt structure.
        Defaults to "/workspace/.aider/prompts/fix-errors.md".

    .PARAMETER CacheFilePath
        The path to the file containing cached conventions.
        Defaults to "/workspace/.aider/prompts/conventions.md".

    .PARAMETER ErrorFilePath
        The path to the JSON file containing error information.
        Defaults to "/workspace/.aider/prompts/errors.json".

    .PARAMETER Model
        The AI model to use (e.g., azure/gpt-4o, gpt-4o-mini, claude-3-5-sonnet).

    .NOTES
        Tags: Testing, Pester, ErrorHandling
        Author: dbatools team

    .EXAMPLE
        PS C:\> Repair-Error
        Processes and attempts to fix all errors found in the error file using default parameters.

    .EXAMPLE
        PS C:\> Repair-Error -ErrorFilePath "custom-errors.json"
        Processes and repairs errors using a custom error file.
    #>
    [CmdletBinding()]
    param (
        [int]$First = 10000,
        [int]$Skip,
        [string[]]$PromptFilePath = "/workspace/.aider/prompts/fix-errors.md",
        [string[]]$CacheFilePath = "/workspace/.aider/prompts/conventions.md",
        [string]$ErrorFilePath = "/workspace/.aider/prompts/errors.json",
        [string]$Model
    )

    $promptTemplate = Get-Content $PromptFilePath
    $testerrors = Get-Content $ErrorFilePath | ConvertFrom-Json
    $commands = $testerrors | Select-Object -ExpandProperty Command -Unique | Sort-Object

    foreach ($command in $commands) {
        $filename = "/workspace/tests/$command.Tests.ps1"
        Write-Output "Processing $command"

        if (-not (Test-Path $filename)) {
            Write-Warning "No tests found for $command"
            Write-Warning "$filename not found"
            continue
        }

        $cmdPrompt = $promptTemplate -replace "--CMDNAME--", $command

        $testerr = $testerrors | Where-Object Command -eq $command
        foreach ($err in $testerr) {
            $cmdPrompt += "`n`n"
            $cmdPrompt += "Error: $($err.ErrorMessage)`n"
            $cmdPrompt += "Line: $($err.LineNumber)`n"
        }

        $aiderParams = @{
            Message      = $cmdPrompt
            File         = $filename
            NoStream     = $true
            CachePrompts = $true
            ReadFile     = $CacheFilePath
            Model        = $Model
        }

        Invoke-Aider @aiderParams
    }
}

function Repair-SmallThing {
    [cmdletbinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName", "FilePath", "File")]
        [object[]]$InputObject,
        [int]$First = 10000,
        [int]$Skip,
        [string]$Model = "azure/gpt-4o-mini",
        [string[]]$PromptFilePath,
        [ValidateSet("ReorgParamTest", "StartNewFile", "RefactorParamTest", "RemoveLines")]
        [string]$Type,
        [string]$EditorModel,
        [switch]$NoPretty,
        [switch]$NoStream,
        [switch]$YesAlways,
        [switch]$CachePrompts,
        [int]$MapTokens,
        [string]$MapRefresh,
        [int]$MaxFileSize = 7.5kb,
        [switch]$NoAutoLint,
        [switch]$AutoTest,
        [switch]$ShowPrompts,
        [ValidateSet("whole", "diff", "diff-fenced", "unified diff", "editor-diff", "editor-whole")]
        [string]$EditFormat,
        [string]$MessageFile,
        [string[]]$ReadFile,
        [string]$Encoding
    )

    begin {
        Write-Verbose "Starting Repair-SmallThing"
        $allObjects = @()

        $prompts = @{
            ReorgParamTest = '
            The parameter test should look like this (not actual parameters)

            Describe "Backup-DbaDbMasterKey" -Tag "UnitTests" {
                BeforeAll {
                    $command = Get-Command Backup-DbaDbMasterKey
                    $expected = $TestConfig.CommonParameters
                    $expected += @(
                        "SqlInstance",
                        "SqlCredential",
                        "Credential",
                        "Database",
                        "ExcludeDatabase",
                        "SecurePassword",
                        "Path",
                        "InputObject",
                        "EnableException",
                        "WhatIf",
                        "Confirm"
                    )
                }
                Context "Parameter validation" {'
        }
        Write-Verbose "Available prompt types: $($prompts.Keys -join ', ')"

        if ($PromptFilePath) {
            Write-Verbose "Loading prompt template from $PromptFilePath"
            $promptTemplate = Get-Content $PromptFilePath
            Write-Verbose "Prompt template loaded: $promptTemplate"
        }

        $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters

        Write-Verbose "Getting base dbatools commands with First: $First, Skip: $Skip"
        $baseCommands = Get-Command -Module dbatools -Type Function, Cmdlet | Select-Object -First $First -Skip $Skip
        Write-Verbose "Found $($baseCommands.Count) base commands"
    }

    process {
        if ($InputObject) {
            Write-Verbose "Adding objects to collection: $($InputObject -join ', ')"
            $allObjects += $InputObject
        }
    }

    end {
        Write-Verbose "Starting end block processing"

        if ($InputObject.Count -eq 0) {
            Write-Verbose "No input objects provided, getting commands from dbatools module"
            $allObjects += Get-Command -Module dbatools -Type Function, Cmdlet | Select-Object -First $First -Skip $Skip
        }

        if (-not $PromptFilePath -and -not $Type) {
            Write-Verbose "Neither PromptFilePath nor Type specified"
            throw "You must specify either PromptFilePath or Type"
        }

        # Process different input types
        $commands = @()
        foreach ($object in $allObjects) {
            switch ($object.GetType().FullName) {
                'System.IO.FileInfo' {
                    Write-Verbose "Processing FileInfo object: $($object.FullName)"
                    $cmdName = [System.IO.Path]::GetFileNameWithoutExtension($object.Name) -replace '\.Tests$', ''
                    $commands += $baseCommands | Where-Object Name -eq $cmdName
                }
                'System.Management.Automation.CommandInfo' {
                    Write-Verbose "Processing CommandInfo object: $($object.Name)"
                    $commands += $object
                }
                'System.String' {
                    Write-Verbose "Processing string path: $object"
                    if (Test-Path $object) {
                        $cmdName = [System.IO.Path]::GetFileNameWithoutExtension($object) -replace '\.Tests$', ''
                        $commands += $baseCommands | Where-Object Name -eq $cmdName
                    } else {
                        Write-Warning "Path not found: $object"
                    }
                }
                'System.Management.Automation.FunctionInfo' {
                    Write-Verbose "Processing FunctionInfo object: $($object.Name)"
                    $commands += $object
                }
                default {
                    Write-Warning "Unsupported input type: $($object.GetType().FullName)"
                }
            }
        }

        Write-Verbose "Processing $($commands.Count) unique commands"
        $commands = $commands | Select-Object -Unique

        foreach ($command in $commands) {
            $cmdName = $command.Name
            Write-Verbose "Processing command: $cmdName"

            $filename = "/workspace/tests/$cmdName.Tests.ps1"
            Write-Verbose "Using test path: $filename"

            if (-not (Test-Path $filename)) {
                Write-Warning "No tests found for $cmdName"
                Write-Warning "$filename not found"
                continue
            }

            # if file is larger than MaxFileSize, skip
            if ((Get-Item $filename).Length -gt $MaxFileSize) {
                Write-Warning "Skipping $cmdName because it's too large"
                continue
            }

            if ($Type) {
                Write-Verbose "Using predefined prompt for type: $Type"
                $cmdPrompt = $prompts[$Type]
            } else {
                Write-Verbose "Getting parameters for $cmdName"
                $parameters = $command.Parameters.Values | Where-Object Name -notin $commonParameters
                $parameters = $parameters.Name -join ", "
                Write-Verbose "Command parameters: $parameters"

                Write-Verbose "Using template prompt with parameters substitution"
                $cmdPrompt = $promptTemplate -replace "--PARMZ--", $parameters
            }
            Write-Verbose "Final prompt: $cmdPrompt"

            $aiderParams = @{
                Message = $cmdPrompt
                File    = $filename
            }

            $excludedParams = @(
                $commonParameters,
                'InputObject',
                'First',
                'Skip',
                'PromptFilePath',
                'Type',
                'MaxFileSize'
            )

            $PSBoundParameters.GetEnumerator() |
                Where-Object Key -notin $excludedParams |
                ForEach-Object {
                    $aiderParams[$PSItem.Key] = $PSItem.Value
                }

            if (-not $PSBoundParameters.Model) {
                $aiderParams.Model = $Model
            }

            Write-Verbose "Invoking aider for $cmdName"
            try {
                Invoke-Aider @aiderParams
                Write-Verbose "Aider completed successfully for $cmdName"
            } catch {
                Write-Error "Error executing aider for $cmdName`: $_"
                Write-Verbose "Aider failed for $cmdName with error: $_"
            }
        }
        Write-Verbose "Repair-SmallThing completed"
    }
}

function Invoke-Aider {
    <#
    .SYNOPSIS
        Invokes the aider AI pair programming tool.

    .DESCRIPTION
        The Invoke-Aider function provides a PowerShell interface to the aider AI pair programming tool.
        It supports all aider CLI options and can accept files via pipeline from Get-ChildItem.

    .PARAMETER Message
        The message to send to the AI. This is the primary way to communicate your intent.

    .PARAMETER File
        The files to edit. Can be piped in from Get-ChildItem.

    .PARAMETER Model
        The AI model to use (e.g., gpt-4, claude-3-opus-20240229).

    .PARAMETER EditorModel
        The model to use for editor tasks.

    .PARAMETER NoPretty
        Disable pretty, colorized output.

    .PARAMETER NoStream
        Disable streaming responses.

    .PARAMETER YesAlways
        Always say yes to every confirmation.

    .PARAMETER CachePrompts
        Enable caching of prompts.

    .PARAMETER MapTokens
        Suggested number of tokens to use for repo map.

    .PARAMETER MapRefresh
        Control how often the repo map is refreshed.

    .PARAMETER NoAutoLint
        Disable automatic linting after changes.

    .PARAMETER AutoTest
        Enable automatic testing after changes.

    .PARAMETER ShowPrompts
        Print the system prompts and exit.

    .PARAMETER EditFormat
        Specify what edit format the LLM should use.

    .PARAMETER MessageFile
        Specify a file containing the message to send.

    .PARAMETER ReadFile
        Specify read-only files.

    .PARAMETER Encoding
        Specify the encoding for input and output.

    .EXAMPLE
        Invoke-Aider -Message "Fix the bug" -File script.ps1

        Asks aider to fix a bug in script.ps1.

    .EXAMPLE
        Get-ChildItem *.ps1 | Invoke-Aider -Message "Add error handling"

        Adds error handling to all PowerShell files in the current directory.

    .EXAMPLE
        Invoke-Aider -Message "Update API" -Model gpt-4 -NoStream

        Uses GPT-4 to update API code without streaming output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$File,
        [string]$Model,
        [string]$EditorModel,
        [switch]$NoPretty,
        [switch]$NoStream,
        [switch]$YesAlways,
        [switch]$CachePrompts,
        [int]$MapTokens,
        [ValidateSet('auto', 'always', 'files', 'manual')]
        [string]$MapRefresh,
        [switch]$NoAutoLint,
        [switch]$AutoTest,
        [switch]$ShowPrompts,
        [ValidateSet("whole", "diff", "diff-fenced", "unified diff", "editor-diff", "editor-whole")]
        [string]$EditFormat,
        [string]$MessageFile,
        [string[]]$ReadFile,
        [ValidateSet('utf-8', 'ascii', 'unicode', 'utf-16', 'utf-32', 'utf-7')]
        [string]$Encoding
    )

    begin {
        $allFiles = @()

        if (-not (Get-Command -Name aider -ErrorAction SilentlyContinue)) {
            throw "Aider executable not found. Please ensure it is installed and in your PATH."
        }
    }

    process {
        if ($File) {
            $allFiles += $File
        }
    }

    end {
        $arguments = @()

        # Add files if any were specified or piped in
        if ($allFiles) {
            $arguments += $allFiles
        }

        # Add mandatory message parameter
        if ($Message) {
            $arguments += "--message", $Message
        }

        # Add optional parameters only if they are present
        if ($Model) {
            $arguments += "--model", $Model
        }

        if ($EditorModel) {
            $arguments += "--editor-model", $EditorModel
        }

        if ($NoPretty) {
            $arguments += "--no-pretty"
        }

        if ($NoStream) {
            $arguments += "--no-stream"
        }

        if ($YesAlways) {
            $arguments += "--yes-always"
        }

        if ($CachePrompts) {
            $arguments += "--cache-prompts"
        }

        if ($PSBoundParameters.ContainsKey('MapTokens')) {
            $arguments += "--map-tokens", $MapTokens
        }

        if ($MapRefresh) {
            $arguments += "--map-refresh", $MapRefresh
        }

        if ($NoAutoLint) {
            $arguments += "--no-auto-lint"
        }

        if ($AutoTest) {
            $arguments += "--auto-test"
        }

        if ($ShowPrompts) {
            $arguments += "--show-prompts"
        }

        if ($EditFormat) {
            $arguments += "--edit-format", $EditFormat
        }

        if ($MessageFile) {
            $arguments += "--message-file", $MessageFile
        }

        if ($ReadFile) {
            foreach ($file in $ReadFile) {
                $arguments += "--read", $file
            }
        }

        if ($Encoding) {
            $arguments += "--encoding", $Encoding
        }

        if ($VerbosePreference -eq 'Continue') {
            Write-Verbose "Executing: aider $($arguments -join ' ')"
        }

        aider @arguments
    }
}

function Repair-Error {
    <#
    .SYNOPSIS
        Repairs errors in dbatools Pester test files.

    .DESCRIPTION
        Processes and repairs errors found in dbatools Pester test files. This function reads error
        information from a JSON file and attempts to fix the identified issues in the test files.

    .PARAMETER First
        Specifies the maximum number of commands to process.

    .PARAMETER Skip
        Specifies the number of commands to skip before processing.

    .PARAMETER PromptFilePath
        The path to the template file containing the prompt structure.
        Defaults to "/workspace/.aider/prompts/fix-errors.md".

    .PARAMETER CacheFilePath
        The path to the file containing cached conventions.
        Defaults to "/workspace/.aider/prompts/conventions.md".

    .PARAMETER ErrorFilePath
        The path to the JSON file containing error information.
        Defaults to "/workspace/.aider/prompts/errors.json".

    .PARAMETER Model
        The AI model to use (e.g., azure/gpt-4o, gpt-4o-mini, claude-3-5-sonnet).

    .NOTES
        Tags: Testing, Pester, ErrorHandling
        Author: dbatools team

    .EXAMPLE
        PS C:\> Repair-Error
        Processes and attempts to fix all errors found in the error file using default parameters.

    .EXAMPLE
        PS C:\> Repair-Error -ErrorFilePath "custom-errors.json"
        Processes and repairs errors using a custom error file.
    #>
    [CmdletBinding()]
    param (
        [int]$First = 10000,
        [int]$Skip,
        [string[]]$PromptFilePath = "/workspace/.aider/prompts/fix-errors.md",
        [string[]]$CacheFilePath = "/workspace/.aider/prompts/conventions.md",
        [string]$ErrorFilePath = "/workspace/.aider/prompts/errors.json",
        [string]$Model
    )

    $promptTemplate = Get-Content $PromptFilePath
    $testerrors = Get-Content $ErrorFilePath | ConvertFrom-Json
    $commands = $testerrors | Select-Object -ExpandProperty Command -Unique | Sort-Object

    foreach ($command in $commands) {
        $filename = "/workspace/tests/$command.Tests.ps1"
        Write-Output "Processing $command"

        if (-not (Test-Path $filename)) {
            Write-Warning "No tests found for $command"
            Write-Warning "$filename not found"
            continue
        }

        $cmdPrompt = $promptTemplate -replace "--CMDNAME--", $command

        $testerr = $testerrors | Where-Object Command -eq $command
        foreach ($err in $testerr) {
            $cmdPrompt += "`n`n"
            $cmdPrompt += "Error: $($err.ErrorMessage)`n"
            $cmdPrompt += "Line: $($err.LineNumber)`n"
        }

        $aiderParams = @{
            Message      = $cmdPrompt
            File         = $filename
            NoStream     = $true
            CachePrompts = $true
            ReadFile     = $CacheFilePath
            Model        = $Model
        }

        Invoke-Aider @aiderParams

        if (-not $NoTest) {
            aider --test-cmd Invoke-ManualPester -NoReimport $filename
        }
    }
}


Write-Verbose "Checking for dbatools.library module"
if (-not (Get-Module dbatools.library -ListAvailable)) {
    Write-Verbose "dbatools.library not found, installing"
    Install-Module dbatools.library -Scope CurrentUser -Force -Verbose:$false
}

if (-not (Get-Command Get-DbaDatabase -ErrorAction SilentlyContinue)) {
    Write-Verbose "Importing dbatools module from /workspace/dbatools.psm1"
    Import-Module /workspace/dbatools.psm1 -Force -Verbose:$false
}


$script:xplat = @(
    'Start-DbaMigration',
    'Copy-DbaDatabase',
    'Copy-DbaLogin',
    'Copy-DbaAgentServer',
    'Copy-DbaSpConfigure',
    'Copy-DbaDbMail',
    'Copy-DbaDbAssembly',
    'Copy-DbaAgentSchedule',
    'Copy-DbaAgentOperator',
    'Copy-DbaAgentJob',
    'Copy-DbaCustomError',
    'Copy-DbaInstanceAuditSpecification',
    'Copy-DbaEndpoint',
    'Copy-DbaInstanceAudit',
    'Copy-DbaServerRole',
    'Copy-DbaResourceGovernor',
    'Copy-DbaXESession',
    'Copy-DbaInstanceTrigger',
    'Copy-DbaRegServer',
    'Copy-DbaSystemDbUserObject',
    'Copy-DbaAgentProxy',
    'Copy-DbaAgentAlert',
    'Copy-DbaStartupProcedure',
    'Get-DbaDbDetachedFileInfo',
    'Copy-DbaAgentJobCategory',
    'Get-DbaLinkedServerLogin',
    'Test-DbaPath',
    'Export-DbaLogin',
    'Watch-DbaDbLogin',
    'Expand-DbaDbLogFile',
    'Test-DbaMigrationConstraint',
    'Test-DbaNetworkLatency',
    'Find-DbaDbDuplicateIndex',
    'Remove-DbaDatabaseSafely',
    'Set-DbaTempdbConfig',
    'Test-DbaTempdbConfig',
    'Repair-DbaDbOrphanUser',
    'Remove-DbaDbOrphanUser',
    'Find-DbaDbUnusedIndex',
    'Get-DbaDbSpace',
    'Test-DbaDbOwner',
    'Set-DbaDbOwner',
    'Test-DbaAgentJobOwner',
    'Set-DbaAgentJobOwner',
    'Measure-DbaDbVirtualLogFile',
    'Get-DbaDbRestoreHistory',
    'Get-DbaTcpPort',
    'Test-DbaDbCompatibility',
    'Test-DbaDbCollation',
    'Test-DbaConnectionAuthScheme',
    'Test-DbaInstanceName',
    'Repair-DbaInstanceName',
    'Stop-DbaProcess',
    'Find-DbaOrphanedFile',
    'Get-DbaAvailabilityGroup',
    'Get-DbaLastGoodCheckDb',
    'Get-DbaProcess',
    'Get-DbaRunningJob',
    'Set-DbaMaxDop',
    'Test-DbaDbRecoveryModel',
    'Test-DbaMaxDop',
    'Remove-DbaBackup',
    'Get-DbaPermission',
    'Get-DbaLastBackup',
    'Connect-DbaInstance',
    'Get-DbaDbBackupHistory',
    'Get-DbaAgBackupHistory',
    'Read-DbaBackupHeader',
    'Test-DbaLastBackup',
    'Get-DbaMaxMemory',
    'Set-DbaMaxMemory',
    'Get-DbaDbSnapshot',
    'Remove-DbaDbSnapshot',
    'Get-DbaDbRoleMember',
    'Get-DbaServerRoleMember',
    'Get-DbaDbAsymmetricKey',
    'New-DbaDbAsymmetricKey',
    'Remove-DbaDbAsymmetricKey',
    'Invoke-DbaDbTransfer',
    'Invoke-DbaDbAzSqlTips',
    'New-DbaDbTransfer',
    'Remove-DbaDbData',
    'Resolve-DbaNetworkName',
    'Export-DbaAvailabilityGroup',
    'Write-DbaDbTableData',
    'New-DbaDbSnapshot',
    'Restore-DbaDbSnapshot',
    'Get-DbaInstanceTrigger',
    'Get-DbaDbTrigger',
    'Get-DbaDbState',
    'Set-DbaDbState',
    'Get-DbaHelpIndex',
    'Get-DbaAgentAlert',
    'Get-DbaAgentOperator',
    'Get-DbaSpConfigure',
    'Rename-DbaLogin',
    'Find-DbaAgentJob',
    'Find-DbaDatabase',
    'Get-DbaXESession',
    'Export-DbaXESession',
    'Test-DbaOptimizeForAdHoc',
    'Find-DbaStoredProcedure',
    'Measure-DbaBackupThroughput',
    'Get-DbaDatabase',
    'Find-DbaUserObject',
    'Get-DbaDependency',
    'Find-DbaCommand',
    'Backup-DbaDatabase',
    'Test-DbaBackupEncrypted',
    'New-DbaDirectory',
    'Get-DbaDbQueryStoreOption',
    'Set-DbaDbQueryStoreOption',
    'Restore-DbaDatabase',
    'Get-DbaDbFileMapping',
    'Copy-DbaDbQueryStoreOption',
    'Get-DbaExecutionPlan',
    'Export-DbaExecutionPlan',
    'Set-DbaSpConfigure',
    'Test-DbaIdentityUsage',
    'Get-DbaDbAssembly',
    'Get-DbaAgentJob',
    'Get-DbaCustomError',
    'Get-DbaCredential',
    'Get-DbaBackupDevice',
    'Get-DbaAgentProxy',
    'Get-DbaDbEncryption',
    'Disable-DbaDbEncryption',
    'Enable-DbaDbEncryption',
    'Get-DbaDbEncryptionKey',
    'New-DbaDbEncryptionKey',
    'Remove-DbaDbEncryptionKey',
    'Start-DbaDbEncryption',
    'Stop-DbaDbEncryption',
    'Remove-DbaDatabase',
    'Get-DbaQueryExecutionTime',
    'Get-DbaTempdbUsage',
    'Find-DbaDbGrowthEvent',
    'Test-DbaLinkedServerConnection',
    'Get-DbaDbFile',
    'Get-DbaDbFileGrowth',
    'Set-DbaDbFileGrowth',
    'Read-DbaTransactionLog',
    'Get-DbaDbTable',
    'Remove-DbaDbTable',
    'Invoke-DbaDbShrink',
    'Get-DbaEstimatedCompletionTime',
    'Get-DbaLinkedServer',
    'New-DbaAgentJob',
    'Get-DbaLogin',
    'New-DbaScriptingOption',
    'Save-DbaDiagnosticQueryScript',
    'Invoke-DbaDiagnosticQuery',
    'Export-DbaDiagnosticQuery',
    'Invoke-DbaWhoIsActive',
    'Set-DbaAgentJob',
    'Remove-DbaAgentJob',
    'New-DbaAgentJobStep',
    'Set-DbaAgentJobStep',
    'Remove-DbaAgentJobStep',
    'New-DbaAgentSchedule',
    'Set-DbaAgentSchedule',
    'Remove-DbaAgentSchedule',
    'Backup-DbaDbCertificate',
    'Get-DbaDbCertificate',
    'Copy-DbaDbCertificate',
    'Get-DbaEndpoint',
    'Get-DbaDbMasterKey',
    'Get-DbaSchemaChangeHistory',
    'Get-DbaInstanceAudit',
    'Get-DbaInstanceAuditSpecification',
    'Get-DbaProductKey',
    'Get-DbatoolsError',
    'Get-DbatoolsLog',
    'Restore-DbaDbCertificate',
    'New-DbaDbCertificate',
    'New-DbaDbMasterKey',
    'New-DbaServiceMasterKey',
    'Remove-DbaDbCertificate',
    'Remove-DbaDbMasterKey',
    'Get-DbaInstanceProperty',
    'Get-DbaInstanceUserOption',
    'New-DbaConnectionString',
    'Get-DbaAgentSchedule',
    'Read-DbaTraceFile',
    'Get-DbaInstanceInstallDate',
    'Backup-DbaDbMasterKey',
    'Get-DbaAgentJobHistory',
    'Get-DbaMaintenanceSolutionLog',
    'Invoke-DbaDbLogShipRecovery',
    'Find-DbaTrigger',
    'Find-DbaView',
    'Invoke-DbaDbUpgrade',
    'Get-DbaDbUser',
    'Get-DbaAgentLog',
    'Get-DbaDbMailLog',
    'Get-DbaDbMailHistory',
    'Get-DbaDbView',
    'Remove-DbaDbView',
    'New-DbaSqlParameter',
    'Get-DbaDbUdf',
    'Get-DbaDbPartitionFunction',
    'Get-DbaDbPartitionScheme',
    'Remove-DbaDbPartitionScheme',
    'Remove-DbaDbPartitionFunction',
    'Get-DbaDefaultPath',
    'Get-DbaDbStoredProcedure',
    'Test-DbaDbCompression',
    'Mount-DbaDatabase',
    'Dismount-DbaDatabase',
    'Get-DbaAgReplica',
    'Get-DbaAgDatabase',
    'Get-DbaModule',
    'Sync-DbaLoginPermission',
    'New-DbaCredential',
    'Get-DbaFile',
    'Set-DbaDbCompression',
    'Get-DbaTraceFlag',
    'Invoke-DbaCycleErrorLog',
    'Get-DbaAvailableCollation',
    'Get-DbaUserPermission',
    'Get-DbaAgHadr',
    'Find-DbaSimilarTable',
    'Get-DbaTrace',
    'Get-DbaSuspectPage',
    'Get-DbaWaitStatistic',
    'Clear-DbaWaitStatistics',
    'Get-DbaTopResourceUsage',
    'New-DbaLogin',
    'Get-DbaAgListener',
    'Invoke-DbaDbClone',
    'Disable-DbaTraceFlag',
    'Enable-DbaTraceFlag',
    'Start-DbaAgentJob',
    'Stop-DbaAgentJob',
    'New-DbaAgentProxy',
    'Test-DbaDbLogShipStatus',
    'Get-DbaXESessionTarget',
    'New-DbaXESmartTargetResponse',
    'New-DbaXESmartTarget',
    'Get-DbaDbVirtualLogFile',
    'Get-DbaBackupInformation',
    'Start-DbaXESession',
    'Stop-DbaXESession',
    'Set-DbaDbRecoveryModel',
    'Get-DbaDbRecoveryModel',
    'Get-DbaWaitingTask',
    'Remove-DbaDbUser',
    'Get-DbaDump',
    'Invoke-DbaAdvancedRestore',
    'Format-DbaBackupInformation',
    'Get-DbaAgentJobStep',
    'Test-DbaBackupInformation',
    'Invoke-DbaBalanceDataFiles',
    'Select-DbaBackupInformation',
    'Publish-DbaDacPackage',
    'Copy-DbaDbTableData',
    'Copy-DbaDbViewData',
    'Invoke-DbaQuery',
    'Remove-DbaLogin',
    'Get-DbaAgentJobCategory',
    'New-DbaAgentJobCategory',
    'Remove-DbaAgentJobCategory',
    'Set-DbaAgentJobCategory',
    'Get-DbaServerRole',
    'Find-DbaBackup',
    'Remove-DbaXESession',
    'New-DbaXESession',
    'Get-DbaXEStore',
    'New-DbaXESmartTableWriter',
    'New-DbaXESmartReplay',
    'New-DbaXESmartEmail',
    'New-DbaXESmartQueryExec',
    'Start-DbaXESmartTarget',
    'Get-DbaDbOrphanUser',
    'Get-DbaOpenTransaction',
    'Get-DbaDbLogShipError',
    'Test-DbaBuild',
    'Get-DbaXESessionTemplate',
    'ConvertTo-DbaXESession',
    'Start-DbaTrace',
    'Stop-DbaTrace',
    'Remove-DbaTrace',
    'Set-DbaLogin',
    'Copy-DbaXESessionTemplate',
    'Get-DbaXEObject',
    'ConvertTo-DbaDataTable',
    'Find-DbaDbDisabledIndex',
    'Get-DbaXESmartTarget',
    'Remove-DbaXESmartTarget',
    'Stop-DbaXESmartTarget',
    'Get-DbaRegServerGroup',
    'New-DbaDbUser',
    'Measure-DbaDiskSpaceRequirement',
    'New-DbaXESmartCsvWriter',
    'Invoke-DbaXeReplay',
    'Find-DbaInstance',
    'Test-DbaDiskSpeed',
    'Get-DbaDbExtentDiff',
    'Read-DbaAuditFile',
    'Get-DbaDbCompression',
    'Invoke-DbaDbDecryptObject',
    'Get-DbaDbForeignKey',
    'Get-DbaDbCheckConstraint',
    'Remove-DbaDbCheckConstraint',
    'Set-DbaAgentAlert',
    'Get-DbaWaitResource',
    'Get-DbaDbPageInfo',
    'Get-DbaConnection',
    'Test-DbaLoginPassword',
    'Get-DbaErrorLogConfig',
    'Set-DbaErrorLogConfig',
    'Get-DbaPlanCache',
    'Clear-DbaPlanCache',
    'ConvertTo-DbaTimeline',
    'Get-DbaDbMail',
    'Get-DbaDbMailAccount',
    'Get-DbaDbMailProfile',
    'Get-DbaDbMailConfig',
    'Get-DbaDbMailServer',
    'New-DbaDbMailServer',
    'New-DbaDbMailAccount',
    'New-DbaDbMailProfile',
    'Get-DbaResourceGovernor',
    'Get-DbaRgResourcePool',
    'Get-DbaRgWorkloadGroup',
    'Get-DbaRgClassifierFunction',
    'Export-DbaInstance',
    'Invoke-DbatoolsRenameHelper',
    'Measure-DbatoolsImport',
    'Get-DbaDeprecatedFeature',
    'Test-DbaDeprecatedFeature'
    'Get-DbaDbFeatureUsage',
    'Stop-DbaEndpoint',
    'Start-DbaEndpoint',
    'Set-DbaDbMirror',
    'Repair-DbaDbMirror',
    'Remove-DbaEndpoint',
    'Remove-DbaDbMirrorMonitor',
    'Remove-DbaDbMirror',
    'New-DbaEndpoint',
    'Invoke-DbaDbMirroring',
    'Invoke-DbaDbMirrorFailover',
    'Get-DbaDbMirrorMonitor',
    'Get-DbaDbMirror',
    'Add-DbaDbMirrorMonitor',
    'Test-DbaEndpoint',
    'Get-DbaDbSharePoint',
    'Get-DbaDbMemoryUsage',
    'Clear-DbaLatchStatistics',
    'Get-DbaCpuRingBuffer',
    'Get-DbaIoLatency',
    'Get-DbaLatchStatistic',
    'Get-DbaSpinLockStatistic',
    'Add-DbaAgDatabase',
    'Add-DbaAgListener',
    'Add-DbaAgReplica',
    'Grant-DbaAgPermission',
    'Invoke-DbaAgFailover',
    'Join-DbaAvailabilityGroup',
    'New-DbaAvailabilityGroup',
    'Remove-DbaAgDatabase',
    'Remove-DbaAgListener',
    'Remove-DbaAvailabilityGroup',
    'Revoke-DbaAgPermission',
    'Get-DbaDbCompatibility',
    'Set-DbaDbCompatibility',
    'Invoke-DbatoolsFormatter',
    'Remove-DbaAgReplica',
    'Resume-DbaAgDbDataMovement',
    'Set-DbaAgListener',
    'Set-DbaAgReplica',
    'Set-DbaAvailabilityGroup',
    'Set-DbaEndpoint',
    'Suspend-DbaAgDbDataMovement',
    'Sync-DbaAvailabilityGroup',
    'Get-DbaMemoryCondition',
    'Remove-DbaDbBackupRestoreHistory',
    'New-DbaDatabase'
    'New-DbaDacOption',
    'Get-DbaDbccHelp',
    'Get-DbaDbccMemoryStatus',
    'Get-DbaDbccProcCache',
    'Get-DbaDbccUserOption',
    'Get-DbaAgentServer',
    'Set-DbaAgentServer',
    'Invoke-DbaDbccFreeCache'
    'Export-DbatoolsConfig',
    'Import-DbatoolsConfig',
    'Reset-DbatoolsConfig',
    'Unregister-DbatoolsConfig',
    'Join-DbaPath',
    'Resolve-DbaPath',
    'Import-DbaCsv',
    'Invoke-DbaDbDataMasking',
    'New-DbaDbMaskingConfig',
    'Get-DbaDbccSessionBuffer',
    'Get-DbaDbccStatistic',
    'Get-DbaDbDbccOpenTran',
    'Invoke-DbaDbccDropCleanBuffer',
    'Invoke-DbaDbDbccCheckConstraint',
    'Invoke-DbaDbDbccCleanTable',
    'Invoke-DbaDbDbccUpdateUsage',
    'Get-DbaDbIdentity',
    'Set-DbaDbIdentity',
    'Get-DbaRegServer',
    'Get-DbaRegServerStore',
    'Add-DbaRegServer',
    'Add-DbaRegServerGroup',
    'Export-DbaRegServer',
    'Import-DbaRegServer',
    'Move-DbaRegServer',
    'Move-DbaRegServerGroup',
    'Remove-DbaRegServer',
    'Remove-DbaRegServerGroup',
    'New-DbaCustomError',
    'Remove-DbaCustomError',
    'Get-DbaDbSequence',
    'New-DbaDbSequence',
    'Remove-DbaDbSequence',
    'Select-DbaDbSequenceNextValue',
    'Set-DbaDbSequence',
    'Get-DbaDbUserDefinedTableType',
    'Get-DbaDbServiceBrokerService',
    'Get-DbaDbServiceBrokerQueue ',
    'Set-DbaResourceGovernor',
    'New-DbaRgResourcePool',
    'Set-DbaRgResourcePool',
    'Remove-DbaRgResourcePool',
    'Get-DbaDbServiceBrokerQueue',
    'New-DbaLinkedServer',
    # Config system
    'Get-DbatoolsConfig',
    'Get-DbatoolsConfigValue',
    'Set-DbatoolsConfig',
    'Register-DbatoolsConfig',
    # Data generator
    'New-DbaDbDataGeneratorConfig',
    'Invoke-DbaDbDataGenerator',
    'Get-DbaRandomizedValue',
    'Get-DbaRandomizedDatasetTemplate',
    'Get-DbaRandomizedDataset',
    'Get-DbaRandomizedType',
    'Export-DbaDbTableData',
    'Export-DbaBinaryFile',
    'Import-DbaBinaryFile',
    'Get-DbaBinaryFileTable',
    'Backup-DbaServiceMasterKey',
    'Invoke-DbaDbPiiScan',
    'New-DbaAzAccessToken',
    'Add-DbaDbRoleMember',
    'Disable-DbaStartupProcedure',
    'Enable-DbaStartupProcedure',
    'Get-DbaDbFilegroup',
    'Get-DbaDbObjectTrigger',
    'Get-DbaStartupProcedure',
    'Get-DbatoolsChangeLog',
    'Get-DbaXESessionTargetFile',
    'Get-DbaDbRole',
    'New-DbaDbRole',
    'New-DbaDbTable',
    'New-DbaDiagnosticAdsNotebook',
    'New-DbaServerRole',
    'Remove-DbaDbRole',
    'Remove-DbaDbRoleMember',
    'Remove-DbaServerRole',
    'Test-DbaDbDataGeneratorConfig',
    'Test-DbaDbDataMaskingConfig',
    'Get-DbaAgentAlertCategory',
    'New-DbaAgentAlertCategory',
    'Install-DbaAgentAdminAlert',
    'Remove-DbaAgentAlert',
    'Remove-DbaAgentAlertCategory',
    'Save-DbaKbUpdate',
    'Get-DbaKbUpdate',
    'Get-DbaDbLogSpace',
    'Export-DbaDbRole',
    'Export-DbaServerRole',
    'Get-DbaBuild',
    'Update-DbaBuildReference',
    'Install-DbaFirstResponderKit',
    'Install-DbaWhoIsActive',
    'Update-Dbatools',
    'Add-DbaServerRoleMember',
    'Get-DbatoolsPath',
    'Set-DbatoolsPath',
    'Export-DbaSysDbUserObject',
    'Test-DbaDbQueryStore',
    'Install-DbaMultiTool',
    'New-DbaAgentOperator',
    'Remove-DbaAgentOperator',
    'Remove-DbaDbTableData',
    'Get-DbaDbSchema',
    'New-DbaDbSchema',
    'Set-DbaDbSchema',
    'Remove-DbaDbSchema',
    'Get-DbaDbSynonym',
    'New-DbaDbSynonym',
    'Remove-DbaDbSynonym',
    'Install-DbaDarlingData',
    'New-DbaDbFileGroup',
    'Remove-DbaDbFileGroup',
    'Set-DbaDbFileGroup',
    'Remove-DbaLinkedServer',
    'Test-DbaAvailabilityGroup',
    'Export-DbaUser',
    'Get-DbaSsisExecutionHistory',
    'New-DbaConnectionStringBuilder',
    'New-DbatoolsSupportPackage',
    'Export-DbaScript',
    'Get-DbaAgentJobOutputFile',
    'Set-DbaAgentJobOutputFile',
    'Import-DbaXESessionTemplate',
    'Export-DbaXESessionTemplate',
    'Import-DbaSpConfigure',
    'Export-DbaSpConfigure',
    'Test-DbaMaxMemory',
    'Install-DbaMaintenanceSolution',
    'Get-DbaManagementObject',
    'Set-DbaAgentOperator',
    'Remove-DbaExtendedProperty',
    'Get-DbaExtendedProperty',
    'Set-DbaExtendedProperty',
    'Add-DbaExtendedProperty',
    'Get-DbaOleDbProvider',
    'Get-DbaConnectedInstance',
    'Disconnect-DbaInstance',
    'Set-DbaDefaultPath',
    'New-DbaDacProfile',
    'Export-DbaDacPackage',
    'Remove-DbaDbUdf',
    'Save-DbaCommunitySoftware',
    'Update-DbaMaintenanceSolution',
    'Remove-DbaServerRoleMember',
    'Remove-DbaDbMailProfile',
    'Remove-DbaDbMailAccount',
    'Set-DbaRgWorkloadGroup',
    'New-DbaRgWorkloadGroup',
    'Remove-DbaRgWorkloadGroup',
    'New-DbaLinkedServerLogin',
    'Remove-DbaLinkedServerLogin',
    'Remove-DbaCredential',
    'Remove-DbaAgentProxy',
    'Disable-DbaReplDistributor',
    'Enable-DbaReplDistributor',
    'Disable-DbaReplPublishing',
    'Enable-DbaReplPublishing',
    'New-DbaReplPublication',
    'Get-DbaReplArticle',
    'Get-DbaReplArticleColumn',
    'Add-DbaReplArticle',
    'Remove-DbaReplArticle',
    'Remove-DbaReplPublication',
    'New-DbaReplSubscription',
    'Remove-DbaReplSubscription',
    'New-DbaReplCreationScriptOptions',
    'Get-DbaReplSubscription',
    'Get-DbaReplDistributor',
    'Get-DbaReplPublication',
    'Get-DbaReplServer'
)