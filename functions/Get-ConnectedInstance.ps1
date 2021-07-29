function Get-DbaConnectedInstance {
    <#
    .SYNOPSIS
        Get a list of all connected instances.

    .DESCRIPTION
        Get a list of all connected instances

    .NOTES
        Tags: Connection
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2021 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaConnectedInstance

    .EXAMPLE
        PS C:\> Get-DbaConnectedInstance

        Gets all connections

    #>
    [CmdletBinding()]
    param ()
    process {
        foreach ($key in $script:connectionhash.Keys) {
            [pscustomobject]@{
                SqlInstance = (Hide-ConnectionString -ConnectionString $key)
                Connection  = $script:connectionhash[$key]
            }
        }
    }
}