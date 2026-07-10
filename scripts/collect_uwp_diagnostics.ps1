param(
    [string]$PackageName = "AlyssonDaPaz.MegaManX816bit",
    [int]$Tail = 300
)

$ErrorActionPreference = "Stop"

$packageRoot = Join-Path $env:LOCALAPPDATA "Packages"
$packages = Get-ChildItem -LiteralPath $packageRoot -Directory -Filter "$PackageName*" -ErrorAction SilentlyContinue

if (-not $packages) {
    throw "Nenhuma pasta UWP encontrada para '$PackageName' em $packageRoot. Instale e abra o MSIX pelo menos uma vez."
}

$found = $false
foreach ($package in $packages) {
    $logPath = Join-Path $package.FullName "LocalState\uwp_diagnostics.log"
    if (Test-Path -LiteralPath $logPath) {
        $found = $true
        Write-Host "Log encontrado: $logPath"
        Get-Content -LiteralPath $logPath -Tail $Tail
    }
}

if (-not $found) {
    throw "O pacote existe, mas o arquivo LocalState\uwp_diagnostics.log ainda não foi criado. Abra o jogo, carregue o buster e destrua alguns inimigos."
}
