Describe "Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $password = ConvertTo-SecureString "dbatools.IO" -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "sqladmin", $password

        $PSDefaultParameterValues["*:SqlInstance"] = "mssql1"
        $PSDefaultParameterValues["*:SqlCredential"] = $cred
        $PSDefaultParameterValues["*:Confirm"] = $false
        $PSDefaultParameterValues["*:SharedPath"] = "/shared"

        #TODO: To be removed?
        $PSDefaultParameterValues["*:-SnapshotShare"] = "/shared"
        $PSDefaultParameterValues["*:WarningAction"] = "SilentlyContinue"
        $global:ProgressPreference = "SilentlyContinue"

        #$null = Get-XPlatVariable | Where-Object { $PSItem -notmatch "Copy-", "Migration" } | Sort-Object
        # load dbatools-lib
        #Import-Module dbatools-core-library
        Import-Module ./dbatools.psd1 -Force

        $null = New-DbaDatabase -Name ReplDb
        $null = Invoke-DbaQuery -Database ReplDb -Query 'CREATE TABLE ReplicateMe ( id int identity (1,1) PRIMARY KEY, col1 varchar(10) )'
    }

    Describe "Enable\Disable Functions" -Tag ReplSetup {

        Context "Get-DbaReplDistributor works" {
            BeforeAll {

                # if distribution is enabled, disable it & enable it with defaults
                if ((Get-DbaReplDistributor).IsDistributor) {
                    Disable-DbaReplDistributor
                }
                Enable-DbaReplDistributor
            }

            It "gets a distributor" {
                (Get-DbaReplDistributor).IsDistributor | Should -Be $true
            }

            It "distribution database name is correct" {
                (Get-DbaReplDistributor).DistributionDatabases.Name | Should -Be 'distribution'
            }

            It "can pipe a sql server object to it" -skip {
                Connect-DbaInstance | Get-DbaReplDistributor | Should -Not -BeNullOrEmpty
            }
        }

        Context "Get-DbaReplPublisher works" {
            BeforeAll {
                # if distribution is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }

                # if publishing is disabled - enable it
                if (-not (Get-DbaReplServer).IsPublisher) {
                    Enable-DbaReplPublishing -PublisherSqlLogin $cred -EnableException
                }
            }

            It "gets a publisher" {
                (Get-DbaReplPublisher).PublisherType | Should -Be "MSSQLSERVER"
            }

            It "gets a publisher using piping" -skip {
                (Connect-DbaInstance | Get-DbaReplPublisher).PublisherType | Should -Be "MSSQLSERVER"
            }

        }

        Context "Enable-DbaReplDistributor works" {
            BeforeAll {
                # if distribution is enabled - disable it
                if ((Get-DbaReplDistributor).IsDistributor) {
                    Disable-DbaReplDistributor
                }
            }

            It "distribution starts disabled" {
                (Get-DbaReplDistributor).IsDistributor | Should -Be $false
            }

            It "distribution is enabled" {
                Enable-DbaReplDistributor
                (Get-DbaReplDistributor).IsDistributor | Should -Be $true
            }
        }

        Context "Enable-DbaReplDistributor works with specified database name" {
            BeforeAll {
                # if distribution is enabled - disable it
                if ((Get-DbaReplDistributor).IsDistributor) {
                    Disable-DbaReplDistributor
                }
            }
            AfterAll {
                if ((Get-DbaReplDistributor).IsDistributor) {
                    Disable-DbaReplDistributor
                }
            }

            It "distribution starts disabled" {
                (Get-DbaReplDistributor).IsDistributor | Should -Be $false
            }

            It "distribution is enabled with specific database" {
                $distDb = ('distdb-{0}' -f (Get-Random))
                Enable-DbaReplDistributor -DistributionDatabase $distDb
                (Get-DbaReplDistributor).DistributionDatabases.Name | Should -Be $distDb
            }
        }

        Context "Disable-DbaReplDistributor works" {
            BeforeAll {
                # if replication is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }
            }

            It "distribution starts enabled" {
                (Get-DbaReplDistributor).IsDistributor | Should -Be $true
            }

            It "distribution is disabled" {
                Disable-DbaReplDistributor
                (Get-DbaReplDistributor).IsDistributor | Should -Be $false
            }
        }

        Context "Enable-DbaReplPublishing works" {
            BeforeAll {
                # if Publishing is enabled - disable it
                if ((Get-DbaReplServer).IsPublisher) {
                    Disable-DbaReplPublishing
                }
                # if distribution is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }
            }

            It "publishing starts disabled" {
                (Get-DbaReplServer).IsPublisher | Should -Be $false
            }

            It "publishing is enabled" {
                Enable-DbaReplPublishing -EnableException
                (Get-DbaReplServer).IsPublisher | Should -Be $true
            }
        }

        Context "Disable-DbaReplPublishing works" {
            BeforeAll {
                # if publishing is disabled - enable it
                if (-not (Get-DbaReplServer).IsPublisher) {
                    write-output -message 'I should enable publishing'
                    Enable-DbaReplPublishing -EnableException
                }

                # if distribution is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    write-output -message 'I should enable distribution'
                    Enable-DbaReplDistributor -EnableException
                }
            }

            It "publishing starts enabled" {
                (Get-DbaReplServer).IsPublisher | Should -Be $true
            }

            It "publishing is disabled" {
                Disable-DbaReplPublishing -EnableException
                (Get-DbaReplServer).IsPublisher | Should -Be $false
            }
        }
    }

    Describe "Publication commands" {
        Context "Get-DbaReplPublisher works" {
            BeforeAll {
                # if distribution is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }

                # if publishing is disabled - enable it
                if (-not (Get-DbaReplServer).IsPublisher) {
                    Enable-DbaReplPublishing -PublisherSqlLogin $cred -EnableException
                }
            }

            It "gets a publisher" {
                (Get-DbaReplPublisher).PublisherType | Should -Be "MSSQLSERVER"
            }

        }

        Context "Get-DbaReplPublication works" {
            BeforeAll {
                # if distribution is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }

                # if publishing is disabled - enable it
                if (-not (Get-DbaReplServer).IsPublisher) {
                    Enable-DbaReplPublishing -PublisherSqlLogin $cred -EnableException
                }

                # create a publication
                $name = 'TestPub'
                New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName ('{0}-Trans' -f $Name)
                New-DbaReplPublication -Database ReplDb -Type Merge -PublicationName ('{0}-Merge' -f $Name)
                $null = New-DbaDatabase -Name Test
                New-DbaReplPublication -Database Test -Type Snapshot -PublicationName ('{0}-Snapshot' -f $Name)
            }

            It "gets all publications" {
                Get-DbaReplPublication | Should -Not -BeNullOrEmpty
            }

            It "gets publications for a specific database" {
                Get-DbaReplPublication -Database ReplDb | Should -Not -BeNullOrEmpty
                (Get-DbaRepPublication -Database ReplDb).DatabaseName | ForEach-Object { $_ | Should -Be 'ReplDb' }
            }

            It "gets publications for a specific type" {
                Get-DbaReplPublication -Type Transactional | Should -Not -BeNullOrEmpty
                (Get-DbaRepPublication -Type Transactional).Type | ForEach-Object { $_ | Should -Be 'Transactional' }
            }

            It "works with piping" -skip {
                Connect-DbaInstance | Get-DbaReplPublication | Should -Not -BeNullOrEmpty
            }
        }

        Context "New-DbaReplPublication works" {
            BeforeAll {
                # if replication is disabled - enable it
                if (-not (Get-DbaReplDistributor).IsDistributor) {
                    Enable-DbaReplDistributor
                }
                # if publishing is disabled - enable it
                if (-not (Get-DbaReplServer).IsPublisher) {
                    Enable-DbaReplPublishing -PublisherSqlLogin $cred -EnableException
                }
            }

            It "New-DbaReplPublication creates a Transactional publication" {
                $name = 'TestPub'
                New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName $Name
                (Get-DbaReplPublication -Name $Name) | Should -Not -BeNullOrEmpty
                (Get-DbaReplPublication -Name $Name).DatabaseName | Should -Be 'ReplDb'
                (Get-DbaReplPublication -Name $Name).Type | Should -Be 'Transactional'
            }
            It "New-DbaReplPublication creates a Snapshot publication" {
                $name = 'Snappy'
                New-DbaReplPublication -Database ReplDb -Type Snapshot -PublicationName $name
                (Get-DbaReplPublication -Name $name) | Should -Not -BeNullOrEmpty
                (Get-DbaReplPublication -Name $name).DatabaseName | Should -Be 'ReplDb'
                (Get-DbaReplPublication -Name $name).Type | Should -Be 'Snapshot'
            }
            It "New-DbaReplPublication creates a Merge publication" {
                $name = 'Mergey'
                New-DbaReplPublication -Database ReplDb -Type Merge -PublicationName $name
                (Get-DbaReplPublication -Name $name) | Should -Not -BeNullOrEmpty
                (Get-DbaReplPublication -Name $name).DatabaseName | Should -Be 'ReplDb'
                (Get-DbaReplPublication -Name $name).Type | Should -Be 'Merge'
            }

        }
    }

    Describe "Article commands" {
        BeforeAll {
            # if replication is disabled - enable it
            if (-not (Get-DbaReplDistributor).IsDistributor) {
                Enable-DbaReplDistributor
            }
            # if publishing is disabled - enable it
            if (-not (Get-DbaReplServer).IsPublisher) {
                Enable-DbaReplPublishing -PublisherSqlLogin $cred -EnableException
            }
            # we need some publications too
            $name = 'TestTrans'
            if (-not (Get-DbaReplPublication -Name $name -Type Transactional )) {
                $null = New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName $Name
            }
            $name = 'TestSnap'
            if (-not (Get-DbaReplPublication -Name $name -Type Snapshot)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Snapshot -PublicationName $Name
            }
            $name = 'TestMerge'
            if (-not (Get-DbaReplPublication -Name $name -Type Merge)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Merge -PublicationName $Name
            }
            $articleName = 'ReplicateMe'
        }

        Context "New-DbaReplCreationScriptOptions works" {
            It "New-DbaReplCreationScriptOptions creates a Microsoft.SqlServer.Replication.CreationScriptOptions" {
                $options = New-DbaReplCreationScriptOptions
                $options | Should -BeOfType Microsoft.SqlServer.Replication.CreationScriptOptions
            }
            It "Microsoft.SqlServer.Replication.CreationScriptOptions should include the 11 defaults by default" {
                ((New-DbaReplCreationScriptOptions).ToString().Split(',').Trim() | Measure-Object).Count | Should -Be 11
            }
            It "Microsoft.SqlServer.Replication.CreationScriptOptions should include ClusteredIndexes" {
                ((New-DbaReplCreationScriptOptions).ToString().Split(',').Trim() | Should -Contain 'ClusteredIndexes')
            }
            It "Microsoft.SqlServer.Replication.CreationScriptOptions with option of NonClusteredIndexes should add NonClusteredIndexes" {
                ((New-DbaReplCreationScriptOptions -Option NonClusteredIndexes).ToString().Split(',').Trim() | Measure-Object).Count | Should -Be 12
                ((New-DbaReplCreationScriptOptions -Option NonClusteredIndexes).ToString().Split(',').Trim() | Should -Contain 'NonClusteredIndexes')
            }

            It "NoDefaults should mean Microsoft.SqlServer.Replication.CreationScriptOptions only contains DisableScripting" {
                ((New-DbaReplCreationScriptOptions -NoDefaults).ToString().Split(',').Trim() | Measure-Object).Count | Should -Be 1
                ((New-DbaReplCreationScriptOptions -NoDefaults).ToString().Split(',').Trim() | Should -Contain 'DisableScripting')
            }
            It "NoDefaults plus option of NonClusteredIndexes should mean Microsoft.SqlServer.Replication.CreationScriptOptions only contains NonClusteredIndexes" {
                ((New-DbaReplCreationScriptOptions -NoDefaults -Option NonClusteredIndexes).ToString().Split(',').Trim() | Measure-Object).Count | Should -Be 1
                ((New-DbaReplCreationScriptOptions -NoDefaults -Option NonClusteredIndexes).ToString().Split(',').Trim() | Should -Contain 'NonClusteredIndexes')
            }
        }

        Context "Add-DbaReplArticle works" {
            BeforeAll {
                $articleName = 'ReplicateMe'
            }

            It "Add-DbaReplArticle adds an article to a Transactional publication" {
                $pubName = 'TestPub'
                { Add-DbaReplArticle -Database ReplDb -Name $articleName -Publication $pubName } | Should -not -throw
                $art = Get-DbaReplArticle -Database ReplDb -Name $articleName -Publication $pubName
                $art | Should -Not -BeNullOrEmpty
                $art.PublicationName | Should -Be $pubName
                $art.Name | Should -Be $articleName
            }

            It "Add-DbaReplArticle adds an article to a Snapshot publication" {
                $pubname = 'TestSnap'
                { Add-DbaReplArticle -SqlInstance mssql1 -Database ReplDb -Name $articleName -Publication $pubname -EnableException } | Should -not -throw
                $art = Get-DbaReplArticle -Database ReplDb -Name $articleName -Publication $pubName
                $art | Should -Not -BeNullOrEmpty
                $art.PublicationName | Should -Be $pubName
                $art.Name | Should -Be $articleName
            }
            It "Add-DbaReplArticle adds an article to a Merge publication" {
                $pubname = 'TestMerge'
                { Add-DbaReplArticle -SqlInstance mssql1 -Database ReplDb -Name $articleName -Publication $pubname -EnableException } | Should -not -throw
                $art = Get-DbaReplArticle -Database ReplDb -Name $articleName -Publication $pubName
                $art | Should -Not -BeNullOrEmpty
                $art.PublicationName | Should -Be $pubName
                $art.Name | Should -Be $articleName
            }
        }

        Context "Get-DbaReplArticle works" -Tag ArtTestGet {
            BeforeAll {
                # we need some articles too remove
                $article = 'ReplicateMe'

                # we need some publications too
                $name = 'TestTrans'
                if (-not (Get-DbaReplPublication -Name $name -Type Transactional)) {
                    $null = New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName $Name
                }
                $name = 'TestSnap'
                if (-not (Get-DbaReplPublication -Name $name -Type Snapshot)) {
                    $null = New-DbaReplPublication -Database ReplDb -Type Snapshot -PublicationName $Name
                }
                $name = 'TestMerge'
                if (-not (Get-DbaReplPublication -Name $name -Type Merge)) {
                    $null = New-DbaReplPublication -Database ReplDb -Type Merge -PublicationName $Name
                }
            }

            It "Get-DbaReplArticle gets the article from a Transactional publication" {
                $PublicationName = 'TestTrans'
                $Name = "ReplicateMe"
                Add-DbaReplArticle -Database ReplDb -Publication $PublicationName -Name $Name

                $TransArticle = Get-DbaReplArticle -Database ReplDb -Type Transactional -Publication $PublicationName
                $TransArticle.Count | Should -Be 1
                $TransArticle.Name | Should -Be $Name
                $TransArticle.PublicationName | Should -Be $PublicationName
            }

            It "Piping from Connect-DbaInstance works" -skip {
                Connect-DbaInstance -Database ReplDb | Get-DbaReplArticle | Should -Not -BeNullOrEmpty
            }



            It "Get-DbaReplArticle gets the article from a Transactional publication" {
                $PublicationName = 'TestTrans'
                $Name = "ReplicateMe"
                Add-DbaReplArticle -Database ReplDb -Publication $PublicationName -Name $Name

                $TransArticle = Get-DbaReplArticle -Database ReplDb -Type Transactional -Publication $PublicationName
                $TransArticle.Count | Should -Be 1
                $TransArticle.Name | Should -Be $Name
                $TransArticle.PublicationName | Should -Be $PublicationName
            }

            It "Piping from Connect-DbaInstance works" -skip {
                Connect-DbaInstance -Database ReplDb | Get-DbaReplArticle | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Remove-DbaReplArticle works" -Tag ArtTestGet {
        BeforeAll {
            # we need some articles too remove
            $article = 'ReplicateMe'

            # we need some publications with articles too
            $pubname = 'TestTrans'
            if (-not (Get-DbaReplPublication -Name $pubname -Type Transactional)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName $pubname
            }
            if (-not (Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article)) {
                $null = Add-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article
            }

            $pubname = 'TestSnap'
            if (-not (Get-DbaReplPublication -Name $pubname -Type Snapshot)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Snapshot -PublicationName $pubname
            }
            if (-not (Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article)) {
                $null = Add-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article
            }

            $pubname = 'TestMerge'
            if (-not (Get-DbaReplPublication $pubname $name -Type Merge)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Merge -PublicationName $pubname
            }
            if (-not (Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article)) {
                $null = Add-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article
            }

        }

        It "Remove-DbaReplArticle removes an article from a Transactional publication" {
            $pubname = 'TestTrans'
            $Name = "ReplicateMe"
            $rm = Remove-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $rm.IsRemoved | Should -Be $true
            $rm.Status | Should -Be 'Removed'
            $article = Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $article | Should -BeNullOrEmpty
        }

        It "Remove-DbaReplArticle removes an article from a Snapshot publication" {
            $pubname = 'TestSnap '
            $Name = "ReplicateMe"
            $rm = Remove-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $rm.IsRemoved | Should -Be $true
            $rm.Status | Should -Be 'Removed'
            $article = Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $article | Should -BeNullOrEmpty
        }

        It "Remove-DbaReplArticle removes an article from a Merge publication" {
            $pubname = 'TestMerge'
            $Name = "ReplicateMe"
            $rm = Remove-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $rm.IsRemoved | Should -Be $true
            $rm.Status | Should -Be 'Removed'
            $article = Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $Name
            $article | Should -BeNullOrEmpty
        }
    }

    Context "Remove-DbaReplArticle works with piping" -Tag ArtTestGet {
        BeforeAll {
            # we need some articles too remove
            $article = 'ReplicateMe'

            # we need some publications with articles too
            $pubname = 'TestTrans'
            if (-not (Get-DbaReplPublication -Name $pubname -Type Transactional)) {
                $null = New-DbaReplPublication -Database ReplDb -Type Transactional -PublicationName $Name
            }
            if (-not (Get-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article)) {
                $null = Add-DbaReplArticle -Database ReplDb -Publication $pubname -Name $article
            }
        }

        It "Remove-DbaReplArticle removes an article from a Transactional publication" {
            $PublicationName = 'TestTrans'
            $Name = "ReplicateMe"

            $rm = Get-DbaReplArticle -Database ReplDb -Publication $PublicationName -Name $Name | Remove-DbaReplArticle -Confirm:$false
            $rm.IsRemoved | ForEach-Object { $_ | Should -Be $true }
            $rm.Status | ForEach-Object { $_ | Should -Be 'Removed' }
            $article = Get-DbaReplArticle -Database ReplDb  -Publication $PublicationName -Name $Name
            $article | Should -BeNullOrEmpty
        }
    }
}
