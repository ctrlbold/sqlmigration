﻿
Function Set-DbaJobOutPutFile
{
<#
.Synopsis
   Sets the OutPut File for a step of an agent job with the Job Names and steps provided dynamically 
.DESCRIPTION
   Sets the OutPut File for a step of an agent job with the Job Names and steps provided dynamically if required

.PARAMETER SqlServer
    The SQL Server that you're connecting to.

.PARAMETER SQLCredential
    Credential object used to connect to the SQL Server as a different user be it Windows or SQL Server. Windows users are determiend by the existence of a backslash, so if you are intending to use an alternative Windows connection instead of a SQL login, ensure it contains a backslash.

.PARAMETER JobName
    The Agent Job Name to provide Output File Path for. Also available dynamically

.PARAMETER Step
    The Agent Job Step to provide Output File Path for. Also available dynamically

.PARAMETER OutputFile
    The Full Path to the New Output file
.EXAMPLE
   Set-DbaJobOutPutFile -sqlserver SERVERNAME -JobName 'The Agent Job' -OutPutFile E:\Logs\AgentJobStepOutput.txt

   Sets the Job step for The Agent job on SERVERNAME to E:\Logs\AgentJobStepOutput.txt
.NOTES
   AUTHOR - Rob Sewell https://sqldbawithabeard.com
   DATE - 30/10/2016
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param
(# The Server/instance 
        [Parameter(Mandatory=$true,HelpMessage='The SQL Server Instance', 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [object]$SqlServer,
       [Parameter(Mandatory=$false,HelpMessage='SQL Credential', 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [System.Management.Automation.PSCredential]$SqlCredential,
        [Parameter(Mandatory=$true,HelpMessage='The Full Output File Path', 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFile,
        [Parameter(Mandatory=$false,HelpMessage='The Job Step name', 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [object]$Step)

    DynamicParam { if ($SqlServer) { return (Get-ParamSqlJobs -SqlServer $SqlServer -SqlCredential $SourceSqlCredential) } }

    BEGIN
    {
            $JobName = $psboundparameters.Jobs   
    }
    PROCESS
    {
        $Server = Connect-SqlServer -SqlServer $sqlserver -SqlCredential $SqlCredential
        $Job = $server.JobServer.Jobs[$JobName]
        If(!$Step)
        {
            if( ($Job.JobSteps).Count -gt 1)
            {
                Write-output "Which Job Step do you wish to add output file to?"
                $Step = $Job.JobSteps| Out-GridView -Title "Choose the Job Steps to add an output file to" -PassThru -Verbose
            }
            else
            {
                $Step = $Job.JobSteps
            }
        }

        Write-Output "Current Output File for $($Job.Name) is $(($Step).OutputFileName)"
        Write-Output "Adding $OutputFile to $($Step.Name) for $($Job.Name)"

        try
        {
           If ($Pscmdlet.ShouldProcess($($Step.Name), "Changing Output File from $(($Step).OutputFileName) to $OutputFile"))
				{
                    $Step.OutputFileName = $OutputFile
                    $Step.Alter()
                    Write-Output "Successfully added Output file $OutputFile to $($Job.Name) - You can check with Get-DbaJobOutputFile -sqlserver $sqlserver -Jobs '$JobName'"
                }
        }
        catch
        {
           Write-Warning "Failed to add $OutputFile to $(($Step).Name) for $JobName - Run `$error[0] | fl -force to find out why!"
        }
    }
    end
    {
          $server.ConnectionContext.Disconnect()
    }
}
