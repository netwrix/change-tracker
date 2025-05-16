. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Delete a proxied device from a Change Tracker Hub.
Does not error if device to delete is not found.

.PARAMETER name
Name of the device to delete.

.EXAMPLE

PS> Remove-NctProxiedDevice -name "win-prod-01" 

#>
Function Remove-NctProxiedDevice {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [string]$name          
    )

    Test-NctSession    
    
    $uri = "$Global:NctHubUrl/devices/delete"

    $device = Get-NctDevices -name $name 
    $AgentId = $device.Id.AgentId
    $DeviceId = $device.Id.DeviceId              
        
    if ($device)
    {
        $body = 
@"
{
    "AgentDeviceIds": ["$AgentId,$DeviceId"]
}
"@
        
        Write-Verbose "Delete device request object: $body"

        try
        {
            $response = Invoke-RestMethod `
                -Method POST `
                -ContentType application/json `
                -Uri $uri `
                -WebSession $global:NctSession `
                -Body $body `
                -SkipCertificateCheck:$Global:NctSkipCertificateCheck 

            Write-Output $response
        
        }
        catch [Net.WebException] {
            $response = $_.Exception.Response;

            if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
            {
                $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
                Throw "Failed to delete device $name. $result"
            } 
            else 
            {
                Throw "Failed to delete device $name. $_.Exception"
            }
	
	        exit 1
        }
        finally
        {
            $body = $null
        }
    }
}