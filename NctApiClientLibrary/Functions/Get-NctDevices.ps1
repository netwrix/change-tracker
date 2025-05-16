. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Gets all devices registered to a Change Tracker Hub.


.EXAMPLE

PS> Get-NctDevices

#>
Function Get-NctDevices {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$false)]
        [string]$name,

        [Parameter(Position=2, mandatory=$false)]
        [switch]$IncludeDeletedDevices = $false
    )
    
    Test-NctSession -v    
    
    # There is no dedicated endpoint for devices as the data is here 
    $uri = "$Global:NctHubUrl/agentsRanked"

    try
    {
        $response = Invoke-RestMethod `
            -Method Get `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck 
                  
        foreach ($agent in $response.Agents) 
        {
            # Filter client side if endpoint doesn't support certain filters

            if ($IncludeDeletedDevices -eq $false -and $agent.Deleted -eq "True")
            {
                continue
            }

            if ($name)
            {
                if ($agent.DeviceName -notlike $name)
                {
                    continue
                }
            }

            $device = [PSCustomObject]@{
                ID=$agent.AgentDevice
                Name=$agent.DeviceName
                Type=$agent.DeviceType
                FullyQualifiedDomainName=$agent.FullyQualifiedDomainName
                HostType=$agent.HostType
                OS=$agent.OS
                IPv4=$agent.IPv4
                IsProxied=$agent.IsProxiedl
                CredentialsTestStatus=$agent.CredentialsTestStatus
                Groups=$agent.DeviceGroupDetails
            }

            Write-Output $device
        }        
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to get devices. $result"
        } 
        else 
        {
            Throw "Failed to get devices. $_.Exception"
        }
	
	    exit 1
    }
}