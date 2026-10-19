# RS ASIO — Optimización para Positive Grid Spark 2 (44100 Hz / 128 Samples)

Fork de [`RS_ASIO`](https://github.com/mdias/rs_asio) diseñado específicamente para utilizar el amplificador **Positive Grid Spark 2 (50W)** (y **Spark 40**) como interfaz de audio USB ASIO en **`Rocksmith 2014 Edition - Remastered`** sobre Windows.

📦 **[Descargar última Release (`v0.7.5-spark2`)](https://github.com/jcruizsebastian/rs_asio-spark-2-44100hz/releases/latest)**

---

## ¿Qué soluciona este proyecto?

`Rocksmith 2014` exige que la interfaz de audio funcione a **48000 Hz** en modo exclusivo, pero el driver USB ASIO del **Positive Grid Spark 2** trabaja bloqueado a **44100 Hz** y entrega la señal limpia (DI) con un margen de grabación muy bajo (`-27 dBFS`).

Esta versión resuelve todos esos problemas de raíz:

1. **Fallback automático a `44100 Hz`**: Si el driver ASIO rechaza `48000 Hz`, `RS_ASIO` conmuta automáticamente a `44100 Hz`.
2. **Remuestreo en tiempo real (`44100 Hz ↔ 48000 Hz`)**: Interpolación cúbica de Hermite de 4 puntos con fase continua (`step = 44100 / 48000 = 0.91875`), optimizada para un **buffer ASIO de `128 samples` en Windows** (~2,9 ms de latencia ASIO → bloques de 139/140 muestras a 48000 Hz). Garantiza detección de nota exacta en el afinador, en las 6 cuerdas y en minijuegos como *Ducks Redux*.
3. **Ganancia limpia por software (`SoftwareMasterVolumePercent=2000`) con protección anti-clipping**: Amplifica `×20` la señal pura de las pastillas en coma flotante de 32 bits (llevando el pico de `-27 dBFS` al rango óptimo de calibración de Rocksmith sin saturar jamás gracias al limitador en `[-1.0, 1.0]`).
4. **Medidor de señal (`[InputMeter]`) integrado**: Registra cada ~3 segundos en `RS_ASIO-log.txt` el pico real de entrada (`rawPeak`) y de salida (`outPeak`), eliminando además el spam de escritura en disco durante la calibración.

---

## 1. Requisitos previos en Windows y en el Spark 2

Antes de abrir el juego, asegúrate de tener estos 3 ajustes:

1. **Driver ASIO de Positive Grid a `128 samples`**:
   - Instala el driver oficial **Positive Grid USB Audio Device** para Windows.
   - Abre el **Panel de Control ASIO de Positive Grid** y selecciona **`Buffer Size: 128 samples`**.
2. **Señal limpia (DI) en el Spark 2**:
   - En la app del Spark (o guardando un preset limpio en el ampli), **apaga todos los bloques**: `GATE`, `COMP`, `DRIVE`, `AMP`, `MOD`, `DELAY` y `REVERB` en **OFF**.
   - *¿Por qué?* El detector de notas de Rocksmith necesita la onda limpia de tus pastillas. Si dejas encendido el bloque `AMP` del Spark, los armónicos artificiales de la simulación de válvulas/altavoz engañan al detector de tono (haciendo que al pulsar el traste 1 dispare en el traste 11 o 12).
3. **Volumen de la guitarra al máximo**:
   - Sube la rueda de volumen de tu guitarra al 100%. (En el Spark 2 con el `AMP` apagado, las ruedas físicas `MASTER` / `OUTPUT` solo controlan el volumen que oyes en la habitación, no el nivel USB).

---

## 2. Instalación

### Opción A: Instalación automática con PowerShell (Recomendada)

Abre **PowerShell** en Windows y ejecuta este comando de una sola línea (busca automáticamente dónde tienes instalado `Rocksmith 2014` en Steam, descarga la última Release de este repositorio y configura los archivos):

```powershell
irm https://raw.githubusercontent.com/jcruizsebastian/rs_asio-spark-2-44100hz/master/install.ps1 | iex
```

<details>
<summary>Ver el código completo del script de PowerShell (<code>install.ps1</code>)</summary>

```powershell
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

if (Get-Process -Name "Rocksmith2014" -ErrorAction SilentlyContinue) {
    Write-Host "[ERROR] Rocksmith 2014 está abierto. Ciérralo antes de continuar." -ForegroundColor Red
    return
}

function Find-RocksmithPath {
    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($rp in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam", "HKCU:\Software\Valve\Steam")) {
        if (Test-Path $rp) {
            $props = Get-ItemProperty $rp -ErrorAction SilentlyContinue
            if ($props.InstallPath) { $candidates.Add($props.InstallPath) }
            if ($props.SteamPath)   { $candidates.Add(($props.SteamPath -replace '/', '\')) }
        }
    }
    $candidates.Add("C:\Program Files (x86)\Steam")
    $candidates.Add("C:\Program Files\Steam")

    $steamLibs = [System.Collections.Generic.List[string]]::new()
    foreach ($steamRoot in ($candidates | Select-Object -Unique)) {
        if (Test-Path $steamRoot) {
            $steamLibs.Add($steamRoot)
            foreach ($vdf in @((Join-Path $steamRoot "steamapps\libraryfolders.vdf"), (Join-Path $steamRoot "config\libraryfolders.vdf"))) {
                if (Test-Path $vdf) {
                    Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches | ForEach-Object {
                        $_.Matches | ForEach-Object {
                            $libPath = $_.Groups[1].Value -replace '\\\\', '\'
                            if (Test-Path $libPath) { $steamLibs.Add($libPath) }
                        }
                    }
                }
            }
        }
    }
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $steamLibs.Add((Join-Path $_.Root "SteamLibrary"))
        $steamLibs.Add((Join-Path $_.Root "Steam"))
        $steamLibs.Add((Join-Path $_.Root "Program Files (x86)\Steam"))
    }
    foreach ($lib in ($steamLibs | Select-Object -Unique)) {
        $rsDir = Join-Path $lib "steamapps\common\Rocksmith2014"
        if (Test-Path (Join-Path $rsDir "Rocksmith2014.exe")) { return $rsDir }
    }
    return $null
}

$rsPath = Find-RocksmithPath
if (-not $rsPath) {
    $rsPath = Read-Host "Introduce la ruta completa a la carpeta de Rocksmith2014"
}

$releaseUrl = "https://github.com/jcruizsebastian/rs_asio-spark-2-44100hz/releases/latest/download/RS_ASIO-v0.7.5-spark2-44100hz.zip"
$tempZip = Join-Path $env:TEMP "RS_ASIO-spark2.zip"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $releaseUrl -OutFile $tempZip -UseBasicParsing
Expand-Archive -Path $tempZip -DestinationPath $rsPath -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Write-Host "¡Instalado correctamente en $rsPath!" -ForegroundColor Green
```

</details>

### Opción B: Instalación manual

1. Descarga **`RS_ASIO-v0.7.5-spark2-44100hz.zip`** desde la sección **[Releases](https://github.com/jcruizsebastian/rs_asio-spark-2-44100hz/releases/latest)**.
2. En Steam, haz clic derecho sobre **Rocksmith 2014** → *Administrar* → *Ver archivos locales*.
3. Extrae los 3 archivos (`RS_ASIO.dll`, `avrt.dll` y `RS_ASIO.ini`) directamente en la carpeta del juego (junto a `Rocksmith2014.exe`).
4. Asegúrate de que en `Rocksmith.ini` estén activos `ExclusiveMode=1` y `Win32UltraLowLatencyMode=1`.

---

## 3. Configuración incluida en `RS_ASIO.ini`

El archivo `RS_ASIO.ini` de la Release ya viene preconfigurado con el modo híbrido óptimo (salida de audio por los altavoces/auriculares del PC mediante WASAPI a 48000 Hz, y entrada de guitarra por ASIO desde el Spark 2):

```ini
[Config]
EnableWasapiOutputs=1
EnableWasapiInputs=0
EnableAsio=1

[Asio]
BufferSizeMode=driver
CustomBufferSize=
SampleRate=

[Asio.Output]
Driver=
BaseChannel=0
AltBaseChannel=
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=100
EnableRefCountHack=

[Asio.Input.0]
Driver=Positive Grid USB Audio Device
Channel=0
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=2000
EnableRefCountHack=
```

> **Nota**: Si prefieres escuchar el sonido del juego a través de los altavoces del propio **Spark 2** en lugar del PC, cambia `EnableWasapiOutputs=0` y pon `Driver=Positive Grid USB Audio Device` debajo de `[Asio.Output]`.

---

## 4. Puesta en marcha y diagnóstico (`RS_ASIO-log.txt`)

1. Dentro de Rocksmith 2014, asegúrate de tener seleccionado el modo de entrada **Real Tone Cable** (no Micrófono).
2. Entra en **Calibración** y sigue las instrucciones rasgueando las cuerdas.
3. Si abres `RS_ASIO-log.txt` en la carpeta del juego, verás que:
   - El driver arranca en modo remuestreo en tiempo real:
     ```txt
     ASIO running at 44100 Hz (host format is 48000 Hz - real-time resampling enabled)
     {ASIO IN 0} Initialize - real-time resampling active: ASIO 44100Hz (128 frames) <-> Host 48000Hz (up to 140 frames)
     ```
   - La ganancia de calibración de Rocksmith (`fLevel`) se estabiliza cómodamente hacia la mitad de la escala (`fLevel ≈ 0.45 - 0.65`).
   - Las líneas `[InputMeter]` muestran los picos de tu guitarra:
     - En silencio: `rawPeak ≈ 0.00005` (`outPeak ≈ 0.0005`, `-66 dBFS`).
     - Rasgueando fuerte: `outPeak ≈ 0.60 - 0.90` (fuerte y claro, sin llegar a `1.0`).
   - **Ajuste fino según tus pastillas**:
     - Si tu guitarra tiene pastillas de salida muy baja y en la calibración `fLevel` se queda clavado en `1`, sube `SoftwareMasterVolumePercent` a `2500` o `3000`.
     - Si tu guitarra tiene pastillas activas muy potentes y `outPeak` llega a `1` constantemente, baja `SoftwareMasterVolumePercent` a `1200` o `1500`.

---

## Desinstalación

Para desinstalar `RS_ASIO`, simplemente elimina `RS_ASIO.dll`, `avrt.dll` y `RS_ASIO.ini` de la carpeta de `Rocksmith2014`.

## Créditos

Basado en el proyecto original **[RS_ASIO](https://github.com/mdias/rs_asio)** creado por **[mdias](https://github.com/mdias)** y colaboradores.
