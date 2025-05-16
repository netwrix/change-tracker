. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Gets all agents registered to a Change Tracker Hub.


.EXAMPLE

PS> Get-NctAgents

#>
Function Get-NctAgents {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$false)]
        [string]$name = $null,

        [Parameter(Position=2, mandatory=$false)]
        [PSCustomObject]$agentDeviceId = $null
    )

    Test-NctSession -Verbose:$VerbosePreference   
    
    $uri = "$Global:NctHubUrl/agentsRanked"

    if ($agentDeviceId)
    {        
        $AgentId = $agentDeviceId.AgentId
        $DeviceId = $agentDeviceId.DeviceId 

        Write-Verbose "AgentId: $AgentId"
        Write-Verbose "DeviceId: $DeviceId"

        if (-not $AgentId -or -not $DeviceId)
        {
            Throw "Invalid agentDeviceId: $agentDeviceId. Must be of the form <AgentId,DeviceId>"
        }

        $agentDeviceId = 
@"
"$AgentId,$DeviceId"
"@
    }
    else
    {
        $agentDeviceId = ""
    }    

    $filter = 
@"
{
    "DeviceFilter": 
    {
        "GroupNames": [],
        "AgentDeviceIds": [$agentDeviceId]
        "AgentDisplayNames": [],
        "OnlineStatuses": [],
        "ExcludeProxiedDevices": false
    },
    "GetAgentGroupDetails": false,
    "GetRelatedTemplates": false,
}
"@

    Write-Verbose "Get agent request object: $filter"

    try
    {
        $response = Invoke-RestMethod `
            -Method Post `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -Body $filter `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck  

        foreach ($agent in $response.Agents) 
        {
            # Filter client side if endpoint doesn't support certain filters
            if ($name)
            {
                if ($agent.Name -notlike $name)
                {
                    continue
                }
            }

            Write-Output $agent
        }

        Write-Verbose "Agent data collected succesfully"
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to get agents. $result"
        } 
        else 
        {
            Throw "Failed to get agents. $_.Exception"
        }
	
	    exit 1
    }
}