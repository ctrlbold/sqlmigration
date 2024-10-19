# this files describes which tests to run on which environment of the build matrix

$TestsRunGroups = @{
    # run on scenario 2008R2
    "2008R2"            = 'autodetect_$script:instance1'
    # run on scenario 2016
    "2016"              = 'autodetect_$script:instance2'
    # run on scenario 2016_2017 - tests that need developer license
    "2016_2017"         = 'autodetect_$script:instance2,$script:instance3'
    #run on scenario service_restarts - SQL Server service tests that might disrupt other tests
    "service_restarts"  = @(
        'Start-DbaService',
        'Stop-DbaService',
        'Set-DbaStartupParameter',
        'Restart-DbaService',
        'Get-DbaService',
        'Update-DbaServiceAccount',
        'Enable-DbaAgHadr',
        'Disable-DbaAgHadr',
        'Reset-DbaAdmin',
        'Set-DbaTcpPort'
    )
    # do not run on appveyor
    "appveyor_disabled" = @(
        # tests that work locally against SQL Server 2022 instances without problems but fail on AppVeyor
        'ConvertTo-DbaXESession',
        'Export-DbaUser',
        'Get-DbaPermission',
        'Get-DbaUserPermission',
        'Invoke-DbaWhoisActive',
        'Remove-DbaAvailabilityGroup',
        'Remove-DbaDatabaseSafely',
        'Sync-DbaLoginPermission',
        # tests that fail locally against SQL Server 2022 instances and fail on AppVeyor
        'Set-DbaAgentJobStep',
        'New-DbaLogin',
        'Watch-DbaDbLogin',
        # tests that fail because the command does not work
        'Copy-DbaDbCertificate',
        'Export-DbaDacPackage',
        'Read-DbaAuditFile',
        'Read-DbaXEFile',
        # takes too long
        'Install-DbaSqlWatch',
        'Uninstall-DbaSqlWatch',
        'Get-DbaExecutionPlan',
        # Non-useful info from newly started sql servers
        'Get-DbaCpuRingBuffer',
        'Get-DbaLatchStatistic'
    )
    # do not run everywhere
    "disabled"          = @()
}
