# Tests

## Test Framework
Pester is the default test framework for PowerShell. See the docs for details, but it should be easy to contribute tests by mimicking the existing test files in this folder.

## Running Tests

### Authentication

A valid session is required for the tests to exectute successfully. 

#### Local Testing
When testing locally, you'll almost certainly want to create a persisted credential. See the README in the root of the module folder for more details on authenticating.
You may also be using a self signed certificate for your Hub. In this case you will want pass the `-SkipCertificateCheck` argument.

```powershell
New-NctSession -url "https://localhost/api" -user "admin" -SkipCertificateCheck
```

#### Automated testing
For automated builds and CI runs pass a credential from a password store into the script below to ensure the test run is able to initialise sessions.

```powershell
# Pass the username in from a pipeline variable
$user = "MyUsername"

# Create a directory to store the encrypted password file in
$path = "$env:USERPROFILE\.nct client library"
New-Item -Path $path -ItemType Directory | Out-Null

# File path to store the encrypted password
$file = "$path\$user.dat"

# Get password 
# This could be a pipeline variable passed in as a secure string or it could be obtained from a secret store.
# Example using Azure Key Vault:
$password = Get-AzKeyVaultSecret -VaultName "<your-unique-keyvault-name>" -Name "MyPassword"

# Convert to byte array
$passwordBytes = [System.Text.Encoding]::UTF8.GetBytes([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))

Remove-Variable -Name password

# Encrypt using DPAPI
$encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt

Remove-Variable -Name passwordBytes

# Save encrypted bytes to file
[System.IO.File]::WriteAllBytes($file, $encryptedBytes)

# Create session using the stored credential
New-NctSession -url $NctHubUrl  -user $user -SkipCertificateCheck
```

The function `New-NctSession` will look in the `$env:USERPROFILE\.nct client library` directory for a .dat file who's name matches the value passed to the user parameter.
If it finds a matching file it will decrypt the file and use the password when initialising a session to the API.

### Execution

To run a suite of tests just execute the files in this folder with a valid session in place.

Naviage to the Tests directory and invoke all tests with `Invoke-Pester`.

Example output:
```
Starting discovery in 2 files.
Discovery found 8 tests in 10.51s.
Running tests.
[+] C:\dev\change-tracker\NctApiClientLibrary\Tests\Credentials.Tests.ps1 9.66s (1.78s|327ms)
[+] C:\dev\change-tracker\NctApiClientLibrary\Tests\Devices.Tests.ps1 7.21s (4.21s|64ms)
Tests completed in 16.88s
Tests Passed: 8, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```