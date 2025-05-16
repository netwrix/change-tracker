using module ..\Classes\NctSessionManager.psm1

<#
.Description
Returns an authenticated session object from the API of a Change Tracker Hub instance.

.PARAMETER url
The URL of the Change Tracker Hub to authenticate with.

.PARAMETER user
The user to authenticate with.

.PARAMETER SkipCertificateCheck
Warning - Any certificate will be trusted.
Skips the checking of the certificate used by the Change Tracker Hub.


.EXAMPLE

PS> $mySession = New-NctSession -url "https://192.168.0.10/api" -user "admin"

#>
Function New-NctSession {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$false)]
        [string]$url = $Global:NctHubUrl,

        [Parameter(Position=2, mandatory=$false)] 
        [string]$user = $Global:NctUserName,

        [Parameter(Position=3, mandatory=$false)]
        [switch]$SkipCertificateCheck = $false
    )    

    # Ensure PowerShell 7 is in use because -SkipCertificateCheck is not available in previous versions
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -lt 7)
    {
        Throw "PowerShell $psVersion is not supported. Please user version 7 or above"
    }

    if (-not $url)
    {
        $url = Read-host "URL (HTTPS://YourNctHubHostName/api)"
    }

    if (-not $user)
    {
        $user = Read-host "User"
    }

    # Set as global variables so all Invoke-RestMethod calls can use it
    $Global:NctSkipCertificateCheck = $SkipCertificateCheck
    $Global:NctUserName = $user
    $Global:NctHubUrl = $url

    # Check rate limiting before proceeding with authentication
    if (-not (Test-NctAuthenticationStatus -Username $user -Action Check)) {
        return $null
    }

    # Validate certificate before proceeding
    if (-not $SkipCertificateCheck) {
        if (-not (Test-NctCertificate -Url $url)) {
            Write-Error "Failed to validate certificate for $url. Please ensure the certificate is trusted or use 'New-NctSession -SkipCertificateCheck' to bypass validation (not recommended in production)."
            return $null
        }
    }

    Write-Verbose "Acquiring User Session for $user to $uri"

    # Use the session manager to create and manage the session
    $sessionManager = [NctSessionManager]::new($url, $user, $SkipCertificateCheck)
    $session = $sessionManager.NewSession()

    if ($session) {
        $Global:NctSession = $session
        $Global:NctSessionCreatedTime = $sessionManager.SessionCreatedTime
        return $session
    }
    else {
        return $null
    }
}
