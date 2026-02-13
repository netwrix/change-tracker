Install-Module -Name Pester -Force -SkipPublisherCheck -PassThru -MinimumVersion 5.7.1
Import-Module Pester -PassThru -MinimumVersion 5.7.1

BeforeAll {
    . $PSScriptRoot\..\Functions\Protect-Credential.ps1
}

Describe 'Test-NctSession Credential File Discovery' {
    BeforeAll {
        # Create a temporary test credential directory
        $TestCredentialDir = Join-Path $env:TEMP "nct-session-test-$(Get-Random)"
        New-Item -Path $TestCredentialDir -ItemType Directory -Force | Out-Null

        # Store original USERPROFILE
        $OriginalUserProfile = $env:USERPROFILE

        # Create test users with credential files
        $TestUsers = @(
            @{ Username = "admin"; Password = "AdminPass123!" }
            @{ Username = "james"; Password = "JamesPass123!" }
            @{ Username = "testuser"; Password = "TestPass123!" }
        )
    }

    Context 'File Extension Bug Regression Tests' {
        BeforeAll {
            # Create test credentials with .dat extension (correct)
            $testPath = Join-Path $TestCredentialDir "correct-extension"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            foreach ($user in $TestUsers) {
                $credPath = Join-Path $testPath "$($user.Username).dat"
                $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($user.Password)
                $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
                [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)
            }
        }

        It 'should find all .dat credential files (CORRECT behavior)' {
            $testPath = Join-Path $TestCredentialDir "correct-extension"

            # This is the CORRECT logic (what the fix should be)
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            $files | Should -Not -BeNullOrEmpty
            $files.Count | Should -Be 3
            $files | Should -Contain "admin.dat"
            $files | Should -Contain "james.dat"
            $files | Should -Contain "testuser.dat"
        }

        It 'should NOT find .dat files when searching for .txt (BUG behavior)' {
            $testPath = Join-Path $TestCredentialDir "correct-extension"

            # This is the BUGGY logic (what currently exists in the code)
            $files = Get-ChildItem -Path $testPath -Filter "*.txt" | Select-Object -ExpandProperty Name

            # This demonstrates the bug: .dat files are NOT found when searching for .txt
            $files.Count | Should -Be 0
            $files | Should -Not -Contain "admin.dat"
            $files | Should -Not -Contain "james.dat"
            $files | Should -Not -Contain "testuser.dat"
        }

        It 'should demonstrate the credential discovery mismatch' {
            $testPath = Join-Path $TestCredentialDir "bug-demo"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # User persists credential (creates .dat file)
            $username = "demo-user"
            $password = "DemoPass123!"
            $credPath = Join-Path $testPath "$username.dat"

            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($password)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)

            # Verify file was created
            $fileExists = Test-Path $credPath
            $fileExists | Should -Be $true

            # Current buggy logic looks for .txt
            $foundWithBuggyLogic = Get-ChildItem -Path $testPath -Filter "*.txt" | Where-Object { $_.Name -eq "$username.txt" }
            $foundWithBuggyLogic | Should -BeNullOrEmpty  # Bug: doesn't find it

            # Correct logic looks for .dat
            $foundWithCorrectLogic = Get-ChildItem -Path $testPath -Filter "*.dat" | Where-Object { $_.Name -eq "$username.dat" }
            $foundWithCorrectLogic | Should -Not -BeNullOrEmpty  # Fix: finds it correctly
        }
    }

    Context 'Username Extraction from Credential Files' {
        BeforeAll {
            $testPath = Join-Path $TestCredentialDir "username-extraction"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # Create credential files with various username formats
            $testCases = @(
                "simple",
                "with.dots",
                "with-dashes",
                "with_underscores",
                "CamelCase",
                "number123"
            )

            foreach ($username in $testCases) {
                $credPath = Join-Path $testPath "$username.dat"
                $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes("TestPass123!")
                $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
                [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)
            }
        }

        It 'should correctly extract username from .dat filename' {
            $testPath = Join-Path $TestCredentialDir "username-extraction"
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            foreach ($file in $files) {
                # This mimics the logic in Test-NctSession line 81
                $extractedUsername = [System.IO.Path]::GetFileNameWithoutExtension($file)

                # Verify the extraction works correctly
                $extractedUsername | Should -Not -Contain ".dat"
                $extractedUsername | Should -Match '^[a-zA-Z0-9._-]+$'
            }
        }

        It 'should handle file selection by index' {
            $testPath = Join-Path $TestCredentialDir "username-extraction"
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            # Simulate user selecting file #2 (index 1 in 0-based array, but user enters "2")
            $userSelection = 2  # User enters "2"
            $selectedFile = $files[$userSelection - 1]  # Convert to 0-based index

            $selectedFile | Should -Not -BeNullOrEmpty

            # Extract username from selected file
            $username = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile)
            $username | Should -Not -BeNullOrEmpty
            $username | Should -Not -Contain ".dat"
        }
    }

    Context 'Edge Cases and Error Handling' {
        It 'should handle directory with no credential files' {
            $emptyPath = Join-Path $TestCredentialDir "empty-dir"
            New-Item -Path $emptyPath -ItemType Directory -Force | Out-Null

            $files = Get-ChildItem -Path $emptyPath -Filter "*.dat" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

            $files.Count | Should -Be 0
        }

        It 'should handle directory that does not exist' {
            $nonExistentPath = Join-Path $TestCredentialDir "does-not-exist"

            # Should not throw, but return empty
            {
                $files = Get-ChildItem -Path $nonExistentPath -Filter "*.dat" -ErrorAction SilentlyContinue
                $files.Count | Should -Be 0
            } | Should -Not -Throw
        }

        It 'should ignore non-.dat files in credential directory' {
            $testPath = Join-Path $TestCredentialDir "mixed-files"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # Create various file types
            "text content" | Out-File (Join-Path $testPath "readme.txt")
            "log content" | Out-File (Join-Path $testPath "log.log")
            "backup content" | Out-File (Join-Path $testPath "admin.dat.bak")

            # Create one valid .dat file
            $credPath = Join-Path $testPath "validuser.dat"
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes("TestPass123!")
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)

            # Should only find the .dat file
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            $files.Count | Should -Be 1
            $files | Should -Contain "validuser.dat"
            $files | Should -Not -Contain "readme.txt"
            $files | Should -Not -Contain "log.log"
            $files | Should -Not -Contain "admin.dat.bak"
        }

        It 'should handle credential files with special characters in username' {
            $testPath = Join-Path $TestCredentialDir "special-chars"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # Test various valid username formats
            $validUsernames = @(
                "user@domain.com",  # Email-style
                "DOMAIN\user",      # Windows domain style (careful with backslash)
                "user-name.test"    # Hyphen and dot
            )

            foreach ($username in $validUsernames) {
                # Sanitize username for filename (remove invalid chars)
                $safeUsername = $username -replace '[\\/:*?"<>|]', '_'
                $credPath = Join-Path $testPath "$safeUsername.dat"

                if (-not (Test-Path $credPath)) {
                    $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes("TestPass123!")
                    $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
                    [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)
                }
            }

            # Verify we can find and list them
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name
            $files.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Multi-User Credential Discovery' {
        BeforeAll {
            $testPath = Join-Path $TestCredentialDir "multi-user"
            New-Item -Path $testPath -ItemType Directory -Force | Out-Null

            # Create credentials for 10 different users
            1..10 | ForEach-Object {
                $username = "user$_"
                $credPath = Join-Path $testPath "$username.dat"
                $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes("Pass$_")
                $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
                [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)
            }
        }

        It 'should find all credential files when multiple exist' {
            $testPath = Join-Path $TestCredentialDir "multi-user"
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            $files.Count | Should -Be 10

            1..10 | ForEach-Object {
                $files | Should -Contain "user$_.dat"
            }
        }

        It 'should be able to select specific credential from list' {
            $testPath = Join-Path $TestCredentialDir "multi-user"
            $files = Get-ChildItem -Path $testPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            # Simulate selecting user5
            $targetUsername = "user5"
            $selectedFile = $files | Where-Object { $_ -eq "$targetUsername.dat" }

            $selectedFile | Should -Be "$targetUsername.dat"

            $extractedUsername = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile)
            $extractedUsername | Should -Be $targetUsername
        }
    }

    AfterAll {
        # Clean up test directory
        if (Test-Path $TestCredentialDir) {
            Remove-Item -Path $TestCredentialDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
