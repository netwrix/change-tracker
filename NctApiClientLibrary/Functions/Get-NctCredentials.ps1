. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Gets credential information from a Change Tracker Hub.


.EXAMPLE

PS> Get-NctCredentials

.EXAMPLE

PS> Get-NctCredentials -type "Database"

.EXAMPLE

PS> Get-NctCredentials -name "*Db*"

.EXAMPLE

PS> Get-NctCredentials -type "ESX" -name "VCenter Prod"

#>
Function Get-NctCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$false)]
        [string]$type = "Unknown",
        
        [Parameter(Position=2, mandatory=$false)]
        [string]$name        
    )

    Test-NctSession    

    $body = 
@"
{
    "CredentialType": "$type"
}
"@
    
    $uri = "$Global:NctHubUrl/credentials"

    try
    {
        $response = Invoke-RestMethod `
            -Method POST `
            -ContentType application/json `
            -Uri $uri `
            -WebSession $global:NctSession `
            -Body $body `
            -SkipCertificateCheck:$Global:NctSkipCertificateCheck 

        foreach ($credential in $response) 
        {
            # Filter client side if endpoint doesn't support certain filters
            if ($name)
            {
                if ($credential.key -notlike $name)
                {
                    continue
                }
            }

            Write-Output $credential
        }
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to get credentials. $result"
        } 
        else 
        {
            Throw "Failed to get credentials. $_.Exception"
        }
	
	    exit 1
    }
}