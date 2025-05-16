<#
.SYNOPSIS
Tests and validates SSL/TLS certificates for secure connections

.DESCRIPTION
Validates SSL/TLS certificates for HTTPS connections to ensure secure communication

.PARAMETER Url
The URL to validate the certificate for

.PARAMETER SkipCertificateCheck
Optional switch to skip certificate validation (not recommended)

.EXAMPLE
# Validate certificate for a URL
Test-NctCertificate -Url "https://example.com"

.EXAMPLE
# Skip certificate validation (not recommended)
Test-NctCertificate -Url "https://example.com" -SkipCertificateCheck
#>
function Test-NctCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$false)]
        [switch]$SkipCertificateCheck
    )

    try {
        # Configure security protocol
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        if (-not $SkipCertificateCheck) {
            # Set up certificate validation callback
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
                param($sender, $certificate, $chain, $sslPolicyErrors)
                
                if ($sslPolicyErrors -eq [System.Net.Security.SslPolicyErrors]::None) {
                    Write-Verbose "Certificate validation successful"
                    return $true
                }

                # Log detailed certificate information
                Write-Warning "Certificate validation failed: $sslPolicyErrors"
                Write-Warning "Certificate details: $($certificate.Subject)"
                Write-Warning "Certificate issuer: $($certificate.Issuer)"
                Write-Warning "Certificate expiration: $($certificate.GetExpirationDateString())"
                
                # Check specific errors
                if ($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateNameMismatch) {
                    Write-Warning "Certificate name does not match the hostname"
                }
                if ($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateChainErrors) {
                    Write-Warning "Certificate chain is invalid or incomplete"
                }
                if ($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateNotAvailable) {
                    Write-Warning "No certificate was provided by the server"
                }
                
                # Only allow trusted certificates
                return $false
            }
        }
        else {
            # Skip certificate validation if requested
            Write-Warning "Certificate validation is disabled. This is not recommended for production use."
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        }

        # Test the connection
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.DefaultRequestHeaders.Add("Accept", "application/json")
        $response = $httpClient.GetAsync($Url).Result

        if ($response.IsSuccessStatusCode) {
            Write-Verbose "Connection test successful"
            return $true
        }
        else {
            Write-Error "Connection test failed with status code: $($response.StatusCode)"
            return $false
        }
    }
    catch {
        Write-Error "Failed to validate certificate: $_"
        return $false
    }
}
