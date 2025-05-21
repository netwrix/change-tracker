# Import required modules
Import-Module Microsoft.PowerShell.Security
Import-Module Microsoft.PowerShell.Utility

# Load functions
$FunctionFiles = Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 -File

foreach ($file in $FunctionFiles) {
    Write-Verbose "Loading function: $($file.Name)"
    . $file.FullName
}

# Export all functions
Export-ModuleMember -Function `
    Add-NctDatabaseCredential, `
    Add-NctProxiedDevice, `
    Get-NctAgents, `
    Get-NctCredentials, `
    Get-NctDevices, `
    New-NctApiCredential, `
    New-NctSession, `
    Protect-Credential, `
    Test-NctAuthenticationStatus, `
    Test-NctCertificate, `
    Remove-NctCredential, `
    Remove-NctProxiedDevice, `
    Test-NctSession, `
    Update-NctDevice
