. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Gets all reports from a Change Tracker Hub.


.EXAMPLE

PS> Get-NctReports

#>
Function Get-NctReports {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$false)]
        [string]$name
    )

    Test-NctSession -Verbose:$VerbosePreference    
    
    $uri = "$Global:NctHubUrl/reports/scheduled"

    $filter = 
@"
{
    "DeviceFilter": 
    {
        "GroupNames": [],
        "AgentDeviceIds": [],
        "AgentDisplayNames": [],
        "OnlineStatuses": [],
        "ExcludeProxiedDevices": false
    },
    "IncludeAllUsersReports": true
}
"@

    try
    {
        $response = Invoke-RestMethod `
            -Method POST `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -Body $filter `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck 

        foreach ($report in $response.Items) 
        {
            # Filter client side if endpoint doesn't support certain filters
            if ($name)
            {
                if ($report.Name -notlike $name)
                {
                    continue
                }
            }

            Write-Output $report
        }

        Write-Verbose "Report data collected succesfully"
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to get reports. $result"
        } 
        else 
        {
            Throw "Failed to get reports. $_.Exception"
        }
	
	    exit 1
    }
}