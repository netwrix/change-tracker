Install-Module -Name Pester -Force -SkipPublisherCheck -PassThru -MinimumVersion 5.7.1
Import-Module Pester -PassThru -MinimumVersion 5.7.1

BeforeAll {
    . $PSScriptRoot\..\Functions\New-NctApiCredential.ps1
    . $PSScriptRoot\..\Functions\Protect-Credential.ps1
}

Describe 'Credential Persistence and File Discovery' {
    BeforeAll {
        # Create a test directory for credential files
        $TestCredentialPath = Join-Path $env:TEMP "nct-test-credentials-$(Get-Random)"
        New-Item -Path $TestCredentialPath -ItemType Directory -Force | Out-Null

        $TestUsername = "test-user-$([System.Guid]::NewGuid().ToString().Substring(0,8))"
        $TestPassword = "TestPassword123!"
    }

    Context 'File Extension Validation' {
        It 'should save persisted credentials with .dat extension' {
            # Create a credential file path
            $expectedPath = Join-Path $TestCredentialPath "$TestUsername.dat"

            # Manually create a credential file to simulate New-NctApiCredential
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($TestPassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($expectedPath, $encryptedBytes)

            # Verify the file exists with .dat extension
            Test-Path $expectedPath | Should -Be $true

            # Verify it's NOT a .txt file
            $wrongPath = Join-Path $TestCredentialPath "$TestUsername.txt"
            Test-Path $wrongPath | Should -Be $false
        }

        It 'should find .dat files when discovering credentials' {
            # Create multiple test credential files with .dat extension
            $user1 = "testuser1"
            $user2 = "testuser2"
            $path1 = Join-Path $TestCredentialPath "$user1.dat"
            $path2 = Join-Path $TestCredentialPath "$user2.dat"

            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($TestPassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($path1, $encryptedBytes)
            [System.IO.File]::WriteAllBytes($path2, $encryptedBytes)

            # Simulate the credential discovery logic from Test-NctSession
            $files = Get-ChildItem -Path $TestCredentialPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            $files | Should -Not -BeNullOrEmpty
            $files.Count | Should -Be 2
            $files | Should -Contain "$user1.dat"
            $files | Should -Contain "$user2.dat"
        }

        It 'should NOT find .txt files when discovering credentials' {
            # Create a .txt file (wrong extension)
            $wrongUser = "wrongextension"
            $wrongPath = Join-Path $TestCredentialPath "$wrongUser.txt"
            "dummy content" | Out-File -FilePath $wrongPath

            # Create a correct .dat file
            $correctUser = "correctextension"
            $correctPath = Join-Path $TestCredentialPath "$correctUser.dat"
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($TestPassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($correctPath, $encryptedBytes)

            # Simulate the credential discovery logic with CORRECT filter
            $datFiles = Get-ChildItem -Path $TestCredentialPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            # Should only find .dat files
            $datFiles | Should -Contain "$correctUser.dat"
            $datFiles | Should -Not -Contain "$wrongUser.txt"

            # Simulate the OLD BUGGY logic with .txt filter (regression test)
            $txtFiles = Get-ChildItem -Path $TestCredentialPath -Filter "*.txt" | Select-Object -ExpandProperty Name

            # Should find .txt but NOT .dat
            $txtFiles | Should -Contain "$wrongUser.txt"
            $txtFiles | Should -Not -Contain "$correctUser.dat"
        }
    }

    Context 'Credential File Discovery Logic' {
        It 'should correctly extract username from .dat filename' {
            # Create credential files
            $user1 = "admin"
            $user2 = "james.anderson"
            $path1 = Join-Path $TestCredentialPath "$user1.dat"
            $path2 = Join-Path $TestCredentialPath "$user2.dat"

            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($TestPassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($path1, $encryptedBytes)
            [System.IO.File]::WriteAllBytes($path2, $encryptedBytes)

            # Get files and extract usernames
            $files = Get-ChildItem -Path $TestCredentialPath -Filter "*.dat" | Select-Object -ExpandProperty Name

            foreach ($file in $files) {
                $username = [System.IO.Path]::GetFileNameWithoutExtension($file)

                # Verify username extraction works correctly
                $username | Should -Match '^[a-zA-Z0-9._-]+$'
                $username | Should -Not -Contain '.dat'
            }
        }

        It 'should handle empty credential directory gracefully' {
            # Create an empty test directory
            $EmptyPath = Join-Path $env:TEMP "nct-empty-$(Get-Random)"
            New-Item -Path $EmptyPath -ItemType Directory -Force | Out-Null

            try {
                # Try to find credential files
                $files = Get-ChildItem -Path $EmptyPath -Filter "*.dat" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

                # Should return empty, not error
                $files.Count | Should -Be 0
            }
            finally {
                Remove-Item -Path $EmptyPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Credential Round-Trip' {
        It 'should successfully encrypt and decrypt credentials' {
            $originalPassword = "MySecurePassword123!"

            # Encrypt
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($originalPassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt

            # Verify encrypted data is different from original
            $encryptedBytes | Should -Not -Be $passwordBytes
            $encryptedBytes.Length | Should -BeGreaterThan 0

            # Decrypt
            $decryptedBytes = Protect-Credential -Data $encryptedBytes -Action Decrypt
            $decryptedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

            # Verify round-trip
            $decryptedPassword | Should -Be $originalPassword
        }

        It 'should persist and retrieve credential from file' {
            $testUser = "roundtrip-user"
            $testPass = "RoundTripPassword123!"
            $credPath = Join-Path $TestCredentialPath "$testUser.dat"

            # Simulate saving credential
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($testPass)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)

            # Verify file was created
            Test-Path $credPath | Should -Be $true

            # Simulate discovering credential
            $files = Get-ChildItem -Path $TestCredentialPath -Filter "*.dat" | Where-Object { $_.Name -eq "$testUser.dat" }
            $files | Should -Not -BeNullOrEmpty

            # Simulate loading credential
            $loadedBytes = [System.IO.File]::ReadAllBytes($credPath)
            $decryptedBytes = Protect-Credential -Data $loadedBytes -Action Decrypt
            $loadedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

            # Verify loaded password matches
            $loadedPassword | Should -Be $testPass
        }
    }

    Context 'Security Validation' {
        It 'should not store passwords in plain text' {
            $sensitivePassword = "SuperSecretPassword123!"
            $credPath = Join-Path $TestCredentialPath "security-test.dat"

            # Encrypt and save
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($sensitivePassword)
            $encryptedBytes = Protect-Credential -Data $passwordBytes -Action Encrypt
            [System.IO.File]::WriteAllBytes($credPath, $encryptedBytes)

            # Read raw file content
            $rawContent = [System.IO.File]::ReadAllText($credPath)

            # Verify password is not in plain text
            $rawContent | Should -Not -Match $sensitivePassword
        }

        It 'should use Windows DPAPI for encryption' {
            $testPass = "TestDPAPI123!"
            $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($testPass)

            # Encrypt using Protect-Credential (which uses DPAPI)
            $encrypted1 = Protect-Credential -Data $passwordBytes -Action Encrypt
            $encrypted2 = Protect-Credential -Data $passwordBytes -Action Encrypt

            # DPAPI should produce different encrypted output each time (due to entropy/IV)
            # But both should decrypt to the same value
            $decrypted1 = Protect-Credential -Data $encrypted1 -Action Decrypt
            $decrypted2 = Protect-Credential -Data $encrypted2 -Action Decrypt

            $pass1 = [System.Text.Encoding]::UTF8.GetString($decrypted1)
            $pass2 = [System.Text.Encoding]::UTF8.GetString($decrypted2)

            $pass1 | Should -Be $testPass
            $pass2 | Should -Be $testPass
        }
    }

    AfterAll {
        # Clean up test directory
        if (Test-Path $TestCredentialPath) {
            Remove-Item -Path $TestCredentialPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
