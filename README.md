# DCX neo — Android Optimization Toolkit

<img width="224" height="117" alt="image" src="https://github.com/user-attachments/assets/36b493c2-fd83-4c39-a224-6f3d3a6d60d3" />

DCX neo is a Windows batch (`.bat`) front-end for **ADB**. Instead of typing
dozens of `adb shell` commands by hand, you pick options from a text menu and
DCX neo runs the right performance, battery and diagnostic tweaks for you.

> **Developed by AnOrmaluser12 · Updated by S1nt3r**

---

## ⚠️ Disclaimer — read this first

**Use DCX neo at your own risk.** It changes live system settings, properties
and `device_config` flags. Most changes are reversible and **a reboot usually
fixes anything that misbehaves**, but a few are device-dependent — see the
warnings on [Gaming](#gaming) and the [Troubleshooting](#troubleshooting)
table. Before applying a lot of changes, make a [Backup](#backup--restore).

DCX neo is a community tool, not affiliated with Google or any manufacturer.

---

## Table of contents

- [Requirements](#requirements) · [Setup](#setup) · [First run](#first-run)
- [Menu reference](#menu-reference): [Main](#main-menu) · [Gaming](#gaming) · [Battery](#battery) · [Optimize](#optimize-android) · [Auto](#auto-setup) · [CheckSetting](#checksetting-diagnostics) · [Backup & Restore](#backup--restore) · [Benchmark](#benchmark) · [App Manager](#app-manager)
- [What actually works](#what-actually-works-vs-placebo) · [Persistence & root](#persistence--root) · [Troubleshooting](#troubleshooting) · [Credits](#credits)

---

## Requirements

| Requirement | Notes |
|---|---|
| **Windows PC** | Runs in `cmd.exe`. Windows 10/11 recommended. |
| **ADB** | On your `PATH`, **or** as `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **Android device** | With **USB debugging** enabled and the PC authorised. |
| **USB cable** | Or a working wireless-ADB connection. |

---

## Setup

1. **Install ADB** — download **Android SDK Platform Tools** from Google, then
   add it to your `PATH` *or* drop `adb.exe` (and its DLLs) into an `adb\`
   folder next to `DCX.bat` (DCX neo `cd`s into it automatically).
2. **Enable USB debugging** — Settings → About phone → tap **Build number**
   ×7 → Developer options → **USB debugging**. Connect and tap **Allow** on the
   RSA prompt.
3. **Run** `DCX.bat` (double-click or from `cmd`).

---

## First run

On startup DCX neo defines ANSI colours, verifies ADB is present, waits up to
10 s for an authorised device (with guidance if none appears), then detects
and prints your device model and Android API level, e.g.
`Device: Pixel 7   API level: 34`. The Main, Gaming, Battery and Optimize
screens also show a live header with **uptime** and **CPU load**.

---

## Menu reference

### Main menu

| # | Option | What it does |
|---|---|---|
| 1 | **Gaming** | Performance toggles (GPU renderer, ANGLE, network boost…). |
| 2 | **Battery** | Two pages of battery / background toggles + diagnostics. |
| 3 | **Optimize Android** | One-shot maintenance (dexopt, fstrim, cache, compile…). |
| 4 | **Auto** | Applies a batch of safe optimisations in one go. |
| 5 | **CheckSetting** | Full device diagnostic report. |
| 6 | **App Mgr** | Background restriction + debloat (remove/restore apps). |
| 7 | **Reboot** | Reboots the device. |
| 8 | **Exit** | Closes DCX neo (stops the ADB server when appropriate). |
| 9 | **Shell** | Interactive `adb shell`. |
| 10 | **Benchmark** | Quick CPU + storage micro-benchmark. |
| 11 / 12 | **Backup / Restore** | Save / re-apply toggleable settings. |

---

### Gaming

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle GMS** | Enable/disable Google Mobile Services (warns + confirms — disabling breaks push, Maps, sign-in, Pay…). |
| 2 | **Toggle Thermal-Service** | Override thermal status (0–6) to relax throttling. Validated input. |
| 3 | **Toggle Package Verifier** | Play Protect package verification on/off. |
| 4 | **Toggle Game-Overlay** | Game overlay / game-mode settings. |
| 5 | **Toggle Performance** | Apply / remove a bundle of performance properties. |
| 6 | **Network Boost** | Safe TCP receive-window hint, optional private DNS (Cloudflare/Google/AdGuard), preferred network mode (LTE/5G), full revert. ⚠️ see below. |
| 7 | **GPU Renderer** | Switch HWUI renderer: `skiagl` (default) / `skiavk` (Skia Vulkan) / clear. |
| 8 | **Force ANGLE for All Apps** | Route all GLES apps through ANGLE. ⚠️ see below. |
| 9 | **Display Scaler** | Lower the render resolution + matching DPI (`wm size` / `wm density`) for more GPU headroom in games and lower power draw. Safe presets are computed live from your panel's native resolution (85 / 75 / 67 / 50 %), with custom and one-tap reset. A separate **UI size (DPI-only)** mode changes element size without touching resolution — a working stand-in for the **Smallest width** developer option, which some OEMs (e.g. Huawei EMUI/HarmonyOS) leave disabled. Reversible, no root, persists across reboot. |
| 10 | **Back** | — |

> **⚠️ Two of these are device-dependent (from real-world testing):**
> - **Network Boost** now applies only a harmless TCP receive-window hint.
>   Earlier versions also wrote deprecated Wi-Fi keys (`wifi_sleep_policy`,
>   `wifi_idle_ms`…) that **killed Wi-Fi on Android 15** — a reboot didn't
>   recover it, only **Revert** did. Those are gone; Revert still clears any
>   left over from an old run.
> - **Force ANGLE** can **crash most apps on launch** on non-Pixel GPUs (e.g.
>   MediaTek). It's opt-in with a Y/N prompt and **persists across reboots**,
>   so a reboot won't fix a crash loop — return here and **Disable**/**Delete**.

**GPU Renderer**, **ANGLE** and the **Display Scaler** are the genuinely
effective graphics switches. Verify a renderer change with:
`adb shell dumpsys gfxinfo <package> | findstr Pipeline`, and a resolution
change with `adb shell wm size` / `adb shell wm density`.

---

### Battery

Two pages.

**Page 1** — Toggle: Power Saver · Animation · Auto Wifi · Sync · Motion ·
ZRAM · Extreme Power Saver · Send Error · Lock Profilling · Logs/etc · Next
Page · Back.

**Page 2:**

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle Log (User Apps)** | Silence logging for third-party apps. |
| 2 | **Universal Toggle Logs/etc** | Broad logging on/off. |
| 3 | **Toggle Deviceidle Whitelist** | Add/remove Doze-whitelist apps (system-app removal is guarded with a protected list). |
| 4 | **Hibernate App** | Hibernate a specific package. |
| 5 | **Refresh Rate Lock** | Lock 60/90/120 Hz, adaptive (1–120), or restore. |
| 6 | **Force Doze Now** | Force deep idle now; unforce; or show state. |
| 7 | **App Hibernation** | Enable/disable Android 12+ system-wide hibernation. |
| 8 | **Account Sync Toggle** | Master switch for all account auto-sync. |
| 9 | **Voice Hotword Toggle** | Disable the always-on "Hey Google" pipeline. |
| A | **Wake-Lock Audit** | Battery-drain diagnostic (below). |
| 0 | **Back** | — |

**Wake-Lock Audit** collects the most useful battery dumps into one `%TEMP%`
report — held wake locks (`dumpsys power`), top holders since charge
(`batterystats`), Doze state (`deviceidle`), top wakeups (`alarm`), and CPU
consumers (`cpuinfo`) — then opens it in Notepad, paginates, or summarises,
with an interpretation guide for spotting the app draining your battery.

---

### Optimize Android

| # | Option | What it does |
|---|---|---|
| 1 | **Run bg-dexopt-job** | Trigger the background dexopt job. |
| 2 | **Run Fstrim** | Trim the filesystem. Runs **silently** (no output on success is normal); shows free space before/after. On some devices it only completes while charging + idle. |
| 3 | **Run Kill-all** | Force-stop background apps (skips the foreground app and protected packages). |
| 4 | **Run Compile App** | Compile a single package — pick a mode (`speed` / `speed-profile` / `verify` / `quicken` / `everything` / `everything-profile`) and name; both are validated and the package must be installed. |
| 5 | **Run Clear Cache** | Trim or wipe app caches (wipe needs root). |
| 6 | **Run Tweak SurfaceFlinger** | Refresh-rate-specific SF timing tweaks (below). |
| 7 | **Run Clear Last Used** | Reset app usage stats. |
| 8 | **Compile All Apps** | Recompile **every** app (modes below). |
| 9 | **Animation Speed** | Set all three animation scales (0 / 0.5 / 0.75 / 1.0 / custom). |
| 0 | **Back** | — |

**Compile All Apps — modes:** `everything-profile` (**recommended** — heavy
but profile-aware), `everything` (heaviest standard), `speed` (hot methods
only), `speed-profile` (Android default), and **heaviest optimization** (full
all-method compile + layouts + dexopt; uses the most storage/time). Compiling
all apps can take **5–30+ min** and warms the device — keep it on a charger.

**Tweak SurfaceFlinger:** pick a refresh rate (**60/90/120/144 Hz**), then a
profile (**Balance/Gaming/Battery**) that sets matching phase-offset and
duration properties. A **Remove** option clears them.

> **Dexopt/compile are version-aware** — you don't choose anything. On
> **API ≤ 33** DCX neo uses the classic `pm compile` / `pm bg-dexopt-job`
> path. On **API ≥ 34** dexopt is ART Service, so it uses `pm compile -m <mode>
> -f -a` (removed flags like `--check-prof` / `--compile-layouts` dropped) and
> prefers the native `pm art dexopt-packages -r bg-dexopt`, falling back to
> `pm bg-dexopt-job` if a build doesn't expose `pm art`.

---

### Auto Setup

Runs a curated batch in one pass: logging cleanup (WindowManager trace
channels, dropbox rate limits), dexopt, thermal status, and the universal log
silencer. The fastest way to a sensible baseline.

> Auto Setup deliberately does **not** enable ANGLE — earlier versions did, on
> Android 12+, which crashed apps on some non-Pixel devices. ANGLE is opt-in
> only (Gaming → Force ANGLE), so Auto stays safe for every device.

---

### CheckSetting (diagnostics)

Generates a timestamped report at `%TEMP%\dcx_report_<timestamp>.txt` (never
overwritten, so you can compare before/after). It covers hardware (SoC, ABI,
model), software (version, patch, build), memory, storage, live state
(uptime, CPU, battery level/temp/voltage/health), display, **current values
of the tweaks DCX neo can change**, network mode, Doze whitelist and top RAM
consumers. Open it in Notepad (recommended), paginate with `MORE`, or show an
inline summary.

---

### Backup & Restore

A safety net so you can experiment freely. **Backup** reads every
Settings.Global/System key, `device_config` flag and property DCX neo can
toggle, and writes a **stand-alone restore `.bat`** to
`%USERPROFILE%\dcx_backups\dcx_backup_<timestamp>.bat`:

```bat
@echo off
:: DCX neo Settings Backup created ...
adb shell settings put global window_animation_scale 1.0
adb shell settings put system min_refresh_rate 60
adb shell settings delete global angle_gl_driver_all_angle >nul 2>&1
adb shell setprop debug.hwui.renderer "skiagl"
...
pause
```

Because it's a normal batch file you can run it directly without DCX neo, edit
out lines you don't want, or share it to reproduce settings elsewhere.
**Restore** lists backups (newest first), confirms, then applies the chosen
one. Both can open the backups folder in Explorer.

---

### Benchmark

A quick, repeatable micro-benchmark (lower is better): a timed CPU loop, a
~10 MB storage random write and a ~10 MB sequential read (both via `dd`). Run
it before and after optimising to compare. Uses a portable shell loop, so it
works on devices that lack `seq`.

---

### App Manager

App-level controls (background restriction + debloat). **Everything here is
reversible.**

| # | Option | What it does |
|---|---|---|
| 1 | **Restrict app background** | Deny `RUN_IN_BACKGROUND` for a package you name (stops it running in the background; saves battery). |
| 2 | **Allow app background** | Undo the above for a package. |
| 3 | **Debloat by package name** | Remove an app for the current user (`pm uninstall -k --user 0`). Validated + confirmed; data kept. |
| 4 | **Suggested bloatware** | Auto-detects your brand and lists only **vetted, safe-to-remove** packages that are **actually installed** (cross-vendor Facebook, optional Google apps, plus Xiaomi / Transsion / Samsung / Huawei sets). |
| 5 | **List installed packages** | Dump all packages — or user/updated apps (`-3`) where bloat usually lives — to Notepad. |
| 6 | **Restore a removed app** | Bring a debloated app back (`pm install-existing`). |
| 7 | **Back** | — |

**How removal works (and why it's safe).** Debloat uses
`pm uninstall -k --user 0`: the app is removed only for the current user and
its data is **kept** (`-k`). The APK stays in `/system`, so you can restore it
any time via **option 6** or a **factory reset**. OTA updates may also bring
packages back.

> **⚠️ Debloat warnings**
> - Only remove apps you recognise. Removing a critical package can cause a
>   **bootloop**. DCX neo hard-blocks known offenders — including
>   **`com.hoffnung`**, which on Transsion (Tecno/Infinix/itel) phones looks
>   like bloat but bootloops the device — plus system UI, phone, settings,
>   telephony providers, and Huawei core services (`com.huawei.hwid`, push,
>   FIDO/`hwasm`, OTA).
> - The **Suggested** lists only ever show packages that are both
>   community-vetted as safe *and* installed, and every removal asks for
>   confirmation. Package lists are sourced from UAD-NG and community debloat
>   guides.
> - If something breaks after a debloat, use **Restore** (option 6) or reboot;
>   a factory reset restores everything.

---

## What actually works vs. placebo

Android only reads a specific set of settings, properties and `device_config`
flags. Many "optimization scripts" set hundreds of made-up keys (e.g.
`persist.sys.cpu.governor`, `debug.cpufreq.max_freq`) that **Android never
reads** — they're stored but do nothing. DCX neo focuses on commands with a
**real, documented effect**:

- **`pm compile` / `pm bg-dexopt-job` / `pm art dexopt-packages` / `fstrim`** —
  maintenance; the **most noticeable** wins (chosen per Android version).
- **Animation scales** — the classic "make it feel faster" tweak.
- **`debug.hwui.renderer`** (`skiagl`/`skiavk`) — the actual HWUI renderer.
- **`angle_gl_driver_all_angle`** — the official ANGLE switch (real, but
  device-dependent — see the Gaming warning).
- **`min_refresh_rate` / `peak_refresh_rate`** — real refresh-rate control.
- **`wm size` / `wm density`** — real logical-resolution and DPI control
  (Display Scaler). Lowering the render resolution is a genuine, no-root way
  to gain GPU headroom and cut power draw; `wm size reset` /
  `wm density reset` fully revert it.
- **`deviceidle force-idle`, app hibernation, `master_sync_status`,
  `hotword_detection_enabled`, `persist.log.tag "*:S"`** — real battery/log
  switches.
- **`cmd appops … RUN_IN_BACKGROUND deny`, `pm uninstall -k --user 0`** —
  background restriction and (reversible) debloat (App Manager).

> CPU/GPU frequency and governor changes are **not** possible via `setprop` —
> they live in kernel sysfs and need **root**. DCX neo doesn't pretend
> otherwise.

---

## Persistence & root

- `settings put` and `device_config put` values (animation scales, refresh
  rate, ANGLE, sync, hotword…) **persist** across reboots without root.
- `setprop`-based changes (e.g. GPU renderer) apply immediately but **reset on
  reboot**; making them permanent needs root (Magisk module or `build.prop`).
- **Android 14+** routes dexopt through **ART Service**; DCX neo detects this
  at startup and adjusts the compile/dexopt commands automatically (details in
  [Optimize Android](#optimize-android)).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| **"ADB not found"** on launch | Install Platform Tools and add to `PATH`, or put `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **"No authorised device found"** | Enable USB debugging, replug, tap **Allow** on the phone. Check `adb devices` shows `device` (not `unauthorized`). |
| **Something feels broken after tweaking** | **Reboot** — most live tweaks reset on reboot and that clears it. |
| **A tweak "didn't do anything"** | Read the value back via **CheckSetting** (graphics: `dumpsys gfxinfo <pkg> \| findstr Pipeline`). Some keys need root or a newer Android. |
| **Most apps crash after enabling ANGLE** | Common on non-Pixel GPUs; **a reboot won't help** (it persists). Gaming → Force ANGLE → **Disable**/**Delete**. |
| **Wi-Fi died after Network Boost** | Gaming → Network Boost → **Revert** (clears any old Wi-Fi keys). |
| **ART Service printed a wall of text** | Not errors — older versions dumped a line per package. Current builds show a summary (optimised/failed) and only real failures; a few failures are normal. |
| **"Unknown option: --compile-layouts" / "Unknown command"** | Expected on Android 12+ (removed; gone on 14+ under ART Service). DCX neo skips it automatically and continues. |
| **Bootloop / something broke after debloat** | Boot to recovery and **factory reset** restores every removed app (they're never deleted from `/system`). To revert a single app without resetting, use **App Mgr → Restore**. |
| **Want to undo everything** | **Restore** a backup, or reboot for non-persistent changes. |
| **Colours / alignment look wrong** | Use Windows Terminal or a recent `cmd.exe`; very old consoles don't render ANSI colours or box characters. |

---

## Credits

- **AnOrmaluser12** — original author ([@AnOrmaluser12](https://github.com/AnOrmaluser12))
- **S1nt3r** — updates and fixes

DCX is provided **as-is, with no warranty**. You are responsible for any
changes you apply to your device.

---

## License & Media Notice

This project's source code is licensed under the **GNU GPLv3**.

Exception: the image file [4152900.jpg] is excluded from the GPL-3.0 license.
It is owned by its respective creator and is included strictly for personal,
non-commercial display. If you fork or reuse this project, you must remove or
replace this image.
