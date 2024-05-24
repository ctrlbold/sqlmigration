param($ModuleName = 'dbatools')
Describe "Connect-DbaInstance" {
    Context "Validate parameters" {
        BeforeAll {
            $CommandUnderTest = Get-Command Connect-DbaInstance
        }
        It "Requires SqlInstance as a Mandatory parameter" {
            $CommandUnderTest | Should -HaveParameter SqlInstance -Type DbaInstanceParameter[] -Mandatory -Alias 'ConnectionString'
        }
        It "Accepts SqlCredential as a parameter" {
            $CommandUnderTest | Should -HaveParameter SqlCredential -Type PSCredential
        }
        It "Accepts Database as a parameter" {
            $CommandUnderTest | Should -HaveParameter Database -Type String -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.database')"
        }
        It "Accepts ApplicationIntent as a parameter" {
            $CommandUnderTest | Should -HaveParameter ApplicationIntent -Type String
        }
        It "Accepts AzureUnsupported as a parameter" {
            $CommandUnderTest | Should -HaveParameter AzureUnsupported -Type Switch
        }
        It "Accepts BatchSeparator as a parameter" {
            $CommandUnderTest | Should -HaveParameter BatchSeparator -Type String
        }
        It "Accepts ClientName as a parameter" {
            $CommandUnderTest | Should -HaveParameter ClientName -Type String -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.clientname')"
        }
        It "Accepts ConnectTimeout as a parameter" {
            $CommandUnderTest | Should -HaveParameter ConnectTimeout -Type int -DefaultValue "([Dataplat.Dbatools.Connection.ConnectionHost]::SqlConnectionTimeout)"
        }
        It "Accepts EncryptConnection as a parameter" {
            $CommandUnderTest | Should -HaveParameter EncryptConnection -Type Switch -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.encrypt')"
        }
        It "Accepts FailoverPartner as a parameter" {
            $CommandUnderTest | Should -HaveParameter FailoverPartner -Type String
        }
        It "Accepts LockTimeout as a parameter" {
            $CommandUnderTest | Should -HaveParameter LockTimeout -Type int
        }
        It "Accepts MaxPoolSize as a parameter" {
            $CommandUnderTest | Should -HaveParameter MaxPoolSize -Type int
        }
        It "Accepts MinPoolSize as a parameter" {
            $CommandUnderTest | Should -HaveParameter MinPoolSize -Type int
        }
        It "Accepts MinimumVersion as a parameter" {
            $CommandUnderTest | Should -HaveParameter MinimumVersion -Type int
        }
        It "Accepts MultipleActiveResultSets as a parameter" {
            $CommandUnderTest | Should -HaveParameter MultipleActiveResultSets -Type Switch
        }
        It "Accepts MultiSubnetFailover as a parameter" {
            $CommandUnderTest | Should -HaveParameter MultiSubnetFailover -Type Switch -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.multisubnetfailover')"
        }
        It "Accepts NetworkProtocol as a parameter" {
            $CommandUnderTest | Should -HaveParameter NetworkProtocol -Type String -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.protocol')"
        }
        It "Accepts NonPooledConnection as a parameter" {
            $CommandUnderTest | Should -HaveParameter NonPooledConnection -Type Switch
        }
        It "Accepts PacketSize as a parameter" {
            $CommandUnderTest | Should -HaveParameter PacketSize -Type int -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.packetsize')"
        }
        It "Accepts SqlExecutionModes as a parameter" {
            $CommandUnderTest | Should -HaveParameter SqlExecutionModes -Type String
        }
        It "Accepts StatementTimeout as a parmeter" {
            $CommandUnderTest | Should -HaveParameter StatementTimeout -Type int -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.execution.timeout')"
        }
        It "Accepts TrustServerCertificate as a parameter" {
            $CommandUnderTest | Should -HaveParameter TrustServerCertificate -Type Switch -DefaultValue "(Get-DbatoolsConfigValue -FullName 'sql.connection.trustcert')"
        }
        It "Accepts WorkstationId as a parameter" {
            $CommandUnderTest | Should -HaveParameter WorkstationId -Type String
        }
        It "Accepts AlwaysEncrypted as a parameter" {
            $CommandUnderTest | Should -HaveParameter AlwaysEncrypted -Type Switch
        }
        It "Accepts AppendConnectionString as a parameter" {
            $CommandUnderTest | Should -HaveParameter AppendConnectionString -Type String
        }
        It "Accepts SqlConnectionOnly as a parameter" {
            $CommandUnderTest | Should -HaveParameter SqlConnectionOnly -Type Switch
        }
        It "Accepts AzureDomain as a parameter" {
            $CommandUnderTest | Should -HaveParameter AzureDomain -Type String -DefaultValue "database.windows.net"
        }
        It "Accepts Tenant as a parameter" {
            $CommandUnderTest | Should -HaveParameter Tenant -Type String -DefaultValue "(Get-DbatoolsConfigValue -FullName 'azure.tenantid')"
        }
        It "Accepts AccessToken as a parameter" {
            $CommandUnderTest | Should -HaveParameter AccessToken -Type psobject
        }
        It "Accepts DedicatedAdminConnection as a parameter" {
            $CommandUnderTest | Should -HaveParameter DedicatedAdminConnection -Type Switch
        }
        It "Accepts DisableException as a parameter" {
            $CommandUnderTest | Should -HaveParameter DisableException -Type Switch
        }
    }
    Context "Validate alias" -Skip:$true { # do not see this working on Windows or Mac
        It "Should contain the alias: cdi" {
            (Get-Alias cdi) | Should -Not -BeNullOrEmpty
        }
    }
    Context "Command usage" {
        BeforeDiscovery {
            # Run setup code to get script variables within scope of the discovery phase
            . (Join-Path $PSScriptRoot 'constants.ps1')
        }
        # -Skip parameter must be true for this to not run, so need to check for the environment variable to not be set to the dependent value
        Context "Connects to Azure" -Skip:([Environment]::GetEnvironmentVariable('azuredbpasswd') -ne "failstooften") {
            BeforeAll {
                $securePassword = ConvertTo-SecureString $env:azuredbpasswd -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential ($script:azuresqldblogin, $securePassword)
            }
            It "Should login to Azure" {
                $s = Connect-DbaInstance -SqlInstance psdbatools.database.windows.net -SqlCredential $cred -Database test
                $s.Name | Should -Match 'psdbatools.database.windows.net'
                $s.DatabaseEngineType | Should -Be 'SqlAzureDatabase'
            }
            It "Should keep the same database context" {
                $s = Connect-DbaInstance -SqlInstance psdbatools.database.windows.net -SqlCredential $cred -Database test
                $results = Invoke-DbaQuery -SqlInstance $s -Query "select db_name() as dbName"
                $results.dbName | Should -Be 'test'
            }
            It "Should keep the same database context again" {
                $s = Connect-DbaInstance -SqlInstance psdbatools.database.windows.net -SqlCredential $cred -Database test
                $results = Invoke-DbaQuery -SqlInstance $s -Query "select db_name() as dbName"
                $results.dbName | Should -Be 'test'
                $results = Invoke-DbaQuery -SqlInstance $s -Query "select db_name() as dbName"
                $results.dbName | Should -Be 'test'
            }
            It "Should keep the same database context" {
                $s = Connect-DbaInstance -SqlInstance psdbatools.database.windows.net -SqlCredential $cred -Database test
                $server = Connect-DbaInstance -SqlInstance $s
                $server.Query("select db_name() as dbName").dbName | Should -Be 'test'
            }
        }
        Context "Connects passing server <_> to -SqlInstance" -ForEach $script:instance1,$script:instance2 {
            BeforeAll {
                $server = Connect-DbaInstance -SqlInstance $_ -ApplicationIntent ReadOnly
            }
            It "Returns the proper name" {
                $server.Name | Should -Be $_
            }
            It "Returns more than one database" {
                $server.Databases.Name.Count -gt 0 | Should -Be $true
            }
            It "Returns the connection with ApplicationIntent of ReadOnly" {
                $server.ConnectionContext.ConnectionString -match "Intent=ReadOnly" | Should -Be $true
            }
            It "Keeps the same database context" {
                $null = $server.Databases['msdb'].Tables.Count
                $server.ConnectionContext.ExecuteScalar("select db_name()") | Should -Be 'master'
            }
            It "Sets StatementTimeout to 0" {
                $server = Connect-DbaInstance -SqlInstance $server -StatementTimeout 0
                $server.ConnectionContext.StatementTimeout | Should -Be 0
            }
            <# We are going to set this as a Windows only thing because it can't be used when Docker is being used #>
            It "Connects using a dot as localhost" -Skip:(-not $IsWindows) {
                $newinstance = $server.Replace("localhost", ".")
                Write-Warning "Connecting to $newinstance"
                $server = Connect-DbaInstance -SqlInstance $newinstance
                $server.Databases.Name | Should -Exist
            }
        }
        Context "Connects using SqlInstance for <_> as a connection string [Windows]" -Skip:(-not $IsWindows) -ForEach $script:instance1,$script:instance2 {
            BeforeAll {
                $cnString = "Data Source=$_;Initial Catalog=tempdb;Integrated Security=True;Encrypt=False;Trust Server Certificate=True"
                $server = Connect-DbaInstance -SqlInstance $cnString
            }
            It "Connects using a connection string" {
                $server.Databases.Name | Should -Exist
            }
            It "PR8962: Ensure context is not changed when connection string is used" {
                $null = $server.Databases['msdb'].Tables.Count
                $server.ConnectionContext.ExecuteScalar("select db_name()") | Should -Be 'tempdb'
            }
            It "connects using a connection object" {
                Set-DbatoolsConfig -FullName commands.connect-dbainstance.smo.computername.source -Value 'instance.ComputerName'
                [Microsoft.Data.SqlClient.SqlConnection]$sqlconnection = $cnString
                $server = Connect-DbaInstance -SqlInstance $sqlconnection
                $server.ComputerName | Should -Be ([DbaInstance]$script:instance1).ComputerName
                $server.Databases.Name | Should -Exist
                Set-DbatoolsConfig -FullName commands.connect-dbainstance.smo.computername.source -Value $null
            }
            It "Connects to the SQL Server 2016 - Appveyor environment" -Skip:([Environment]::GetEnvironmentVariable('appveyor')) {
                $server = Connect-DbaInstance -SqlInstance "Data Source=$_$cnString"
                $server.Databases.Name | Should -Exist
            }
            It "connects using a connection object - instance2" {
                Set-DbatoolsConfig -FullName commands.connect-dbainstance.smo.computername.source -Value 'instance.ComputerName'
                [Microsoft.Data.SqlClient.SqlConnection]$sqlconnection = "Data Source=$_$cnString;Encrypt=False;Trust Server Certificate=True"
                $server = Connect-DbaInstance -SqlInstance $sqlconnection
                $server.ComputerName | Should -Be ([DbaInstance]$_).ComputerName
                $server.Databases.Name | Should -Exist
                Set-DbatoolsConfig -FullName commands.connect-dbainstance.smo.computername.source -Value $null
            }
            It "sets ConnectionContext parameters that are provided" {
                $params = @{
                    'BatchSeparator'           = 'GO'
                    'ConnectTimeout'           = 1
                    'Database'                 = 'master'
                    'LockTimeout'              = 1
                    'MaxPoolSize'              = 20
                    'MinPoolSize'              = 1
                    'NetworkProtocol'          = 'TcpIp'
                    'PacketSize'               = 4096
                    'PooledConnectionLifetime' = 600
                    'WorkstationId'            = 'MadeUpServer'
                    'SqlExecutionModes'        = 'ExecuteSql'
                    'StatementTimeout'         = 0
                }
                $server = Connect-DbaInstance -SqlInstance $_ @params
                foreach ($param in $params.GetEnumerator()) {
                    if ($param.Key -eq 'Database') {
                        $propName = 'DatabaseName'
                    } else {
                        $propName = $param.Key
                    }
                    $server.ConnectionContext.$propName | Should -Be $param.Value
                }
            }
        }
        Context "Connects using newly created login" -ForEach $script:instance1, $script:instance2 {
            BeforeAll {
                $password = 'MyV3ry$ecur3P@ssw0rd'
                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                $server = Connect-DbaInstance -SqlInstance $_
                $login = "dbatoolscitestlogin"

                #Create login
                $newLogin = New-Object Microsoft.SqlServer.Management.Smo.Login($server, $login)
                $newLogin.LoginType = "SqlLogin"
                $newLogin.Create($password)

                <# Create connection using new login #>
                $cred = New-Object System.Management.Automation.PSCredential ($login, $securePassword)
                $serverNewLogin = Connect-DbaInstance -SqlInstance $_ -SqlCredential $cred -NonPooledConnection
            }
            AfterAll {
                Disconnect-DbaInstance -InputObject $serverNewLogin
                #Cleanup created login
                if ($l = $server.logins[$login]) {
                    if ($c = $l.EnumCredentials()) {
                        $l.DropCredential($c)
                    }
                    $l.Drop()
                }
            }
            It "Successful login using the new login" {
                $serverNewLogin.Name | Should -Be $_
            }
        }
    }
}