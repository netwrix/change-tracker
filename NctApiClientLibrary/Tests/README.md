# Tests

## Test Framework
Pester is the default test framework for PowerShell. See the docs for details, but it should be easy to contribute tests by mimicking the existing test files in this folder.

## Running Tests

### Authentication

A valid session is required for the tests to exectute successfully. You'll almost certainly want to create a persisted credential. See the README in the root of the module folder for more details on authenticating.

When running locally you may be using a self signed certificate for your Hub. In this case you will want pass the `-SkipCertificateCheck` argument.

```powershell
New-NctSession -url "https://localhost/api" -user "admin" -SkipCertificateCheck
```

### Execution

To run a suite of tests just execute the file or files in this folder when a valid session is in place.

Example output:

```powershell
Starting discovery in 1 files.
Discovery found 4 tests in 150ms.
Running tests.
[+] C:\Users\james\Desktop\NctApiClientLibrary\Tests\DevicesTests.ps1 2.89s (2.59s|157ms)
Tests completed in 2.9s
Tests Passed: 4, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```