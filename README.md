# DCX neo — Android Optimization Toolkit

<img width="224" height="117" alt="image" src="https://github.com/user-attachments/assets/36b493c2-fd83-4c39-a224-6f3d3a6d60d3" />

DCX neo is a Windows batch (`.bat`) front-end for **ADB**. Instead of typing
dozens of `adb shell` commands by hand, you pick options from a text menu and
DCX neo runs the right performance, battery and diagnostic tweaks for you. It
also covers the SystemUI-Tuner and SetEdit ground without root: status bar,
quick-settings tiles, the volume cap, and a settings explorer with
snapshot/diff and profiles.

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
- [Menu reference](#menu-reference): [Main](#main-menu) · [Gaming](#gaming) · [Battery](#battery) · [Optimize](#optimize-android) · [Auto](#auto-setup) · [CheckSetting](#checksetting-diagnostics) · [Tweaks](#tweaks) · [Backup & Restore](#backup--restore) · [Benchmark](#benchmark) · [App Manager](#app-manager) · [Wireless ADB](#wireless-adb) · [Settings Tools](#settings-tools)
- [What actually works](#what-actually-works-vs-placebo) · [Persistence & root](#persistence--root) · [Troubleshooting](#troubleshooting) · [Credits](#credits)

---

## Requirements

| Requirement | Notes |
|---|---|
| **Windows PC** | Runs in `cmd.exe`. Windows 10/11 recommended. |
| **ADB** | On your `PATH`, **or** as `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **Android device** | **USB debugging** enabled and the PC authorised. |
| **USB cable** | Or Wi-Fi — the built-in **Wireless ADB** menu (option 13) handles pairing/connecting. |

---

## Setup

1. **Install ADB** — download **Android SDK Platform Tools** from Google, then
   add it to your `PATH`, or drop `adb.exe` (and its DLLs) into an `adb\`
   folder next to `DCX.bat` (the Release already contains one; DCX `cd`s into
   it automatically).
2. **Enable USB debugging** — Settings → About phone → tap **Build number**
   ×7 → Developer options → **USB debugging**. Connect and tap **Allow** on the
   RSA prompt.
3. **Run** `DCX.bat` (double-click or from `cmd`).

---

## First run

On startup DCX neo sets up ANSI colours, verifies ADB, and waits up to 10 s for
an authorised device — if none appears you can jump straight to **[W] Wireless
ADB setup** or **[R]etry** instead of exiting. It then prints your device model
and Android API level, e.g. `Device: Pixel 7   API level: 34`. The Main,
Gaming, Battery and Optimize screens show a live header with **uptime** and
**CPU load**.

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
| 6 | **Tweaks** | Status bar, quick-settings tiles, volume cap, font scale, night modes and more — the SystemUI-Tuner-style toggles. |
| 7 | **Reboot** | Reboots the device. |
| 8 | **Exit** | Closes DCX neo (stops the ADB server when appropriate). |
| 9 | **Shell** | Interactive `adb shell`. |
| 10 | **Benchmark** | Quick CPU + storage micro-benchmark. |
| 11 / 12 | **Backup / Restore** | Save / re-apply toggleable settings. |
| 13 | **Wireless ADB** | Pair (Android 11+), connect by IP, enable via USB (`adb tcpip`) with auto-IP, disconnect. |
| 14 | **App Mgr** | Background restriction + debloat (remove/restore apps). |
| 15 | **Settings Tools** | Explorer, snapshot & diff, profiles — these work on *any* settings key, not just the curated ones. |

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
| 9 | **Display Scaler** | Lower render resolution + matching DPI (`wm size` / `wm density`) for more GPU headroom and lower power. Safe presets are computed live from the panel's native resolution (85 / 75 / 67 / 50 %), plus custom and one-tap reset. A separate **UI size (DPI-only)** mode changes element size without touching resolution — a stand-in for the **Smallest width** developer option that some OEMs (e.g. Huawei EMUI/HarmonyOS) disable. Reversible, no root, persists across reboot. |
| 10 | **Back** | — |

> **⚠️ Two of these are device-dependent (from real-world testing):**
> - **Network Boost** now applies only a harmless TCP receive-window hint.
>   Earlier versions also wrote deprecated Wi-Fi keys (`wifi_sleep_policy`,
>   `wifi_idle_ms`…) that **killed Wi-Fi on Android 15** — only **Revert**
>   recovered it, not a reboot. Those are gone; Revert still clears any
>   leftovers from an old run.
> - **Force ANGLE** can **crash most apps on launch** on non-Pixel GPUs (e.g.
>   MediaTek). It's opt-in (Y/N) and **persists across reboots**, so a reboot
>   won't fix a crash loop — return here and **Disable**/**Delete**.

**GPU Renderer**, **ANGLE** and the **Display Scaler** are the genuinely
effective graphics switches. Verify a renderer change with
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
| 8 | **Account Sync Toggle** | Account auto-sync switch. Writes `master_sync_status`, which is **placebo on modern Android** — see [What works vs placebo](#what-actually-works-vs-placebo). |
| 9 | **Voice Hotword Toggle** | Disable the always-on "Hey Google" pipeline. |
| A | **Wake-Lock Audit** | Battery-drain diagnostic (below). |
| 0 | **Back** | — |

**Wake-Lock Audit** collects the key battery dumps into one `%TEMP%` report —
held wake locks (`dumpsys power`), top holders since charge (`batterystats`),
Doze state (`deviceidle`), top wakeups (`alarm`) and CPU consumers
(`cpuinfo`) — then opens it in Notepad, paginates, or summarises, with a guide
for spotting the app draining your battery.

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
| 9 | **Animation Speed** | Set all three animation scales (0 / 0.5 / 0.75 / 1.0 / custom). Custom input is validated to the documented 0–2 range (comma decimals like `1,5` accepted). |
| 0 | **Back** | — |

**Compile All Apps — modes:** `everything-profile` (**recommended** — heavy
but profile-aware), `everything` (heaviest standard), `speed` (hot methods
only), `speed-profile` (Android default), and **heaviest optimization** (full
all-method compile + layouts + dexopt; uses the most storage/time). Compiling
all apps can take **5–30+ min** and warms the device — keep it on a charger.

**Tweak SurfaceFlinger:** pick a refresh rate (**60/90/120/144 Hz**), then a
profile (**Balance/Gaming/Battery**) that sets matching phase-offset and
duration properties. A **Remove** option clears them.

> **Dexopt/compile are version-aware** (no choice needed). On **API ≤ 33** DCX
> neo uses the classic `pm compile` / `pm bg-dexopt-job` path. On **API ≥ 34**
> dexopt is ART Service, so it uses `pm compile -m <mode> -f -a` (dropping
> removed flags like `--check-prof` / `--compile-layouts`) and prefers
> `pm art dexopt-packages -r bg-dexopt`, falling back to `pm bg-dexopt-job`
> where a build doesn't expose `pm art`.

---

### Auto Setup

Runs a curated batch in one pass: logging cleanup (WindowManager trace
channels, dropbox rate limits), dexopt, thermal status, and the universal log
silencer — the fastest way to a sensible baseline.

> Auto Setup deliberately does **not** enable ANGLE (earlier versions did on
> Android 12+, which crashed apps on some non-Pixel devices). ANGLE is opt-in
> only (Gaming → Force ANGLE), so Auto stays safe for every device.

---

### CheckSetting (diagnostics)

Generates a timestamped report at `%TEMP%\dcx_report_<timestamp>.txt` (never
overwritten, so you can compare before/after). It covers hardware (SoC, ABI,
model), software (version, patch, build), memory, storage, live state (uptime,
CPU, battery level/temp/voltage/health), display, **current values of the
tweaks DCX neo can change**, network mode, Doze whitelist and top RAM
consumers. Open it in Notepad, paginate with `MORE`, or show an inline summary.

---

### Tweaks

SystemUI Tuner and SetEdit territory, with no root and no companion app — the
`adb shell` user already holds `WRITE_SECURE_SETTINGS`, which is exactly the
permission those apps ask you to grant them.

**Every write here is undo-protected**: the previous value is captured to
`%USERPROFILE%\dcx_backups\dcx_explorer_undo_<timestamp>.bat` before anything
changes, and all of these keys are also covered by
[Backup](#backup--restore).

| # | Option | What it does |
|---|---|---|
| 1 | **Clock — show seconds** | `secure clock_seconds`. Applies live — SystemUI watches the key. Heavily skinned clocks (some OneUI) ignore it. |
| 2 | **Battery percent** | `system status_bar_show_battery_percent`. Live on AOSP-based status bars. |
| 3 | **Icon blacklist** | `secure icon_blacklist` — hide status bar icons (rotate, alarm, bluetooth, DND, VPN…). 15-slot picker plus free text; icons that answer to two names write both. Re-hiding an icon can't pile up duplicates. |
| 4 | **Demo mode** | Freezes the status bar into a clean fixed state — full signal, no clutter, 12:00 — for screenshots. Purely cosmetic; ends on exit or reboot. |
| 5 | **QS tile editor** | `secure sysui_qs_tiles`. Add the tiles Android ships but doesn't show: `dream`, `font_scaling`, `qr_code_scanner`, `onehanded`, `reverse`, `hearing_devices`, `notes`, `reduce_brightness`… Add at the end or the front, remove, reset. Applies live. |
| 6 | **Volume cap** | The **software** safe-media-volume cap. ⚠️ see below. |
| 7 | **Heads-up notifications** | `global heads_up_notifications_enabled` — pop-ups on/off for every app at once. |
| 8 | **Font scale** | `system font_scale`, clamped 0.5–2.0 (outside that, layouts clip and dialogs lose buttons). Comma decimals accepted: `1,15` → `1.15`. |
| 9 | **Long-press timeout** | `secure long_press_timeout`. ⚠️ Battery → Animation → **Off** also pins this key to 250 and **On** deletes it — whichever you run last wins. |
| 10 | **Stay awake while charging** | `global stay_on_while_plugged_in`, a bitmask: AC=1, USB=2, wireless=4, dock=8 (add them; 0 = off). Rough on an OLED panel over time. |
| 11 | **Night** | Two different features share the name: **dark theme** (`cmd uimode night`) and **night light**, the warm blue-light filter (`night_display_*`). Both live here, labelled apart. |
| 12 | **More device tweaks** | Camera gestures (double-tap power, twist to flip), charging sounds/vibration, storage low-space warning, battery-saver auto-trigger, freeform windows (needs a reboot), default install location. |
| 13 | **Back** | — |

> **⚠️ Volume cap — what it is, and what it isn't.** It lifts the **software**
> cap and the *"raise above safe level?"* nag (the EU hearing-safety rule) by
> writing `global audio_safe_volume_state`. It does **not** raise the hardware
> amplifier ceiling — that lives in vendor gain tables (the engineering menu)
> and needs root. Android reads the key **once at boot** and re-writes it back
> to *active* after every boot on a capped device, so this is a **per-boot**
> switch: set it, reboot, and that session runs uncapped. To re-arm it after
> each reboot without walking the menus, keep a
> [Profile](#settings-tools). On Android 14+ a *sound dose* regime replaces the
> old cap entirely; the screen offers its live levers instead.

> **Dark theme won't budge?** Some ROMs lock night mode, and the uimode service
> then refuses the change **silently**. DCX prints the mode the device reports
> back rather than claiming success — if the readout doesn't move, that's the
> honest answer, not a bug.

---

### Backup & Restore

**Backup** reads every Settings.Global/System key, `device_config` flag and
property DCX neo can toggle — **47 targets**, including every
[Tweaks](#tweaks) key — and writes a **stand-alone restore `.bat`** to
`%USERPROFILE%\dcx_backups\dcx_backup_<timestamp>.bat`:

```bat
@echo off
:: DCX neo Settings Backup created ...
adb shell settings put global window_animation_scale "1.0"
adb shell settings put system min_refresh_rate "60"
adb shell settings delete global angle_gl_driver_all_angle >nul 2>&1
adb shell setprop debug.hwui.renderer "skiagl"
:: prop persist.log.tag was unset at backup time - not restoring
...
pause
```

Captured values are quoted; any key unset at backup time becomes a `delete`
(or, for a property, a comment) — so a restore returns you to the exact prior
state and never pins a property to an empty string. Because it's a normal batch
file you can run it directly without DCX neo, edit out lines you don't want, or
share it to reproduce settings elsewhere. **Restore** lists backups (newest
first), confirms, then applies the chosen one. Both can open the backups folder
in Explorer.

---

### Benchmark

A quick, repeatable micro-benchmark (lower is better): a timed CPU loop, a
~10 MB random write and a ~10 MB sequential read (both via `dd`). Run it before
and after optimising to compare. Uses a portable shell loop, so it works on
devices that lack `seq`.

---

### App Manager

App-level controls (background restriction + debloat), main menu **14**.
**Everything here is reversible.**

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
> - Only remove apps you recognise — removing a critical package can cause a
>   **bootloop**. DCX neo hard-blocks known offenders, including
>   **`com.hoffnung`** (looks like bloat on Transsion Tecno/Infinix/itel
>   phones but bootloops them), plus system UI, phone, settings, telephony
>   providers, and Huawei core services (`com.huawei.hwid`, push, FIDO/`hwasm`,
>   OTA).
> - The **Suggested** lists only ever show packages that are both
>   community-vetted as safe *and* installed, and every removal asks for
>   confirmation. Lists are sourced from UAD-NG and community debloat guides.
> - If something breaks after a debloat, use **Restore** (option 6) or reboot;
>   a factory reset restores everything.

---

### Wireless ADB

Run DCX over Wi-Fi with no cable. Reachable from the main menu (**13**) or from
the startup screen when no USB device is found (**[W]**).

| # | Option | What it does |
|---|---|---|
| 1 | **Pair with code** | Android 11+ one-time pairing: enter the `ip:port` **and 6-digit code** from Developer options → Wireless debugging → *Pair device with pairing code* (keep that dialog open — the code dies when it closes). |
| 2 | **Connect** | Connect to `ip[:port]`. On Android 11+ use the ip:port from the **main** Wireless-debugging screen — it's a **different port** than the pairing one, and changes after a reboot or re-toggle. Plain IP assumes port 5555. |
| 3 | **Enable over USB** | Classic method for any Android version: flips adbd to TCP/IP on port 5555 (`adb tcpip 5555`) while the cable is attached, auto-detects the phone's Wi-Fi IP from `ip route`, and offers to connect immediately. Reverts on reboot or via option 5. |
| 4 | **Disconnect** | Drop all Wi-Fi connections (USB unaffected). |
| 5 | **Back to USB** | `adb usb` for devices switched with option 3. |
| 6 | **Help** | Where to find the ports/code, per-version notes (incl. Huawei EMUI/HarmonyOS builds that hide the pairing dialog — option 3 works there). |

> **Security note:** while Wireless debugging is on, any PC paired with the
> phone on the same network can run adb commands. Turn it off when done.

The old standalone `wirelessadb.bat` is **removed** — this menu replaces it
(that script only did `adb connect`, with no Android 11+ pairing support).
`opencmd.bat` remains if you want to use ADB separately from DCX neo.

---

### Settings Tools

The generic half. These work on **any** key in the settings provider, including
every key DCX has no menu row for — the [Tweaks](#tweaks) list is curated, this
one isn't. Reachable from the main menu (**15**).

| # | Option | What it does |
|---|---|---|
| 1 | **Settings explorer** | `list` / `get` / `put` / `delete` across `system`, `secure` and `global`. Every write echoes the exact command, asks to confirm, shows a read-back, and saves the old value to an undo script first. Keys and values are whitelist-validated — anything with spaces or shell metacharacters is declined toward **Shell** rather than mangled. |
| 2 | **Snapshot & diff** | Dump all three tables to `%USERPROFILE%\dcx_snapshots\`, flip a toggle in the device's own UI, dump again, diff. This tells you **exactly which key that toggle writes** — the fastest way to find OEM-specific settings DCX doesn't know about. |
| 3 | **Profiles** | A plain text file in `%USERPROFILE%\dcx_profiles\`, one key per line: `namespace`\|`key`\|`value`, or `DELETE` as the value to remove a key. Save the current tweak keys, then apply the profile to re-write them all in one pass — this is the answer to the volume cap's per-boot re-arm. Lines starting with `#` are ignored, and every line is re-validated on the way in, so a hand-edited typo is skipped with a reason rather than executed. |
| 4 | **Back** | — |

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
  (Display Scaler). Lowering the render resolution is a genuine, no-root way to
  gain GPU headroom and cut power draw; `wm size reset` / `wm density reset`
  fully revert it.
- **`deviceidle force-idle`, app hibernation, `hotword_detection_enabled`,
  `persist.log.tag "*:S"`** — real battery/log switches.
- **`cmd appops … RUN_IN_BACKGROUND deny`, `pm uninstall -k --user 0`** —
  background restriction and (reversible) debloat (App Manager).
- **`clock_seconds`, `icon_blacklist`, `sysui_qs_tiles`** — real SystemUI
  tunables. SystemUI *observes* these keys, so they apply live with no restart:
  the tile list still reads from `sysui_qs_tiles` on current AOSP, content
  observer and all.
- **`audio_safe_volume_state`** — real, but honestly **per-boot**; Android
  re-arms it at every boot (see [Tweaks](#tweaks)).

> **Not every toggle is effective.** The **Account Sync** switch writes
> `master_sync_status`, which is a **placebo on modern Android** — nothing
> reads it, and the real master-sync state lives in the sync framework
> (`adb shell dumpsys content` → *Auto sync*), unreachable via `settings`
> without root (on Android 17, writing `master_sync_status 0` left *Auto sync:
> true* unchanged). It's kept only so Backup/Restore round-trips the value.

> **Some famous tweaks are dead, and DCX won't ship them as decoration.**
> `policy_control` (the old immersive-mode key) — the framework class that
> implemented it is **gone from AOSP**, so it stores fine and does nothing on
> Android 11+. `sysui_qqs_count` — modern SystemUI no longer reads it.
> Tethering flags sit behind carrier entitlement checks that `settings` can't
> touch. All three would look like features and be placebo, so they aren't in
> the menus. If you want them anyway, **Settings Tools → Explorer** will write
> any key you like — declining a menu row isn't blocking you.

> CPU/GPU frequency and governor changes are **not** possible via `setprop` —
> they live in kernel sysfs and need **root**. Neither is the **speaker
> amplifier ceiling**: the engineering-menu "max volume" sliders edit vendor
> gain tables, root only. DCX neo doesn't pretend otherwise.

---

## Persistence & root

- `settings put` and `device_config put` values (animation scales, refresh
  rate, ANGLE, sync, hotword…) **persist** across reboots without root.
- `setprop`-based changes (e.g. GPU renderer) apply immediately but **reset on
  reboot**; making them permanent needs root (Magisk module or `build.prop`).
- **Android 14+** routes dexopt through **ART Service**; DCX neo detects this
  at startup and adjusts the compile/dexopt commands automatically (details in
  [Optimize Android](#optimize-android)).
- Two keys are **deliberately not permanent**, because Android won't let them
  be: the **volume cap** is re-armed at every boot, and **freeform windows**
  need a reboot to take effect at all. For the first, keep a **Profile**
  ([Settings Tools](#settings-tools) → 3) and apply it after a reboot — that's
  the no-root, no-daemon equivalent of SetEdit's on-device boot queue.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| **"ADB not found"** on launch | Install Platform Tools and add to `PATH`, or put `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **"No authorised device found"** | Enable USB debugging, replug, tap **Allow** on the phone. Check `adb devices` shows `device` (not `unauthorized`). No cable? Press **[W]** for Wireless ADB. |
| **Wireless connect says "failed to authenticate" / "connection refused"** | Pair this PC first (Wireless ADB → option 1), or the port went stale — it changes on reboot/re-toggle, so grab it fresh from the Wireless-debugging screen. |
| **Something feels broken after tweaking** | **Reboot** — most live tweaks reset on reboot and that clears it. |
| **A tweak "didn't do anything"** | Read the value back via **CheckSetting** (graphics: `dumpsys gfxinfo <pkg> \| findstr Pipeline`). Some keys need root or a newer Android. |
| **CheckSetting report or Wake-Lock Audit saved empty / blank** | Fixed — a bare `)` in an echo annotation like `(first 15)` closed the redirected `( … ) > file` block early; annotations are now escaped (same fix covers the background-dexopt failure list). |
| **CheckSetting/Wake-Lock report shows `can't create nul` / `findstr` errors, or a blank section** | Fixed — the `\| findstr` filtering leaked to the Android shell; it now runs Android-side (`adb shell "… 2>/dev/null \| grep …"`). |
| **Box characters / logo turn into `?????` after a report or backup (until relaunch)** | Fixed — the timestamp used `powershell Get-Date`, which reset the console code page; it's now built in pure `cmd` from `%date%`/`%time%`. |
| **First apply in a menu jumps back without pausing (second time is fine)** | Fixed — an `adb shell` forwards stdin, so `pause` ate a keystroke; every `adb shell` before a pause now reads stdin from `nul` (`<nul`). |
| **Clear Caches said "complete" but nothing was wiped** | Fixed — on a non-rooted device `su` did nothing silently; it now probes for root first and says *Root is not available — nothing was wiped*. |
| **Clear Last Used printed a wall of `No shell command implementation`** | Fixed — that `usagestats` subcommand is missing on many builds; the per-package error is now suppressed Android-side. |
| **Most apps crash after enabling ANGLE** | Common on non-Pixel GPUs; **a reboot won't help** (it persists). Gaming → Force ANGLE → **Disable**/**Delete**. |
| **Wi-Fi died after Network Boost** | Gaming → Network Boost → **Revert** (clears any old Wi-Fi keys). |
| **ART Service printed a wall of text** | Not errors — older versions dumped a line per package. Current builds show a summary (optimised/failed) and only real failures; a few failures are normal. |
| **"Unknown option: --compile-layouts" / "Unknown command"** | Expected on Android 12+ (removed; gone on 14+ under ART Service). DCX neo skips it automatically and continues. |
| **Bootloop / something broke after debloat** | Boot to recovery and **factory reset** restores every removed app (they're never deleted from `/system`). To revert a single app, use **App Mgr → Restore**. |
| **Volume cap is back after a reboot** | By design, not a bug — Android re-writes `audio_safe_volume_state` to *active* at boot on a capped device. Re-apply it, or keep a **Profile** (Settings Tools → 3) and apply that after each reboot. |
| **Dark theme won't switch** | Some ROMs lock night mode and the service ignores the request **silently**. The readout on the Night screen is the device's own answer — if it doesn't move, the ROM refused. |
| **A quick-settings tile I added never appeared** | The spec was wrong. SystemUI drops unknown tile specs instead of breaking the panel, so a typo costs you the tile quietly. Use the names listed on the Tile editor screen. |
| **Clock seconds / battery percent did nothing** | Heavily skinned status bars (some OneUI, EMUI) don't read the AOSP keys. The key is set; the skin ignores it. Nothing to fix. |
| **Freeform windows did nothing** | It needs a **reboot** — it's a developer-options key. The screen offers one. |
| **A profile line was skipped when I applied it** | Deliberate. Profiles are hand-editable, so every line is re-validated: a bad namespace, key or value prints `skip - …` and the rest of the profile still runs. |
| **Want to undo everything** | **Restore** a backup, or run the undo script a Tweaks/Explorer write left in `dcx_backups\`, or reboot for non-persistent changes. |
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

