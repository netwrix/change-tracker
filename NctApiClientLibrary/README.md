# Netwrix Change Tracker API Client Library

This PowerShell client library is used to simplify the automation of Change Tracker tasks such as:
- Adding credentials
- Adding proxied devices
- Updating device names
- Retrieving information on agents, devices, credentials, etc
Some of these are included in the examples section at the bottom of this doc

## Requirements
- Powershell 7.4+
- Change Tracker 8+
- A Change Tracker user account with a custom role that contains the following permissions:
  - CredentialsGet
  - CredentialsManage
  - DeviceView
  - DeviceRegister

Custom roles can be created and assigned to users on the Settings -> Users page in Change Tracker.

## Installation
For installation copy this NctApiClientLibrary folder to:

`C:\Program Files\PowerShell\7\Modules\NctApiClientLibrary`

It will then be possible to import the module.

```powershell

Import-Module NctApiClientLibrary

```

## Use

### Authenticating

One of the main improvements the client library offers is the removal of the need to store passwords in scripts when pulling data from the API. There are two ways to authenticate to Change Tracker, interactively and with persisted credentials.

#### Interactive Authentication

It is possible to call client library functions without having entered any credentials before hand.

Example out put when calling Get-NctAgents without persisted credentials:

```powershell

Get-Nctagents

URL (HTTPS://YourNctHubHostName/api): https://localhost/api
User: james
Password can be persisted with:
New-NctApiCredential -user 'james' -persist
Enter Password:
: ****

```

The client library will prompt for the url and user. Before asking for the password it will describe how the password can be persisted. The url and user will be persisted in global variables (see global variable section below) and will not need to be entered again unless the values need to be changed.

Passwords are hidden with asterisks to avoid them leaking into command prompt history.

If the password is accepted and the Change Tracker Hub's certificate is trusted, then a session will be established and results will be shown. This session will last for ten minutes. After that, use of any function will ask for credentials again.

Interactive authentication is useful when exploring the API.

#### Persisted Credentials

The encrypted credentials can be persisted by calling `New-NctApiCredential` with the user and persist arguments.

Example command and output:

```powershell

New-NctApiCredential -user 'james' -persist
Enter Password to be stored to C:\Users\james\.nct client library\james.dat: *******

```

The contents of this file will be the encrypted password. This avoids any temptation to store passwords in scripts.

When calling a function from a new PowerShell session, the client library will detect any previously persisted credentials that were stored in the default directory.

```powershell

Get-NctDevices

The following credential files were found in C:\Users\james\.nct client library:
1. admin.dat
2. james.dat
Select a credential file to load. Enter the number or press Enter to skip:

```


### Sessions

A session can be created by calling New-NctSession.

```powershell

New-NctSession -url "https://192.168.0.10/api" -user "admin"

```

If a credential has been persisted for the passed user the session will be created with those credentials automatically. If a credential has not been persisted for the user then a prompt will ask for the password after explaining how it could be persisted for future use.

```powershell

Password can be persisted with:
New-NctApiCredential -user 'james' -persist
Enter Password:
: ****

```

If a session has been created with persisted credentials then a new session will automatically be created on the first call to a function after the ten minute session limit has expired.

#### Certificates

If the Hub's certificate is not trusted the session will fail to initialize. While not recommended, it is possible to pass the `-SkipCertificateCheck` argument to build a session for a Change Tracker Hub with an untrusted certificate.

```powershell

New-NctSession -url "https://192.168.0.10/api" -user "admin" -SkipCertificateCheck

```

### Two-Factor Authentication (2FA)

The client library now supports Two-Factor Authentication for enhanced security. When connecting to a Change Tracker Hub that has 2FA enabled for your user account, the authentication flow will automatically handle the 2FA requirements.

#### First-Time 2FA Setup

If 2FA is required but not yet configured for your account, the client library will guide you through the setup process:

1. A QR code will be displayed as a base64 data image for scanning with your authenticator app when opened in a browser
2. Alternatively, a manual setup code will be provided
3. You'll be prompted to complete the setup in your authenticator app
4. After setup, you'll enter the one-time password to complete authentication

Example output during first-time setup:
```
Using an authenticator app on your mobile device (eg Google Authenticator, Authy, LastPass, iPhone etc) scan the QR barcode found at the link below:

data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALcAAAC3AQAAAAB4FfIyAAADTUlEQVR4nO2YMa6kMAyGjSjSwQUi5RrpciXmAsBcAK6UjmtE4gLQpYjw...

Alternatively manually enter this setup code into the authenticator app to register Change Tracker with your mobile device: ABCD EFGH IJKL MNOP

Press Enter when you have completed the 2FA setup:
Enter the one-time password from your authenticator app: 123456
```

#### Subsequent Authentications

After initial setup, you'll only need to provide the one-time password from your authenticator app when prompted:

```
Enter the one-time password from your authenticator app: 123456
```

#### Supported Authenticator Apps

The 2FA implementation works with any TOTP (Time-based One-Time Password) compatible authenticator app, including:
- Google Authenticator
- Authy
- LastPass Authenticator
- Microsoft Authenticator
- Built-in authenticators (iPhone, etc.)

### Global Variables

Use the following snippet to view the global variables used to hold session settings.

```powershell

Get-Variable -Scope Global | Where-Object Name -like "Nct*"

```

Example output:
```
Name                           Value
----                           -----
NctApiCredentialPath           C:\Users\james\Desktop\NctApiClientLibrary\Functions\\admin.txt
NctHubUrl                      https://localhost/api
NctSession                     Microsoft.PowerShell.Commands.WebRequestSession
NctSessionCreatedTime          4/4/2025 6:31:41 AM
NctSkipCertificateCheck        True
NctUserName                    james
```


### Functions

The following snippet returns all the functions available in the client library:

```powershell

Get-Command -Module NctApiClientLibrary -CommandType Function

````

Example output:
```
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-NctDatabaseCredential                          0.1.0      NctApiClientLibrary
Function        Add-NctProxiedDevice                               0.1.0      NctApiClientLibrary
Function        Get-NctAgents                                      0.1.0      NctApiClientLibrary
Function        Get-NctCredentials                                 0.1.0      NctApiClientLibrary
Function        Get-NctDevices                                     0.1.0      NctApiClientLibrary
Function        New-NctApiCredential                               0.1.0      NctApiClientLibrary
Function        New-NctSession                                     0.1.0      NctApiClientLibrary
Function        Remove-NctCredential                               0.1.0      NctApiClientLibrary
Function        Remove-NctProxiedDevice                            0.1.0      NctApiClientLibrary
Function        Test-NctSession                                    0.1.0      NctApiClientLibrary
```

## Uninstalling

The following snippet will remove the client library module:

```powershell
Remove-Module NctApiClientLibrary
```

## Examples

A script to trim specific prefixes and suffixes from device names
```powershell

$devices = Get-NctDevices -name "ThePrefix*TheSuffix" 

foreach ($device in $devices) {
    Write-Output "Trimming 'ThePrefix' prefix and 'TheSuffix' suffix from name for: $($device.Name)"

    $newName = $device.Name.TrimStart("ThePrefix").TrimEnd("TheSuffix")

    Update-NctDevice -device $device -newName $newName
}

```