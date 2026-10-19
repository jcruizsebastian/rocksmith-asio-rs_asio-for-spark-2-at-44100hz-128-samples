#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host " RS_ASIO Installer for Positive Grid Spark 2 (44100 Hz / 128 Smps)" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan

# 1. Make sure Rocksmith 2014 is not currently running
if (Get-Process -Name "Rocksmith2014" -ErrorAction SilentlyContinue) {
    Write-Host "[ERROR] Rocksmith 2014 is currently running. Please close it before running the installer." -ForegroundColor Red
    return
}

# 2. Automatically locate the Rocksmith 2014 installation directory
function Find-RocksmithPath {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # Check Windows Registry for Steam installation path
    $regPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\Software\Valve\Steam"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $props = Get-ItemProperty $rp -ErrorAction SilentlyContinue
            if ($props.InstallPath) { $candidates.Add($props.InstallPath) }
            if ($props.SteamPath)   { $candidates.Add(($props.SteamPath -replace '/', '\')) }
        }
    }

    # Standard default Steam locations
    $candidates.Add("C:\Program Files (x86)\Steam")
    $candidates.Add("C:\Program Files\Steam")

    # Parse Steam's libraryfolders.vdf to discover Steam libraries across all drives
    $steamLibs = [System.Collections.Generic.List[string]]::new()
    foreach ($steamRoot in ($candidates | Select-Object -Unique)) {
        if (Test-Path $steamRoot) {
            $steamLibs.Add($steamRoot)
            $vdfPaths = @(
                (Join-Path $steamRoot "steamapps\libraryfolders.vdf"),
                (Join-Path $steamRoot "config\libraryfolders.vdf")
            )
            foreach ($vdf in $vdfPaths) {
                if (Test-Path $vdf) {
                    $matches = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
                    foreach ($m in $matches.Matches) {
                        $libPath = $m.Groups[1].Value -replace '\\\\', '\'
                        if (Test-Path $libPath) { $steamLibs.Add($libPath) }
                    }
                }
            }
        }
    }

    # Also check common SteamLibrary folders on local fixed drives
    [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object {
        $root = $_.RootDirectory.FullName
        $steamLibs.Add((Join-Path $root "SteamLibrary"))
        $steamLibs.Add((Join-Path $root "Steam"))
        $steamLibs.Add((Join-Path $root "Program Files (x86)\Steam"))
    }

    foreach ($lib in ($steamLibs | Select-Object -Unique)) {
        $rsDir = Join-Path $lib "steamapps\common\Rocksmith2014"
        if (Test-Path (Join-Path $rsDir "Rocksmith2014.exe")) {
            return $rsDir
        }
    }

    return $null
}

$rsPath = Find-RocksmithPath
if (-not $rsPath) {
    Write-Host "[WARN] Could not automatically locate the Rocksmith 2014 folder." -ForegroundColor Yellow
    $rsPath = Read-Host "Please enter the full path to your Rocksmith2014 folder"
    if (-not (Test-Path (Join-Path $rsPath "Rocksmith2014.exe"))) {
        Write-Host "[ERROR] Could not find Rocksmith2014.exe in '$rsPath'." -ForegroundColor Red
        return
    }
}

Write-Host "[OK] Found Rocksmith 2014 installation at:" -ForegroundColor Green
Write-Host "     $rsPath" -ForegroundColor White

# 3. Download the latest release from GitHub and extract files
$releaseUrl = "https://github.com/jcruizsebastian/rocksmith-asio-rs_asio-for-spark-2-at-44100hz-128-samples/releases/latest/download/RS_ASIO-v0.7.5-spark2-44100hz.zip"
$tempZip = Join-Path $env:TEMP "RS_ASIO-spark2.zip"

Write-Host "[..] Downloading latest release from GitHub..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $releaseUrl -OutFile $tempZip -UseBasicParsing

Write-Host "[..] Extracting RS_ASIO.dll, avrt.dll, and RS_ASIO.ini..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $rsPath -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

# 4. Verify ExclusiveMode=1 and Win32UltraLowLatencyMode=1 in Rocksmith.ini
$rsIni = Join-Path $rsPath "Rocksmith.ini"
if (Test-Path $rsIni) {
    $iniContent = Get-Content $rsIni -Raw
    $updated = $false
    if ($iniContent -match "ExclusiveMode=0") {
        $iniContent = $iniContent -replace "ExclusiveMode=0", "ExclusiveMode=1"
        $updated = $true
    }
    if ($iniContent -match "Win32UltraLowLatencyMode=0") {
        $iniContent = $iniContent -replace "Win32UltraLowLatencyMode=0", "Win32UltraLowLatencyMode=1"
        $updated = $true
    }
    if ($updated) {
        Set-Content -Path $rsIni -Value $iniContent -Encoding UTF8
        Write-Host "[OK] Updated Rocksmith.ini (ExclusiveMode=1, Win32UltraLowLatencyMode=1)." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " Installation completed successfully!" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Green
Write-Host "Quick checklist before launching Rocksmith 2014:" -ForegroundColor Yellow
Write-Host "  1. Positive Grid ASIO Control Panel (Windows): Buffer Size = 128 samples."
Write-Host "  2. Spark App: Turn OFF all preset blocks (GATE, COMP, DRIVE, AMP, MOD, DELAY, REVERB) for a clean DI signal."
Write-Host "  3. In Rocksmith 2014: Select 'Real Tone Cable' input mode and run Calibration."
