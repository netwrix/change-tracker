<#
.SYNOPSIS
Asks for credentials and stores them to a file as an encrypted secure string.

.Description
Asks for a file path and username before searching the path provided to see if a file exists with the name of the user.

If a file is not found then the user will be asked to enter a password. 
The password is stored as a secure string to a file in the provided path.

If a file exists it will attempt to load a secure string from the file to be used as the password.

Returns a System.Net.NetworkCredential object.

.PARAMETER user
The user to authenticate with.

.PARMAETER persist
Store encrypted credentials to a file.

.PARAMETER path
The file path to store encrypted credentials at.

.EXAMPLE

PS> New-NctApiCredential -user "admin"

.EXAMPLE

PS> New-NctApiCredential -user "admin" -persist

.EXAMPLE

PS> New-NctApiCredential -user "admin" -persist -path "c:\temp"
#>
Function New-NctApiCredential {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [string]$user,
            
        [Parameter(Position=2, mandatory=$false)]
        [switch]$persist = $false          
    )

    if ($persist)
    {
        $path = "$env:USERPROFILE\.nct client library" 
        $file = "$path\$user.dat"

        # If file does not exist, create a new credential and write it out
        if (!(Test-Path $file))
        {
            try
            {
                Write-Verbose "Creating new credential file at $file"       

                if (-not (Test-Path -Path $path)) 
                {
                    Write-Verbose "Creating directory $path"

                    New-Item -Path $path -ItemType Directory | Out-Null
                }
                
                # Get password as secure string
                $password = Read-Host "Enter Password to be stored to $file" -AsSecureString
                
                # Convert to byte array
                $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))
                
                # Encrypt using DPAPI
                $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
                
                # Save encrypted bytes to file
                [System.IO.File]::WriteAllBytes($file, $encryptedBytes)
                
                Write-Verbose "Password stored to $file"    
            }
            catch
            {
                Write-Error "An error occurred while storing the password to $file. Please check the path and permissions."
                Throw
            }
        }

        # Passing the persist argument also causes the credential to be read from file
        try
        {
            # Read encrypted bytes from file
            $encryptedBytes = [System.IO.File]::ReadAllBytes($file)
            
            # Decrypt using DPAPI
            $passwordBytes = Protect-Credential -Data $encryptedBytes -Action Decrypt
            
            # Convert back to secure string
            $password = ConvertTo-SecureString -String ([System.Text.Encoding]::UTF8.GetString($passwordBytes)) -AsPlainText -Force
            
            $ApiCredential = New-Object System.Net.NetworkCredential($user, $password) 

            Write-Verbose "Reading credentials from $file"
        }
        catch
        {
            Write-Verbose $_.Exception.Message
            Write-Error "Failed to load Netwrix Change Tracker API credentials from discovered credentials file: $file"
            Throw
        }
    }
    else
    {
        $password = Read-Host "Password can be persisted with:`nNew-NctApiCredential -user '$user' -persist`nEnter Password:`n" -AsSecureString

        $ApiCredential = New-Object System.Net.NetworkCredential($user, $password)        
    }  
    
    Return $ApiCredential  
}
