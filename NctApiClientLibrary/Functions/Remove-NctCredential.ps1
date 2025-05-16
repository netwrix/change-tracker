. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Delete a credential from a Change Tracker Hub.
Does not error if credential to delete is not found.

.PARAMETER name
Name of the credential. Will be visible in the web UI.

.EXAMPLE

PS> Remove-NctCredential -name "DB Cred Production" 

#>
Function Remove-NctCredential {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [string]$name          
    )

    Test-NctSession    
    
    $uri = "$Global:NctHubUrl/credentials/delete"
    
    $body = 
@"
{
    "CredentialsType": "Database",
    "Key": "$name"
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

        Write-Output $response
        
    }
    catch [Net.WebException] {
        $response = $_.Exception.Response;

        if ( $response.StatusCode -eq [Net.HttpStatusCode]::BadRequest ) 
        {
            $result = (New-Object IO.StreamReader($response.GetResponseStream())).ReadToEnd() | ConvertFrom-Json;
            
            Throw "Failed to add database credential. $result"
        } 
        else 
        {
            Throw "Failed to add database credential. Check if credential already exists. $_.Exception"
        }
	
	    exit 1
    }
    finally
    {
        $body = $null
    }
}