#Requires -Module @{ ModuleName="Pester"; ModuleVersion="5.0"}
param(
    $ModuleName = "dbatools",
    $PSDefaultParameterValues = ($TestConfig = Get-TestConfig).Defaults
)

Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan

Describe "Find-DbaDbDuplicateIndex" -Tag "UnitTests" {
    BeforeAll {
        $command = Get-Command Find-DbaDbDuplicateIndex
        $expected = $TestConfig.CommonParameters
        $expected += @(
            "SqlInstance",
            "SqlCredential", 
            "Database",
            "IncludeOverlapping",
            "EnableException"
        )
    }

    Context "Parameter validation" {
        It "Has parameter: <_>" -ForEach $expected {
            $command | Should -HaveParameter $PSItem
        }

        It "Should have exactly the number of expected parameters ($($expected.Count))" {
            $hasparms = $command.Parameters.Values.Name
            Compare-Object -ReferenceObject $expected -DifferenceObject $hasparms | Should -BeNullOrEmpty
        }
    }
}

Describe "Find-DbaDbDuplicateIndex" -Tag "IntegrationTests" {
    BeforeAll {
        $server = Connect-DbaInstance -SqlInstance $TestConfig.instance1
        $sql = "create database [dbatools_dupeindex]"
        $server.Query($sql)
        $sql = "CREATE TABLE [dbatools_dupeindex].[dbo].[WABehaviorEvent](
                [BehaviorEventId] [smallint] NOT NULL,
                [ClickType] [nvarchar](50) NOT NULL,
                [Description] [nvarchar](512) NOT NULL,
                [BehaviorClassId] [tinyint] NOT NULL,
             CONSTRAINT [PK_WABehaviorEvent_BehaviorEventId] PRIMARY KEY CLUSTERED
            (
                [BehaviorEventId] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
            UNIQUE NONCLUSTERED
            (
                [ClickType] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
            ) ON [PRIMARY]


            CREATE UNIQUE NONCLUSTERED INDEX [IX_WABehaviorEvent_ClickType] ON [dbatools_dupeindex].[dbo].[WABehaviorEvent]
            (
                [ClickType] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

            ALTER TABLE [dbatools_dupeindex].[dbo].[WABehaviorEvent] ADD UNIQUE NONCLUSTERED
            (
                [ClickType] ASC
            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
            "
        $server.Query($sql)
    }

    AfterAll {
        Remove-DbaDatabase -SqlInstance $TestConfig.instance1 -Database dbatools_dupeindex -Confirm:$false
    }

    Context "When finding duplicate indexes" {
        BeforeAll {
            $results = Find-DbaDbDuplicateIndex -SqlInstance $TestConfig.instance1 -Database dbatools_dupeindex
        }

        It "Should return at least two results" {
            $results.Count | Should -BeGreaterOrEqual 2
        }
    }
}
