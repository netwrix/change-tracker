. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Update details of a device registered to a Change Tracker Hub.


.EXAMPLE

PS> Update-NctDevice -device $device -newName $newName

#>
Function Update-NctDevice {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [PSCustomObject]$device,

        [Parameter(Position=2, mandatory=$true)]
        [string]$newName
    )
    
    Test-NctSession -Verbose:$VerbosePreference    
    
    # There is no dedicated endpoint for devices as the data is here 
    $uri = "$Global:NctHubUrl/agents/update"

    # Get the device's agent
    $agent = Get-NctAgents -agentDeviceId $device.Id

    if ($null -eq $agent) 
    {
        Throw "Failed to get agent for device $($device.DeviceName) with id $($device.Id)."
    }
    
    # Clear poll dates to meet API requirements
    $agent.LastPollUtc = ""
    $agent.NextPollUtc = ""

    try 
    {
        $agent.DeviceName = $newName
    }
    catch
    {
        Throw "Failed to update device name in agent object to $newName. Supplied device may be invalid: $_. $device"
    }

    $agentJSON = $agent | ConvertTo-Json -Depth 10

    $body = @"
{    
    "Agent": $agentJSON,    
    "UpdateAgentDeviceName": "True"
}
"@
    Write-Verbose "Updating device $($device.DeviceName) with id $($device.Id) to new name $newName"
    Write-Verbose "Request body: $body"
    try
    {
        $response = Invoke-RestMethod `
            -Method Get `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -body $body `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck       
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to update device. $result"
        } 
        else 
        {
            Throw "Failed to update device. $_.Exception"
        }
	
	    exit 1
    }
}