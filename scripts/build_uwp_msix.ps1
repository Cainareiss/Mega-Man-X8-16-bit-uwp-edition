param(
    [string]$Godot = "$PSScriptRoot\..\.tools\godot-3.5.3\Godot_v3.5.3-stable_win64.exe",
    [string]$CertificateSubject = "CN=AlyssonDaPaz"
)

$ErrorActionPreference = "Stop"
$project = (Resolve-Path "$PSScriptRoot\..").Path
$build = Join-Path $project "build\uwp"
$rawAppx = Join-Path $build "MegaManX8-16bit.appx"
$msix = Join-Path $build "MegaManX8-16bit.msix"
$repack = Join-Path $build "repack"
$dependencies = Join-Path $build "dependencies"
$vclibsRoot = "C:\Program Files (x86)\Microsoft SDKs\Windows Kits\10\ExtensionSDKs\Microsoft.VCLibs\14.0\Appx"
$sdk = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Directory |
    Where-Object Name -Match '^10\.' | Sort-Object Name -Descending | Select-Object -First 1
$makeAppx = Join-Path $sdk.FullName "x64\makeappx.exe"
$signTool = Join-Path $sdk.FullName "x64\signtool.exe"

if (!(Test-Path $Godot)) { throw "Godot 3.5.3 not found: $Godot" }
if (!(Test-Path $makeAppx) -or !(Test-Path $signTool)) { throw "Windows 10 SDK tools not found." }

New-Item -ItemType Directory -Force $build | Out-Null
New-Item -ItemType Directory -Force $dependencies | Out-Null
Copy-Item (Join-Path $vclibsRoot "Retail\x64\Microsoft.VCLibs.x64.14.00.appx") $dependencies -Force
Copy-Item (Join-Path $vclibsRoot "Debug\x64\Microsoft.VCLibs.x64.Debug.14.00.appx") $dependencies -Force
Remove-Item $rawAppx -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $build "repack") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $build "validation_unpack") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $build "template_debug") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $build "dep_Debug") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $build "dep_Retail") -Recurse -Force -ErrorAction SilentlyContinue
$godotArgs = @(
    "--no-window", "--path", ('"' + $project + '"'),
    "--export-debug", '"UWP Xbox Series S"', ('"' + $rawAppx + '"')
)
$godotProcess = Start-Process -FilePath $Godot -ArgumentList $godotArgs -Wait -PassThru
if ($godotProcess.ExitCode -ne 0 -or !(Test-Path $rawAppx)) { throw "Godot UWP export failed." }

if (Test-Path $repack) { Remove-Item -LiteralPath $repack -Recurse -Force }
New-Item -ItemType Directory $repack | Out-Null
tar -xf $rawAppx -C $repack
Copy-Item (Join-Path $project "uwp_assets\*.png") (Join-Path $repack "Assets") -Force
Remove-Item -LiteralPath (Join-Path $repack "AppxBlockMap.xml"), (Join-Path $repack "[Content_Types].xml") -Force
& $makeAppx pack /d $repack /p $msix /o
if ($LASTEXITCODE -ne 0) { throw "MakeAppx repack failed." }

$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {
    $_.Subject -eq $CertificateSubject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date).AddMonths(1)
} | Sort-Object NotAfter -Descending | Select-Object -First 1
if (!$cert) {
    $cert = New-SelfSignedCertificate -Type Custom -Subject $CertificateSubject `
        -KeyUsage DigitalSignature -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") -NotAfter (Get-Date).AddYears(5)
}
$cer = Join-Path $build "AlyssonDaPaz-test.cer"
Export-Certificate -Cert $cert -FilePath $cer -Force | Out-Null
& $signTool sign /fd SHA256 /sha1 $cert.Thumbprint $msix
if ($LASTEXITCODE -ne 0) { throw "MSIX signing failed." }

Write-Host "Built: $msix"
Write-Host "Test certificate: $cer"
Write-Host "Dependencies: $dependencies"
