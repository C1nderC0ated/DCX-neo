# DCX neo — Android Optimization Toolkit

DCX neo is a Windows batch (`.bat`) front-end for **ADB** that bundles a large
collection of Android performance, battery and diagnostic tweaks behind a
simple text menu. Instead of typing dozens of `adb shell` commands by hand,
you pick options from a menu and DCX neo runs the right commands for you.

> **Developed by AnOrmaluser12 · Updated by S1nt3r**

---

## ⚠️ Disclaimer — read this first

**Use DCX neo at your own risk.** It changes live system settings, system
properties and `device_config` flags on your phone. Most changes are
reversible, but some can cause apps to misbehave, break notifications, or
make the UI glitch until you reboot.

- A **restart of the phone** usually fixes anything that starts misbehaving.
- Many tweaks **do not survive a reboot** on a non-rooted device (this is
  normal — see [Persistence & root](#persistence--root)).
- Before applying lots of changes, use **[Backup](#backup--restore)** so you
  can roll back.
- DCX neo is a community tool. It is **not** affiliated with Google or your
  phone manufacturer.

---

## Table of contents

- [Requirements](#requirements)
- [Setup](#setup)
- [First run](#first-run)
- [Menu reference](#menu-reference)
  - [Main menu](#main-menu)
  - [Gaming](#gaming)
  - [Battery](#battery)
  - [Optimize Android](#optimize-android)
  - [Auto Setup](#auto-setup)
  - [CheckSetting (diagnostics)](#checksetting-diagnostics)
  - [Backup & Restore](#backup--restore)
  - [Benchmark](#benchmark)
  - [Other options](#other-options)
- [What actually works vs. placebo](#what-actually-works-vs-placebo)
- [Persistence & root](#persistence--root)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

---

## Requirements

| Requirement | Notes |
|---|---|
| **Windows PC** | The script is a `.bat` file and runs in `cmd.exe`. Windows 10/11 recommended. |
| **ADB (Android Debug Bridge)** | Must be installed and on your `PATH`, **or** placed in an `adb\` folder next to `DCX.bat`. |
| **An Android device** | With **USB debugging** enabled and the PC authorised. |
| **A USB cable** | Or a working wireless-ADB connection. |

A UTF-8 capable console is used (`chcp 65001`) and ANSI colours are enabled
automatically, so the menu shows colours on modern Windows terminals.

---

## Setup

### 1. Install ADB

Download **Android SDK Platform Tools** from Google and either:

- Add the folder to your Windows `PATH`, **or**
- Drop the extracted `adb.exe` (and its DLLs) into a folder named `adb`
  placed right next to `DCX.bat`. DCX neo automatically `cd`s into `adb\` if it
  finds it.

### 2. Enable USB debugging on the phone

1. Open **Settings → About phone**.
2. Tap **Build number** seven times to unlock **Developer options**.
3. Open **Settings → System → Developer options**.
4. Turn on **USB debugging**.
5. Connect the phone via USB and tap **Allow** on the RSA fingerprint prompt.

### 3. Run DCX neo

Double-click `DCX.bat` (or run it from a `cmd` window).

---

## First run

When DCX neo starts it performs several safety checks before showing the menu:

1. **Defines colours** (ANSI escape codes) so all messages render correctly.
2. **Checks that ADB is available.** If not, it tells you to install ADB or
   place it next to the script, then exits.
3. **Waits up to 10 seconds for an authorised device.** If none is found it
   reminds you to enable USB debugging, approve the fingerprint, and check
   the cable, then exits.
4. **Detects your Android API level and device model** and prints them, e.g.
   `Device: Pixel 7   API level: 34`.

After that, you land on the **Main menu**.

The Main menu, Gaming, Battery and Optimize screens also show a small live
header with device **uptime** and current **CPU load**.

---

## Menu reference

### Main menu

| # | Option | What it does |
|---|---|---|
| 1 | **Gaming** | Performance-oriented toggles (GPU renderer, ANGLE, network boost, etc). |
| 2 | **Battery** | Two pages of battery / background-management toggles + diagnostics. |
| 3 | **Optimize Android** | One-shot maintenance tasks (dexopt, fstrim, cache, compile, etc). |
| 4 | **Auto** | Applies a large batch of safe optimisations in one go. |
| 5 | **CheckSetting** | Generates a full device diagnostic report. |
| 6 | **Github** | Opens the project page. |
| 7 | **Reboot** | Reboots the connected device. |
| 8 | **Exit** | Closes DCX neo. |
| 9 | **Shell** | Drops you into an interactive `adb shell`. |
| 10 | **Benchmark** | Quick CPU + storage micro-benchmark. |
| 11 | **Backup** | Saves current toggleable settings to a restore script. |
| 12 | **Restore** | Re-applies a previously saved backup. |

---

### Gaming

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle GMS** | Enable/disable Google Mobile Services. Disabling shows a clear warning (breaks push, Maps, sign-in, Pay, etc) and asks for confirmation. |
| 2 | **Toggle Thermal-Service** | Override the thermal service status (0–6) to relax throttling. Input is validated. |
| 3 | **Toggle Package Verifier** | Turn Play Protect package verification on/off. |
| 4 | **Toggle Game-Overlay** | Control the game overlay / game-mode settings. |
| 5 | **Toggle Performance** | Apply / remove a bundle of performance-oriented properties. |
| 6 | **Network Boost** | TCP buffer tuning, Cloudflare/Google/AdGuard private DNS, preferred network mode (LTE/5G), and a full revert. |
| 7 | **GPU Renderer (Skia GL/Vulkan)** | Switch the HWUI renderer between `skiagl` (default), `skiavk` (Skia Vulkan), or clear the override. |
| 8 | **Force ANGLE for All Apps** | Force all GLES apps through ANGLE (GLES-on-Vulkan). Persists across reboots. |
| 9 | **Back** | Return to the main menu. |

**GPU Renderer** and **ANGLE** are the genuinely effective graphics switches
(see [What actually works](#what-actually-works-vs-placebo)). After changing
them you can verify with:

```
adb shell dumpsys gfxinfo <package> | findstr Pipeline
```

---

### Battery

The Battery section spans **two pages**.

#### Page 1

| # | Option |
|---|---|
| 1 | Toggle Power Saver |
| 2 | Toggle Animation |
| 3 | Toggle Auto Wifi |
| 4 | Toggle Sync |
| 5 | Toggle Motion |
| 6 | Toggle ZRAM |
| 7 | Toggle Extreme Power Saver |
| 8 | Toggle Send Error |
| 9 | Toggle Lock Profilling |
| 10 | Toggle Logs/etc |
| 11 | Next Page |
| 12 | Back |

#### Page 2

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle Log (For User Apps)** | Silence logging for third-party apps. |
| 2 | **Universal Toggle Logs/etc** | Broad logging on/off. |
| 3 | **Toggle Deviceidle Whitelist** | Add/remove apps from the Doze whitelist (system-app removal is guarded with a warning + protected list). |
| 4 | **Hibernate App** | Hibernate a specific package. |
| 5 | **Refresh Rate Lock** | Lock to 60 / 90 / 120 Hz, set adaptive (1–120), or restore defaults. |
| 6 | **Force Doze Now** | Immediately force the device into deep idle; unforce; or show state. |
| 7 | **App Hibernation (system-wide)** | Enable/disable Android 12+ app hibernation. |
| 8 | **Account Sync Toggle** | Master switch for all account auto-sync (battery saver). |
| 9 | **Voice Hotword Toggle** | Disable the always-on "Hey Google"/hotword pipeline. |
| A | **Wake-Lock Audit** | Battery-drain diagnostic (see below). |
| 0 | **Back** | Return to the main menu. |

**Wake-Lock Audit** collects the most useful battery dumps into one report
saved in `%TEMP%`:

1. Currently held wake locks (`dumpsys power`)
2. Top wake-lock holders since last charge (`dumpsys batterystats`)
3. Doze / deep-sleep state (`dumpsys deviceidle`)
4. Top alarms / background wakeups (`dumpsys alarm`)
5. Current CPU consumers (`dumpsys cpuinfo`)

It can open the report in Notepad, paginate it, or show a quick summary, and
includes an interpretation guide for spotting the app draining your battery.

---

### Optimize Android

One-shot maintenance and compilation tasks.

| # | Option | What it does |
|---|---|---|
| 1 | **Run bg-dexopt-job** | Trigger the background dexopt job. |
| 2 | **Run Fstrim** | Trim the filesystem (frees and reclaims storage blocks). |
| 3 | **Run Kill-all** | Force-stop background apps. Skips the current foreground app and protected packages to avoid data loss. |
| 4 | **Run Compile App** | Compile a single package; mode and package name are validated. |
| 5 | **Run Clear Cache** | Trim or wipe app caches (wipe requires root). |
| 6 | **Run Tweak SurfaceFlinger** | Apply refresh-rate-specific SurfaceFlinger timing tweaks. |
| 7 | **Run Clear Last Used** | Reset app usage stats. |
| 8 | **Compile All Apps** | Recompile **every** installed app. See modes below. |
| 9 | **Animation Speed** | Set all three animation scales (0 / 0.5 / 0.75 / 1.0 / custom). |
| 0 | **Back** | Return to the main menu. |

#### Compile All Apps — modes

| Mode | Description |
|---|---|
| **everything-profile** | Heavy but respects each app's usage profile. **Recommended.** |
| **everything** | Heaviest standard mode. |
| **speed** | Compile hot methods only (fast). |
| **speed-profile** | Android default behaviour. |
| **heaviest optimization** | `--check-prof false -m everything` + layout compilation + dexopt job. Uses the most storage and time; the layout step is skipped automatically on Android 12+ where it is unsupported. |

> Compiling all apps can take **5–30+ minutes** and warms the device. Keep
> it on a charger.

#### Tweak SurfaceFlinger

Choose a target refresh rate — **60 / 90 / 120 / 144 Hz** — and then a
profile (**Balance / Gaming / Battery**) that sets matching SurfaceFlinger
phase-offset and duration properties. A **Remove** option clears them.

---

### Auto Setup

**Auto** runs a large, curated batch of optimisations in one pass: logging
cleanup (including the WindowManager trace channels and dropbox rate limits),
dexopt, thermal status, and — on Android 12+ — enabling ANGLE and the
universal log silencer. It is the fastest way to apply a sensible baseline.

---

### CheckSetting (diagnostics)

Generates a **full device diagnostic report** and saves it with a timestamp
to `%TEMP%\dcx_report_<timestamp>.txt`, so reports are never overwritten and
you can compare before/after applying tweaks.

The report includes hardware (SoC, ABI, model), software (Android version,
patch level, build), memory (RAM/swap/cached), storage, live state (uptime,
CPU load, battery level/temp/voltage/health), display (refresh rate, size,
density), **current values of the graphics/animation/sync tweaks DCX neo can
change**, network mode, Doze whitelist, and the top RAM consumers.

You can:
- **Open in Notepad** — fully scrollable and searchable (recommended).
- **Paginate with MORE** — view in the console page by page.
- **Show summary** — a few key lines printed inline.

---

### Backup & Restore

A safety net so you can experiment freely.

**Backup** reads the current value of every Settings.Global / Settings.System
key, `device_config` flag and system property that DCX neo is able to toggle, and
writes them into a **stand-alone `.bat` restore script** in:

```
%USERPROFILE%\dcx_backups\dcx_backup_<timestamp>.bat
```

Because the backup is itself a normal batch file, you can:
- **Run it directly** without DCX neo to restore,
- **Open it in a text editor** and delete any lines you don't want to
  restore, or
- **Share it** to reproduce the same settings on another device.

Example of what a backup file looks like:

```bat
@echo off
:: DCX neo Settings Backup created ...
adb shell settings put global window_animation_scale 1.0
adb shell settings put system min_refresh_rate 60
adb shell settings put global master_sync_status 1
adb shell settings delete global angle_gl_driver_all_angle >nul 2>&1
adb shell setprop debug.hwui.renderer "skiagl"
...
pause
```

**Restore** lists the backups (newest first), asks for confirmation, and then
applies the chosen file. Both Backup and Restore can open the backups folder
in Explorer.

---

### Benchmark

A quick, repeatable micro-benchmark (lower numbers are better):

1. **CPU loop** — timed integer loop.
2. **Storage random write** — ~10 MB write with `dd`.
3. **Storage sequential read** — ~10 MB read with `dd`.

Run it before and after optimising to compare. It uses a portable shell loop,
so it works across devices that lack `seq`.

---

### Other options

- **Shell** — opens an interactive `adb shell` on the device.
- **Reboot** — reboots the connected phone.
- **Github** — opens the project page in your browser.
- **Exit** — closes DCX neo (also stops the ADB server when appropriate).

---

## What actually works vs. placebo

Android only reads a specific set of settings, properties and `device_config`
flags. A lot of "optimization scripts" floating around the internet set
hundreds of made-up keys (e.g. `persist.sys.cpu.governor`,
`debug.cpufreq.max_freq`, `persist.sys.gpu.boost_level`) that **Android never
reads** — they get stored but do nothing.

DCX neo focuses on the commands that have a **real, documented effect**, such as:

- **`debug.hwui.renderer`** (`skiagl` / `skiavk`) — the actual HWUI renderer.
- **`settings put global angle_gl_driver_all_angle 1`** — the official way to
  force ANGLE for all apps.
- **`persist.log.tag "*:S"`** — genuinely silences logcat.
- **Animation scales** (`window/transition/animator_*`) — the classic, real
  "make it feel faster" tweak.
- **`min_refresh_rate` / `peak_refresh_rate`** — real refresh-rate control.
- **`dumpsys deviceidle force-idle`**, **app hibernation**,
  **`master_sync_status`**, **`hotword_detection_enabled`** — real
  battery-related switches.
- **`pm compile` / `pm bg-dexopt-job` / `fstrim`** — real maintenance.

> **Note:** CPU/GPU frequency and governor changes are **not** possible via
> `setprop` — they live in kernel sysfs and require **root**. DCX neo does not
> pretend otherwise.

---

## Persistence & root

- On a **non-rooted** device, `setprop`-based changes (like the GPU renderer)
  apply immediately but **reset on reboot**. To make such properties
  permanent you need root (e.g. a Magisk module or editing
  `/system/build.prop`).
- `settings put` and `device_config put` values (animation scales, refresh
  rate, ANGLE, sync, hotword, etc.) **do persist** across reboots without
  root.
- On **Android 14+**, the package-manager dexopt path was replaced by **ART
  Service**, so some `pm compile` options behave differently or are removed
  (DCX neo handles the unsupported `--compile-layouts` case gracefully).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| **"ADB not found"** on launch | Install Platform Tools and add to `PATH`, or place `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **"No authorised device found"** | Enable USB debugging, replug the cable, and tap **Allow** on the phone's RSA prompt. Run `adb devices` to confirm it shows `device` (not `unauthorized`). |
| **Something feels broken after tweaking** | **Reboot the phone.** Most live tweaks reset on reboot, and that clears any misbehaviour. |
| **A tweak "didn't do anything"** | Use **CheckSetting** to read the current value back, and for graphics use `dumpsys gfxinfo <pkg> | findstr Pipeline`. Some properties need root to persist, or aren't supported on your Android version. |
| **A specific game glitches under ANGLE** | Go to **Gaming → Force ANGLE for All Apps → Disable**. |
| **Want to undo everything** | Use **Restore** with a backup made earlier, or reboot for non-persistent changes. |
| **Colours look wrong / menu is misaligned** | Use Windows Terminal or a recent `cmd.exe`; very old consoles may not render ANSI colours or the box characters. |

---

## Credits

- **AnOrmaluser12** — original author. (@AnOrmaluser12)
- **S1nt3r** — updates and fixes.

DCX is provided **as-is, with no warranty**. You are responsible for any
changes you apply to your device.
