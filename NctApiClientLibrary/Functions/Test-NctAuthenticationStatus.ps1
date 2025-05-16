<#
.SYNOPSIS
Tests the authentication status and manages rate limiting

.DESCRIPTION
Checks if authentication is allowed based on rate limiting rules and manages authentication state

.PARAMETER Username
The username being authenticated

.PARAMETER Action
The action to take: 'Check', 'SetSuccess', or 'SetFailure'

.PARAMETER MaxAttempts
Maximum number of failed attempts allowed before locking out

.PARAMETER LockoutDuration
Duration in minutes to lock out after max attempts

.EXAMPLE
# Check if authentication is allowed
$allowed = Test-NctAuthenticationStatus -Username "admin" -Action Check

.EXAMPLE
# Record a successful authentication
Test-NctAuthenticationStatus -Username "admin" -Action SetSuccess

.EXAMPLE
# Record a failed authentication
Test-NctAuthenticationStatus -Username "admin" -Action SetFailure
#>
function Test-NctAuthenticationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Check','SetSuccess','SetFailure')]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [int]$MaxAttempts = 5,

        [Parameter(Mandatory=$false)]
        [int]$LockoutDuration = 30
    )

    $rateLimitPath = Join-Path $env:TEMP "NCTAuthRateLimit"
    $userRateLimitPath = Join-Path $rateLimitPath "$Username.json"

    if (-not (Test-Path $rateLimitPath)) {
        New-Item -Path $rateLimitPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created rate limit directory at $rateLimitPath"
    }

    try {
        $rateLimitData = if (Test-Path $userRateLimitPath) {
            Get-Content $userRateLimitPath | ConvertFrom-Json
            Write-Verbose "Rate limit data loaded from $userRateLimitPath"
        } else {
            @{
                LastSuccess = [DateTime]::UtcNow
                FailedAttempts = 0
                LastFailedAttempt = $null
            }
        }

        switch ($Action) {
            'Check' {
                if ($rateLimitData.FailedAttempts -ge $MaxAttempts) {
                    $lockoutTime = $rateLimitData.LastFailedAttempt.AddMinutes($LockoutDuration)
                    if ([DateTime]::UtcNow -lt $lockoutTime) {
                        $timeRemaining = $lockoutTime - [DateTime]::UtcNow
                        Write-Error "Account locked out for $timeRemaining minutes due to too many failed attempts"
                        return $false
                    }
                    # Reset failed attempts if lockout period has passed
                    $rateLimitData.FailedAttempts = 0
                }
                return $true
            }
            'SetSuccess' {
                $rateLimitData.LastSuccess = [DateTime]::UtcNow
                $rateLimitData.FailedAttempts = 0
                $rateLimitData | ConvertTo-Json | Set-Content $userRateLimitPath
            }
            'SetFailure' {
                $rateLimitData.FailedAttempts++
                $rateLimitData.LastFailedAttempt = [DateTime]::UtcNow
                $rateLimitData | ConvertTo-Json | Set-Content $userRateLimitPath
            }
        }
    } catch {
        Write-Error "Failed to manage authentication rate limiting: $_"
        throw
    }
}
