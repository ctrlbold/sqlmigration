param($ModuleName = 'dbatools')
Describe "ConvertTo-DbaDataTable" {
    BeforeAll {
        $CommandUnderTest = Get-Command ConvertTo-DbaDataTable
    }
    Context "Validate parameters" {
        It "Requires InputObject as a Mandatory parameter" {
            $CommandUnderTest | Should -HaveParameter InputObject -Type PSObject[] -Mandatory
        }
        It "Accepts EnableException as a parameter" {
            $CommandUnderTest | Should -HaveParameter EnableException -Type Switch
        }
        It "Accepts TimeSpanType as a parameter with default value" {
            $CommandUnderTest | Should -HaveParameter TimeSpanType -Type String -DefaultValue TotalMilliseconds
        }
        It "Accepts SizeType as a parameter with default value" {
            $CommandUnderTest | Should -HaveParameter SizeType -Type String -DefaultValue Int64
        }
        It "Accepts IngoreNull as a parameter" {
            $CommandUnderTest | Should -HaveParameter IgnoreNull -Type Switch
        }
        It "Accepts Raw as a parameter" {
            $CommandUnderTest | Should -HaveParameter Raw -Type Switch
        }
    }
    Context "Command usage" {
        BeforeAll {
            . "$PSScriptRoot\constants.ps1"
            $obj = New-Object -TypeName psobject -Property @{
                guid     = [system.guid]'32ccd4c4-282a-4c0d-997c-7b5deb97f9e0'
                timespan = New-TimeSpan -Start 2016-10-30 -End 2017-04-30
                datetime = Get-Date -Year 2016 -Month 10 -Day 30 -Hour 5 -Minute 52 -Second 0 -Millisecond 0
                char     = [System.Char]'T'
                true     = $true
                false    = $false
                null     = [bool]$null
                string   = "it's a boy."
                UInt64   = [System.UInt64]123456
                myObject = @{
                    Mission = "Mission Complete"
                }
            }
            $result = ConvertTo-DbaDataTable -InputObject $obj
        }
        Context "Data type guid" {
            It " has a column called guid" {
                $result.Columns.ColumnName | Should -Contain guid
            }
            It " has a [guid] data type on the column guid" {
                $result.guid | Should -BeOfType Guid
            }
            It " has the following guid: 32ccd4c4-282a-4c0d-997c-7b5deb97f9e0" {
                $result.guid | Should -Be '32ccd4c4-282a-4c0d-997c-7b5deb97f9e0'
            }
        }
        Context "Data type timespan" {
            It " has a column called timespan" {
                $result.Columns.ColumnName | Should -Contain timespan
            }
            It " has a [long] data type on the column timespan" {
                $result.timespan | Should -BeOfType Int64
            }
            It " has the following timespan: 15724800000" {
                $result.timespan | Should -Be 15724800000
            }
        }
        Context "Data type datetime" {
            It " has a column called datetime" {
                $result.Columns.ColumnName.Contains('datetime') | Should -Be $true
            }
            It " has a [datetime] data type on the column datetime" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'datetime' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'datetime'
            }
            It " has the following datetime: 2016-10-30 05:52:00.000" {
                $date = Get-Date -Year 2016 -Month 10 -Day 30 -Hour 5 -Minute 52 -Second 0 -Millisecond 0
                $result.datetime -eq $date | Should -Be $true
            }
        }
        Context "Data type char" {
            It " has a column called char" {
                $result.Columns.ColumnName.Contains('char') | Should -Be $true
            }
            It " has a [char] data type on the column char" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'char' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'char'
            }
            It " has the following char: T" {
                $result.char | Should -Be "T"
            }
        }
        Context "Data type true" {
            It " has a column called true" {
                $result.Columns.ColumnName.Contains('true') | Should -Be $true
            }
            It " has a [bool] data type on the column true" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'true' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'boolean'
            }
            It " has the following bool: true" {
                $result.true | Should -Be $true
            }
        }
        Context "Data type false" {
            It " has a column called false" {
                $result.Columns.ColumnName.Contains('false') | Should -Be $true
            }
            It " has a [bool] data type on the column false" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'false' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'boolean'
            }
            It " has the following bool: false" {
                $result.false | Should -Be $false
            }
        }
        Context "Data type null" {
            It " has a column called null" {
                $result.Columns.ColumnName.Contains('null') | Should -Be $true
            }
            It " has a [bool] data type on the column null" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'null' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'boolean'
            }
            It " has the following bool: false" {
                $result.null | Should -Be $false #should actually be $null but its hard to compare :)
            }
        }
        Context "Data type string" {
            It " has a column called string" {
                $result.Columns.ColumnName.Contains('string') | Should -Be $true
            }
            It " has a [string] data type on the column string" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'string' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'string'
            }
            It " has the following string: it's a boy." {
                $result.string | Should -Be "it's a boy."
            }
        }
        Context "Data type UInt64" {
            It " has a column called UInt64" {
                $result.Columns.ColumnName.Contains('UInt64') | Should -Be $true
            }
            It " has a [UInt64] data type on the column UInt64" {
                $result.Columns | Where-Object -Property 'ColumnName' -EQ 'UInt64' | Select-Object -ExpandProperty 'DataType' | Select-Object -ExpandProperty Name | Should -Be 'UInt64'
            }
            It " has the following number: 123456" {
                $result.UInt64 | Should -Be 123456
            }
        }
        Context "Data type myObject" {
            It " has a column called myObject" {
                $result.Columns.ColumnName.Contains('myObject') | Should -Be $true
            }
            It " has a [string] data type on the column myObject" {
                $result.myObject | Should -BeOfType System.String
            }
            It " type should be string hashtable (which is really just a string)" {
                $result.myObject | Should -BeOfType String
            }
        }
    }
    Context "Verifying TimeSpanType" -ForEach $obj {
        BeforeAll {
            $obj = New-Object -TypeName psobject -Property @{
                timespan = New-TimeSpan -Start 2017-01-01 -End 2017-01-02
            }
        }
        It " returns '1.00:00:00' when String is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType String).Timespan | Should -Be '1.00:00:00'
        }
        It " returns 864000000000 when Ticks is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType Ticks).Timespan | Should -Be 864000000000
        }
        It " returns 1 when TotalDays is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType TotalDays).Timespan | Should -Be 1
        }
        It " returns 24 when TotalHours is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType TotalHours).Timespan | Should -Be 24
        }
        It " returns 86400000 when TotalMilliseconds is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType TotalMilliseconds).Timespan | Should -Be 86400000
        }
        It " return 1440 when TotalMinutes is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType TotalMinutes).Timespan | Should -Be 1440
        }
        It " returns 86400 when TotalSeconds is used" {
            (ConvertTo-DbaDataTable -InputObject $obj -TimeSpanType TotalSeconds).Timespan | Should -Be 86400
        }
    }
    Context "Verifying IgnoreNull" {
        BeforeAll {
            # To be able to force null
            function returnnull {
                [CmdletBinding()]
                param ()
                New-Object -TypeName psobject -Property @{ Name = [int]1 }
                $null
                New-Object -TypeName psobject -Property @{ Name = [int]3 }
            }
        }
        It " does not create row if null is in array when IgnoreNull is set" {
            $result = ConvertTo-DbaDataTable -InputObject (returnnull) -IgnoreNull -WarningAction SilentlyContinue
            $result.Rows.Count | Should -Be 2
        }
        It " does not create row if null is in pipeline when IgnoreNull is set" {
            $result = returnnull | ConvertTo-DbaDataTable -IgnoreNull -WarningAction SilentlyContinue
            $result.Rows.Count | Should -Be 2
        }
        It " returns empty row when null value is provided (without IgnoreNull)" {
            $result = ConvertTo-DbaDataTable -InputObject (returnnull)
            $result.Name[0] | Should -Be 1
            $result.Name[1] | Should -BeOfType System.DBNull
            $result.Name[2] | Should -Be 3
        }
        It " returns empty row when null value is passed in pipe (without IgnoreNull)" {
            $result = returnnull | ConvertTo-DbaDataTable
            $result.Name[0] | Should -Be 1
            $result.Name[1] | Should -BeOfType System.DBNull
            $result.Name[2] | Should -Be 3
        }
        It " suppresses warning messages when Silent is used" {
            $null = ConvertTo-DbaDataTable -InputObject (returnnull) -IgnoreNull -EnableException -WarningVariable warn -WarningAction SilentlyContinue
            $warn.message -eq $null | Should -Be $true
        }
    }
    Context "Verifying script properties returning null" {
        It "Returns string column if a script property returns null" {
            $myObj = New-Object -TypeName psobject -Property @{ Name = 'Test' }
            $myObj | Add-Member -Force -MemberType ScriptProperty -Name ScriptNothing -Value { $null }
            $r = ConvertTo-DbaDataTable -InputObject $myObj
            ($r.Columns | Where-Object ColumnName -EQ ScriptNothing | Select-Object -ExpandProperty DataType).ToString() | Should -Be 'System.String'

        }
    }
    Context "Verifying a datatable gets cloned when passed in" {
        BeforeAll {
            $obj = New-Object -TypeName psobject -Property @{
                col1 = 'col1'
                col2 = 'col2'
            }
            $first = $obj | ConvertTo-DbaDataTable
            $second = $first | ConvertTo-DbaDataTable
        }
        It " has the same columns" {
            # does not add ugly RowError,RowState Table, ItemArray, HasErrors
            $firstColumns = ($first.Columns.ColumnName | Sort-Object) -Join ','
            $secondColumns = ($second.Columns.ColumnName | Sort-Object) -Join ','
            $firstColumns | Should -Be $secondColumns
        }
    }
}