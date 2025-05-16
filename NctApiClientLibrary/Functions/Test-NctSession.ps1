. "$PSScriptRoot\New-NctApiCredential.ps1"
. "$PSScriptRoot\New-NctSession.ps1"

<#
.Description
Tests that a session to a Change Tracker Hub is valid and attempts to create a new one if not.


.EXAMPLE

PS> Test-NctSession

#>
Function Test-NctSession {
    [CmdletBinding()]
    param()

    # Get global variable existnece status
    $urlExists = Test-Path variable:global:NctHubUrl
    $sessionExists = Test-Path variable:global:NctSession
    $sessionCreatedTimeExists = Test-Path variable:global:NctSessionCreatedTime
    $userNameExists = Test-Path variable:global:NctUserName
    $SkipCertificateCheckExists = Test-Path variable:global:NctSkipCertificateCheck

    # If any of the global variables do not exist then check for a credential file in $env:USERPROFILE\.nct client library
    # If no credential file found then prompt user for the Hub URL and username
    if 
    ( (-not $urlExists) -or (-not $sessionExists) -or (-not $sessionCreatedTimeExists) -or (-not $userNameExists) -or (-not $SkipCertificateCheckExists))
    {
        Write-Verbose "Netwrix Change Tracker session details were not found."
        Write-Verbose "Hub URL found: $urlExists"
        Write-Verbose "Session found: $sessionExists"
        Write-Verbose "Session create time found: $sessionCreatedTimeExists"
        Write-Verbose "Username found: $userNameExists"
        Write-Verbose "SkipCertificateCheck setting found: $SkipCertificateCheckExists"

        # Create the "$env:USERPROFILE\.nct client library" directory if it does not exist
        if (-not (Test-Path -Path "$env:USERPROFILE\.nct client library"))
        {
            New-Item -Path "$env:USERPROFILE\.nct client library" -ItemType Directory
        }

        # If text files found in $env:USERPROFILE\.nct client library then print a numbered list for the user to select which to load
        $files = Get-ChildItem -Path "$env:USERPROFILE\.nct client library" -Filter "*.txt" | Select-Object -ExpandProperty Name
        if ($files.Count -gt 0)
        {
            Write-Host "The following credential files were found in $env:USERPROFILE\.nct client library:"
            $i = 1
            try
            {
                $i = 1
                foreach ($file in $files)
                {
                    Write-Host "$i. $file"
                    $i++
                }
            }
            catch
            {
                Write-Output "Error: $_"
            }
            
            # Prompt user to select a file to load
            $selection = Read-Host "Select a credential file to load. Enter the number or press Enter to skip"

            if ($selection -eq "") 
            { 
                $selection = $null 
                
                # Prompt user for the Hub URL, username and password
                New-NctSession -SkipCertificateCheck:$Global:NctSkipCertificateCheck
            }
            else
            {
                if ($selection -and $selection -match '^\d+$' -and $selection -le $files.Count)
                {
                    # Load the selected credential file
                    $user = [System.IO.Path]::GetFileNameWithoutExtension($files[$selection - 1])
                    
                    New-NctApiCredential -user $user -persist

                    New-NctSession -user $user -SkipCertificateCheck:$Global:NctSkipCertificateCheck
                }
                else
                {
                    Write-Output "Invalid selection. Please enter a number between 1 and $($files.Count) or press Enter to skip."
                    return
                }
            }
        }
        else
        {
            Write-Output "No credential files found in $env:USERPROFILE\.nct client library."

            # Prompt user for the Hub URL, username and password
            New-NctSession 
        }

        # If any sessions details were not created correctly then exit
        if 
        ( (-not(Test-Path variable:global:NctHubUrl)) -or (-not(Test-Path variable:global:NctSession)) -or (-not(Test-Path variable:global:NctSessionCreatedTime)) -or (-not(Test-Path variable:global:NctUserName)) -or (-not(Test-Path variable:global:NctSkipCertificateCheck)))
        {
            throw "Netwrix Change Tracker session details were not created correctly!"
        }
    }

    # If current session is older than 10 minutes then renew the session
    if ($global:NctSessionCreatedTime.AddMinutes(10) -lt (Get-Date))
    {
        Write-Verbose "Renewing session that was created at $global:NctSessionCreatedTime for $global:NctHubUrl with the $global:NctUserName credential"

        New-NctSession -url $global:NctHubUrl -user $global:NctUserName -SkipCertificateCheck:$Global:NctSkipCertificateCheck 

        # If any sessions details were not created correctly then exit
        if 
        ( (-not(Test-Path variable:global:NctHubUrl)) -or (-not(Test-Path variable:global:NctSession)) -or (-not(Test-Path variable:global:NctSessionCreatedTime)) -or (-not(Test-Path variable:global:NctUserName)) -or (-not(Test-Path variable:global:NctSkipCertificateCheck)))
        {
            throw "Session renewal failed. Netwrix Change Tracker session details were not created correctly!"
        }
    }
}