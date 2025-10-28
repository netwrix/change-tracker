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
        # Enforce HTTPS
        if (-not $HubUrl.StartsWith("https://")) {
            throw "Insecure connection: Only HTTPS endpoints are allowed. Refusing to connect to $HubUrl"
        }
        
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

            # Check if 2FA is required
            $oneTimePassword = $this.Check2FA($credentials)

            # Build request 
            $body = @{
                "UserName" = $credentials.username
                "Password" = $credentials.Password
                "RememberMe" = "false"
                "Meta" = @{
                    "OneTimePassword" = $oneTimePassword
                }
            } | ConvertTo-Json
            
            # Create new session
            $uri = "$($this.HubUrl)/auth/credentials"
            Write-Verbose "Creating new session at $uri"

            $this.Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $result = Invoke-RestMethod `
                -Method Post `
                -ContentType application/json `
                -Uri $uri `
                -Headers @{ Accept = 'application/json' } `
                -Body $body `
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
            throw "Authentication failed: $_"
        }
        catch {
            $this.Cleanup()
            throw "Unknown connection failure: $_"
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
                $ApiCredential = New-NctApiCredential -user $this.Username -persist
            }
            else {
                Write-Verbose "Credentials not found at $path"
                $ApiCredential = New-NctApiCredential -user $this.Username
            }  

            return $ApiCredential
        }
        catch {
            throw "Credential retrieval error: $_"
        }
    }

    [string] Check2FA([System.Net.NetworkCredential]$ApiCredential) {
        $uri = "$($this.HubUrl)/users/twoFactorStatus" 
        try {
            Write-Verbose "Checking if 2FA is required"                     

            $body = @{
                "UserName" = $($ApiCredential.UserName)
                "Password" = $($ApiCredential.Password)
            } | ConvertTo-Json
  
            $result = Invoke-RestMethod `
                -Method Post `
                -Uri $uri `
                -ContentType application/json `
                -Headers @{ Accept = 'application/json' } `
                -Body $body `
                -SkipCertificateCheck:$this.SkipCertificateCheck

            Write-Verbose "2FA check result: $result"

            if ($result.TwoFactorRequired) { 
                if ($result.TwoFactorRegistration -eq "Registering") {
                    Write-Verbose "2 Factor Authentication is required"
                    Write-Host "Using an authenticator app on your mobile device (eg Google Authenticator, Authy, LastPass, iPhone etc) scan the QR barcode found at the link below: "
                    Write-Host ""
                    Write-Host "$($result.SetupImageUrl)"
                    Write-Host ""
                    Write-Host "Alternatively manually enter this setup code into the authenticator app to register Change Tracker with your mobile device: $($result.SetupCode)"
                    Write-Host ""
                    Read-Host "Press Enter when you have completed the 2FA setup"
                }  
                
                $OneTimePassword = Read-Host "Enter the one-time password from your authenticator app"
                return $OneTimePassword                
            }   
            else {
                Write-Verbose "2FA is not required"
                return $null
            }
        }
        catch {
            throw "2FA check failed: $_"
            return $null
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
