param(
    [string]$PackageName = "AlyssonDaPaz.MegaManX816bit",
    [string]$BuildDir = "$PSScriptRoot\..\build\uwp"
)

$ErrorActionPreference = "Stop"

$build = (Resolve-Path $BuildDir).Path
$msix = Join-Path $build "MegaManX8-16bit.msix"
$cer = Join-Path $build "AlyssonDaPaz-test.cer"
$dependencies = Join-Path $build "dependencies"

if (!(Test-Path $msix)) { throw "MSIX not found: $msix" }
if (!(Test-Path $cer)) { throw "Certificate not found: $cer" }
if (!(Test-Path $dependencies)) { throw "Dependencies folder not found: $dependencies" }

Write-Host "Importing test certificate..."
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\CurrentUser\TrustedPeople | Out-Null

# Add-AppxPackage updates the existing identity while preserving LocalState.
# Removing the previous package deletes the player's save and preferences.

Write-Host "Installing UWP dependencies..."
Get-ChildItem $dependencies -Filter "*.appx" | ForEach-Object {
    Add-AppxPackage -Path $_.FullName
}

Write-Host "Installing game package..."
Add-AppxPackage -Path $msix

Write-Host "Installed: $PackageName"
