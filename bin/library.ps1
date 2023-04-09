if ($PSVersionTable.PSEdition -ne "Core") {
    $dir = [System.IO.Path]::Combine($script:libraryroot, "lib")
    $dir = ("$dir\").Replace('\', '\\')

    if (-not ("Redirector" -as [type])) {
        $source = @"
            using System;
            using System.Linq;
            using System.Reflection;
            using System.Text.RegularExpressions;

            public class Redirector
            {
                public Redirector()
                {
                    this.EventHandler = new ResolveEventHandler(AssemblyResolve);
                }

                public readonly ResolveEventHandler EventHandler;

                protected Assembly AssemblyResolve(object sender, ResolveEventArgs e)
                {
                    string[] dlls = {
                        "System.Memory",
                        "System.Runtime.CompilerServices.Unsafe",
                        "System.Resources.Extensions",
                        "Microsoft.SqlServer.ConnectionInfo",
                        "Microsoft.SqlServer.Smo",
                        "Microsoft.Identity.Client",
                        "System.Diagnostics.DiagnosticSource",
                        "Microsoft.IdentityModel.Abstractions",
                        "Microsoft.Data.SqlClient",
                        "Microsoft.SqlServer.Types",
                        "System.Configuration.ConfigurationManager",
                        "Microsoft.SqlServer.Management.Sdk.Sfc",
                        "Microsoft.SqlServer.Management.IntegrationServices",
                        "Microsoft.SqlServer.Replication",
                        "Microsoft.SqlServer.Rmo",
                        "System.Private.CoreLib"
                    };

                    var name = new AssemblyName(e.Name);
                    var assemblyName = name.Name.ToString();
                    foreach (string dll in dlls)
                    {
                        if (assemblyName == dll)
                        {
                            string filelocation = "$dir" + dll + ".dll";
                            //Console.WriteLine(filelocation);
                            return Assembly.LoadFrom(filelocation);
                        }
                    }

                    foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
                    {
                        // maybe this needs to change?
                        var info = assembly.GetName();
                        if (info.FullName == e.Name) {
                            return assembly;
                        }
                    }
                    return null;
                }
            }
"@

        $null = Add-Type -TypeDefinition $source
    }

    try {
        $redirector = New-Object Redirector
        [System.AppDomain]::CurrentDomain.add_AssemblyResolve($redirector.EventHandler)
    } catch {
        # unsure
    }
}

$dll = [System.IO.Path]::Combine($script:libraryroot, "lib", "dbatools.dll")

if ($IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    $sqlclient = [System.IO.Path]::Combine($script:libraryroot, "lib", "win-sqlclient", "Microsoft.Data.SqlClient.dll")
} else {
    $sqlclient = [System.IO.Path]::Combine($script:libraryroot, "lib", "Microsoft.Data.SqlClient.dll")
}

try {
    Import-Module $sqlclient
    Import-Module $dll
} catch {
    throw "Couldn't import dbatools.dll | $PSItem"
}

if ($PSVersionTable.PSEdition -ne "Core") {
    [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($onAssemblyResolveEventHandler)
}