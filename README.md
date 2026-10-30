# Rocksmith ASIO (RS_ASIO) for Spark 2 at 44100Hz 128 samples

> ### 🙏 Credits & Acknowledgments
> All credit for the core architecture and runtime patching of **[RS_ASIO](https://github.com/mdias/rs_asio)** goes to its original creator, **[Micael Dias (`mdias`)](https://github.com/mdias)**, and all [upstream contributors](https://github.com/mdias/rs_asio/graphs/contributors) who made low-latency ASIO possible in *Rocksmith 2014*. If you would like to support the original author's work, you can donate via [paypal.me/mdiasdonations](https://paypal.me/mdiasdonations).
>
> ### 🎯 Purpose of This Fork
> This fork exists specifically to make the **Positive Grid Spark 2 (50W)** (and **Spark 40**) work seamlessly as a USB ASIO guitar interface in **`Rocksmith 2014 Edition - Remastered`** on Windows (**44100 Hz / 128 samples**) by adding real-time `44100 Hz ↔ 48000 Hz` cubic Hermite resampling, clean DI software pre-gain with anti-clipping protection, and ready-to-use configuration files.

📦 **[Download Latest Release (`v0.7.5-spark2`)](https://github.com/jcruizsebastian/rocksmith-asio-rs_asio-for-spark-2-at-44100hz-128-samples/releases/latest)**

---

## 1. Installation

### Option A: Automatic PowerShell Installer (Recommended)

Open **PowerShell** on Windows and run this single command. It automatically locates your `Rocksmith 2014` Steam installation folder across all drives, downloads the latest release from this repository, and installs the files:

```powershell
irm https://raw.githubusercontent.com/jcruizsebastian/rocksmith-asio-rs_asio-for-spark-2-at-44100hz-128-samples/master/install.ps1 | iex
```

<details>
<summary>View full PowerShell installer script (<code>install.ps1</code>)</summary>

```powershell
#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (Get-Process -Name "Rocksmith2014" -ErrorAction SilentlyContinue) {
    Write-Host "[ERROR] Rocksmith 2014 is currently running. Please close it first." -ForegroundColor Red
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
    [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object {
        $root = $_.RootDirectory.FullName
        $steamLibs.Add((Join-Path $root "SteamLibrary"))
        $steamLibs.Add((Join-Path $root "Steam"))
        $steamLibs.Add((Join-Path $root "Program Files (x86)\Steam"))
    }
    foreach ($lib in ($steamLibs | Select-Object -Unique)) {
        $rsDir = Join-Path $lib "steamapps\common\Rocksmith2014"
        if (Test-Path (Join-Path $rsDir "Rocksmith2014.exe")) { return $rsDir }
    }
    return $null
}

$rsPath = Find-RocksmithPath
if (-not $rsPath) {
    $rsPath = Read-Host "Please enter the full path to your Rocksmith2014 folder"
}

$releaseUrl = "https://github.com/jcruizsebastian/rocksmith-asio-rs_asio-for-spark-2-at-44100hz-128-samples/releases/latest/download/RS_ASIO-v0.7.5-spark2-44100hz.zip"
$tempZip = Join-Path $env:TEMP "RS_ASIO-spark2.zip"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $releaseUrl -OutFile $tempZip -UseBasicParsing
Expand-Archive -Path $tempZip -DestinationPath $rsPath -Force
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
if ((Test-Path "HKLM:\SOFTWARE\WOW6432Node\ASIO\Positive Grid USB Audio Device") -or (Test-Path "HKLM:\SOFTWARE\ASIO\Positive Grid USB Audio Device")) {
    Write-Host "[OK] Positive Grid USB Audio Device ASIO driver detected." -ForegroundColor Green
} else {
    Write-Host "[WARN] Positive Grid Windows ASIO driver not detected yet. Please install it from Positive Grid Help Center." -ForegroundColor Yellow
}
Write-Host "Successfully installed to $rsPath!" -ForegroundColor Green
```

</details>

### Option B: Manual Installation

1. Download **`RS_ASIO-v0.7.5-spark2-44100hz.zip`** from the **[Releases](https://github.com/jcruizsebastian/rocksmith-asio-rs_asio-for-spark-2-at-44100hz-128-samples/releases/latest)** page.
2. In Steam, right-click **Rocksmith 2014** → *Manage* → *Browse local files*.
3. Extract `RS_ASIO.dll`, `avrt.dll`, and `RS_ASIO.ini` directly into the game directory (next to `Rocksmith2014.exe`).
4. Ensure `ExclusiveMode=1` and `Win32UltraLowLatencyMode=1` are set in `Rocksmith.ini`.

---

## 2. Optimal Settings (Windows & Spark 2: `44100 Hz` / `128 samples`)

Before launching the game, verify these 3 settings:

1. **Positive Grid Windows ASIO Driver set to `44100 Hz` and `128 samples`**:
   - Install the official **Positive Grid USB Audio Device** driver for Windows.
   - Open the **Positive Grid ASIO Control Panel** in Windows (with Rocksmith closed) and set **`Buffer Size: 128 samples`** (sample rate is locked at **`44100 Hz`** by the Spark 2 hardware).
   - *Why `128 samples`?* The official **Ubisoft Real Tone Cable** operates in WASAPI Exclusive mode with a **`3.0 ms` (`144 samples` at `48000 Hz`)** capture buffer, while Rocksmith's internal audio engine ticks every **`128 samples` (`2.67 ms`)**. At **`44100 Hz`**, a **`128 samples`** ASIO buffer corresponds to **`2.90 ms`** (`139–140 resampled frames` at `48000 Hz`), matching the native Real Tone Cable block size and timing almost 1:1. Using much larger buffers such as `512 samples` (`11.6 ms` / `558 frames`) delivers 4× larger bursts than Rocksmith's `3 ms` input period, causing pitch/fret detection errors (especially on the low 5th and 6th strings in fret-sensitive minigames like *Ducks Redux*).

### Optimal Buffer Size by Sample Rate (For Other USB Amplifiers & Interfaces)

To match the **`~2.67 ms – 3.00 ms` (`128 – 144 frames` at `48000 Hz`)** capture window expected by Rocksmith 2014's pitch detector across any ASIO sample rate ($\text{Optimal Buffer} \approx \text{SampleRate} \times 0.0029$), use the following settings:

| ASIO Driver Sample Rate | Optimal ASIO `Buffer Size` | Block Duration | Frames Delivered to Rocksmith (`48000 Hz`) | `RS_ASIO.ini` Setting | Common Amplifiers / Interfaces |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *(Real Tone Cable — WASAPI)* | *`144 samples` (fixed)* | *`3.00 ms`* | *`144 frames` (native reference)* | *`EnableWasapiInputs=1`* | *Ubisoft Real Tone Cable* |
| **`44100 Hz`** | **`128 samples`** | **`2.90 ms`** | **`139–140 frames`** (Resampled) | `ResamplingMode=Auto` | Positive Grid Spark 2 / 40 / MINI / GO, Boss Katana, Yamaha THR |
| **`48000 Hz`** | **`128 samples`** *(or `144`)* | **`2.67 ms`** *(or `3.00 ms`)* | **`128 frames`** *(or `144`)* (Native 1:1) | `ResamplingMode=Auto` | Focusrite Scarlett, Steinberg UR, Behringer UMC, Line 6 Helix |
| **`88200 Hz`** | **`256 samples`** | **`2.90 ms`** | **`139–140 frames`** (Resampled) | `ResamplingMode=Auto` *(or `Always`)* | Interfaces running at `2× 44.1 kHz` |
| **`96000 Hz`** | **`256 samples`** | **`2.67 ms`** | **`128 frames`** (Resampled) | `ResamplingMode=Auto` *(or `Always`)* | Interfaces running at `2× 48 kHz` |
| **`176400 Hz`** | **`512 samples`** | **`2.90 ms`** | **`139–140 frames`** (Resampled) | `ResamplingMode=Auto` *(or `Always`)* | Interfaces running at `4× 44.1 kHz` |
| **`192000 Hz`** | **`512 samples`** | **`2.67 ms`** | **`128 frames`** (Resampled) | `ResamplingMode=Auto` *(or `Always`)* | Interfaces running at `4× 48 kHz` |

> **General Tips for Other USB Modeling Amplifiers (Boss Katana, Yamaha THR, Fender Mustang, Line 6, etc.):**
> - **Use a Clean DI Signal**: If your amp exposes a dedicated **Dry / DI** USB input channel (commonly `Channel=2` or `Channel=3` on Boss Katana / Yamaha THR), set `Channel=` to that DI channel in `[Asio.Input.0]`. If your amp sends the processed signal chain over `Channel=0` (like the **Positive Grid Spark 2 / Spark 40**), save a hardware preset with all amp/effect blocks (`GATE`, `COMP`, `DRIVE`, `AMP`, `MOD`, `DELAY`, `REVERB`) turned **OFF**.
> - **Adjust Digital Pre-Gain (`SoftwareMasterVolumePercent`)**: Standard `0 dB` interfaces use `SoftwareMasterVolumePercent=100`. USB modeling amps that output a conservative DI signal (`-24 dBFS` to `-30 dBFS`, like the Spark 2) should use `SoftwareMasterVolumePercent=1000` to `2000` (`+20 dB` to `+26 dB`) so Rocksmith's calibration `fLevel` settles around `0.45 – 0.65`.
> - **Using Both an ASIO Amp and the Official Real Tone Cable**: Set `EnableWasapiInputs=1` under `[Config]` in `RS_ASIO.ini`. When your ASIO amp is powered off or unplugged from USB, `RS_ASIO` will automatically fall back to your native WASAPI **Real Tone Cable** without needing to remove `RS_ASIO.dll` or `avrt.dll`.
2. **Clean DI Signal on the Spark 2**:
   - In the Spark mobile app (or by saving a clean hardware preset on the amp by holding the Preset button), **turn OFF all signal chain blocks**: `GATE`, `COMP`, `DRIVE`, `AMP`, `MOD`, `DELAY`, and `REVERB`.
   - *Why?* Rocksmith's pitch detector expects an unprocessed Direct Injection (DI) guitar signal (just like the official Real Tone Cable) and applies its own in-game amp modeling. Leaving the Spark's `AMP` or `COMP` blocks enabled introduces harmonic overtones that trick Rocksmith into detecting notes an octave (+12 frets) or several frets higher. *(Remember: if you power-cycle the Spark 2 without saving the bypassed preset to a hardware slot, the amp will boot back into its stored preset with effects enabled).*
3. **Guitar Volume Knob at 100%**:
   - Turn your guitar's physical volume knob all the way up. *(Note: when the `AMP` block is bypassed on the Spark 2, the physical `MASTER` / `OUTPUT` knobs on the amp only control room speaker volume and do not affect the USB audio send level).*

---

## 3. Technical Overview: Why is this fork needed for the Spark 2?

`Rocksmith 2014` strictly requires audio interfaces to run at **48000 Hz** in exclusive mode, whereas the **Positive Grid Spark 2** USB ASIO driver is hardware-locked at **44100 Hz** and outputs its clean DI guitar signal with very conservative headroom (`~-27 dBFS`).

This version solves those limitations out of the box:

1. **Configurable `ResamplingMode` (`Auto`, `Always`, `Disabled`)**: With `ResamplingMode=Auto` (default), `RS_ASIO` attempts to switch the ASIO driver to `48000 Hz` first and automatically falls back to the driver's current sample rate via `getSampleRate` (e.g. `44100 Hz` on the Spark 2, or `88200` / `96000 Hz` on other interfaces) with real-time resampling. `ResamplingMode=Always` resamples on the fly without attempting to switch the driver's sample rate, and `ResamplingMode=Disabled` disables on-the-fly resampling.
2. **Real-Time Continuous-Phase Resampling (`44100 Hz ↔ 48000 Hz`)**: Uses 4-point cubic Hermite interpolation (`step = 44100 / 48000 = 0.91875`), tuned for a **`128 samples` ASIO buffer on Windows** (~2.9 ms ASIO latency → 139/140-frame blocks at 48000 Hz). Ensures rock-solid pitch detection in the tuner, across all 6 strings, and in fret-sensitive minigames like *Ducks Redux*.
3. **Clean Software Pre-Gain (`SoftwareMasterVolumePercent=2000`) with Anti-Clipping Protection**: Boosts the pure 32-bit floating-point pickup signal by `20x` (bringing the `-27 dBFS` Spark 2 DI peak right into Rocksmith's optimal calibration sweet spot while clamping to `[-1.0, 1.0]` to prevent integer wrap-around or harsh digital clipping).
4. **Zero-Stutter Real-Time Audio Callback**: Suppresses repeated `SetMasterVolumeLevelScalar` disk-flush spam during calibration and avoids any disk I/O inside the real-time ASIO buffer switch callback.

---

## 4. Included `RS_ASIO.ini` Configuration

The preconfigured `RS_ASIO.ini` included in the release uses the recommended hybrid setup (game audio output through your PC speakers/headphones via WASAPI at 48000 Hz, low-latency guitar input via ASIO from the Spark 2, and `EnableWasapiInputs=1` so an official Real Tone Cable also works natively whenever the Spark 2 is powered off/unplugged):

```ini
[Config]
EnableWasapiOutputs=1
EnableWasapiInputs=1
EnableAsio=1

[Asio]
BufferSizeMode=driver
CustomBufferSize=
ResamplingMode=Auto

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

> **Note**: If you prefer routing game audio output through the **Spark 2** speakers instead of your PC soundcard, set `EnableWasapiOutputs=0` and set `Driver=Positive Grid USB Audio Device` under `[Asio.Output]`.

---

## 5. In-Game Setup & Diagnostics (`RS_ASIO-log.txt`)

1. Launch Rocksmith 2014 and make sure your input mode is set to **Real Tone Cable** (not Microphone).
2. Run **Calibration** inside the game.
3. If you inspect `RS_ASIO-log.txt` in the game folder, you will see:
   - Real-time resampling automatically engaged at **`44100 Hz` (`128 frames`)**:
     ```txt
     ASIO running at 44100 Hz (host format is 48000 Hz - real-time resampling enabled)
     {ASIO IN 0} Initialize - real-time resampling active: ASIO 44100Hz (128 frames) <-> Host 48000Hz (up to 140 frames)
     ```
   - Rocksmith's internal input gain (`fLevel`) settling right in the middle of the range (`fLevel ≈ 0.45 - 0.65`).
   - **Fine-tuning `SoftwareMasterVolumePercent` for different guitar pickups**:
     - If you use very low-output vintage single-coils and `fLevel` stays pinned at `1` during calibration, increase `SoftwareMasterVolumePercent` to `2500` or `3000`.
     - If you use high-output humbuckers/active pickups (or notice that hard picking on the heavy 5th/6th strings causes a momentary `+1 fret` pitch spike), lower `SoftwareMasterVolumePercent` to `1000`–`1500`.

---

## Uninstallation

To remove `RS_ASIO`, simply delete `RS_ASIO.dll`, `avrt.dll`, and `RS_ASIO.ini` from your `Rocksmith2014` folder.
