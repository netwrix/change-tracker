. "$PSScriptRoot\Test-NctSession.ps1"
. "$PSScriptRoot\Get-NctAgents.ps1"

<#
.Description
Submit a proxied device for a specific proxy agent to a Change Tracker Hub.

.PARAMETER name
Name of proxied device to add.

.EXAMPLE

PS> Add-NctProxiedDevice -ProxyAgentName "win-prod-proxy" -ProxiedDeviceName "win-prod-01" -HostName "win-prod-01" -Credential "win-prod" 

#>
Function Add-NctProxiedDevice {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [string]$ProxyAgentName,  
        
        [Parameter(Position=2, mandatory=$true)]
        [string]$ProxiedDeviceName,

        [Parameter(Position=3, mandatory=$true)]
        [string]$HostName,
        
        [Parameter(Position=4, mandatory=$true)]
        [string]$Credential
        
        # TODO: Add more params for DeviceType, HostType, etc
    )

    Test-NctSession -v    
    
    $uri = "$Global:NctHubUrl/agents/register"

    try
    {
        $ProxyAgent = Get-NctAgents -name $ProxyAgentName
        $ProxyAgentId = $ProxyAgent.AgentDevice.AgentId

        if ($ProxyAgentId -gt 0)
        {
            Write-Verbose "Proxy agent $ProxyAgentName found with id $ProxyAgentId"
        }
        else
        {
            Throw "Proxy agent $ProxyAgentName not found for new proxy agent $ProxiedDeviceName"
        }
    }
    catch
    {
        Throw "Failed to request proxy agent $ProxyAgentName's details for new proxy device $ProxiedDeviceName"
    }
    
    $body =
@"
{    
    "DeviceName": "$ProxiedDeviceName",    
    "DeviceType": "Server",
    "HostName": "$HostName",
    "HostType": "Windows",
    "CredentialKey": "$Credential",
    "OnlineDetection": "None",
    "ProxiedByAgentId": $ProxyAgentId 
}
"@

    try
    {
        $response = Invoke-RestMethod `
            -Method POST `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -Body $body `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck 

        Write-Verbose "Proxied device $ProxiedDeviceName added to proxy agent $ProxyAgentName"

        Write-Output $response
        
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to add proxied device $ProxiedDeviceName. $result"
        } 
        else 
        {
            Throw "Failed to add proxied device. Check if device already exists with the name $ProxiedDeviceName. $_.Exception"
        }
    }
    finally
    {
        $body = $null
    }
}