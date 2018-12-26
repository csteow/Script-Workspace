<#
.SYNOPSIS
Set RDS Services user account into the configuration file.

.DESCRIPTION
This script is used to encrypt the password.

.EXAMPLE
PS> Set-EncryptedPassword.ps1

#>

param (
    [switch] $CreateKey
)

$AESKeyFilePath = Join-Path $PSScriptRoot -ChildPath "aes.key"
if ($CreateKey) {
    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
    $EncodedText =[Convert]::ToBase64String($AESKey)
    Set-Content $AESKeyFilePath $EncodedText
    Write-Host "Created AES key file: $AESKeyFilePath"
}

if (Test-Path $AESKeyFilePath) {
    $encodedText = Get-Content $AESKeyFilePath -Raw
    $AESKey = [System.Convert]::FromBase64String($EncodedText)
    Write-Host "Loaded AES key file: $AESKeyFilePath"
}

$password = Read-Host -AsSecureString "Enter Password: "
$confirmPassword = Read-Host -AsSecureString "Confirm Password: "

if ($password.Length -gt 0 -and $confirmPassword.Length -gt 0) {
    $cred1 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "dummy", $password
    $cred2 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "dummy", $confirmPassword

    # Check both passwords are matched
    if ($cred1.GetNetworkCredential().Password -eq $cred2.GetNetworkCredential().Password) {
        $encodedPassword = ConvertFrom-SecureString -SecureString $password -key $AESKey
        Write-Host "Encoded Password: $encodedPassword"
    }
    else {
        Write-Host "Both passwords did not match"
    }
}
else {
    Write-Host "Abort!"
}