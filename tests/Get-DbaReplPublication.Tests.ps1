$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
$global:TestConfig = Get-TestConfig

Describe "$commandname Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        [object[]]$params = (Get-Command $CommandName).Parameters.Keys | Where-Object { $_ -notin ('whatif', 'confirm') }
        [object[]]$knownParameters = 'SqlInstance', 'SqlCredential', 'Database', 'Name', 'Type', 'EnableException'
        $knownParameters += [System.Management.Automation.PSCmdlet]::CommonParameters
        It "Should only contain our specific parameters" {
            (@(Compare-Object -ReferenceObject ($knownParameters | Where-Object { $_ }) -DifferenceObject $params).Count ) | Should Be 0
        }
    }

    InModuleScope dbatools {
        Context "Code Validation" {

            Mock Connect-ReplicationDB -MockWith {
                [object]@{
                    Name              = 'TestDB'
                    TransPublications = @{
                        Name         = 'TestDB_pub'
                        Type         = 'Transactional'
                        DatabaseName = 'TestDB'
                    }
                    MergePublications = @{}
                }
            }

            Mock Connect-DbaInstance -MockWith {
                [object]@{
                    Name               = "MockServerName"
                    ServiceName        = 'MSSQLSERVER'
                    DomainInstanceName = 'MockServerName'
                    ComputerName       = 'MockComputerName'
                    Databases          = @{
                        Name               = 'TestDB'
                        #state
                        #status
                        ID                 = 5
                        ReplicationOptions = 'Published'
                        IsAccessible       = $true
                        IsSystemObject     = $false
                    }
                    ConnectionContext  = @{
                        SqlConnectionObject = 'FakeConnectionContext'
                    }
                }
            }

            It "Honors the SQLInstance parameter" {
                $Results = Get-DbaReplPublication -SqlInstance MockServerName
                $Results.SqlInstance.Name | Should Be "MockServerName"
            }

            It "Honors the Database parameter" {
                $Results = Get-DbaReplPublication -SqlInstance MockServerName -Database TestDB
                $Results.DatabaseName | Should Be "TestDB"
            }

            It "Honors the Type parameter" {

                Mock Connect-ReplicationDB -MockWith {
                    [object]@{
                        Name              = 'TestDB'
                        TransPublications = @{
                            Name = 'TestDB_pub'
                            Type = 'Snapshot'
                        }
                        MergePublications = @{}
                    }
                }

                $Results = Get-DbaReplPublication -SqlInstance MockServerName -Database TestDB -Type Snapshot
                $Results.Type | Should Be "Snapshot"
            }

            It "Stops if validate set for Type is not met" {

                { Get-DbaReplPublication -SqlInstance MockServerName -Type NotAPubType } | should Throw

            }
        }
    }
}