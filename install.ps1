#Requires -Version 5.1
$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Instalador de RS_ASIO para Positive Grid Spark 2 (44100 Hz)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Comprobar que Rocksmith 2014 no está en ejecución
if (Get-Process -Name "Rocksmith2014" -ErrorAction SilentlyContinue) {
    Write-Host "[ERROR] Rocksmith 2014 está abierto. Ciérralo antes de ejecutar el instalador." -ForegroundColor Red
    return
}

# 2. Localizar automáticamente la carpeta de instalación de Rocksmith 2014
function Find-RocksmithPath {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # Rutas de Steam desde el Registro de Windows
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

    # Rutas habituales por defecto
    $candidates.Add("C:\Program Files (x86)\Steam")
    $candidates.Add("C:\Program Files\Steam")

    # Analizar libraryfolders.vdf de Steam para encontrar bibliotecas en otros discos
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

    # Añadir bibliotecas estándar en unidades fijas (C:, D:, E:, F:...)
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $root = $_.Root
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
    Write-Host "[AVISO] No se encontró automáticamente la carpeta de Rocksmith 2014." -ForegroundColor Yellow
    $rsPath = Read-Host "Introduce la ruta completa a la carpeta de Rocksmith2014"
    if (-not (Test-Path (Join-Path $rsPath "Rocksmith2014.exe"))) {
        Write-Host "[ERROR] No se encontró Rocksmith2014.exe en '$rsPath'." -ForegroundColor Red
        return
    }
}

Write-Host "[OK] Carpeta de Rocksmith 2014 encontrada en:" -ForegroundColor Green
Write-Host "     $rsPath" -ForegroundColor White

# 3. Descargar la última Release desde GitHub y extraer los ficheros
$releaseUrl = "https://github.com/jcruizsebastian/rs_asio-spark-2-44100hz/releases/latest/download/RS_ASIO-v0.7.5-spark2-44100hz.zip"
$tempZip = Join-Path $env:TEMP "RS_ASIO-spark2.zip"

Write-Host "[..] Descargando última versión desde GitHub Releases..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $releaseUrl -OutFile $tempZip -UseBasicParsing

Write-Host "[..] Extrayendo RS_ASIO.dll, avrt.dll y RS_ASIO.ini..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $rsPath -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

# 4. Verificar ExclusiveMode=1 y Win32UltraLowLatencyMode=1 en Rocksmith.ini
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
        Write-Host "[OK] Rocksmith.ini actualizado (ExclusiveMode=1, Win32UltraLowLatencyMode=1)." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " ¡Instalación completada con éxito!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Recuerda antes de jugar:" -ForegroundColor Yellow
Write-Host "  1. En el panel ASIO de Positive Grid en Windows: Buffer Size = 128 samples."
Write-Host "  2. En la app del Spark 2: apaga todos los bloques (GATE, COMP, DRIVE, AMP, MOD, DELAY, REVERB en OFF)."
Write-Host "  3. En Rocksmith 2014: selecciona entrada 'Real Tone Cable' y realiza la Calibración."
