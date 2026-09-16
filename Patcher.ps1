#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Port = 18080
$DummyKey = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
$Old45 = "https://assetripper.com/v1/access-key/validat"
$New45 = "http://127.0.0.1:18080/v1/access-key/validate"
$OldLast = [byte][char]"e"
$NewLast = [byte][char]"/"
$Latin1 = [Text.Encoding]::GetEncoding(28591)

function Write-Info([string]$Message) { Write-Host "[*] $Message" }
function Write-Ok([string]$Message) { Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Err([string]$Message) { Write-Host "[!] $Message" -ForegroundColor Red }

function Find-Bytes([byte[]]$Haystack, [byte[]]$Needle) {
    $hay = $Latin1.GetString($Haystack)
    $nee = $Latin1.GetString($Needle)
    return $hay.IndexOf($nee)
}

function Resolve-TargetExe {
    param([string[]]$CliArgs, [string]$PatcherDir)

    foreach ($a in $CliArgs) {
        if ([string]::IsNullOrWhiteSpace($a)) { continue }
        $p = $a.Trim('"')
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            if ([IO.Path]::GetFileName($p) -ieq "AssetRipper.GUI.Premium.exe") {
                return (Resolve-Path -LiteralPath $p).Path
            }
        }
        if (Test-Path -LiteralPath $p -PathType Container) {
            $hit = Join-Path $p "AssetRipper.GUI.Premium.exe"
            if (Test-Path -LiteralPath $hit -PathType Leaf) {
                return (Resolve-Path -LiteralPath $hit).Path
            }
        }
    }

    foreach ($c in @(
            (Join-Path $PatcherDir "AssetRipper.GUI.Premium.exe"),
            (Join-Path (Split-Path $PatcherDir -Parent) "AssetRipper.GUI.Premium.exe")
        )) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }

    foreach ($root in @($PatcherDir, (Split-Path $PatcherDir -Parent))) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $found = Get-ChildItem -LiteralPath $root -Filter "AssetRipper.GUI.Premium.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike "*.bak" } |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Write-RuntimeFiles([string]$ExeDir, [string]$PayloadDir) {
    $keyPath = Join-Path $ExeDir "premium-access.key"
    [IO.File]::WriteAllText($keyPath, $DummyKey + [Environment]::NewLine)

    foreach ($name in @("_license_emu.ps1", "AssetRipper_Cracked.ps1", "AssetRipper_Cracked.cmd")) {
        $src = Join-Path $PayloadDir $name
        if (-not (Test-Path -LiteralPath $src)) {
            throw "missing payload $src"
        }
        Copy-Item -LiteralPath $src -Destination (Join-Path $ExeDir $name) -Force
    }

    Write-Ok "wrote premium-access.key"
    Write-Ok "wrote AssetRipper_Cracked.cmd"
}

function Patch-Exe([string]$ExePath) {
    $oldBytes = [Text.Encoding]::Unicode.GetBytes($Old45)
    $newBytes = [Text.Encoding]::Unicode.GetBytes($New45)
    if ($oldBytes.Length -ne $newBytes.Length) {
        throw "patch pattern length mismatch"
    }

    Write-Info "reading $ExePath"
    $data = [IO.File]::ReadAllBytes($ExePath)
    $idx = Find-Bytes $data $oldBytes
    $already = Find-Bytes $data $newBytes

    if ($idx -lt 0 -and $already -ge 0) {
        Write-Ok "already patched"
        return
    }
    if ($idx -lt 0) {
        throw "license URL not found. This is not an unpatched AssetRipper.GUI.Premium.exe"
    }

    $bak = $ExePath + ".bak"
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $ExePath -Destination $bak -Force
        Write-Ok "backup $bak"
    } else {
        Write-Info "backup already exists"
    }

    [Buffer]::BlockCopy($newBytes, 0, $data, $idx, $newBytes.Length)
    $lastOff = $idx + $newBytes.Length
    if ($data[$lastOff] -ne $OldLast -and $data[$lastOff] -ne $NewLast) {
        throw ("unexpected last character 0x{0:X2}" -f $data[$lastOff])
    }
    $data[$lastOff] = $NewLast
    [IO.File]::WriteAllBytes($ExePath, $data)
    Write-Ok "patched license URL -> http://127.0.0.1:$Port/v1/access-key/validate/"
}

$patcherDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$payloadDir = Join-Path $patcherDir "payload"

Write-Host ""
Write-Host " AssetRipper Premium Patcher"
Write-Host " ==========================="
Write-Host ""

$exe = Resolve-TargetExe -CliArgs $args -PatcherDir $patcherDir
if (-not $exe) {
    Write-Err "AssetRipper.GUI.Premium.exe not found"
    Write-Host "  - drop the exe onto Patcher.cmd"
    Write-Host "  - or put this patcher folder next to / inside the AssetRipper folder"
    exit 1
}

Write-Info "target: $exe"
$exeDir = Split-Path -Parent $exe
try {
    Patch-Exe $exe
    Write-RuntimeFiles $exeDir $payloadDir
} catch {
    Write-Err $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Ok "done"
Write-Host "start with AssetRipper_Cracked.cmd next to the exe"
Write-Host "running the exe directly will not validate the license"
Write-Host ""
exit 0
