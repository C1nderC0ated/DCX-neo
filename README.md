# DCX neo — Android Optimization Toolkit

<img width="224" height="117" alt="image" src="https://github.com/user-attachments/assets/36b493c2-fd83-4c39-a224-6f3d3a6d60d3" />

DCX neo is a Windows batch (`.bat`) front-end for **ADB**. Instead of typing
dozens of `adb shell` commands by hand, you pick options from a text menu and
DCX neo runs the right performance, battery and diagnostic tweaks for you. It
also covers the SystemUI-Tuner and SetEdit ground without root: status bar,
quick-settings tiles, the volume cap, and a settings explorer with
snapshot/diff, profiles, and live key watch.

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
| **ADB** | On your `PATH`, **or** as `adb.exe` in an `adb\` folder next to `DCX.bat` — DCX adds that folder to `PATH` itself, so it works even on images that disable current-directory executable lookup. |
| **Android device** | **USB debugging** enabled and the PC authorised. |
| **USB cable** | Or Wi-Fi — the built-in **Wireless ADB** menu (option 13) handles pairing/connecting. |

---

## Setup

1. **Install ADB** — download **Android SDK Platform Tools** from Google, then
   add it to your `PATH`, or drop `adb.exe` (and its DLLs) into an `adb\`
   folder next to `DCX.bat` (the Release already contains one; DCX `cd`s into it automatically).
2. **Enable USB debugging** — Settings → About phone → tap **Build number**
   ×7 → Developer options → **USB debugging**. Connect and tap **Allow** on the RSA prompt.
3. **Run** `DCX.bat` (double-click or from `cmd`).

---

## First run

On startup DCX neo sets up ANSI colours, verifies ADB, and waits up to 10 s for
an authorised device. If more than one is attached it asks which to target; if
none appears you can jump straight to **[W] Wireless ADB setup** or **[R]etry**
instead of exiting. It then prints your device model and Android API level, e.g.
`Device: Pixel 7   API level: 34`, and opens the main menu. The Main, Gaming,
Battery and Optimize screens show a live header with **uptime** and **CPU load**.
The model is shown exactly as the phone reports it, `!`, `%` and a leading `;`
included. If the phone answers with an API level that is not a number, DCX
treats it as unknown (`0`), the same as no answer.

> Earlier builds got as far as the device line and then **closed instead of
> opening the menu** — see [Troubleshooting](#troubleshooting) if you're on an older copy.

---

## Menu reference

### Main menu

| # | Option | What it does |
|---|---|---|
| 1 | **Gaming** | GMS (full or safe subset), GPU renderer, ANGLE, display scaler, TCP/DNS, Game Mode, game performance monitor… |
| 2 | **Battery** | Two pages of battery / background toggles + diagnostics. |
| 3 | **Optimize Android** | One-shot maintenance (dexopt, fstrim, cache, compile…). |
| 4 | **Auto** | Applies a batch of safe optimisations in one go. |
| 5 | **CheckSetting** | Full device diagnostic report. |
| 6 | **Tweaks** | Status bar, quick-settings tiles, volume cap, font scale, night modes, DeviceConfig sync and more — the SystemUI-Tuner-style toggles. |
| 7 | **Reboot** | Reboots the device — asks for confirmation first. |
| 8 | **Exit** | Closes DCX neo. The adb server is left running: it is shared with Android Studio, scrcpy and any other terminal, and killing it would drop their sessions and every Wi-Fi connection along with them. Exit also removes this window's scratch folder, `%TEMP%\dcx_<number>`. |
| 9 | **Shell** | Interactive `adb shell`. |
| 10 | **Benchmark** | Quick CPU + storage micro-benchmark. The write is flushed to storage and the read bypasses the cache, so the storage numbers are storage, not RAM. |
| 11 / 12 | **Backup / Restore** | Save / re-apply toggleable settings. |
| 13 | **Wireless ADB** | Pair (Android 11+), connect by IP, enable via USB (`adb tcpip`) with auto-IP, disconnect. |
| 14 | **App Mgr** | Background restriction + debloat (remove/restore apps). |
| 15 | **Settings Tools** | Explorer, snapshot & diff, profiles, watch a key — these work on *any* settings key, not just the curated ones. |

---

### Gaming

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle GMS** | Full disable/enable of Google Mobile Services (warns + confirms — disabling breaks push, Maps, sign-in, Pay…). Does **not** change Do Not Disturb / `zen_mode`. Also offers a **safe subset**: disable ads/telemetry-adjacent packages only (`adservices`, `as.oss`, mainline telemetry, federatedcompute, partnersetup, feedback, turbo) while keeping Play Services running. Reversible. |
| 2 | **Thermal override (temporary)** | `cmd thermalservice override-status` (0–6). This does **not** relax throttling: it makes the framework *report* the status you pick and stop reporting the real one, so even `0 = NONE` is a lock rather than "throttling off". Option **7** clears the override and hands the reporting back to the device; a reboot clears it too. Validated input. |
| 3 | **Toggle Package Verifier** | Play Protect package verification on/off. |
| 4 | **Game Mode (FPS cap / render scale)** | One game gets its own FPS cap and render scale; the rest of the phone keeps its resolution and DPI. **Set**, **Show** and **Reset** per game (games only on Android 13+). Android 14+ uses `cmd game set` (custom Game Mode, kept across reboots), 13 a `game_overlay` entry plus Performance mode, 12 `cmd game downscale` (render scale only). Every write is read back. Replaces *Toggle Game-Overlay*. [Details](#game-mode). |
| 5 | **Performance props (debug/OEM dump)** | Large dump of debug/OEM `setprop`s — volatile and mixed; not a guaranteed FPS mode. The lasting parts are more than they look: besides `low_power` off, **On** writes ten persistent keys including `activity_manager_constants`, `device_idle_constants` and six `device_config` flags, and **pins the thermal status at NONE** — only **Off** runs `thermalservice reset`. `activity_manager_constants` is captured to the session undo file before it is replaced. No longer switches off SQLite durability, and the two vsync-disabling props are gone as well — [neither trade is worth making](#what-actually-works-vs-placebo). |
| 6 | **TCP / DNS / network mode** | TCP receive-window hint, **Private DNS** (Cloudflare / Google / AdGuard / Quad9 / your own DoT hostname / back to automatic), preferred network mode (LTE/5G), full revert. ⚠️ see below. |
| 7 | **GPU Renderer** | Switch the per-app HWUI renderer: `skiagl` (default) / `skiavk` (Skia Vulkan) / clear. Each write is read back. SurfaceFlinger's own `debug.renderengine.backend` is no longer set: SurfaceFlinger reads it once, when it starts, so without root it could not change before a reboot cleared it. **Clear** still empties both. |
| 8 | **Force ANGLE for All Apps** | Route all GLES apps through ANGLE. ⚠️ see below. |
| 9 | **Display Scaler** | Lower render resolution + matching DPI (`wm size` / `wm density`) for more GPU headroom and lower power. Safe presets are computed live from the panel's native resolution (85 / 75 / 67 / 50 %), plus custom and one-tap reset. A custom width, height or density under half or over double the panel's own is shown as a percentage of it and needs a second yes — a typo guard (4800 for 480) inside the absolute limits. A separate **UI size (DPI-only)** mode changes element size without touching the resolution — a stand-in for the **Smallest width** developer option that some OEMs (e.g. Huawei EMUI/HarmonyOS) disable. Its percentages are relative to the resolution you are actually on: if a resolution override is active (say the 50 % preset), the 100 % baseline is scaled to match it, so "100 % UI" means the same size on screen instead of doubling it. Reversible, no root, persists across reboot; **included in Backup/Restore** (override or `wm size`/`wm density` reset). |
| 10 | **Game performance monitor** | A game's real frame rate and frame pacing from SurfaceFlinger's own frame statistics, with a thermal row about every 5 s. Also works for SurfaceView games, where `gfxinfo` shows nothing. Android 10+. See [Game performance monitor](#game-performance-monitor). |
| 11 | **Back** | — |

> **⚠️ Two of these are device-dependent (from real-world testing):**
> - **TCP / DNS / network mode** applies only a harmless TCP receive-window hint
>   by default (plus optional DNS / preferred-network). Earlier versions also
>   wrote deprecated Wi-Fi keys (`wifi_sleep_policy`, `wifi_idle_ms`…) that
>   **killed Wi-Fi on Android 15** — only **Revert** recovered it, not a reboot.
>   Those are gone; Revert still clears any leftovers from an old run.
> - **Force ANGLE** can **crash most apps on launch** on non-Pixel GPUs (e.g.
>   MediaTek). It's opt-in (Y/N) and **persists across reboots**, so a reboot
>   won't fix a crash loop — return here and **Disable**/**Delete**.

**GPU Renderer**, **ANGLE** and the **Display Scaler** are the genuinely
effective graphics switches. Verify a renderer change with
`adb shell dumpsys gfxinfo <package> | findstr Pipeline`, and a resolution
change with `adb shell wm size` / `adb shell wm density`. To see whether a change actually helped, play the same stretch of the game before and after it with **Game performance monitor** (option 10) and compare the two history lines.

#### Game Mode

Gaming → **4** gives one game its own frame-rate cap and render scale. A 60 fps cap on a 120 Hz phone is the most reliable no-root way to cut heat and stutter in long sessions, and a lower render scale gives the GPU fewer pixels to draw. The rest of the phone keeps its resolution and DPI (the **Display Scaler** changes the whole screen).

- **Games only (13+).** Android applies Game Mode only to apps that declare `android:appCategory="game"`. DCX checks this first and changes nothing for any other app: on 14+ through `cmd game list-modes` (`current mode: unsupported`, or the phone's own refusal from Android 15 QPR1 on), on 13 through `dumpsys game`, which lists games only. Android 12's render scale works for any app.
- **FPS cap** (13+): 30, 40, 45, 60, 90, 120 or none. SurfaceFlinger holds a cap by skipping whole refreshes, so it works only while the screen runs at 2×, 3× … of it: 60 or 40 at 120 Hz, not 45. DCX lists only the caps that one of the panel's refresh rates (from `dumpsys display`) is such a multiple of; if that read fails, it lists all six. The cap applies at once.
- **Render scale:** 100 / 90 / 80 / 70 / 60 / 50 %. It applies the next time the game starts, so DCX offers to close the game (Y/N; unsaved progress is lost) once Android has confirmed the change. Android 12 closes it by itself.

| Android | What DCX runs | How it is read back |
|---|---|---|
| 14+ (API 34+) | `cmd game set --downscale <s> [--fps <n>] <pkg>`, which selects custom Game Mode. "No cap" leaves `--fps` out: Android 14 rejects `disable`, and before its QPR1 update `0` as well | `cmd game list-modes` must say `current mode: custom`, and `cmd game list-configs` must show the scale and cap in the custom (mode 4) entry |
| 13 | `device_config put game_overlay <pkg> mode=2,downscaleFactor=<s>,fps=<n>,dcx=1`, then `cmd game mode 2 <pkg>` | the entry is read back, and `cmd game list` must show both values under mode 2 |
| 12 | `cmd game downscale <s> <pkg>` (no FPS cap before 13) | `dumpsys platform_compat` must list the game's `DOWNSCALED` and `DOWNSCALE_<n>` overrides |

What it cannot promise:
- **Not proven on screen.** A green result means "set and reported by Android". OEM game tools may override it; watch the frame rate to be sure.
- **Android 13:** a game can opt out (`allowGameDownscaling` / `allowGameFpsOverride = false`), and the first 13 release (fixed in QPR1) drops the FPS cap of any app that carries manifest meta-data. The read-back catches both and says so. On 14+ Android applies a shell override even to a game that opted out. DCX's entry replaces any entry Google shipped for that game, and Google Play services may put its own back at the next sync (**Tweaks → DeviceConfig server sync** can freeze that). 13's own `cmd game set` is not used: it refuses unless the game already has a Performance mode, and it forgets everything at reboot.
- **Reset** goes back to Standard: `cmd game reset` + `cmd game mode standard` on 14+, read back as `current mode: standard`; `cmd game mode 1` + `cmd game reset` on 13; `cmd game downscale disable` on 12, read back in `dumpsys platform_compat`. On 12–13 it deletes a `game_overlay` entry only if DCX wrote it (the `dcx=1` tag, or the `mode=1` the old Low/Medium options left) and reads it back as `null`; an entry Google shipped is left alone.
- Game Mode is not in Backup or in the session undo file. **Reset** is its undo.

#### Game performance monitor

Gaming → **10**. Open the game on the phone, keep the screen on and pick **1**. Press Enter to measure the app in the foreground, or type a package. Then press **Y** and play normally. **Q** stops the run and shows the report. **R** clears a thermal status override mid-run.

**While it runs**, one row about every 5 s:

| Column | What it is |
|---|---|
| status | `Thermal Status` from `dumpsys thermalservice`: NONE, LIGHT, MODERATE, SEVERE, CRITICAL, EMERGENCY. A `*` means `IsStatusOverride: true`: the status is pinned, so the row shows the pin, not the phone's real throttling. Gaming → **Thermal override** and **Performance props On** pin it. Thermal override option 7, **Performance props Off**, this screen's option 2 or **R**, or a reboot clear it. |
| CPU / GPU / skin | Hottest sensor of each kind in the thermal HAL's current temperatures, in °C. If the HAL reports none, the hottest of the kernel's thermal zones (`/sys/class/thermal`), sorted by their names. `-` = the phone reports none. |
| batt | Battery temperature from `dumpsys battery`. |
| cool c/g/on | Highest CPU and GPU cooling (throttle) level, and how many cooling devices are above level 0. |
| headroom | Android 15+: `cmd thermalservice headroom 10`, the forecast 10 s ahead. 100 % is the SEVERE throttling threshold. |

**The report** comes from `dumpsys SurfaceFlinger --timestats -dump`. DCX takes the game's busiest layer, matched by the app's uid on Android 12+ and by `<package>/` in the layer name on 10/11. It adds up all of that layer's entries, one per refresh rate and game mode, and shows:
- Average frame rate: 1000 / the mean time between two frames reaching the screen, over the whole run. This is SurfaceFlinger's own formula. It counts frame times in whole ms, so a steady 60 fps shows about 62 and a steady 120 about 125.
- Frames of 18 ms or more and of 35 ms or more: the share slower than a 60 fps or a 30 fps frame. These are TimeStats' own histogram buckets.
- Dropped frames, and on Android 12+ janky frames (FrameTimeline's own verdict).
- The refresh rate(s) in SurfaceFlinger's 30 Hz steps (a 144 Hz panel shows as 150), the game mode, and how much of the run the layer's frames cover.
- Peak temperatures, the worst thermal status and when throttling was first reported. The status shows as "not known" if the phone never reported one that was not pinned.

Each run adds one line to `%USERPROFILE%\dcx_perf\<serial>_<package>.txt`: date, fps, 18 ms+ and 35 ms+ shares, refresh rate, worst status, peak CPU/skin temperature and run length. The report lists the last five runs.

**What it changes on the phone.** Only SurfaceFlinger's frame-statistics collector.
- On many Android 11+ phones the collector already runs for Android's usage statistics. Starting a run resets it, so the phone loses the frame counts it has not reported yet. DCX asks before doing that and leaves the collector running afterwards.
- If the collector was off, DCX turns it on for the run, turns it off again and reads that back.
- If the statistics hold data but did not move during the check, the phone's screen was probably off. DCX says so: turn the screen on and start again, so that DCX never turns off statistics the phone itself is collecting.
- Before turning the collector on, DCX sets a `debug.dcx.perfmon` marker and reads it back. If the marker cannot be set, the run does not start. If you close DCX mid-run, the next visit to this screen turns the collector off and clears the marker. A reboot clears both.

**Limits.**
- Menus, loading screens and pauses count as slow frames, so measure during play.
- An app that hardly draws gives no meaningful frame rate. With fewer than 60 frames, or frames over less than a fifth of the run, the report says so instead of showing a green number. Apps like Discord draw only when something changes.
- If the phone's thermal HAL is not ready (`HAL Ready: false`), CPU, GPU and skin come from the kernel's thermal zones instead. A zone counts by its name: `cpu`, `gpu` or `g3d`, and `skin`, `shell`, `xo-therm` or `quiet` for the skin. A zone above 150 °C is a broken sensor and is skipped. Without such zones only the battery temperature can be shown. The screen says which, once.
- Android 10 records only packages starting with `com.` or `co.`.
- The phone's own statistics upload can reset the counters mid-run. The report warns when it can tell; "Frames cover" shows how much of the run was measured.
- Sensors the phone does not report are shown as `-`.

---

### Battery

Two pages.

**Page 1**

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle Power Saver** | `low_power` / `low_power_sticky` — real battery saver. |
| 2 | **Toggle Animation** | Animation scales + related accessibility/blur flags. Off also pins long-press timeouts (see Tweaks). |
| 3 | **Wi-Fi/BT scan and related** | `wifi_scan_always_enabled`, `ble_scan_always_enabled` (the key Android actually reads for "Bluetooth scanning" — earlier versions wrote `bluetooth_scan_always_enabled`, which is not an AOSP key and did nothing), scoring/netstats — not an OEM “auto Wi-Fi” switch. |
| 4 | **Toggle Sync (placebo key)** | Writes `master_sync_status` only — placebo on modern Android; kept for Backup round-trip. |
| 5 | **Samsung motion (OEM)** | OneUI motion-gesture keys. Placebo on non-Samsung devices. |
| 6 | **ZRAM preference (reboot)** | `zram_enabled` StorageManager preference; needs reboot; may no-op if the OEM has no zram toggle. |
| 7 | **Aggressive saver constants** | Not OEM “Extreme power saving” — tweaks `battery_saver_constants`, power mode, related flags. |
| 8 | **Toggle Send Error** | Crash/diagnostic reporting keys (`send_action_app_error` + OEM extras). |
| 9 | **ART lock profiling (dev)** | `device_config … disable_lock_profiling` — developer/debug only, not battery/FPS. |
| 10 | **Toggle Logs/etc** | Broad log/metric silencing. **On** is a real revert, not a second pass of Off: it runs `cmd dropbox restore-defaults` (which re-reads the low-priority tag list and rate limit from framework resources) rather than re-applying the low-priority list, and it deletes the device_config flags it changed instead of writing a guessed value back. Does **not** freeze DeviceConfig server sync (that lives under Tweaks), no longer switches off SQLite durability ([why](#what-actually-works-vs-placebo)), and no longer deletes your `gpu_debug_layers` value. **On** now reverts everything **Off** sets, including `persist.*` props that survive reboot. |
| 11 | **Next Page** | — |
| 12 | **Back** | — |

**Page 2:**

| # | Option | What it does |
|---|---|---|
| 1 | **Toggle Log (For User Apps)** | Silence logging for third-party apps. |
| 2 | **Universal Toggle Logs/etc** | Sets/clears every `log.tag*` prop (`S` = Off; On clears them). |
| 3 | **Toggle Deviceidle Whitelist** | Bulk-remove apps from the Doze whitelist, or reset it. There is no add-one / remove-one entry here; system-app removal is guarded with a protected list. A line from the phone that is not a plain package name (letters, digits, `.` and `_`) is left alone, and the count is shown. |
| 4 | **Hibernate App** | Hibernate a specific package. **Android 14+ (API 34+) only** — earlier APIs are refused in-menu. |
| 5 | **Refresh Rate Lock** | Lock 60/90/120 Hz, adaptive (1–120), or restore. |
| 6 | **Force Doze Now** | Force deep idle now; unforce; or show state. |
| 7 | **App Hibernation (system-wide)** | Enable/disable Android 12+ system-wide hibernation. |
| 8 | **Account Sync Toggle** | Writes `master_sync_status` only — **placebo on modern Android** (UI says so). Real Auto sync is not rootless-writable; kept for Backup/Restore round-trip. See [What works vs placebo](#what-actually-works-vs-placebo). |
| 9 | **Voice Hotword Toggle** | Disable the always-on "Hey Google" pipeline. |
| A | **Drain leaderboard + Wake-Lock Audit** | Which apps used the battery in the background since the last charge, ranked, with one key to open an app in App check. The raw Wake-Lock Audit report is its **W** (below). Android 12+, read-only. |
| B | **Toggle Finish Activities** | toggles `always_finish_activities` via ADB (many Android builds report the value correctly but only fully honor it when enabled through Developer Options). |
| C | **Per-app battery restrict** | One screen for a package: show inactive / standby-bucket / hibernation, then Light / Medium / Heavy / Unrestrict. Lighter than **Hibernate App** (no appops flood). Heavy needs API 34+. |
| D | **App check** | One app, one screen: everything in Android's own settings that can hold its notifications back, each with a verdict — force-stopped or never opened, paused, disabled, notification permission (13+), hibernated (12+), battery mode, standby bucket and idle, restriction level (14+). Then Android's own Restricted / Optimized / Unrestricted modes and a way back to the default. See [App check](#app-check). |
| 0 | **Back** | — |

**Drain leaderboard** (Android 12+, read-only: it changes nothing on the phone) ranks up to 15 apps by the phone's own battery estimate, in mAh, since the phone last reset its battery stats. That is normally the last full charge.

| Column | Meaning | Read from |
|---|---|---|
| **Bg** | Use while the app was not in the foreground: background, foreground services and cached. The list is ranked by it. | `dumpsys batterystats --usage` (Android 14+; the phone syncs its counters first, a few seconds), or the same lines of `--charged` (Android 12-13) |
| **Fg** | Use while on screen, or while the system kept it in the foreground (a keyboard, for example) | same |
| **Wake** | Alarm wake-ups **since boot**, not since the charge | `dumpsys alarm` (Alarm Stats) |
| **Now** | Holds a partial wake lock right now. Disabled locks are not counted. | `dumpsys power` |
| **Bucket** | App standby bucket: active, working, frequent, rare, restrict(ed), never, exempt | `am get-standby-bucket --user 0` |
| **Doze** | On the Doze exemption list: `user` (allowed in Battery optimisation) or `system` | `cmd deviceidle whitelist` |

- Some phones do not split use into foreground and background: all Android 12 phones, and phones whose kernel does not track CPU time per process state. There the list is ranked by **Total**, and the screen says so.
- The app figures are the phone's power model, not a measurement. Above the list DCX shows what the battery gauge measured since the reset (`actual drain` in the dump; when that is 0 or missing, the phone's computed total). When the apps' estimates alone add up to more than that by a quarter, the board says the power model over-counts: compare the apps with each other, not with the battery.
- While **Toggle Logs Off** (page 1) is in effect, the phone stops reading per-app CPU time (`track_cpu_active_cluster_time=false`), so the CPU part of every estimate is under-counted. The board warns about it. **Toggle Logs On** restores it from then on.
- `?` means that query did not answer. The screen names which one and suggests **R**. If the battery stats themselves cannot be read, the screen says why (adb exit code, Android version not read, or no scratch folder).
- Only apps of the main user are listed; work-profile apps are not. Apps that share a UID, such as Play services and its companions, are one row ("+N shared"). Those rows and Play services itself cannot be opened from here; **D** still shows their details. If the app names were not read, nothing can be opened until **R**.
- 100000 mAh or more, and more than 99999 wake-ups, show as `100k+`.
- Keys:
  - **1-15** (gold numbers) opens that app in App check and comes back here.
  - **D**<n> saves `dumpsys batterystats --charged <package>` to DCX's scratch folder and opens it in Notepad. The file is removed when you leave the board with **0**, or when DCX exits.
  - **R** reads the phone again. Coming back from App check or the raw report shows the board as it was read; press **R** to see a change you made.
  - **W** opens the raw report.
  - **0** goes back.
- Right after a full charge the list is empty or short, because the phone restarts the stats then.
- Every line from the phone is checked before use. A line with any character other than letters, digits, spaces and `. _ : , -`, or a row whose numbers are not in the expected shape, is left out, and the count is shown.

**Wake-Lock Audit** (**W** on the leaderboard) collects the key battery dumps into one `%TEMP%` report: held wake locks (`dumpsys power`), top holders since charge (`batterystats`), Doze state (`deviceidle`), top wakeups (`alarm`) and CPU consumers (`cpuinfo`). It then opens the report in Notepad, pages it, or summarises it, with a guide for spotting the app draining your battery. The five dumps take about 5 s, with progress shown. **0**, **Q** or **4** go back to the leaderboard.

#### App check

Battery → page 2 → **D**. Type a package name. (App Manager's **Restrict** and **Allow** also end on this screen, to show the result.) One screen shows what in Android's own settings can hold that app's notifications back:

| Line | Read with | Android |
|---|---|---|
| Force-stopped / never opened, paused, disabled | the user-0 line of `dumpsys package` (`stopped=`, `notLaunched=`, `suspended=`, `enabled=`) | 9+ |
| Notification permission | `POST_NOTIFICATIONS: granted=` in the same dump | 13+ |
| Hibernated | `cmd app_hibernation get-state` | 12+ |
| Battery mode | `cmd appops get … RUN_ANY_IN_BACKGROUND` and `cmd deviceidle whitelist` | 9+ |
| Standby bucket, idle | `am get-standby-bucket`, `am get-inactive` | 9+ |
| Android's own restriction level | `cmd activity get-bg-restriction-level` | 14+ |

Each line is **BLOCKS** (nothing arrives until it is fixed), **DELAYS** (things arrive late), **OK** or **i**, and the screen ends with a total. Lines that could not be read are counted in that total, so a gap never reads as all clear.

| Key | Mode | `RUN_ANY_IN_BACKGROUND` | Doze allowlist |
|---|---|---|---|
| 1 | Restricted | `ignore` | off |
| 2 | Optimized, Android's default | `allow` | off |
| 3 | Unrestricted | `allow` | on |

This is the mapping Settings itself uses. The legacy `RUN_IN_BACKGROUND` is set to match, because apps built for Android 7 and older obey only that op. **Unrestricted** asks first and says who needs it: apps that fetch their own messages, alarms, VPNs, trackers. It also puts the app in the *exempted* standby bucket. Taking an app **off** the allowlist asks first too. Apps on the phone's built-in allowlist are left alone for all three keys, since Android exempts them and Settings greys them out. Before each change, both background app-ops and the allowlist entry go into the session undo file (Tweaks → **14**). Every write is read back, and the screen ends in **[OK]** or **[WARN]**. On Android 9–11 Settings shows these as *Background restriction* plus *Battery optimization*.

**[4] Back to Android's default** only touches what differs from the default:
- the app-op goes back to `allow`;
- hibernation is switched off;
- on 14+, the restriction level goes back to `adaptive_bucket` if a tool left it elsewhere;
- a rare-or-lower standby bucket, or the inactive flag, is lifted with `am set-inactive <pkg> false`. That is a nudge, not a pin: Android re-rates the app from its real use or its predicted bucket at the next idle check, within about three hours. Using the app, or **Unrestricted**, is the lasting fix.

The Doze allowlist stays as it is. The app-op change goes into the session undo file; hibernation, idle and the restriction level are not recorded.

**[5] Check again** reads everything once more. **[6] Clear the force-stop** appears only when the app is stopped, and Back is then **7** instead of **6**. On Android 15+ it runs `pm unstop` and nothing opens on the phone. Android 14 and older have no `pm unstop`, but opening the app once clears a force-stop, so after **Y** DCX opens it once (`monkey … LAUNCHER`). Either way the stopped state is read back.

Limits:
- Android 9 or newer, user 0 only.
- A phone maker's own battery manager (MIUI, EMUI, One UI …) is invisible to it, and the screen says so.
- A uid-level app-op override is shown, not cleared.
- Nothing the phone prints is parsed by cmd. Answers go to files in this window's scratch folder and are only matched against fixed words.

---

### Optimize Android

| # | Option | What it does |
|---|---|---|
| 1 | **Run bg-dexopt-job** | Trigger the background dexopt job. |
| 2 | **Run Fstrim** | Trim the filesystem. Runs **silently** (no output on success is normal); shows free space before/after. On some devices it only completes while charging + idle. |
| 3 | **Run Kill-all** | Force-stop third-party apps. First it asks the phone what has to keep running and skips it: the foreground app, the keyboard, the launcher, accessibility services, the default dialer and SMS app (where this Android can say), and four always-protected packages. Then it lists every app as **Stop** or **Skip** with the reason, warns that a force-stopped app gets no notifications or alarms until you open it, and does nothing without **Y** (Ctrl+C = No). Each stop is counted. |
| 4 | **Run Compile App** | Compile a single package — pick a mode (`speed` / `speed-profile` / `verify` / `quicken` / `everything` / `everything-profile`) and name; both are validated and the package must be installed. |
| 5 | **Run Clear Cache** | Trim or wipe app caches (wipe needs root). |
| 6 | **SurfaceFlinger offsets (retired)** | The Hz profiles are gone — they could not take effect (below). **Remove** clears values an older DCX set. |
| 7 | **Run Clear Last Used** | Reset app usage timestamps. Needs Android 13 (API 33) or newer — below that the per-app command does not exist and the screen says so up front instead of printing a page of ticks. It no longer runs `blob_store clear-all-blobs`, which deleted every app's shared BlobStore data and had nothing to do with usage stats. |
| 8 | **Compile All Apps** | Recompile **every** app (modes below). |
| 9 | **Animation Speed** | Set all three animation scales (0 / 0.5 / 0.75 / 1.0 / custom). Custom input is validated to the documented 0–2 range (comma decimals like `1,5` accepted). |
| 0 | **Back** | — |

**Compile All Apps — modes:** `everything-profile` (**recommended** — heavy
but profile-aware), `everything` (heaviest standard), `speed` (hot methods
only), `speed-profile` (Android default), and **heaviest optimization** (full
all-method compile + layouts + dexopt; uses the most storage/time). Compiling
all apps can take **5–30+ min** and warms the device — keep it on a charger.

**SurfaceFlinger offsets — retired.** The 60/90/120/144 Hz profiles wrote
`debug.sf.*` phase offsets and durations, and each screen said *Done*. They could
not take effect on a phone without root. SurfaceFlinger reads those properties
once, when it starts (AOSP `VsyncConfiguration.cpp`). The shell user cannot
restart SurfaceFlinger: `ctl.restart` is not among the properties shell may set
(`system/sepolicy` `shell.te`). The reboot that does restart it clears every
`debug.*` property first. The screen now says so, and **Remove** still clears
values an older DCX set this boot, reporting each one. To pin the refresh rate,
use Battery → Refresh Rate Lock.

> **Dexopt/compile are version-aware** (no choice needed). On **API ≤ 33** DCX
> neo uses the classic `pm compile` / `pm bg-dexopt-job` path. On **API ≥ 34**
> dexopt is ART Service, so it uses `pm compile -m <mode> -f -a` (dropping
> removed flags like `--check-prof` / `--compile-layouts`) and prefers
> `pm art dexopt-packages -r bg-dexopt`, falling back to `pm bg-dexopt-job`
> where a build doesn't expose `pm art`.

---

### Auto Setup

Runs a curated batch in one pass: logging cleanup (WindowManager trace
channels, dropbox rate limits), dexopt, `fstrim`, `am kill-all`, the
phantom-process flag, `binder_calls_stats`, autofill logging off, `logcat -c`.
Fastest way to a sensible baseline. It no longer writes SurfaceFlinger phase
offsets — they could not take effect (see Optimize) — so it also no longer stops
at step one when the refresh rate cannot be read.

Two things it used to do and no longer does. It **no longer pins the thermal
status** at LIGHT: an override stops the phone reporting real heat until
something clears it, which is a poor trade for a benefit nobody can point at
(the Thermal screen still offers overrides deliberately, and can now clear
them). And it no longer sets `persist.log.tag '*:S'` — liblog reads only the
first character of that property as a level letter and `*` is not one, so the
value was ignored and nothing was ever silenced. A bare `S` does work, but it
hides crash logs too, so it is a decision to take rather than something to
apply behind your back.

> Auto Setup deliberately does **not** enable ANGLE (earlier versions did on
> Android 12+, which crashed apps on some non-Pixel devices). ANGLE is opt-in
> only (Gaming → Force ANGLE), so Auto stays safe for every device.

---

### CheckSetting (diagnostics)

Generates a timestamped report at `%TEMP%\dcx_report_<timestamp>.txt` (never
overwritten, so you can compare before/after). It covers hardware (SoC, ABI,
model), software (version, patch, build), memory in MB, storage, live state (uptime,
CPU, battery level in %, temperature in °C, voltage in mV, status and health by name), display, **current values of the
tweaks DCX neo can change** (including `master_sync_status` labelled as placebo
and DeviceConfig `sync_disabled_for_tests`), network mode, the first 20 Doze
whitelist entries and the first 40 lines of `dumpsys meminfo --oom`. Properties
that are not set are listed as `(not set)` rather than dropped from the report,
so "no line" always means "not covered", never "not set". Open it in Notepad, paginate with `MORE`, show an inline
summary (available RAM in GB, battery level and temperature), or **Diff vs previous report** (the lines only in the older and only in the newer CheckSetting run
**of the same phone**). The last report is remembered per phone, by its adb serial,
in `%TEMP%\dcx_last_report_path_<serial>.txt`, so Diff never compares two different
phones. Over Wi-Fi the serial is usually `ip:port`, and Android 11+ picks a new port
when wireless debugging restarts, so a report taken before that is not offered for Diff. The diff
is saved next to the new report as `dcx_report_<timestamp>_diff.txt`. Generation is ~50 device
queries (≈8 s) and prints step-by-step progress; the window can't take input
until it finishes. On the report menu, **0** or **Q** also work as Back.

---

### Tweaks

SystemUI Tuner and SetEdit territory, with no root and no companion app — the
`adb shell` user already holds `WRITE_SECURE_SETTINGS`, which is exactly the
permission those apps ask you to grant them.

**Every write here is undo-protected**: the value is captured to
`%USERPROFILE%\dcx_backups\dcx_explorer_undo_<timestamp>.bat` before anything
changes, and all of these keys are also covered by [Backup](#backup--restore).
What it records is the value from before your **first** change to that key this
session, not your most recent one — so changing font scale 1.0 → 1.15 → 1.30 and
then running the undo puts back 1.0. (It used to append a capture per write and
replay them in order, which landed you on the middle value.) The dark-theme
switch is included: it writes `secure ui_night_mode` through the uimode service,
and that is captured like everything else.
The Tweaks menu shows the session/last undo and last backup paths; **[14] Undo /
backups hub** opens them in Notepad, runs undo/restore (DCX stays open), or opens the backups folder.

| # | Option | What it does |
|---|---|---|
| 1 | **Clock — show seconds** | `secure clock_seconds`. Applies live — SystemUI watches the key. Heavily skinned clocks (some OneUI) ignore it. |
| 2 | **Battery percent** | `system status_bar_show_battery_percent`. Live on AOSP-based status bars. |
| 3 | **Icon blacklist** | `secure icon_blacklist` — hide status bar icons (rotate, alarm, bluetooth, DND, VPN…). 15-slot picker plus free text; icons that answer to two names write both. Re-hiding an icon can't pile up duplicates. If the list on the phone holds a `!`, `^`, `*`, `?`, `;`, `=`, a space or a double quote, DCX shows it but will not rewrite it, because the list it wrote back would not be the one it read. **Clear** still works. |
| 4 | **Demo mode** | Freezes the status bar into a clean fixed state — full signal, no clutter, 12:00 — for screenshots. Purely cosmetic; ends on exit or reboot. |
| 5 | **QS tile editor** | `secure sysui_qs_tiles`. Add the tiles Android ships but doesn't show: `dream`, `font_scaling`, `qr_code_scanner`, `onehanded`, `reverse`, `hearing_devices`, `notes`, `reduce_brightness`… Add at the end or the front, remove, reset. Applies live. Existing OEM `custom(pkg/cls)` tiles are preserved (paren-aware split); typing a new `custom(...)` spec is still declined toward Shell. A list holding a `!` or a double quote is shown but not rewritten; **Reset** still works. |
| 6 | **Volume cap** | The **software** safe-media-volume cap. ⚠️ see below. |
| 7 | **Heads-up notifications** | `global heads_up_notifications_enabled` — pop-ups on/off for every app at once. Deleting the key is **not** a reset to how the phone shipped: SystemUI reads it with a default of *off*, so deleting it is the same as choosing off. Phones ship with the key already written to 1. |
| 8 | **Font scale** | `system font_scale`, clamped 0.5–2.0 (outside that, layouts clip and dialogs lose buttons). Comma decimals accepted: `1,15` → `1.15`. |
| 9 | **Long-press timeout** | `secure long_press_timeout`. ⚠️ Battery → Animation → **Off** also pins this key to 250 and **On** deletes it — whichever you run last wins. |
| 10 | **Stay awake while charging** | `global stay_on_while_plugged_in`, a bitmask: AC=1, USB=2, wireless=4, dock=8 (add them; 0 = off). Deleting the key gives **AC only**, not off — PowerManagerService reads it with a default of `BATTERY_PLUGGED_AC`. Rough on an OLED panel over time. |
| 11 | **Night** | Two different features share the name: **dark theme** (`cmd uimode night`) and **night light**, the warm blue-light filter (`night_display_*`). Both live here, labelled apart. |
| 12 | **More device tweaks** | Camera gestures (double-tap power, twist to flip), charging sounds/vibration, storage low-space warning, battery-saver auto-trigger, freeform windows (needs a reboot), default install location. |
| 13 | **DeviceConfig server sync** | `device_config set_sync_disabled_for_tests` — freezes **remote DeviceConfig flag updates**, not Google/account sync. Modes: `none` (default), `until_reboot`, `persistent` (survives reboot; confirm). Previously a silent side effect of Battery → Logs Off. Some builds (EMUI 14 among them) implement the setter but **not** the readback; DCX says so rather than displaying a mode it never read, and Backup skips the key instead of guessing. |
| 14 | **Undo / backups hub** | Open or run the session/last undo `.bat` (DCX stays open), open the backups folder, or open the last Backup file. Paths are shown on the Tweaks menu itself. |
| 15 | **Back** | — |

> **⚠️ Volume cap — what it is, and what it isn't.** It lifts the **software**
> cap and the *"raise above safe level?"* nag (the EU hearing-safety rule) by
> writing `global audio_safe_volume_state`. It does **not** raise the hardware
> amplifier ceiling — that lives in vendor gain tables (the engineering menu)
> and needs root. Android reads the key **once at boot** and re-writes it back
> to *active* after every boot on a capped device, so this is a **per-boot**
> switch: set it, reboot, and that session runs uncapped. To re-arm it after
> each reboot without walking the menus, arm a
> [Profile](#profiles) for re-apply after reboot. On Android 14+ a *sound dose* regime replaces the
> old cap entirely; the screen offers its live levers instead.

> **Dark theme won't budge?** Some ROMs lock night mode, and the uimode service
> then refuses the change **silently**. DCX prints the mode the device reports
> back rather than claiming success — if the readout doesn't move, that's the honest answer, not a bug.

---

### Backup & Restore

**Backup** reads the first-class Settings / `device_config` / props / Display
Scaler (`wm`) / DeviceConfig sync targets DCX neo toggles — **62 capture calls**
(56 `settings`, 3 props, 1 `device_config`, 1 `wm`, 1 sync mode), including every
[Tweaks](#tweaks) key — and writes a **stand-alone restore `.bat`** to
`%USERPROFILE%\dcx_backups\dcx_backup_<timestamp>.bat`.

**Backup tells you what it got.** The list lives in one routine
(`:_bk_capture_all`), it prints which group it is on as it goes, and when it
finishes it says how many values it captured and how many it had to skip:

```
Backup complete. 62 values captured.
```
```
Backup saved, but incomplete. Captured 41, skipped 21.
```

A key is skipped either because the device didn't answer for it — a Wi-Fi ADB
drop, or the settings service still coming up after a reboot — or because its
value holds a double quote, which no `.bat` line can carry. The file records
which, and why, on a `:: DCX_SKIP` line. Skipped keys are simply absent, so a
restore leaves them exactly as they are; it will not delete them.

**What Backup does *not* cover.** It is a curated list, not a snapshot of
everything DCX writes. Of the persistent keys each feature touches, Backup
captures: Logs Off 1 of 87, Performance 1 of 11 (`low_power`), Wi-Fi/BT scanning
2 of the 9 it writes, and **none** of Aggressive saver (5 keys), Send Error
(10), Samsung motion (4) or Game Mode (per game; its **Reset** is the undo). The session undo file written by
Tweaks, Explorer, profiles, the DNS screens and the saver screens covers what
you actually changed in a session; Backup covers the curated set. Use both.

**Backups are tied to the phone they came from.** Each file records the device
serial, and Restore compares it against the phone connected now — if they
differ it names both and refuses, instead of writing one phone's screen
resolution, density and delete lines onto another. Files written by older DCX
versions carry no serial; those still restore, with a line saying the device
could not be verified. A serial is recorded only if it is made of letters,
digits and `. : - _ [ ]`. That covers USB serials, `emulator-5554`, `ip:port`
and the mDNS names Android 11+ wireless debugging uses. Any other serial would
be parsed again, as batch code, when the `.bat` file runs. So the file is
written untagged instead, and DCX prints a `[WARN]` saying so. The same applies
to the Tweaks undo file; there DCX waits for a key, because the next screen
would clear the warning. Restore says such a file does not record which phone
it came from, and it says the same of a file written while adb reported no
serial at all. Only files from older DCX versions are described as predating
device tagging.

**A value the file cannot carry is never written as if it could.** If a setting
contains a double quote — a Material You theme blob, for instance — the restore
file gets a comment naming the key instead of a mangled command. And a key the
device did not answer for is recorded as a comment too, not as a `delete`:
empty output means the read failed, while Android prints the literal word
`null` for a key that genuinely is not set.

**ADB path:** those `.bat` files live under `%USERPROFILE%\dcx_backups` — *not* next to DCX’s local `adb\` folder. New backup/undo scripts:

- **Embed** the full `adb.exe` path DCX was using, also write
  `%USERPROFILE%\dcx_backups\dcx_adb_path.txt`, and fall back to `PATH`.
- **Stop with an error** (and wait for a key) if adb still can’t be found —
  they no longer silently no-op.
- Accept **`/nopause`** when DCX launches them from the menu so control returns
  to Tweaks / Restore without closing the shared console. Double-clicking a
  `.bat` still pauses with *Press any key to close this window*.
- Put helpers (`:dcx_do`, `:dcx_hold`, `:dcx_report`) **before** `:dcx_main` so
  restore lines stay in the main body and the hold always runs.

Re-run **Backup** (or any Tweaks write) once under this DCX to refresh older
scripts that still call bare `adb`, use `1) Add …` help text inside an `if`
block, or append restores after `:dcx_hold`.

```bat
@echo off
setlocal
set "DCX_NOPAUSE="
if /i "%~1"=="/nopause" set "DCX_NOPAUSE=1"
set "ADB=C:\...\DCX\adb\adb.exe"   :: embedded by DCX
...
echo Using adb: "%ADB%"
goto :dcx_main
:dcx_do
"%ADB%" shell %* >nul 2>&1
...
:dcx_hold
if defined DCX_NOPAUSE exit /b 0
pause
...
:dcx_main
set "DCX_OK=0" & set "DCX_FAIL=0"
call :dcx_do "settings put global window_animation_scale '1.0'"
goto :dcx_report
:: -> [OK] Restored n settings, none failed.
::    or [WARN] n restored, m FAILED - listed above.
```

Captured values are quoted; any settings/`device_config` key unset at backup
time becomes a `delete` (properties still become a comment) — so a restore
returns you to the exact prior state and never pins a property to an empty string.
Values are also read with delayed expansion **off**, so a value containing `!`
is captured whole; older files could store `Hi!There!` as `Hi` and then restore
that shortened text over your setting (see [Troubleshooting](#troubleshooting)).

**Backup refuses to run without the device attached, on purpose.** Reading a key
that the device doesn't answer for looks *identical* to a key that's genuinely
unset — both come back empty — and unset is recorded as *"delete this on
restore"*. A backup taken with the cable out would therefore be a file that
**erases** your settings instead of restoring them, so DCX checks the device is
there first and declines rather than write that.

**And it only says `Backup complete.` once it has checked the file is really
there** with real content in it. `%USERPROFILE%\dcx_backups` is exactly the sort
of folder antivirus and Controlled Folder Access guard; if the writes are
blocked, you get a clear failure and how to fix it — not a backup you *think*
you have and find out about later. **Restore reports what actually happened.** 
It's a long run of ADB writes — if the cable is pulled, wireless ADB drops or 
authorisation expires part-way, the rest silently do nothing. Newer backup files 
count every write and end with `[OK] n restored` or `[WARN] n restored, m FAILED`
naming the failures; DCX also re-checks the device is still connected afterwards, 
which covers backup files made before this existed. Restoring twice is harmless.

Because it's a normal batch file you can run it directly without DCX neo (double-click 
holds the window until you press a key), edit out lines you don't want, or share it to 
reproduce settings elsewhere. **Restore** lists backups (newest first), shows which device the chosen file
came from, confirms, then applies it with `/nopause` so DCX stays open. To open
the backups folder in Explorer, use **[14] Undo / backups hub** — Restore itself
only restores, and the hub only opens files and runs undo scripts.

#### Preview — what would this restore actually change?

At the confirmation prompt, **[P]** re-reads every key the backup covers from
the phone as it is *now* and compares the two. It writes nothing to the device.

```
 In the backup : 62 restore commands
 On the phone  : 62 values readable right now
 Would change  : 3

Restoring would write these - the phone holds something else today:
   set "DCX_CMD=settings put system font_scale '1.0'"
   set "DCX_CMD=settings put secure sysui_qs_tiles 'wifi,custom(com.x/.y:2),bt'"
   set "DCX_CMD=settings put global heads_up_notifications_enabled '1'"
```

Nothing to change is a useful answer too — it means the backup and the phone
already agree and restoring is a no-op. From there you can open the full
comparison (the lines only in the backup, and only on the phone) in Notepad or page it in the window, then go back to the
prompt and decide. The reading pass is ~62 adb round trips, about six seconds,
and the screen says so rather than sitting blank.

Two cases it refuses rather than guessing: a backup written by an **older DCX**
passes its command to the helper as an argument instead of in a variable, so
there is nothing to line up — it says so instead of reporting "no differences",
and such files still restore normally. A file with no `:dcx_main` section is
truncated or isn't a DCX backup, and it says that too.

---

### Benchmark

A quick, repeatable micro-benchmark: a timed CPU loop (lower is better), then a
32 MB sequential write and a 32 MB sequential read with `dd` (higher M/s is
better). The write ends with `conv=fsync`, so it is timed until the data is on
storage, and the read uses `iflag=direct`, so it comes from storage rather than
the copy still in RAM. Both options are in toybox `dd`'s own help. An older `dd`
without them gets the plain command, labelled as including the cache (write) or
as memory speed (read). Run it before and after optimising to compare. Uses a
portable shell loop, so it works on devices that lack `seq`.

---

### App Manager

App-level controls (background restriction + debloat), main menu **14**. **Everything here is reversible.**

| # | Option | What it does |
|---|---|---|
| 1 | **Restrict app background** | Asks for a package, then sets Android's own **Restricted** mode the way Settings does: `RUN_ANY_IN_BACKGROUND` (and the legacy `RUN_IN_BACKGROUND`) → `ignore`, and off the Doze allowlist (it asks first if the app is on it). Read back, recorded in the session undo file, then [App check](#app-check) opens. Earlier versions wrote `deny`, which no Settings version shows correctly: 9–11 grey the switch out ("App not allowed to run in background"), 12–15 show no mode, 16 calls it Unrestricted. |
| 2 | **Allow app background** | Both ops back to `allow`. The Doze allowlist is left as it is, so the app ends up Optimized or Unrestricted; the session undo file restores an allowlist entry that Restrict took off. Read back and undo-recorded, then App check. |
| 3 | **Debloat by package name** | Remove an app for the current user (`pm uninstall -k --user 0`). The name is checked against the Android package-name charset (a letter, then letters/digits/dots/underscores) *before* anything runs, then checked to be installed, then confirmed; data kept. Only pm's own `Success` line counts as removed; a `Failure [...]` is shown and the screen ends in a warning. |
| 4 | **Suggested bloatware** | Auto-detects your brand and lists only **vetted, safe-to-remove** packages that are **actually installed** (cross-vendor Facebook, optional Google apps, plus Xiaomi / Transsion / Samsung / Huawei sets). |
| 5 | **List installed packages** | Dump all packages — or user/updated apps (`-3`) where bloat usually lives — to Notepad. |
| 6 | **Restore a removed app** | Bring a debloated app back (`pm install-existing`). |
| 7 | **Back** | — |

**How removal works (and why it's safe).** Debloat uses `pm uninstall -k --user 0`: 
the app is removed only for the current user and its data is **kept** (`-k`). 
The APK stays in `/system`, so you can restore it any time via **option 6** or 
a **factory reset**. OTA updates may also bring packages back.

> **⚠️ Debloat warnings**
> - Only remove apps you recognise — removing a critical package can cause a
>   **bootloop**. DCX neo hard-blocks known offenders, including
>   **`com.hoffnung`** (looks like bloat on Transsion Tecno/Infinix/itel
>   phones but bootloops them), plus system UI, phone, settings, telephony
>   providers, and Huawei core services (`com.huawei.hwid`, push, FIDO/`hwasm`, OTA).
> - The **Suggested** lists only ever show packages that are both
>   community-vetted as safe *and* installed. Confirmation is **per list, not
>   per app**: one `Y` removes the whole group that was printed above the
>   prompt, so read the list before answering. Sources are UAD-NG and community
>   debloat guides.
> - If something breaks after a debloat, use **Restore** (option 6) or reboot;
>   a factory reset restores everything.

---

### Wireless ADB

Run DCX over Wi-Fi with no cable. Reachable from the main menu (**13**) or from the startup screen when no USB device is found (**[W]**).

| # | Option | What it does |
|---|---|---|
| 1 | **Pair with code** | Android 11+ one-time pairing: enter the `ip:port` **and 6-digit code** from Developer options → Wireless debugging → *Pair device with pairing code* (keep that dialog open — the code dies when it closes). |
| 2 | **Connect** | Connect to `ip[:port]`. On Android 11+ use the ip:port from the **main** Wireless-debugging screen — it's a **different port** than the pairing one, and changes after a reboot or re-toggle. Plain IP assumes port 5555. |
| 3 | **Enable over USB** | Classic method for any Android version: flips adbd to TCP/IP on port 5555 (`adb tcpip 5555`) while the cable is attached, auto-detects the phone's Wi-Fi IP from `ip route` (only an IPv4 address made of digits and dots is offered; otherwise it asks you to use option 2), and offers to connect immediately. Reverts on reboot or via option 5. |
| 4 | **Disconnect** | Drop all Wi-Fi connections (USB unaffected). |
| 5 | **Back to USB** | `adb usb`, for devices switched with option 3 only. If `adb usb` fails — which it does for an Android 11+ Wireless-debugging connection, where the toggle on the phone is the only way back — it says so rather than reporting Done. |
| 6 | **Help** | Where to find the ports/code, per-version notes (incl. Huawei EMUI/HarmonyOS builds that hide the pairing dialog — option 3 works there). |
| 7 | **Select target device** | Pick which attached device DCX talks to when more than one is present. Sets `ANDROID_SERIAL`, so every later adb call follows without any `-s` flags. |
| 8 | **Back** | — |

> **Security note:** while Wireless debugging is on, any PC paired with the phone on the same network can run adb commands. Turn it off when done.

> **More than one device attached?** adb refuses to act when it cannot tell which device
> you mean — every command fails with *more than one device/emulator*. DCX now picks a
> target instead of walking into that: on startup, and again whenever this menu changes the
> connection list, it enumerates the authorised devices and sets `ANDROID_SERIAL` to the one
> you choose. One device is selected silently; two or more get a picker that labels each
> entry **USB** or **Wi-Fi**. The header then shows which transport is in use.
>
> This matters most for a case DCX creates itself: **Enable over USB** runs `adb tcpip 5555`
> and connects over Wi-Fi *while the cable is still attached*, so the same phone appears
> twice — once by USB serial, once as `ip:5555`. Either entry works; the picker just makes
> you say which. Pull the cable, or use **Disconnect**, if you would rather have one.

The old standalone `wirelessadb.bat` is **removed** — this menu replaces it
(that script only did `adb connect`, with no Android 11+ pairing support).
`opencmd.bat` remains if you want to use ADB separately from DCX neo. It opens a prompt
already in the bundled `adb` folder, with that folder **on PATH** and the server started,
then reports what is attached and in what state. The PATH part matters on hardened and
enterprise Windows images: those set `NoDefaultCurrentDirectoryInExePath`, so cmd does not
search the current directory for executables. Being *in* the adb folder was not enough
there — every call failed and the script told you to install the platform-tools sitting
right next to it. `adb` also keeps working after you `cd` somewhere else. A `!` in the
folder's name is fine too, including when delayed expansion is on by default (the
`DelayedExpansion` registry value that `cmd /?` describes) or `opencmd.bat` is started from a
batch file that has it on — there it used to say *ADB was not found*. So is a `;`: that
folder now goes on `PATH` in quotes, where it used to be split in two.

---

### Settings Tools

The generic half. These work on **any** key in the settings provider, including
every key DCX has no menu row for — the [Tweaks](#tweaks) list is curated, this
one isn't. Reachable from the main menu (**15**).

| # | Option | What it does |
|---|---|---|
| 1 | **Settings explorer** | `list` / `get` / `put` / `delete` across `system`, `secure` and `global`. Every write echoes the exact command, asks to confirm, shows a read-back, and saves the old value to an undo script first. Keys and values are whitelist-validated — anything with spaces or shell metacharacters is declined toward **Shell** rather than mangled. |
| 2 | **Snapshot & diff** | Dump all three tables to `%USERPROFILE%\dcx_snapshots\`, flip a toggle in the device's own UI, dump again, diff. This tells you **exactly which key that toggle writes** — the fastest way to find OEM-specific settings DCX doesn't know about. |
| 3 | **Profiles** | Plain text in `%USERPROFILE%\dcx_profiles\`, one `namespace`\|`key`\|`value` (or `DELETE`) per line. **Check** a profile against the phone (writes nothing), **Apply** only the keys that differ (each read back), three **goal presets**, and **re-apply after reboot**. See [Profiles](#profiles). |
| 4 | **Watch a key** | Poll one known `namespace`/`key` once per second while you flip a toggle on the phone. Auto-stops when the value changes (or press **Q**). Faster than snapshot/diff when you already know which table to watch. |
| 5 | **Back** | — |

#### Profiles

| # | Option | What it does |
|---|---|---|
| 1 | **Save Tweaks-only profile** | The curated Tweaks keys, as the phone holds them now. A key that is not set is saved as `DELETE`. |
| 2 | **Save full stack** | The same, plus the Battery/Gaming keys (animation, refresh, ANGLE, low_power, zram, scan-always, hotword…). |
| 3 | **Check a profile** | Reads every key in the profile and compares it with the phone: `[+]` it matches, `[WARN] … differs: phone X, profile Y`, `[!]` no answer. Nothing is written. |
| 4 | **Apply a profile** | Writes only the keys that differ, then reads each one back. Keys that already match are not written again (Android would not change anything for them). Ends in `[OK]`, or `[WARN] n passed, m failed`. A failed key shows what the phone reports and the adb exit code: 255 means the phone refused it, 1 means the connection dropped, and 0 with a wrong value means the phone accepted the write and ignored it. |
| 5 | **Goal presets** | Snappier, Longer battery, Easier to read (below). |
| 6 | **Re-apply after reboot** | Arm one profile for this phone. DCX checks it when the phone connects after a reboot. |
| 7 | **Open the profiles folder** | — |
| 8 | **Back** | — |

Lines starting with `#` are ignored. Every line is validated again on Check and Apply, because anyone can edit a profile file. A bad namespace, key or value prints `skip - …`, and the rest still runs. A line holding `%` or `!` is skipped, because cmd would read `%NAME%` or `!NAME!` in it as a variable on this PC. A namespace typed as `System` is sent as `system`. A profile DCX cannot read, for example one another program has locked, shows `Could not read <name>`, and the list asks again. Check compares the text exactly, so `60` and `60.0` count as different, and Apply then writes the profile's text. Reading a value back proves it is stored, not that the phone uses it: a skin can ignore a key it doesn't read.

**Goal presets.** A preset reads its keys first and shows `now -> preset` for each one. It only moves a key toward the goal. A key that is already there is `kept`. A key that is empty, is not a plain number, or holds a value DCX could not save for undo is `left alone`. Nothing is written until you press **Y**. Before writing, DCX saves `before_<preset>_<time>.txt` in the profiles folder. It holds the old value of exactly the keys the preset changes, or `DELETE` for keys that were not set. **Apply that file to undo the preset.** The session undo script in `dcx_backups` also records the first value of every key DCX changed in this session. DCX builds the presets from its own rules each time rather than shipping them as files, because what they change depends on the phone.

| Preset | Key | Goal | Changed when the phone has |
|---|---|---|---|
| Snappier | `global` `window_animation_scale`, `transition_animation_scale`, `animator_duration_scale` | 0.5 | more than 0.5, or not set. 0 (animations off) is kept. For a window or animator scale that was not set, the `before_` file holds `1.0`, not `DELETE`: Android keeps the running scale when those two keys are deleted, until the next reboot. |
| Longer battery | `global low_power_trigger_level` | 20 % | less, or not set. A higher trigger is kept. |
| | `system screen_off_timeout` | 30 s | longer. Not set means 15 s, so it is kept. |
| | `system screen_brightness_mode` | 1 (automatic) | anything else |
| | `system peak_refresh_rate` | 60 | more, `Infinity`, `0` (no cap), or not set. Android 10+ only, and only when the panel lists a mode above 60 Hz. |
| | `system min_refresh_rate` | 0 (no floor) | more than 60, or `Infinity`. Android caps the rate at the larger of min and peak, so a high min would cancel the 60 Hz cap. Not set means 0, so it is kept. Same condition. |
| Easier to read | `system font_scale` | 1.3 | less, or not set |
| | `secure long_press_timeout` | 1000 ms | less, or not set |
| | `system status_bar_show_battery_percent` | 1 | anything else |
| | `system screen_off_timeout` | 2 min | shorter, or not set (Android then uses 15 s) |
| | `secure high_text_contrast_enabled` | 1 | anything else |

The 20 % battery-saver trigger only counts when battery saver is scheduled *Based on percentage*, and DCX warns when the phone follows *your routine* instead. Battery saver never turns itself on while the phone is charging, and a USB cable charges it, so unplug to see it work. Font size 1.3 can clip text in some apps, and some skins ignore high-contrast text. Longer battery and Easier to read both set the screen timeout, and the one applied last wins. Each keeps its own `before_` file.

**Re-apply after reboot.** Some values don't survive a reboot. Android sets the volume cap back to active at every boot and reads that key only while booting, so re-applying it after a reboot keeps the *next* boot uncapped. Use **6 → Arm a profile**, and DCX keeps a copy of that profile for this phone in `dcx_profiles\rearm\`. When the phone connects after it has rebooted, DCX checks the copy, lists the keys that drifted, and asks **Re-apply them now?** Nothing is written without **Y**, and each key is read back. It asks once per boot. DCX recognises the phone by its own serial (`ro.serialno`), which is the same over USB and Wi-Fi. It spots a reboot by the kernel's `boot_id`, which is new at every boot. If the phone reports no usable serial or boot id, DCX says so and does not arm it. If the phone is still starting up, or some keys can't be read, DCX waits for the next connect. If you edit the profile later, arm it again. **6 → Turn it off** removes the copy. With nothing armed, connecting costs no extra adb calls.

---

## What actually works vs. placebo

Android only reads a specific set of settings, properties and `device_config`
flags. Many "optimization scripts" set hundreds of made-up keys (e.g.
`persist.sys.cpu.governor`, `debug.cpufreq.max_freq`) that **Android never
reads** — they're stored but do nothing. DCX neo focuses on commands with a **real, documented effect**:

- **`pm compile` / `pm bg-dexopt-job` / `pm art dexopt-packages` / `fstrim`** —
  maintenance; the **most noticeable** wins (chosen per Android version).
- **Animation scales** — the classic "make it feel faster" tweak.
- **`debug.hwui.renderer`** (`skiagl`/`skiavk`) — the actual HWUI renderer.
- **`angle_gl_driver_all_angle`** — the official ANGLE switch (real, but
  device-dependent — see the Gaming warning).
- **`min_refresh_rate` / `peak_refresh_rate`** — real refresh-rate control.
- **`wm size` / `wm density`** — real logical-resolution and DPI control
  (Display Scaler). Lowering the render resolution is a genuine, no-root way to
  gain GPU headroom and cut power draw; `wm size reset` / `wm density reset` fully revert it.
- **`deviceidle force-idle`, app hibernation, `hotword_detection_enabled`** —
  real battery switches.
- **`cmd appops … RUN_ANY_IN_BACKGROUND deny`, `pm uninstall -k --user 0`** —
  background restriction and (reversible) debloat (App Manager). It has to be
  `RUN_ANY_IN_BACKGROUND`: Android checks the older `RUN_IN_BACKGROUND` only for
  apps targeting below Android 8, so on anything modern denying that one alone
  changes nothing. DCX sets both.
- **`clock_seconds`, `icon_blacklist`, `sysui_qs_tiles`** — real SystemUI
  tunables. SystemUI *observes* these keys, so they apply live with no restart:
  the tile list still reads from `sysui_qs_tiles` on current AOSP, content observer and all.
- **`audio_safe_volume_state`** — real, but honestly **per-boot**; Android
  re-arms it at every boot (see [Tweaks](#tweaks)).

> **Not every toggle is effective.** The **Account Sync** switch writes
> `master_sync_status`, which is a **placebo on modern Android** — nothing
> reads it, and the real master-sync state lives in the sync framework
> (`adb shell dumpsys content` → *Auto sync*), unreachable via `settings`
> without root (on Android 17, writing `master_sync_status 0` left *Auto sync:
> true* unchanged). It's kept only so Backup/Restore round-trips the value.

> **Other honesty labels (Battery / Gaming / Optimize):** Samsung **Motion**
> is OEM-only; **ZRAM** is a boot preference (may no-op); **Wi-Fi/BT scan**
> is not an OEM “auto Wi-Fi” switch; the SurfaceFlinger Hz profiles are retired
> (they could not take effect); **Performance props** are a debug/OEM dump.

> **Some famous tweaks are dead, and DCX won't ship them as decoration.**
> `policy_control` (the old immersive-mode key) — the framework class that
> implemented it is **gone from AOSP**, so it stores fine and does nothing on
> Android 11+. `sysui_qqs_count` — modern SystemUI no longer reads it.
> `persist.log.tag "*:S"` was in this list on the wrong side until recently: it
> looks like a universal log silencer and is not one, because liblog reads only
> the **first character** of the property as a level letter and `*` is not one of
> them. The whole value is ignored. A bare `S` does work — and silences crash logs
> with everything else, which is why DCX does not set it for you.
> Tethering flags sit behind carrier entitlement checks that `settings` can't
> touch. All three would look like features and be placebo, so they aren't in
> the menus. If you want them anyway, **Settings Tools → Explorer** will write
> them — declining a menu row isn't blocking you. Explorer accepts key names
> made of letters, digits and `_ . -`, and values made of letters, digits and
> `_ . , : / = + -`, so a value containing spaces, `*`, `{` or `"` has to go in
> through `adb shell settings put` by hand.

> **And some tweaks are removed because they're harmful, not because they're
> fake.** DCX no longer writes `debug.sqlite.journalmode OFF`,
> `debug.sqlite.syncmode OFF` or `debug.sqlite.wal.syncmode OFF` (they were in
> Battery → **Logs Off** and Gaming → **Performance props**). Those switch off
> SQLite's durability for **every database on the device**: `journalmode=OFF`
> removes the rollback journal, so a transaction interrupted by a crash, a
> kernel panic or a battery pull can't be rolled back and leaves a **corrupt
> database**; `syncmode=OFF` and its WAL counterpart stop SQLite calling
> `fsync`, so data an app believes is committed can vanish. What you'd be
> trading away is contacts, messages and app state — for write throughput you
> won't notice. `debug.sqlite.journalsizelimit` stays: it only caps the journal
> **file size** after commit and costs nothing in integrity. Both revert paths
> (Logs On, Performance Off) now clear the three props, so if you ran an older
> DCX and haven't rebooted, either one restores `fsync` immediately. Same
> reasoning already retired `debug.force_low_ram` from Logs Off and the
> vsync-disabling props from Performance Mode.

> CPU/GPU frequency and governor changes are **not** possible via `setprop` —
> they live in kernel sysfs and need **root**. Neither is the **speaker
> amplifier ceiling**: the engineering-menu "max volume" sliders edit vendor
> gain tables, root only. DCX neo doesn't pretend otherwise.

---

## Persistence & root

- `settings put` and `device_config put` values (animation scales, refresh
  rate, ANGLE, sync, hotword…) **persist** across reboots without root —
  **except on Android 14+**, where most `device_config put` writes from the
  shell need root (DCX warns once via `_dcfg_warn` when that applies).
  `device_config set_sync_disabled_for_tests` is covered by Backup/Restore.
- `setprop`-based changes (e.g. GPU renderer) apply immediately but **reset on
  reboot**; making them permanent needs root (Magisk module or `build.prop`).
- **Android 14+** routes dexopt through **ART Service**; DCX neo detects this
  at startup and adjusts the compile/dexopt commands automatically (details in
  [Optimize Android](#optimize-android)).
- Two keys are **deliberately not permanent**, because Android won't let them
  be: the **volume cap** is re-armed at every boot, and **freeform windows**
  need a reboot to take effect at all. For the first, arm a **Profile** under
  [Profiles](#profiles) → **Re-apply after reboot**: when the phone reconnects
  after a reboot, DCX checks it and re-applies what drifted once you press Y.
  Android reads the volume-cap key only while it boots, so this keeps the *next*
  boot uncapped. That is the no-root, no-daemon equivalent of SetEdit's on-device
  boot queue.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| **One app's notifications arrive late or not at all** | Battery → page 2 → **D App check**. It shows whether the app is force-stopped (Kill all, Force stop), paused, hibernated, Restricted, in a rare or restricted standby bucket, or has no notification permission. It fixes Android's own settings from the same screen. A phone maker's battery manager is outside what adb can see. |
| **"ADB not found"** on launch | Install Platform Tools and add to `PATH`, or put `adb.exe` in an `adb\` folder next to `DCX.bat`. |
| **"ADB not found" even though `adb\` is right there next to `DCX.bat`** | Fixed. DCX `cd`s into `adb\` and then calls bare `adb`, which worked only because cmd searches the current directory for executables. Windows images that set `NoDefaultCurrentDirectoryInExePath=1` — hardened and enterprise builds do — turn that off, so every one of the ~1500 adb calls failed and the error told you to install the Platform Tools you already had. DCX now puts that folder on `PATH` explicitly instead of trusting the current directory. Verified both ways: with the variable set the old code reported *ADB not found* and the new code finds it, and nothing changes on a normal image. |
| **"ADB not found", or the wrong adb, when DCX's folder name holds a `!`** | Fixed. DCX runs with delayed expansion on, and it read its own folder (`%~dp0`), `%CD%` and `%PATH%` in a way that let that pass eat the `!`: `D:\Tools\DC!X\` was looked up as `D:\Tools\DCX\`, and a name like `k!OS!m` as `kWindows_NTm` (the text between two `!` swapped for a Windows variable). So DCX said *ADB not found* with its `adb\` folder right there, or ran an adb from `PATH`, or ran the `adb\` of another copy that happened to sit at the mangled name. The folder is now captured before delayed expansion goes on and read late everywhere, and so are `%CD%` and `%PATH%`. Backups had the same problem one step later: whenever the adb in use sat in a folder with a `!` (the bundled one once the above was fixed, or one on `PATH`), the `adb.exe` path they embed lost it, so Backup said it *could not embed* one and a backup or undo file run on its own stopped with `[ERROR] adb.exe not found`. Verified with a stub adb in folders named `DC!X`, `a!b!c`, `k!OS!m`, `x^y!z`, `p&q (r) 50%` and `s^t`, with another copy at the mangled name, with an older adb on `PATH`, with adb only on a `PATH` entry holding a `!`, and with delayed expansion already on in whatever started DCX. A `;` in the folder name lost the bundled adb as well, on images that set `NoDefaultCurrentDirectoryInExePath` (row above). `;` separates `PATH` entries, so the folder went on `PATH` as two halves that name nothing, and an older adb from `PATH` ran instead. A folder holding a `;` now goes on `PATH` in quotes, which cmd reads as one entry. Every other folder goes on as before. `opencmd.bat` does the same. Verified with `q;r`, `a&b;c (1)` and `x!y;z`. |
| **A backup or undo `.bat` stops at once with *The syntax of the command is incorrect.*** | Fixed; it happened when DCX's folder name holds a `%` (say `D:\Tools 50%\DCX`). Those files carry DCX's `adb.exe` path as literal text, and a `.bat` expands `%…%` when it runs, so that line lost its command and the file ended there, before restoring anything. The `%` is now doubled when the path is written. An `&` in the folder name no longer splits the file's *Using adb:* line either (it printed a cut-off path, then tried to run the rest as a command). That alone did not make such a file restore: it still stopped at its device check, which is the next row, now fixed too. A file written from such a folder by an older DCX can be repaired by hand: double each `%` in the path on its `if exist "…" set "ADB=…"` line near the top. |
| **A backup or undo `.bat` says *This file was taken from device …, which is not attached* — and lists that device as attached right under it** | Fixed. It happened when DCX's folder name holds an `&` or a `^`, an `@` when the full path has a space, or a `(`, `;`, `,` or `=` when it has none. Nothing was restored. DCX's own **Restore** and **Undo** stopped the same way, because they run these files. Before it restores anything, the file checks that the phone it was taken from is attached, by reading `adb devices` through `for /f`. `for /f` runs that command in a second cmd, which strips one pair of quotes from it (the rule is on Microsoft's `cmd` page). So the quoted `adb.exe` path lost its quotes: the command split apart or lost a `^`, and the check never saw the phone. The line now carries one more pair of quotes for that cmd to strip, and lets it read the adb path from the `ADB` variable itself. The path is then parsed only once, so a folder name holding two `%` signs (`a%OS%b`) is not expanded a second time either. Restore and Undo now work from such folders. Verified with a stub adb that reports a serial, so the check really runs, in folders named `t&u`, `s^t`, `a@b`, `a b@c`, `a(1)`, `q;r`, `r,s=t`, `p&q (r) 50%`, `50%x%y`, `a%OS%b` and `a&b;c (1)` and the earlier `!` names. Each ran under a parent path with and without a space, both on its own and the way DCX runs it. Still open: on a PC where delayed expansion is on by default (the `DelayedExpansion` registry value), these files still lose a `!` in the adb path. The file then runs another adb, or stops with *adb.exe not found*. A file written by an older DCX can be repaired by hand. On its `for /f "tokens=1" %%d in (…)` line, replace `('"%ADB%" devices 2^>nul')` with `('^""%%ADB%%" devices 2^>nul^"')`. |
| **Backup ends in *Backup FAILED*, or Undo, Snapshots, Profiles, CheckSetting or the Restore preview go wrong, when the Windows user name holds a `!`, `%`, `^`, `&` or `)`** | Fixed. Every folder DCX keeps is under your profile: `%USERPROFILE%\dcx_backups`, `dcx_snapshots` and `dcx_profiles`, plus `%TEMP%` for the reports, the package lists and the Restore preview. DCX runs with delayed expansion on, and it read those paths in ways that changed them. A `!` was dropped, so for the user `Bo!b` DCX used `C:\Users\Bob\...`, a folder that is not yours. Backup then ended in *Backup FAILED* and blamed antivirus, and where that other folder could be written, DCX wrote into it instead. A `%` or `^` was changed on its way into the routines that write a backup, the undo file and a profile, because `call` parses its arguments a second time. The settings then went to a different file from the backup's header, and Backup reported a failure. An `&` cut every line that printed a path, and cmd tried to run the rest as a command. The path CheckSetting saves for its next *Diff* was cut there too. A `)` (`Sam (Work)`) ended a block early: after a profile Apply, DCX stopped with *… was unexpected at this time.* The folders are now captured once, before delayed expansion goes on, and every path is read late (`!…!`). Files go to those routines by the name of the variable that holds them. Some commands run in a second cmd: the `for /f` counts and listings, and Restore and Undo running their `.bat`. That cmd now reads the path from its own environment, so it does not expand a `%NAME%` pair inside the path. The folders have not moved. Verified with a stub adb, under a parent path with a space, for user folders named `Bo!b`, `k!OS!m`, `Bo%b`, `Bo%OS%b`, `50%x%y`, `Bo^b`, `Bo&b`, `Bo (W)` and `A!b%OS%^&(1) x`. The run covered Backup, Restore and its Preview, the undo file and the Undo hub, CheckSetting's report and Diff, the Wake-Lock report, the heaviest compile, the Doze-whitelist removal, both package lists, Snapshots, and Profile Save and Apply. It also ran a backup file on its own, including its `where adb` fallback in `%TEMP%` and its *adb.exe not found* message. Every check passed. The previous DCX, run the same way, failed 179 of them, and for a plain user name both versions wrote the same files and printed the same screens. Not measured: a PC where the `DelayedExpansion` registry value turns delayed expansion on for every cmd. There that second cmd would still drop a `!`, like the backup files in the row above. |
| **Two DCX windows (two phones): Debloat listed the other phone's apps and sent their removal to this one; the Restore preview or report Diff showed the other phone** | Fixed. DCX kept its scratch files in `%TEMP%` under fixed names: the package lists, the Doze-whitelist dump, the Restore preview, the quick-settings split, the two compile logs, the report diff and the pointer to the last CheckSetting report. A second DCX window overwrote them while the first was still using them. So **Suggested bloatware** could list the packages of the other phone and then send their removal to this one, two windows on the Doze screen at once collided on its file so that one of them removed nothing, and the preview and Diff showed the other phone's values. Each window now keeps these files in a folder of its own, `%TEMP%\dcx_<number>`, and **Exit** removes it. After a failed compile its logs stay in that folder, because the screen tells you they are kept there. A window closed with **X** or Ctrl+C leaves its folder behind; it holds a few KB and is safe to delete. Two windows never get the same folder, even when they start in the same second. (Picking a random number alone could not promise that: every cmd started in the same second draws the same `%RANDOM%` numbers.) Diff now remembers the last report per phone (see CheckSetting), so a single window no longer compares two phones after Wireless ADB switches the target either. Reports from before this change are not offered for Diff; the next CheckSetting starts the history again. Backup and undo files, when they look for adb on `PATH`, no longer write `%TEMP%\dcx_where_adb.txt`. Verified with a stub adb and two fake phones sharing one `%TEMP%`, with one window at a menu while the other ran the same screen. The old DCX sent the other phone's apps for removal, showed the other phone in the preview and in Diff, and compared two phones after a device switch; with two windows on the Doze screen at the same moment, one of them failed in every one of 25 runs (the file was in use, then deleted by the other window) and removed nothing. The new one did none of these, and both Doze windows worked in all 25 runs. Also verified: Exit and the startup **X** leave nothing behind, a failed compile's two logs survive Exit, the package list, Doze removal, quick-settings split and backup-file fallback still work, and Diff works with serials of the forms `192.168.1.5:5555` and `[fe80::1]:5555`. These checks ran under a plain user folder and under `Bo!b`, `Bo%OS%b`, `Bo^b`, `Bo&b` and `A!b%OS%^&(1) x`; the 25 Doze runs used the plain one. |
| **"No authorised device found"** | Enable USB debugging, replug, tap **Allow** on the phone. Check `adb devices` shows `device` (not `unauthorized`). No cable? Press **[W]** for Wireless ADB. |
| **Stuck in the paginated report view — Q works but 0 does nothing** | Working as designed, now signposted. The paginated view is Windows' own **MORE** pager, and it only understands its own keys: **SPACE** next page, **ENTER** one line, **Q** quit. `0` is a DCX *menu* key, so it means nothing to MORE. Both report screens now spell the keys out before paging **and** put them in the window title, where they stay visible on every page instead of scrolling away. |
| **CheckSetting / Wake-Lock Audit ignored keypresses and had no way out** | Fixed. Those two report menus were the only ones without the tight re-ask every other menu has, and they had no `cls` — so *any* miss redrew the whole block, including the phantom empty line the console hands `set /p` right after ~50 adb probes. Your first keypress looked ignored, and repeated misses stacked copies of the menu until **Back** scrolled off screen. Reproduced: the old menu spun in an infinite redraw loop and had to be killed; the fixed one re-asks in place. Both now redraw only on a real return and accept **0** or **Q** as Back. |
| **CheckSetting / Wake-Lock Audit look frozen while generating** | Partly by design, now visible. The report is ~50 device queries (≈8 s) and ~5 dumps (≈5 s), and batch has no way to accept a keypress mid-run — so the window genuinely can't respond until it finishes. It now says so up front and prints step-by-step progress (`[3/6] display and graphics…`) instead of sitting blank. There is no mid-run abort; close the window if you must. |
| **"Clear"/"Remove"/"On" said it worked but the property was still set** | Fixed — and it hit four features. `adb shell setprop KEY ""` **never clears anything**: cmd strips the quotes, adb re-joins the arguments, and the phone gets `setprop KEY` with one argument, so it prints `usage:` to a swallowed stderr and changes nothing. Affected **SF → Remove**, **Universal Toggle Logs → On**, **Toggle Logs/etc → On** (`persist.log.tag`) and **GPU Renderer → Clear override** — all reporting success. Now `''`, which survives the round trip; verified on-device. Same quote-stripping as the `sysui_qs_tiles` restore bug. |
| **DeviceConfig server sync shows "none" / always warns the change didn't apply** | Some builds (EMUI 14 included) implement the setter but not the getter — `get_sync_disabled_for_tests` answers *"Invalid command"*. DCX used to read that as `none`, so the screen showed a mode it had never read, the verifier reported a failure it couldn't know about, and **Backup wrote a restore line for a value it never captured**. It now detects the unreadable case, says so, reports `[NOTE] cannot confirm` instead of a false warning, and skips the key in Backup. |
| **DCX closed by itself right after detecting the device — the main menu never appeared** | Fixed; the big one. After picking the target the script fell *through* into `:pick_device` a second time, and that pass wasn't a `call`, so its `exit /b` ended the batch file. The menu was unreachable on a normal USB start — the only way in was the no-device → **[W]** Wireless ADB → **Back** detour, which is why it looked like "works over Wi-Fi, closes over USB". One `goto` fixes it; the two-device picker also no longer appears twice. |
| **Wireless connect says "failed to authenticate" / "connection refused"** | Pair this PC first (Wireless ADB → option 1), or the port went stale — it changes on reboot/re-toggle, so grab it fresh from the Wireless-debugging screen. |
| **A game looks blurry or wrong after Game Mode** | Gaming → **Game Mode** → **Reset**, then open the game again. |
| **Something feels broken after tweaking** | **Reboot** — most live tweaks reset on reboot and that clears it. |
| **A tweak "didn't do anything"** | Read the value back via **CheckSetting** (graphics: `dumpsys gfxinfo <pkg> \| findstr Pipeline`). Some keys need root or a newer Android. |
| **CheckSetting report or Wake-Lock Audit saved empty / blank** | Fixed — a bare `)` in an echo annotation like `(first 15)` closed the redirected `( … ) > file` block early; annotations are now escaped (same fix covers the background-dexopt failure list). |
| **CheckSetting/Wake-Lock report shows `can't create nul` / `findstr` errors, or a blank section** | Fixed — the `\| findstr` filtering leaked to the Android shell; it now runs Android-side (`adb shell "… 2>/dev/null \| grep …"`). **This originally only covered the generated report.** Wake-Lock Audit → **[3] Show summary only** kept the old form (`adb shell dumpsys power ^<nul 2^>nul ^\| findstr …`): those carets belong inside a `for /f ('…')` clause, and out in the open they make `<`, `>` and `\|` literal, so the whole string was handed to adb and run on the *phone* — which has no `findstr` and no `nul` device. That view now uses `grep` Android-side like the rest, so it prints wake locks instead of shell errors. |
| **Box characters / logo turn into `?????` after a report or backup (until relaunch)** | Fixed — the timestamp used `powershell Get-Date`, which resets the console code page on exit; it's now built in pure `cmd` from `%date%`/`%time%`. The two places that still need PowerShell (SurfaceFlinger Hz math, quick-settings tile tokenizer) each run `chcp 65001` immediately afterwards, so the code page is restored rather than left for the next `:logo` redraw to repair. |
| **First apply in a menu jumps back without pausing (second time is fine)** | Fixed — an `adb shell` forwards stdin, so `pause` ate a keystroke; every `adb shell` before a pause now reads stdin from `nul` (`<nul`). |
| **DeviceConfig flags stopped updating after Logs Off / Sync Off** | Fixed — `set_sync_disabled_for_tests persistent` was a silent side effect of those toggles. It now lives only under **Tweaks → DeviceConfig server sync**; pick **Allow sync (none)** to undo a leftover freeze. |
| **QS tile Add/Remove crashed or wrecked the list on Huawei/OEM** | Fixed — lists with `custom(pkg/cls)` tokens are split paren-aware and written with shell quoting. |
| **Force Doze "did nothing" / the device stayed awake** | Doze only holds when the phone is **unplugged**, and the adb cable counts as charging. Fixed — *Force* now sends `dumpsys battery unplug` **before** `deviceidle force-idle`, and *Undo* pairs `deviceidle unforce` with `dumpsys battery reset`, matching the documented Android sequence. While forced, the battery UI shows a spoofed *unplugged* state until you pick **Undo**. Both options refuse if no device is attached. Note: some ROMs (e.g. EMUI) run their own power management that can override AOSP doze — if state stays `ACTIVE`, that's the ROM, not DCX. |
| **App-hibernation crashed the script when I typed a package name** | Fixed — a package name containing `)` closed a `for … do ( )` loop early at parse time; the one in-loop use now expands the name late (`!pkgv2!`) so parentheses are safe. Same class as the CheckSetting `(first 15)` annotation fix. |
| **Clear Caches said "complete" but nothing was wiped** | Fixed — on a non-rooted device `su` did nothing silently; it now probes for root first and says *Root is not available — nothing was wiped*. |
| **Clear Last Used printed a wall of `No shell command implementation`** | Fixed — that `usagestats` subcommand is missing on many builds; the per-package error is now suppressed Android-side. |
| **A restore said it worked when it didn't / partially failed** | Fixed — restore is a long run of ADB writes, and if the cable is pulled, wireless ADB drops or authorisation expires part-way, the rest silently no-op. It used to print *Restore complete.* regardless, leaving a half-restored device you believed was fine. Backup files now count what actually landed and report `[OK] n restored` or `[WARN] n restored, m FAILED` with the failures listed; DCX prevents adb quote-stripping, which prevents partial failure, and also re-checks the device is still connected afterwards, which catches the disconnect case for backup files made before this change. Restoring twice is harmless. |
| **Clear Last Used / Log for user apps took ~30 seconds** | Fixed — those three actions ran one `adb shell` per package, and on a 269-package device that's ~27 s of pure USB round-trip for work the phone finishes in milliseconds. They now run the loop inside a single device shell session: same packages, same per-package progress lines, without the transport cost. Clear Last Used also pauses before returning to Optimize so a leftover keystroke can't skip the menu prompt. |
| **Most apps crash after enabling ANGLE** | Common on non-Pixel GPUs; **a reboot won't help** (it persists). Gaming → Force ANGLE → **Disable**/**Delete**. |
| **Name lookups stopped working after setting Private DNS** | Some networks (hotel/captive portals, some corporate Wi-Fi, a few mobile carriers) block outbound DNS-over-TLS, and Android then fails lookups rather than falling back. Gaming → **TCP / DNS / network mode** → **Private DNS** → **Automatic (device default)** puts it straight back. That option exists on its own precisely so you don't have to use **Revert**, which would also drop the TCP hint and network mode. |
| **Wi-Fi died after TCP / DNS / network mode (old Network Boost)** | Gaming → **TCP / DNS / network mode** → **Revert** (clears any old Wi-Fi keys). |
| **ART Service printed a wall of text** | Not errors — older versions dumped a line per package. Current builds show a summary (optimised/failed) and only real failures; a few failures are normal. The heading said *"Failed entries (first 15)"* while actually paging through every one of them — the cap is now real, and if there are more it says how many it withheld rather than truncating quietly. |
| **App Manager → List installed packages showed an old list** | Fixed — only `1`/`2`/`3` were handled with no re-ask, so any other key ran no `pm list` and fell through to opening the file. That file has a fixed temp name, so you got the *previous* run's packages, unmarked — and debloat decisions get made off it. Invalid input now re-asks, the file is cleared before each dump, and an empty result says so. |
| **DCX said a package was installed when it wasn't (or acted on the wrong one)** | Fixed — the probe was a *substring* match, so `com.foo` matched `com.foobar`'s line. All ten call sites now match the whole line. Note the one-character fix (`findstr /x`) alone would have been worse than the bug: adb output can arrive LF-only, which makes findstr see one long line and report *every* package as missing. The output is normalised with `find /v ""` first — the trick Snapshot already uses — verified under both LF-only and CRLF. |
| **Back from Clear Cache landed in the wrong menu** | Fixed — every screen under **Optimize → Clear Cache** exited two levels up to Optimize, so *Back* skipped its own parent and finishing a trim or wipe dumped you out of the section. Each screen now returns to the one it came from. |
| **A backup restored a shortened value** | Fixed; worth knowing if you have old backups. Capture ran with delayed expansion on, which **eats `!`** — `Hi!There!` was stored as `Hi`, and that shortened text is what a restore wrote back over your setting. The four capture helpers now read with it off. Rare (few Android values contain `!`), but re-run **Backup** for a clean file. |
| **A Tweaks change wasn't in the undo script / "this change will NOT be recorded"** | The undo script is rewritten in place before each capture, and the old code checked only that the temp file *existed*, not that it had survived — so a failed rewrite could silently replace a populated undo script with an empty one. It now requires the rewrite to still carry its `:dcx_main` label, keeps the original on any doubt, and **says so** when a write won't be undoable. If you see that warning, check `%USERPROFILE%\dcx_backups` isn't blocked by antivirus or Controlled Folder Access. |
| **Logs On didn't fully undo Logs Off** | Fixed — `persist.debug.trace_layouts` was set by Logs Off and never reverted, and `persist.*` survives reboot, so one Logs Off pinned it off for good. Logs Off also used to `delete` your `gpu_debug_layers` value, which nothing could restore; that delete is gone, since the master switch beside it already disables the feature. |
| **"Unknown option: --compile-layouts" / "Unknown command"** | Expected on Android 12+ (removed; gone on 14+ under ART Service). DCX neo skips it automatically and continues. |
| **Bootloop / something broke after debloat** | Boot to recovery and **factory reset** restores every removed app (they're never deleted from `/system`). To revert a single app, use **App Mgr → Restore**. |
| **Volume cap is back after a reboot** | By design, not a bug — Android re-writes `audio_safe_volume_state` to *active* at boot on a capped device, and reads it only while booting. Re-apply it (it takes effect from the next boot), or arm a **Profile** holding it (Settings Tools → 3 → Re-apply after reboot). |
| **Apply says `wanted X, phone reports Y (adb exit 0)`** | The phone accepted the write and kept its own value. Some skins manage that key themselves. Older DCX counted this as landed. |
| **Dark theme won't switch** | Some ROMs lock night mode and the service ignores the request **silently**. The readout on the Night screen is the device's own answer — if it doesn't move, the ROM refused. |
| **A quick-settings tile I added never appeared** | The spec was wrong. SystemUI drops unknown tile specs instead of breaking the panel, so a typo costs you the tile quietly. Use the names listed on the Tile editor screen. |
| **Clock seconds / battery percent did nothing** | Heavily skinned status bars (some OneUI, EMUI) don't read the AOSP keys. The key is set; the skin ignores it. Nothing to fix. |
| **Freeform windows did nothing** | It needs a **reboot** — it's a developer-options key. The screen offers one. |
| **A profile line was skipped when I applied it** | Deliberate. Profiles are hand-editable, so every line is re-validated: a bad namespace, key or value prints `skip - …` and the rest of the profile still runs. A line holding `%` or `!` is skipped too. Older DCX versions saved such values, and applying them sent the PC's variables to the phone: a phone value `wifi,%USERDOMAIN%bt` went back with this PC's domain name in the middle. Saving the profile again from the phone writes a `#` line for that key instead. |
| **A value with `&` or `\|` was accepted by a prompt that should have rejected it** | Fixed. The charset checks were built as `echo(value \| findstr …`, and a pipe makes cmd hand the *already-expanded* text to a child that parses it again — so `1&echo hi` split at the `&`, findstr saw only `1` and reported **valid**, while the half after the `&` ran inside the pipe with its output swallowed. The check passed the bad value *and* executed part of it. The package-name and DoT-hostname validators are now pipe-free (`for /f "delims=…"`, which never builds a command line), and every remaining prompt runs the pipe-free `:_tw_safechk` first so `&`, `\|`, `<`, `>` can't reach the pipe. Verified: the same input that used to be accepted is now rejected at every prompt. |
| **The device line was cut short, or an error followed the model, brand or CPU load** | Fixed. Text the phone supplies (model, brand, manufacturer, serial, CPU load, `wm` output, the foreground app, `ip route` lines) was read with `%…%`, which cmd expands *before* it splits a line into commands. An `&` in a model name therefore cut the header there, and cmd tried to run the rest as a command on the PC. Android accepts any valid UTF-8 in a property value, and a rooted phone can change even `ro.*` properties, so this text is not trusted. It is now read late (`!…!`), which cmd never parses. The API level and the screen size/density must be plain digits before they are used anywhere. The pipes that sent phone text through a second parse (the brand match, the Doze-whitelist protection check, the refresh-rate and `wm` digit checks, and the device picker's USB/Wi-Fi label) are now tests inside the same shell. The Wi-Fi IP detection no longer passes the route line as `call` arguments. Phone text that goes **back** to the phone is covered too. Profile Save + Apply, the icon-blacklist and QS-tile editors, the Doze-whitelist removal, Backup's `wm` override capture, the `log.tag` loops of Logs Off/On and Kill all's app list could read `%NAME%` or `!NAME!` in the phone's own value as a variable on the PC. The PC's value (your user name, the computer name) was then written back to the phone. None of this could run a command. Each of these paths now reads the phone's text with delayed expansion off, and skips, or refuses to rewrite, a value that would be read that way. |
| **A screen said *Done* or *Applied*, but nothing had changed** | Fixed on every screen that did it outside the retired SurfaceFlinger profiles: error reporting, lock profiling, background-restriction reset, auto-sync, the Display Scaler (apply, custom density, reset), GPU renderer, thermal override and reset, safe volume, debloat, and profile Apply. Each write is now read back, or counted by the exit code adb passes back. The screen ends in `[OK]` or in a `[WARN]` naming what failed. A dropped connection no longer reads like success: a cleared property only counts once the phone has answered at all. |
| **A backup or undo `.bat` opened by double-click restored garbage into a setting with Cyrillic or other non-ASCII letters, or said *adb.exe not found* when DCX sits in such a folder** | Fixed. The files are UTF-8, and a double-click opens them at the PC's default code page, which read «Телефон Ивана» as `╨ó╨╡╨╗╨╡╤ä...` - and still printed `[OK]`. Run from DCX's Restore they were always right. Every generated file now switches to UTF-8 on its second line and puts the window's code page back when it ends. A file from an older DCX: run it from **Restore**, or add `chcp 65001 >nul` as its second line. |
| **A diff showed broken letters, like `Теле�?он`** | Fixed. `fc` damages UTF-8 letters whose bytes fall in 0x80-0x9F - half the Cyrillic alphabet - in every code page. The report diff, the snapshot diff and the Restore preview now list the lines only in the older and only in the newer file, read and written as UTF-8. |
| **Kill all stopped my keyboard, launcher or accessibility service — or an alarm did not ring** | Fixed. Kill all force-stopped every third-party app except four, with no list and no confirmation, and a force-stopped app gets no notifications or alarms until it is opened again. It now asks the phone for the keyboard, the launcher, the accessibility services, and the default dialer and SMS app, and skips them. It lists what it will stop and warns first, and nothing happens without **Y**. |
| **DCX used a whole CPU core and never ended when it was started with its input redirected** | Fixed. `set /p` cannot tell a closed input from an Enter, so every menu that asks again on an empty answer looped for good. DCX now counts empty answers in a row. Any real answer resets the count, and at 100 it says the input looks closed and stops, without closing the console it was started from. |
| **Benchmark storage numbers were far too fast** | Fixed. The write was never flushed and the read came straight back from RAM. See [Benchmark](#benchmark). |
| **UI size "100 %" doubled the UI after a resolution preset** | Fixed. With a resolution override active (say the 50 % preset), option **[2] 100 % UI** showed the density that matches that resolution but applied the panel's physical density, which is twice as large at 50 %. It now applies the figure it shows. |
| **A package name with odd characters did something strange, or the window closed** | Fixed — package names are free text, and they used to reach `adb shell … %pkg%` through *immediate* expansion, so a name containing `&`, `\|`, `<` or `>` was parsed by cmd as an operator instead of passed as data. Every use is now late-expanded (`!pkg!`), which makes those characters literal, and a charset check runs before the value reaches adb at all. Note the old "is it installed?" probe could never have caught this: that line expanded the value too. |
| **Backup/undo `.bat` flashes and closes / says `Add was unexpected at this time.`** | Fixed — help text used `1) Add …` inside an `if ( )` block (cmd treated `1)` as the end of the block), and undo lines could land *after* `:dcx_hold` so a double-click exited before any restores. New scripts use `[1]`/`[2]`/`[3]`, put helpers before `:dcx_main`, and always pause unless `/nopause`. Re-run **Backup** or a Tweaks write to regenerate; or use Tweaks → **[14]** on the repaired session undo. |
| **Running undo/restore from DCX closed the whole DCX window** | Fixed — DCX now launches those scripts with `cmd /c … /nopause` so the child cannot take over (or kill) the menu console. |
| **Standalone backup/undo can’t find adb / restores nothing** | Fixed — scripts embed DCX’s `adb.exe` path (plus `dcx_adb_path.txt` / PATH). If adb is still missing they print `[ERROR]` and wait. Regenerate under current DCX if an old file still calls bare `adb`. |
| **Want to undo everything** | **Restore** a backup, or run the undo script a Tweaks/Explorer write left in `dcx_backups\`, or reboot for non-persistent changes. |
| **Every command says `more than one device/emulator`** | Fixed — DCX now sets `ANDROID_SERIAL` to a device you pick, so adb stops guessing. It asks on startup and after any Wireless-ADB change; you can re-pick any time from **Wireless ADB → [7] Select target device**. The usual cause is *Enable over USB*, which deliberately leaves the phone connected by cable **and** Wi-Fi at once. |
| **The SurfaceFlinger Hz profiles, and Auto Setup's SurfaceFlinger step, are gone** | Retired, not broken. They wrote `debug.sf.*` values that SurfaceFlinger reads only when it starts. Without root, the only restart is a reboot, and a reboot clears those values first. So they changed nothing, while saying *Done*. **Optimize → SurfaceFlinger offsets → Remove** still clears values an older DCX set. |
| **Colours / alignment look wrong** | Use Windows Terminal or a recent `cmd.exe`; very old consoles don't render ANSI colours or box characters. |

---

## Credits

- **AnOrmaluser12** — original author ([@AnOrmaluser12](https://github.com/AnOrmaluser12))
- **S1nt3r** — updates and fixes

DCX is provided **as-is, with no warranty**. You are responsible for any changes you apply to your device.

---

## License & Media Notice

This project's source code is licensed under the **GNU GPLv3**.

Exception: the image file [4152900.jpg] is excluded from the GPL-3.0 license.
It is owned by its respective creator and is included strictly for personal, non-commercial display. 
If you fork or reuse this project, you must remove or replace this image.
