# Controls the timeout on sql connects
Set-DbatoolsConfig -FullName 'sql.connection.timeout' -Value 15 -Initialize -Validation integerpositive -Handler { [Sqlcollaborative.Dbatools.Connection.ConnectionHost]::SqlConnectionTimeout = $args[0] } -Description "The number of seconds before sql server connection attempts are aborted"
