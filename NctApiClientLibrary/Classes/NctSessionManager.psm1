<#
.SYNOPSIS
Manages Netwrix Change Tracker API sessions

.DESCRIPTION
Provides methods for creating, validating, and managing API sessions
#>

# Add type definitions
Add-Type -AssemblyName System.Net
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName Microsoft.PowerShell.Commands.Utility

class NctSessionManager {
    [string]$HubUrl
    [string]$Username
    [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    [datetime]$SessionCreatedTime
    [int]$SessionTimeoutMinutes = 10
    [bool]$SkipCertificateCheck

    # Constructor
    NctSessionManager([string]$HubUrl, [string]$Username, [bool]$SkipCertificateCheck = $false) {
        $this.HubUrl = $HubUrl
        $this.Username = $Username
        $this.SkipCertificateCheck = $SkipCertificateCheck
    }

    # Create a new session
    [Microsoft.PowerShell.Commands.WebRequestSession] NewSession() {
        try {
            # Check if we already have a valid session
            if ($this.Session -and $this.IsSessionValid()) {
                Write-Verbose "Using existing valid session"
                return $this.Session
            }

            # Get credentials
            $credentials = $this.GetCredentials()
            if (-not $credentials) {
                throw "Failed to get credentials"
            }

            # Create new session
            $uri = "$($this.HubUrl)/auth/credentials"
            Write-Verbose "Creating new session at $uri"

            $this.Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $result = Invoke-RestMethod `
                -Method Post `
                -Uri $uri `
                -Headers @{ Accept = 'application/json' } `
                -Body "username=$($credentials.username)&password=$($credentials.Password)&format=json" `
                -WebSession $this.Session `
                -SkipCertificateCheck:$this.SkipCertificateCheck

            if ($null -ne $result.UserId -and $null -ne $result.SessionId) {
                $this.SessionCreatedTime = Get-Date
                Write-Verbose "Session created successfully"

                # Record successful authentication
                Test-NctAuthenticationStatus -Username $credentials.username -Action SetSuccess
                
                return $this.Session
            }
            else 
            {
                # Record failed authentication
                Test-NctAuthenticationStatus -Username $credentials.username -Action SetFailure

                throw "Authentication failed: Invalid credentials or server response"
            }
        }
        catch [System.Net.WebException] {
            $this.Cleanup()
            $statusCode = $_.Exception.Response.StatusCode
            $errorDetails = $_.Exception.Response.StatusDescription

            # Don't expose sensitive error details
            if ($statusCode -eq 401) {
                throw "Authentication failed: Invalid credentials"
            }
            if ($statusCode -eq 403) {
                throw "Authentication failed: Access denied"
            }
            if ($statusCode -eq 404) {
                throw "Authentication failed: API endpoint not found"
            }

            Write-Verbose "Error details: $errorDetails"
            throw "Authentication failed: Network error occurred"
        }
        catch [System.Security.Authentication.AuthenticationException] {
            $this.Cleanup()
            throw "Authentication failed: Invalid credentials"
        }
        catch {
            $this.Cleanup()
            Write-Verbose "Error details: $_"
            throw "Authentication failed: An unexpected error occurred"
        }
    }

    # Check if session is valid
    [bool] IsSessionValid() {
        if (-not $this.Session) {
            return $false
        }

        # Check session age
        $sessionAge = (Get-Date) - $this.SessionCreatedTime
        if ($sessionAge.TotalMinutes -ge $this.SessionTimeoutMinutes) {
            Write-Verbose "Session has expired"
            return $false
        }

        # Test session by making a simple request
        try {
            $testUri = "$($this.HubUrl)/api/agentsRanked"
            $result = Invoke-RestMethod `
                -Method Get `
                -Uri $testUri `
                -WebSession $this.Session `
                -SkipCertificateCheck:$this.SkipCertificateCheck

            if ($result) {
                Write-Verbose "Session test successful"
                return $true
            }
            else {
                Write-Verbose "Session test failed: No response received"
                return $false
            }
        }
        catch {
            Write-Verbose "Session test failed: $_"
            return $false
        }
    }

    # Get credentials
    [System.Net.NetworkCredential] GetCredentials() {
        try {
            $path = "$env:USERPROFILE\.nct client library\$($this.Username).dat" 
            if ($path -and (Test-Path $path)) {
                Write-Verbose "Reading credentials from $path"
                return New-NctApiCredential -user $this.Username -persist
            }
            else {
                Write-Verbose "Credentials not found at $path"
                return New-NctApiCredential -user $this.Username
            }
        }
        catch {
            Write-Verbose "Credential retrieval error: $_"
            throw "Failed to retrieve credentials"
        }
    }

    # Clean up session
    [void] Cleanup() {
        if ($this.Session) {
            $this.Session.Dispose()
            $this.Session = $null
        }
        #$this.SessionCreatedTime = [datetime]::MinValue
    }

    # Static method to create a new session
    static [System.Net.CookieContainer] CreateSession([string]$HubUrl, [string]$Username, [bool]$SkipCertificateCheck = $false) {
        $manager = [NctSessionManager]::new($HubUrl, $Username, $SkipCertificateCheck)
        return $manager.NewSession()
    }

    # Static method to test session validity
    static [bool] IsSessionValid([System.Net.CookieContainer]$Session, [string]$HubUrl, [bool]$SkipCertificateCheck = $false) {
        $manager = [NctSessionManager]::new($HubUrl, $null, $SkipCertificateCheck)
        $manager.Session = $Session
        return $manager.IsSessionValid()
    }
}
