﻿$commandname = $MyInvocation.MyCommand.Name.Replace(".ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
	Context "Can remove a certificate" {
		BeforeAll {
			$cert = New-DbaComputerCertificate -SelfSigned -Silent
			$thumbprint = $cert.Thumbprint
		}
		
		$results = $cert | Remove-DbaComputerCertificate -Confirm:$false

		It "returns the store Name" {
			$results.Store -eq "LocalMachine" | Should Be $true
		}
		It "returns the folder Name" {
			$results.Folder -eq "My" | Should Be $true
		}
		
		It "reports the proper status of Removed" {
			$results.Status -eq "Removed" | Should Be $true
		}
		
		It "really removed it" {
			$results = Get-DbaComputerCertificate -Thumbprint $thumbprint
			$results | Should Be $null
		}
	}
}