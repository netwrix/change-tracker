Install-Module -Name Pester -Force -SkipPublisherCheck -PassThru -MinimumVersion 5.7.1    
Import-Module Pester -PassThru -MinimumVersion 5.7.1

BeforeAll {
    . $PSScriptRoot\..\Functions\Get-NctDevices.ps1
    . $PSScriptRoot\..\Functions\Add-NctProxiedDevice.ps1
    . $PSScriptRoot\..\Functions\Remove-NctProxiedDevice.ps1
}

Describe 'Adding, getting and deleting proxied devices' {
    BeforeAll {
        
        # Add a credential for the device

        $CredentialName = [System.Guid]::NewGuid().ToString()
        $password = ConvertTo-SecureString "test123" -AsPlainText -Force 

        # enusre the random user doesn't exist
        # Remove-NctCredential does not error if it doesn't find the credential to delete
        Remove-NctCredential -name $CredentialName

        Add-NctDatabaseCredential -name $CredentialName -username "PesterTest" -password $password

        # Prep the device name
        $DeviceName = [System.Guid]::NewGuid().ToString()

        # enusre the random device doesn't exist
        # Remove-NctProxiedDevice does not error if it doesn't find the device to delete
        Remove-NctProxiedDevice -name $DeviceName
    }

    It 'add a proxied device' {        
        Add-NctProxiedDevice `
            -ProxyAgentName "ubuntu24-01" `
            -ProxiedDeviceName $DeviceName `
            -HostName $DeviceName `
            -Credential $CredentialName
    }

    It 'ensure random device is not found' { 
        $RandomDeviceName = [System.Guid]::NewGuid().ToString()   
            
        $Device = Get-NctDevices -name $RandomDeviceName                           

        $Device | Should -BeNullOrEmpty
    }

    It 'ensure device was added' {        
        $Device = Get-NctDevices -name $DeviceName                           

        $Device | Should -Not -BeNullOrEmpty
    }
    
    It 'delete the device' {        
        Remove-NctProxiedDevice -name $DeviceName

        $Device = Get-NctDevices -name $DeviceName 
        $Device | Should -Be $null
    }

    AfterAll {
        # Delete credential and devices if any test fails
        Remove-NctProxiedDevice -name $DeviceName
        Remove-NctCredential -name $CredentialName
    }
}