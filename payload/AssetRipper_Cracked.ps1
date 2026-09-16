#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Exe = Join-Path $Root "AssetRipper.GUI.Premium.exe"
$Emu = Join-Path $Root "_license_emu.ps1"
if (-not (Test-Path -LiteralPath $Exe)) { throw "missing $Exe" }
$emuProc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Emu) -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 400
try {
    & $Exe @args
} finally {
    if ($emuProc -and -not $emuProc.HasExited) {
        Stop-Process -Id $emuProc.Id -Force -ErrorAction SilentlyContinue
    }
}
