. "$PSScriptRoot\Test-NctSession.ps1"

<#
.Description
Submit a credential of type database to a Change Tracker Hub.

.PARAMETER name
Name of the credential. Will be visible in the web UI.

.PARMAETER username
Username for the credential. Will be visible in the web UI.

.PARAMETER password
A secure string that will store the password for the credential. This will not be visible in the web UI.

.EXAMPLE

PS> Add-NctDatabaseCredential -name "DB Cred Production" -username "netwrix" -password $password

#>
Function Add-NctDatabaseCredential {
    [CmdletBinding()]
    param(
        [Parameter(Position=1, mandatory=$true)]
        [string]$name,
        
        [Parameter(Position=2, mandatory=$true)]
        [string]$username, 
        
        [Parameter(Position=3, mandatory=$true)]
        [securestring]$password            
    )

    Test-NctSession -Verbose:$VerbosePreference    
    
    $uri = "$Global:NctHubUrl/credentials/add"
    
    try
    {
        $Credential = New-Object System.Net.NetworkCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))
        $pswd = $credential.Password

        $body = 
@"
{
    "Credentials": 
    {
        "CredentialType": "Database",
        "Key": "$name",
        "Parameters": 
        {
            "UserName": "$username",
            "Password": "$pswd"            
        }
    }
}
"@
    }
    finally
    {
        # Ensure plain text password variable is cleared
        $pswd = $null
    }

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