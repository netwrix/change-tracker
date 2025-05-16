<#
.SYNOPSIS
Encrypts or decrypts data using Windows Data Protection API (DPAPI)

.DESCRIPTION
Uses the Windows Data Protection API to securely encrypt/decrypt data using the user's credentials

.PARAMETER Data
The data to encrypt or decrypt

.PARAMETER Action
The action to take: 'Encrypt' or 'Decrypt'

.PARAMETER Entropy
Optional additional entropy to use for encryption

.EXAMPLE
$encrypted = Protect-Credential -Data "mysecret" -Action Encrypt
$decrypted = Protect-Credential -Data $encrypted -Action Decrypt
#>
function Protect-Credential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet('Encrypt','Decrypt')]
        [string]$Action,
        
        [Parameter(Mandatory=$false)]
        [byte[]]$Entropy
    )

    Add-Type -AssemblyName System.Security
    
    if ($Action -eq 'Encrypt') {
        return [System.Security.Cryptography.ProtectedData]::Protect($Data, $Entropy, 'CurrentUser')
    }
    else {
        return [System.Security.Cryptography.ProtectedData]::Unprotect($Data, $Entropy, 'CurrentUser')
    }
}
