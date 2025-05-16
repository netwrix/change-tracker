Install-Module -Name Pester -Force -SkipPublisherCheck -PassThru -MinimumVersion 5.7.1    
Import-Module Pester -PassThru -MinimumVersion 5.7.1

BeforeAll {
    . $PSScriptRoot\..\Functions\Get-NctCredentials.ps1
    . $PSScriptRoot\..\Functions\Add-NctDatabaseCredential.ps1
    . $PSScriptRoot\..\Functions\Remove-NctCredential.ps1
}

Describe 'Adding, getting and deleting database credentials' {
    BeforeAll {
        $CredentialName = [System.Guid]::NewGuid().ToString()
        $password = ConvertTo-SecureString "test123" -AsPlainText -Force 

        # enusre the random user doesn't exist
        # Remove-NctCredential does not error if it doesn't find the credential to delete
        Remove-NctCredential -name $CredentialName
    }

    It 'add a database credential' {        
        Add-NctDatabaseCredential -name $CredentialName -username "PesterTest" -password $password
    }

    It 'ensure database credential was added' {        
        $credentials = Get-NctCredentials

        $CredentialPresent = $false

        if ($credentials | Where-Object { $_.Key -eq $CredentialName }) {
            $CredentialPresent = $true
        } 

        $CredentialPresent | Should -Be $true
    }

    It 'get a database credential with name param' {        
        $credential = Get-NctCredentials -name $CredentialName 
        $credential.Key | Should -Be $CredentialName
    }

    It 'delete the database credential' {        
        Remove-NctCredential -name $CredentialName

        $credential = Get-NctCredentials -name $CredentialName 
        $credential | Should -Be $null
    }

    AfterAll {
        # Delete random credential if any test fails
        Remove-NctCredential -name $CredentialName
    }
}