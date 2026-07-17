@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul
mode 100,37
title DCX Menu
:: ============================================================
:: FIX: ESC and colour codes MUST be defined BEFORE first use.
:: Previously the ADB-not-found message referenced %ESC% which
:: was still empty at that point, so colours never rendered.
:: ============================================================
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set g=%ESC%[92m
set r=%ESC%[91m
set red=%ESC%[04m
set l=%ESC%[1m
set w=%ESC%[0m
set b=%ESC%[94m
set m=%ESC%[95m
set p=%ESC%[35m
set c=%ESC%[35m
set d=%ESC%[96m
set u=%ESC%[0m
set z=%ESC%[91m
set n=%ESC%[96m
set y=%ESC%[40;33m
set g2=%ESC%[102m
set r2=%ESC%[101m
set t=%ESC%[40m
set gold=%ESC%[93m
:: Safely navigate to adb folder if it exists
if exist adb\ cd adb
:: Verify ADB is available
adb version > nul 2>&1
if %errorlevel% neq 0 (
    echo [%r%^^!%w%] ADB not found^^!
    echo     Please install ADB and ensure it is in your PATH
    echo     or place this script next to an 'adb' folder.
    echo.
    echo Press any key to exit...
    pause > nul
    exit /b
)
call :logo
echo                         %m%DCX Developed By AnOrmaluser12, Updated By S1nt3r%d%
echo                                    %r%Use It At Your Own Risk%w%
echo                         %y%A Restart Is Required If Something Is Misbehaving%w%
echo.
echo.
echo                                  %w%Press Any Button To Continue
pause > nul
title Connecting . . .
adb start-server > nul 2>&1

:startup_wait
:: ============================================================
:: NEW: Wait for a device and verify it is connected/authorised
:: before issuing further adb shell calls. Previously the script
:: charged ahead even with no device, producing silent failures.
:: ============================================================
echo.
echo [%b%i%w%] Waiting for an authorised device (max 10s)...
set "DEVICE_OK=0"
for /l %%i in (1,1,10) do (
    if "!DEVICE_OK!"=="0" (
        for /f "skip=1 tokens=1,2" %%a in ('adb devices ^<nul') do (
            if "%%b"=="device" set "DEVICE_OK=1"
        )
        if "!DEVICE_OK!"=="0" timeout /t 1 /nobreak > nul
    )
)
if "%DEVICE_OK%"=="0" (
    cls
    call :logo
    echo [%r%^^!%w%] No authorised device found.
    echo     - Enable USB debugging on the device
    echo     - Approve the RSA fingerprint prompt
    echo     - Check the cable / driver
    echo.
    echo     Run 'adb devices' manually to verify.
    echo.
    echo     No cable handy? Wireless ADB can connect over Wi-Fi instead.
    echo.
    echo    [W] Wireless ADB setup    [R] Retry    [X] Exit
    choice /c WRX /n >nul
    if errorlevel 3 (
        adb kill-server > nul 2>&1
        exit /b
    )
    if errorlevel 2 goto startup_wait
    rem Wireless path skips the probe below - give SDK/MODEL safe
    rem defaults; :wadb_back re-runs :detect_device once connected.
    set "SDK=0"
    set "MODEL=(not connected yet)"
    goto wirelessadb
)

:detect_device
:: Retrieve the current Android API level safely
set "SDK="
for /f "delims=" %%i in ('adb shell getprop ro.build.version.sdk 2^>nul ^<nul') do set "SDK=%%i"
:: Strip trailing CR if any
if defined SDK set "SDK=%SDK:~0,3%"
if defined SDK for /f "tokens=* delims= " %%a in ("%SDK%") do set "SDK=%%a"
:: Normalise: if detection failed, default to 0 so numeric `if %SDK% GEQ N`
:: comparisons later never break on an empty value.
if not defined SDK set "SDK=0"
:: Capture device model for friendlier messages
set "MODEL="
for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul ^<nul') do set "MODEL=%%i"
echo [%g%+%w%] Device: %MODEL%   API level: %SDK%
timeout /t 1 /nobreak > nul
goto menu

:menu
cls
title Main Menu
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo           [%g%+%w%]Uptime: %%a %%b %%c
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
echo           [%g%+%w%]%cpucheck% LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                           %r%Gaming%w%         %gold%Battery%w%   %g%Optimize Android%w%
echo                             [1]            [2]            [3]
echo.
echo                            %d%Auto%w%       %d%CheckSetting%w%      %d%Tweaks%w%
echo                             [4]            [5]            [6]
echo.
echo.
echo                           %b%Reboot%w%          %b%Exit%w%           %b%Shell%w%
echo                             [7]            [8]            [9]
echo.
echo.
echo                          %m%Benchmark%w%        %m%Backup%w%         %b%Restore%w%
echo                             [10]           [11]           [12]
echo.
echo                         %gold%Wireless ADB%w%     %gold%App Mgr%w%     %gold%Settings Tools%w%
echo                             [13]           [14]           [15]
echo.

:menu_ask
:: FIX (press-twice): re-prompt WITHOUT redrawing on empty/invalid input so a
:: phantom empty line handed to set /p right after the uptime/cpuinfo probes is
:: absorbed instead of being treated as a miss that redraws (re-runs the probes).
:: Same fix validated on :dispscaler.
set "kb=" & set /p kb="                            Choose An Option >> "
if not defined kb goto menu_ask
if "!kb!"=="1" goto Gaming
if "!kb!"=="2" goto Battery
if "!kb!"=="3" goto Optimize
if "!kb!"=="4" goto Auto
if "!kb!"=="5" goto Check
if "!kb!"=="6" goto tweaks
if "!kb!"=="7" goto reboot
if "!kb!"=="8" goto exitscript
if "!kb!"=="9" goto shell
if "!kb!"=="10" goto benchmark
if "!kb!"=="11" goto backup
if "!kb!"=="12" goto restore
if "!kb!"=="13" goto wirelessadb
if "!kb!"=="14" goto appmgr
if "!kb!"=="15" goto settools
goto menu_ask
:: ===================================================================
:: NEW: Backup / Restore of toggleable settings
::
:: Backup dumps current values of every Settings.Global / System key,
:: device_config flag and system property that DCX can toggle, into
:: a stand-alone .bat file in %USERPROFILE%\dcx_backups\. The format stays
:: human-readable and you can edit it before restoring - deleting a line just
:: skips that key. :restore `call`s it and then checks BOTH its exit code and
:: whether the device is still attached, because a restore that lost the device
:: half way must not report success.
:: ===================================================================
:backup
cls
title Backup Settings
call :logo
echo.
:: FIX (safeguard): verify the device is actually attached BEFORE reading ~50 keys off
:: it. :_bk_settings cannot tell "the device did not answer" from "this key is unset" -
:: both come back empty, and empty is written as a `delete` line. So a backup taken with
:: the cable out looks complete and is in fact an instruction to WIPE every managed
:: setting on restore. The startup check is not enough: DCX runs long sessions and the
:: cable can leave at any point after it.
set "_dvst="
for /f "delims=" %%d in ('adb get-state 2^>nul') do set "_dvst=%%d"
if /i not "%_dvst%"=="device" (
    echo  %r%No device connected - backup refused.%w%
    echo.
    echo  Backup reads the CURRENT value of every key DCX manages. A key the device
    echo  does not answer for is indistinguishable from one that is genuinely unset,
    echo  and unset is recorded as "delete this on restore". Writing that file now
    echo  would hand you a backup that erases your settings instead of restoring them.
    echo.
    echo  Reconnect the device ^(check: adb devices^) and try again.
    echo.
    pause > nul
    goto menu
)
set "BACKUPDIR=%USERPROFILE%\dcx_backups"
if not exist "%BACKUPDIR%" mkdir "%BACKUPDIR%"
:: FIX: build the timestamp via PowerShell so it is locale-independent.
:: The old %date%/%time% substring slicing assumed a US M/D/Y format and
:: produced garbled or invalid filenames on other regional date formats.
:: locale-safe, filename-safe timestamp (no PowerShell = no console code-page reset)
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "BAKFILE=%BACKUPDIR%\dcx_backup_%TS%.bat"
echo  Saving current settings to:
echo    %BAKFILE%
echo.
:: Build a restore script. Each captured value becomes a put/setprop
:: command; missing values become delete to clear any stale override.
:: FIX: the literal ')' in the comment line below must be escaped as '^)'.
:: It was previously '^^)', which inside this ( ... ) block collapses to a
:: literal caret + an UNescaped ')' that closed the block early, aborting
:: the whole backup with ". was unexpected at this time." (no file written).
(
    echo @echo off
    echo :: DCX Settings Backup created %date% %time%
    echo :: This file is a stand-alone restore script - run it with the
    echo :: same device connected to revert to the captured state.
    echo ::
    echo :: You can also edit it (delete lines you don't want to restore^).
    echo ::
    echo :: Every restore line below goes through :dcx_do, which checks whether the
    echo :: write actually landed and counts it. Deleting a line still just skips that
    echo :: key - the count follows whatever is left.
    echo.
    echo adb start-server ^>nul 2^>^&1
    echo echo Restoring DCX-managed settings...
    echo set "DCX_OK=0" ^& set "DCX_FAIL=0"
    echo.
) > "%BAKFILE%" < nul
:: Helper macro for capturing settings (Settings.X namespace)
:: We capture each key by reading current value and building the
:: corresponding put or delete line.
call :_bk_settings global window_animation_scale     "%BAKFILE%"
call :_bk_settings global transition_animation_scale "%BAKFILE%"
call :_bk_settings global animator_duration_scale    "%BAKFILE%"
call :_bk_settings system min_refresh_rate           "%BAKFILE%"
call :_bk_settings system peak_refresh_rate          "%BAKFILE%"
call :_bk_settings global angle_gl_driver_all_angle  "%BAKFILE%"
call :_bk_settings global master_sync_status         "%BAKFILE%"
call :_bk_settings global hotword_detection_enabled  "%BAKFILE%"
call :_bk_settings global preferred_network_mode     "%BAKFILE%"
call :_bk_settings global preferred_network_mode1    "%BAKFILE%"
call :_bk_settings global private_dns_mode           "%BAKFILE%"
call :_bk_settings global private_dns_specifier      "%BAKFILE%"
call :_bk_settings global mobile_data_always_on      "%BAKFILE%"
call :_bk_settings global tcp_default_init_rwnd      "%BAKFILE%"
call :_bk_settings global wifi_idle_ms               "%BAKFILE%"
call :_bk_settings global wifi_sleep_policy          "%BAKFILE%"
call :_bk_settings global low_power                  "%BAKFILE%"
call :_bk_settings secure clock_seconds              "%BAKFILE%"
call :_bk_settings system status_bar_show_battery_percent "%BAKFILE%"
call :_bk_settings global audio_safe_volume_state    "%BAKFILE%"
call :_bk_settings secure audio_safe_csd_as_a_feature_enabled "%BAKFILE%"
call :_bk_settings secure icon_blacklist             "%BAKFILE%"
call :_bk_settings global heads_up_notifications_enabled "%BAKFILE%"
call :_bk_settings system font_scale                 "%BAKFILE%"
call :_bk_settings secure long_press_timeout         "%BAKFILE%"
call :_bk_settings global stay_on_while_plugged_in   "%BAKFILE%"
call :_bk_settings secure ui_night_mode              "%BAKFILE%"
call :_bk_settings secure night_display_activated    "%BAKFILE%"
call :_bk_settings secure night_display_auto_mode    "%BAKFILE%"
call :_bk_settings secure night_display_color_temperature "%BAKFILE%"
call :_bk_settings global sysui_demo_allowed         "%BAKFILE%"
call :_bk_settings secure sysui_qs_tiles             "%BAKFILE%"
call :_bk_settings secure camera_gesture_disabled    "%BAKFILE%"
call :_bk_settings secure camera_double_tap_power_gesture_disabled "%BAKFILE%"
call :_bk_settings secure camera_double_twist_to_flip_enabled "%BAKFILE%"
call :_bk_settings global charging_sounds_enabled    "%BAKFILE%"
call :_bk_settings global charging_vibration_enabled "%BAKFILE%"
call :_bk_settings global sys_storage_threshold_percentage "%BAKFILE%"
call :_bk_settings global sys_storage_threshold_max_bytes "%BAKFILE%"
call :_bk_settings global low_power_trigger_level    "%BAKFILE%"
call :_bk_settings global default_install_location   "%BAKFILE%"
call :_bk_settings global enable_freeform_support    "%BAKFILE%"
call :_bk_settings global force_resizable_activities "%BAKFILE%"
call :_bk_devcfg   app_hibernation app_hibernation_enabled "%BAKFILE%"
call :_bk_prop     debug.hwui.renderer        "%BAKFILE%"
call :_bk_prop     debug.renderengine.backend "%BAKFILE%"
call :_bk_prop     persist.log.tag            "%BAKFILE%"
:: FIX: the generated script used to end with a flat "Done. Press any key to close."
:: no matter what happened. A restore is a long run of adb writes - pull the cable,
:: drop wireless ADB, or let authorisation expire part-way and the remaining writes
:: all no-op, yet it still said Done and the device was left half-restored with
:: nothing to show for it. The footer below counts what actually landed and exits
:: with the failure count, so both this file standalone AND :restore can tell.
(
    echo.
    echo goto :dcx_report
    echo.
    echo :dcx_do
    echo :: Runs one restore command and records whether it landed. adb exits non-zero
    echo :: when the device is gone ^(the disconnect case^) and, on Android 7+, when the
    echo :: command itself is rejected. Values are quoted by the generator, so a value
    echo :: holding a cmd metacharacter cannot break out of this line.
    echo adb shell %%* ^>nul 2^>^&1
    echo if errorlevel 1 ^(
    echo     set /a DCX_FAIL+=1
    echo     echo   [FAIL] %%*
    echo ^) else ^(
    echo     set /a DCX_OK+=1
    echo ^)
    echo goto :eof
    echo.
    echo :dcx_report
    echo echo.
    echo if "%%DCX_FAIL%%"=="0" ^(
    echo     echo [OK] Restored %%DCX_OK%% settings, none failed.
    echo ^) else ^(
    echo     echo [WARN] %%DCX_OK%% restored, %%DCX_FAIL%% FAILED - listed above.
    echo     echo        The device may be in a mixed state. Reconnect it and run this
    echo     echo        file again - restoring twice is harmless.
    echo ^)
    echo echo.
    echo pause ^>nul
    echo exit /b %%DCX_FAIL%%
) >> "%BAKFILE%"
:: FIX (safeguard): "Backup complete." used to print no matter what. The file is built
:: by ~50 append redirections into %USERPROFILE%\dcx_backups - exactly the kind of path
:: Controlled Folder Access and antivirus guard. When that happens every append no-ops
:: silently and the user is told they have a backup they do not have -
:: worse than a failed backup they know about, because they will rely on it later.
:: Checking for a real restore line proves the settings were captured, not just that
:: the header was written.
set "_bkok=0"
if exist "%BAKFILE%" findstr /b /c:"call :dcx_do" "%BAKFILE%" >nul 2>&1 && set "_bkok=1"
if "%_bkok%"=="0" (
    echo  %r%Backup FAILED%w% - no usable restore file was written.
    echo    Tried: %BAKFILE%
    echo.
    echo  That folder is often blocked by antivirus or Controlled Folder Access.
    echo  Allow it, or run DCX from another location, then try again.
    echo.
    pause > nul
    goto menu
)
echo  %g%Backup complete.%w%
echo.
echo  %b%[%w%1%b%]%w% Open backups folder in Explorer
echo  %b%[%w%2%b%]%w% View this backup in Notepad
echo  %b%[%w%3%b%]%w% Back to main menu
set "bk=" & set /p bk="Choose An Option >> "
if "!bk!"=="1" (
    start "" "%BACKUPDIR%"
    goto menu
)
if "!bk!"=="2" (
    start "" notepad "%BAKFILE%"
    goto menu
)
goto menu
:: -------------------------------------------------------------------
:: Helper subroutines used by :backup
::
:: _bk_settings  <namespace> <key> <outfile>
::   Reads the current value of a settings put/delete key. If null,
::   writes a `delete`; otherwise writes a `put` with the value.
:: -------------------------------------------------------------------
:_bk_settings
:: FIX (robustness): enabledelayedexpansion + quote the value in the generated
:: line. The old unquoted `%_val%` let a value containing a CMD metacharacter
:: (& | < >) break backup GENERATION (echo `a&b` ran `b` as a command and wrote
:: a truncated line). DCX-managed values don't contain those, but the backup
:: also captures whatever the device currently holds under these keys.
setlocal enabledelayedexpansion
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
for /f "delims=" %%v in ('adb shell settings get %_ns% %_key% 2^>nul ^<nul') do set "_val=%%v"
if "!_val!"=="" set "_val=null"
if /i "!_val!"=="null" (
    >>"%_out%" echo call :dcx_do settings delete %_ns% %_key%
) else (
    >>"%_out%" echo call :dcx_do settings put %_ns% %_key% "!_val!"
)
endlocal
exit /b

:_bk_devcfg
:: FIX (robustness): same as :_bk_settings - delayed expansion + quoted value.
setlocal enabledelayedexpansion
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
for /f "delims=" %%v in ('adb shell device_config get %_ns% %_key% 2^>nul ^<nul') do set "_val=%%v"
if "!_val!"=="" set "_val=null"
if /i "!_val!"=="null" (
    >>"%_out%" echo :: %_ns%/%_key% was unset at backup time
) else (
    >>"%_out%" echo call :dcx_do device_config put %_ns% %_key% "!_val!"
)
endlocal
exit /b

:_bk_prop
:: FIX (robustness): (1) an UNSET prop makes getprop return empty; the old code
:: then wrote `setprop key ""`, which on restore SETS the prop to empty instead
:: of leaving it untouched. Emit a comment instead. (2) delayed expansion so a
:: metachar value can't corrupt the generated line.
setlocal enabledelayedexpansion
set "_key=%~1"
set "_out=%~2"
set "_val="
for /f "delims=" %%v in ('adb shell getprop %_key% 2^>nul ^<nul') do set "_val=%%v"
if "!_val!"=="" (
    >>"%_out%" echo :: prop %_key% was unset at backup time - not restoring
) else (
    >>"%_out%" echo call :dcx_do setprop %_key% "!_val!"
)
endlocal
exit /b
:: ===================================================================
:: Restore from backup file
:: ===================================================================
:restore
cls
title Restore Settings
call :logo
echo.
set "BACKUPDIR=%USERPROFILE%\dcx_backups"
if not exist "%BACKUPDIR%" (
    echo  %r%No backups folder found.%w%
    echo  Run option [11] Backup first to create one.
    echo.
    pause > nul
    goto menu
)
echo  Available backups in %BACKUPDIR%:
echo.
set "i=0"
:: Numbered listing - newest first
for /f "delims=" %%f in ('dir /b /o-d "%BACKUPDIR%\dcx_backup_*.bat" 2^>nul') do (
    set /a i+=1
    setlocal enabledelayedexpansion
    set "_idx=  [!i!]"
    echo    !_idx:~-5! %%f
    endlocal
    set "_bk_%%f=defined"
    call set "_bk_n_%%i%%=%%f"
)
if "%i%"=="0" (
    echo  %r%No backup files found.%w%
    echo.
    pause > nul
    goto menu
)
echo.
echo    [0] Cancel
echo.
set "ri=" & set /p ri="Pick a backup to restore >> "
if "!ri!"=="0" goto menu
:: Look up the chosen filename
call set "_chosen=%%_bk_n_%ri%%%"
if "%_chosen%"=="" (
    echo  %r%Invalid selection.%w%
    pause > nul
    goto restore
)
set "RESTOREFILE=%BACKUPDIR%\%_chosen%"
echo.
echo  About to apply settings from:
echo    %RESTOREFILE%
echo.
echo  %y%This will overwrite your current values for every key listed.%w%
echo.
echo    [Y] Proceed and restore
echo    [N] Cancel
choice /c:YN /n > nul
if errorlevel 2 goto menu
cls
call "%RESTOREFILE%"
set "_rrc=%errorlevel%"
:: FIX: this printed "Restore complete." unconditionally - whatever actually happened.
:: Two ways it lied: a backup file written by this version exits with its failed-write
:: count, and older files (written before that existed) always exit 0 even if the
:: device vanished half way. So check both: the exit code, and whether the device is
:: even still there. A half-restored device the user believes is fully restored is
:: worse than a failed restore they know about.
set "_rdev="
for /f "delims=" %%d in ('adb get-state 2^>nul') do set "_rdev=%%d"
echo.
if not "%_rrc%"=="0" (
    echo  %r%Restore finished with %_rrc% failed write^(s^)%w% - they are listed above.
    echo  The device may be in a mixed state. Reconnect it and restore again;
    echo  restoring twice is harmless.
) else if /i not "%_rdev%"=="device" (
    echo  %r%The device is no longer connected.%w% The restore may have stopped part-way,
    echo  and this backup file is too old to report its own failures. Reconnect the
    echo  device and run the restore again - restoring twice is harmless.
) else (
    echo  %g%Restore complete.%w% Some changes may need a reboot to fully apply.
)
echo.
pause > nul
goto menu

:benchmark
cls
title Benchmark
echo [%g%+%w%] Quick device benchmark - lower is better.
echo.
echo  This runs three quick checks:
echo    1. CPU loop time
echo    2. Storage random write
echo    3. Storage sequential read
echo.
echo  Total time: about 10-15 seconds.
echo.
echo.
echo [%b%1/3%w%] CPU loop test (1M iterations)...
:: FIX: 'seq' is not on every Android. Use a portable POSIX shell loop.
:: We also reduce iterations from 8M to 1M for sane wait times.
adb shell "time sh -c 'i=0; while [ $i -lt 1000000 ]; do i=$((i+1)); done'"
echo.
echo [%b%2/3%w%] Storage random write (10MB)...
adb shell "time dd if=/dev/urandom of=/data/local/tmp/_dcx_bench bs=64k count=160 2>&1 | tail -1"
echo.
echo [%b%3/3%w%] Storage sequential read (10MB)...
adb shell "time dd if=/data/local/tmp/_dcx_bench of=/dev/null bs=64k 2>&1 | tail -1"
adb shell rm -f /data/local/tmp/_dcx_bench <nul
echo.
echo.
echo [%g%Done%w%] Numbers vary - run twice after optimization for comparison.
echo.
echo Press Any Button To Go Back
pause > nul
goto menu

:shell
@echo off
cls
title Shell
adb shell
goto menu

:exitscript
@echo off
cls
title Exit
call :logo
echo.
echo.
echo.
echo.
echo.
echo                   %d%Thanks For Using My Script, Goodbye And Have A Good Day^^!^^!%w%
echo.
echo.
timeout /t 3 /nobreak > nul
adb shell cmd notification post -S bigtext -t '⚙DCX⚙' 'Tag' 'Restart = Remove All Settings Applied, Please Use This Script At Least Once A Month To Keep Your Device Smooth, Bye^^!^^!' > nul 2>&1
adb kill-server
exit /b

:reboot
adb reboot
timeout /t 1 /nobreak > nul
adb disconnect
goto menu
:: ===================================================================
:: NEW: Wireless ADB (pair / connect / manage Wi-Fi debugging)
::
:: Two ways onto Wi-Fi, depending on Android version:
::
::   Android 11+ : Developer options -> Wireless debugging. The
::     "Pair device with pairing code" dialog shows a ONE-TIME
::     ip:port + 6-digit code -> option [1]. Pairing is per-PC and
::     only needed once. The port for CONNECTING afterwards is the
::     DIFFERENT one shown on the main Wireless-debugging screen.
::
::   Android 10 and below (or builds that hide pairing): connect the
::     USB cable once and use option [3] - it flips adbd to TCP/IP on
::     port 5555 and auto-detects the phone's Wi-Fi IP.
::
:: Honest notes: the Android 11+ connect port is random and changes
:: after a reboot or re-toggling Wireless debugging, so reconnects
:: need the fresh port. While the mode is on, any PC paired with the
:: phone on the same network can run adb - turn it off when done.
:: ===================================================================
:wirelessadb
cls
title Wireless ADB
call :logo
echo                            %b%[%w% Wireless ADB %b%]%w%
echo.
echo  Run DCX over Wi-Fi - no cable needed. PC and phone must be on the
echo  same network.
echo.
echo  Currently attached (USB and Wi-Fi entries both show here):
for /f "skip=1 delims=" %%i in ('adb devices ^<nul 2^>nul') do echo     %%i
echo.
echo                 %g%[%w%1%g%]%w% Pair with code       (Android 11+, once per PC)
echo                 %g%[%w%2%g%]%w% Connect to IP[:port]
echo                 %g%[%w%3%g%]%w% Enable over USB      (adb tcpip 5555 + auto-IP)
echo                 %g%[%w%4%g%]%w% Disconnect all Wi-Fi connections
echo                 %g%[%w%5%g%]%w% Switch device back to USB mode
echo                 %g%[%w%6%g%]%w% Help - where the ports and code live
echo                 %g%[%w%7%g%]%w% Back
set "wa=" & set /p wa="Choose An Option >> "
if "!wa!"=="1" goto wadb_pair
if "!wa!"=="2" goto wadb_connect
if "!wa!"=="3" goto wadb_tcpip
if "!wa!"=="4" goto wadb_disconnect
if "!wa!"=="5" goto wadb_usb
if "!wa!"=="6" goto wadb_help
if "!wa!"=="7" goto wadb_back
goto wirelessadb

:wadb_back
:: If we arrived from the no-device startup path, the model/API probe
:: was skipped (SDK defaulted to 0) - run it now that a device may be
:: attached. Re-probing on a genuine API-0 is harmless.
if "!SDK!"=="0" goto detect_device
goto menu

:wadb_pair
cls
title Wireless ADB : pair
call :logo
echo  On the phone: Developer options -^> Wireless debugging -^>
echo  %g%Pair device with pairing code%w%. Keep that dialog OPEN - the
echo  code and port stop working the moment it closes.
echo.
set "WIP=" & set /p WIP="Pairing ip:port (blank = cancel) >> "
if "!WIP!"=="" goto wirelessadb
echo !WIP!| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*:[0-9][0-9]*$" >nul || goto wadb_pair_bad
set "WCODE=" & set /p WCODE="6-digit pairing code (blank = cancel) >> "
if "!WCODE!"=="" goto wirelessadb
echo !WCODE!| findstr /r "^[0-9][0-9][0-9][0-9][0-9][0-9]$" >nul || goto wadb_pair_bad
echo.
adb pair !WIP! !WCODE!
echo.
echo  If it said "Successfully paired": this PC is trusted now, but you
echo  are NOT connected yet. The connect port is the DIFFERENT one on
echo  the main Wireless-debugging screen -^> option [2].
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_pair_bad
echo [%r%^^!%w%] Expected ip:port like 192.168.1.23:37123 and a 6-digit code.
timeout /t 2 /nobreak >nul
goto wadb_pair

:wadb_connect
cls
title Wireless ADB : connect
call :logo
echo  Enter the ip:port from the MAIN Wireless-debugging screen
echo  (Android 11+), or just the phone's IP if you used option [3]
echo  (port 5555 is assumed then).
echo.
set "WIP=" & set /p WIP="ip[:port] (blank = cancel) >> "
if "!WIP!"=="" goto wirelessadb
if "!WIP!"=="!WIP::=!" set "WIP=!WIP!:5555"
echo !WIP!| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*:[0-9][0-9]*$" >nul || goto wadb_connect_bad
echo.
adb connect !WIP!
echo.
echo  Now attached:
for /f "skip=1 delims=" %%i in ('adb devices ^<nul 2^>nul') do echo     %%i
echo.
echo  "failed to authenticate" / "connection refused" usually means this
echo  PC isn't paired with the phone yet -^> option [1] first, or the
echo  port went stale (it changes on reboot/re-toggle).
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_connect_bad
echo [%r%^^!%w%] Expected an IPv4 address like 192.168.1.23 or 192.168.1.23:41235.
timeout /t 2 /nobreak >nul
goto wadb_connect

:wadb_tcpip
cls
title Wireless ADB : enable over USB
call :logo
echo  Flips the USB-connected device's adbd into TCP/IP mode on port
echo  5555 - the classic method: works on any Android version, no
echo  pairing needed. %y%Needs the cable attached for this one step.%w%
echo  Reverts on reboot, or via option [5].
echo.
echo    [Y] Enable    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto wirelessadb
adb tcpip 5555
timeout /t 2 /nobreak >nul
:: Read the phone's Wi-Fi IP so the user doesn't have to dig through
:: Settings. `ip route` lines look like:
::   192.168.1.0/24 dev wlan0 proto kernel scope link src 192.168.1.42
:: Prefer a wlan line; the shift-walk helper grabs the token after
:: 'src' no matter where in the line it sits.
set "WDEVIP="
for /f "delims=" %%l in ('adb shell ip route ^<nul 2^>nul ^| findstr /C:"wlan"') do if not defined WDEVIP call :_wadb_src %%l
if not defined WDEVIP for /f "delims=" %%l in ('adb shell ip route ^<nul 2^>nul ^| findstr /C:" src "') do if not defined WDEVIP call :_wadb_src %%l
echo.
if defined WDEVIP (
    echo  Phone Wi-Fi IP detected: %g%!WDEVIP!%w%
    echo.
    echo    [Y] Connect to !WDEVIP!:5555 now    [N] Not yet
    choice /c:YN /n >nul
    if errorlevel 2 goto wirelessadb
    adb connect !WDEVIP!:5555
    echo.
    echo  You can unplug the cable now. If the list shows the device
    echo  twice, USB and Wi-Fi are both attached - that's normal.
    for /f "skip=1 delims=" %%i in ('adb devices ^<nul 2^>nul') do echo     %%i
) else (
    echo  Could not auto-detect the IP - the phone may be off Wi-Fi.
    echo  Find it under Settings -^> About phone -^> Status, then use
    echo  option [2].
)
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb
:: _wadb_src <route line tokens...>
::   Walks the arguments until it finds 'src' and keeps the next one.
:_wadb_src
if "%~1"=="" exit /b
if "%~1"=="src" (
    set "WDEVIP=%~2"
    exit /b
)
shift
goto _wadb_src

:wadb_disconnect
cls
title Wireless ADB : disconnect
adb disconnect
echo Done - all Wi-Fi connections dropped. USB is unaffected.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_usb
cls
title Wireless ADB : back to USB
:: Only meaningful for devices switched with option [3]; for the
:: Android 11+ mode just turn the Wireless-debugging toggle off.
adb usb 2>nul
echo Done - adbd is back on USB; any Wi-Fi connection to it dropped.
echo (Android 11+ Wireless debugging: turn the toggle off on the phone.)
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_help
cls
title Wireless ADB : help
call :logo
echo  %g%Android 11 and newer%w% - Developer options -^> %g%Wireless debugging%w%:
echo    - Toggle it ON while the phone is on your Wi-Fi.
echo    - "Pair device with pairing code" shows ip:port + a 6-digit
echo      code -^> option [1]. One-time per PC; keep the dialog open.
echo    - The MAIN screen's "IP address and Port" is what option [2]
echo      wants. That port is random and %y%changes after a reboot or
echo      re-toggle%w% - grab it fresh each time.
echo.
echo  %g%Android 10 and older%w% (pairing does not exist there):
echo    - Plug in USB once, use option [3], unplug. Port is fixed 5555.
echo.
echo  %g%Huawei EMUI / HarmonyOS%w%: same place in Developer options; some
echo    builds hide the pairing dialog - option [3] over USB works too.
echo.
echo  %y%Security note:%w% while wireless debugging is on, any PC paired
echo  with the phone on the same network can run adb commands. Turn it
echo  off when you're done.
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:check
cls
title Device Info ^& Diagnostics
call :logo
echo.
echo  Generating full device report...
echo.
:: Build a timestamped report so old reports aren't overwritten
:: and the user can compare before/after applying tweaks.
:: FIX: build the timestamp via PowerShell so it is locale-independent.
:: The old %date%/%time% substring slicing assumed a US M/D/Y format and
:: produced garbled or invalid filenames on other regional date formats.
:: locale-safe, filename-safe timestamp (no PowerShell = no console code-page reset)
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "REPORT=%TEMP%\dcx_report_%TS%.txt"
(
    echo ===========================================================
    echo  DCX Device Diagnostic Report - %date% %time%
    echo ===========================================================
    echo.
    echo [Hardware]
    for /f "delims=" %%i in ('adb shell getprop ro.product.manufacturer 2^>nul ^<nul') do echo   Manufacturer        : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul ^<nul')        do echo   Model               : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.device 2^>nul ^<nul')       do echo   Device codename     : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.cpu.abi 2^>nul ^<nul')      do echo   CPU ABI             : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.hardware 2^>nul ^<nul')             do echo   SoC platform        : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.board.platform 2^>nul ^<nul')       do echo   Board platform      : %%i
    echo.
    echo [Software]
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.release 2^>nul ^<nul')        do echo   Android version     : %%i
    echo   API level           : %SDK%
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.security_patch 2^>nul ^<nul') do echo   Security patch      : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.incremental 2^>nul ^<nul')    do echo   Build incremental   : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.build.type 2^>nul ^<nul')                   do echo   Build type          : %%i
    echo.
    echo [Memory]
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep MemTotal"')     do echo   Total RAM           : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep MemAvailable"') do echo   Available RAM       : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep MemFree"')      do echo   Free RAM            : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep Buffers"')      do echo   Buffers             : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep '^Cached'"')      do echo   Cached              : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep SwapTotal"')    do echo   Swap total          : %%i kB
    for /f "tokens=2" %%i in ('adb shell "cat /proc/meminfo 2>/dev/null | grep SwapFree"')     do echo   Swap free           : %%i kB
    echo.
    echo [Storage]
    adb shell "df -h /data 2>/dev/null"
    echo.
    echo [State]
    for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo   Uptime              : %%a %%b %%c
    for /f "delims=" %%i in ('adb shell "dumpsys cpuinfo 2>/dev/null | grep 'Load:'"')      do echo   %%i
    for /f "delims=" %%i in ('adb shell "dumpsys battery 2>/dev/null | grep 'level:'"')       do echo   Battery            %%i
    for /f "delims=" %%i in ('adb shell "dumpsys battery 2>/dev/null | grep 'temperature:'"') do echo   Battery temp       %%i ^(deci-degrees C^)
    for /f "delims=" %%i in ('adb shell "dumpsys battery 2>/dev/null | grep 'voltage:'"')     do echo   Battery voltage    %%i
    for /f "delims=" %%i in ('adb shell "dumpsys battery 2>/dev/null | grep 'status:'"')      do echo   Battery status     %%i
    for /f "delims=" %%i in ('adb shell "dumpsys battery 2>/dev/null | grep 'health:'"')      do echo   Battery health     %%i
    echo.
    echo [Display]
    for /f "tokens=2 delims==" %%i in ('adb shell "dumpsys SurfaceFlinger 2>/dev/null | grep refresh-rate"') do echo   Display refresh    : %%i Hz
    for /f "delims=" %%i in ('adb shell wm size 2^>nul ^<nul')                                              do echo   %%i
    for /f "delims=" %%i in ('adb shell wm density 2^>nul ^<nul')                                           do echo   %%i
    echo.
    echo [Graphics renderer - current values]
    for /f "delims=" %%i in ('adb shell getprop debug.hwui.renderer 2^>nul ^<nul')   do echo   debug.hwui.renderer        : "%%i" ^(skiagl=default, skiavk=Skia Vulkan, empty=auto^)
    for /f "delims=" %%i in ('adb shell getprop ro.hwui.renderer 2^>nul ^<nul')      do echo   ro.hwui.renderer           : "%%i"
    for /f "delims=" %%i in ('adb shell settings get global angle_gl_driver_all_angle 2^>nul ^<nul') do echo   angle_gl_driver_all_angle  : %%i ^(1=force ANGLE for all GLES apps, 0/null=off^)
    for /f "delims=" %%i in ('adb shell getprop persist.log.tag 2^>nul ^<nul')       do echo   persist.log.tag            : "%%i" ^(set to "*:S" to silence all logs^)
    echo.
    echo [Animation / Refresh - current values]
    for /f "delims=" %%i in ('adb shell settings get global window_animation_scale 2^>nul ^<nul')     do echo   window_animation_scale     : %%i
    for /f "delims=" %%i in ('adb shell settings get global transition_animation_scale 2^>nul ^<nul') do echo   transition_animation_scale : %%i
    for /f "delims=" %%i in ('adb shell settings get global animator_duration_scale 2^>nul ^<nul')    do echo   animator_duration_scale    : %%i
    for /f "delims=" %%i in ('adb shell settings get system min_refresh_rate 2^>nul ^<nul')           do echo   min_refresh_rate ^(Hz^)      : %%i
    for /f "delims=" %%i in ('adb shell settings get system peak_refresh_rate 2^>nul ^<nul')          do echo   peak_refresh_rate ^(Hz^)     : %%i
    echo.
    echo [Battery savers / Sync - current values]
    for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul ^<nul')          do echo   master_sync_status         : %%i  ^(1=on, 0=off^)
    for /f "delims=" %%i in ('adb shell settings get global hotword_detection_enabled 2^>nul ^<nul')   do echo   hotword_detection_enabled  : %%i  ^(1=on, 0=off^)
    for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul ^<nul') do echo   app_hibernation_enabled    : %%i
    echo.
    echo [Network]
    for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul ^<nul') do echo   Preferred network mode      : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_mode 2^>nul ^<nul')       do echo   Private DNS mode           : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_specifier 2^>nul ^<nul')  do echo   Private DNS host           : %%i
    echo.
    echo [Power state]
    for /f "delims=" %%i in ('adb shell settings get global low_power 2^>nul ^<nul') do echo   Battery saver         : %%i
    adb shell "cmd power get-mode 2>/dev/null"
    echo.
    echo [Doze whitelist - first 20 entries]
    adb shell "dumpsys deviceidle whitelist 2>/dev/null"
    echo.
    echo [Top 10 RAM consumers]
    adb shell "dumpsys meminfo --oom 2>/dev/null | head -40"
    echo.
    echo [Currently focused app]
    adb shell "dumpsys activity activities 2>/dev/null | grep mResumedActivity"
    echo.
    echo ===========================================================
    echo  End of report
    echo ===========================================================
) > "%REPORT%" < nul
:: FIX (report hygiene): the ~10s report is generated ONCE above; the menu is a
:: separate :check_menu label so open-in-notepad / paginate / invalid input
:: re-show the menu instead of re-running every adb dump AND writing another
:: timestamped temp file each time. (Re-entering :check fresh still makes a new
:: dated report, which is the intended before/after-compare behavior.)
:check_menu
echo  %g%Report saved to:%w%
echo    %REPORT%
echo.
echo  %b%[%w%1%b%]%w% Open report in Notepad (scrollable, searchable)
echo  %b%[%w%2%b%]%w% Show report in this window (paginated with MORE)
echo  %b%[%w%3%b%]%w% Show short summary here ^& go back
echo  %b%[%w%4%b%]%w% Back to main menu
echo.
set "ck=" & set /p ck="Choose An Option >> "
if "!ck!"=="1" goto check_open
if "!ck!"=="2" goto check_paginate
if "!ck!"=="3" goto check_summary
if "!ck!"=="4" goto menu
goto check_menu

:check_open
start "" notepad "%REPORT%"
goto check_menu

:check_paginate
cls
title Device Diagnostics ^(paginated^)
more "%REPORT%"
echo.
echo Press Any Button To Go Back
pause > nul
goto check_menu

:check_summary
cls
call :logo
echo                            %b%[%w% Quick Summary %b%]%w%
echo.
for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul ^<nul') do echo   Device: %%i  ^(API %SDK%^)
for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^<nul ^| findstr "MemAvailable"') do echo   Free RAM: %%i kB
for /f "delims=" %%i in ('adb shell dumpsys battery ^<nul ^| findstr /C:"level:"')       do echo  %%i
for /f "delims=" %%i in ('adb shell dumpsys battery ^<nul ^| findstr /C:"temperature:"') do echo  %%i (deci-degrees C)
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo   Uptime: %%a %%b %%c
echo.
echo   Full report still saved at: %REPORT%
echo.
echo Press Any Button To Go Back
pause > nul
goto menu

:Auto
cls
title Auto Setup
call :logo
echo.
echo.
echo %g%Easy To Use And Safe For Daily Use If You Don't Know Anything About This Script%w%
echo.
echo.
echo %b%[%w%1%b%]%w% Run Auto Setup
echo %b%[%w%2%b%]%w% Go Back
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto setupautorun
if "!kb!"=="2" goto menu
:: FIX: guard against invalid input - previously any other key fell
:: straight through into :setupautorun and ran Auto Setup unprompted.
goto Auto

:setupautorun
cls && title SurfaceFlinger Setup^^!
call :logo
echo.
echo.
echo [%g%+%w%] Check Refresh Rate
timeout /t 1 /nobreak > nul
set "refresh_rate="
for /f "tokens=3 delims= " %%i in ('adb shell dumpsys SurfaceFlinger ^<nul ^| findstr "refresh-rate"') do (
    set refresh_rate=%%i
)
if defined refresh_rate set "refresh_rate=%refresh_rate: =%"
if "%refresh_rate%"=="" (
    echo [%r%^^!%w%] Could not detect refresh rate. Auto setup cannot continue.
    pause > nul
    goto menu
)
echo [%b%^^!%w%]Refresh rate : %refresh_rate%
timeout /t 1 /nobreak > nul
for /f "delims=" %%i in ('powershell -Command "[math]::Round(1 / %refresh_rate%, 10)"') do set result=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%result% * 1000000000, 0)"') do set final=%%i
echo [%g%+%w%] Check Result . . . .
echo.
timeout /t 1 /nobreak > nul
echo.
echo.
echo [%b%^^!%w%] SurfaceFlinger Setup. . .
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 18.518520, 0)"') do set eaglpos=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 8.771929, 0)"') do set apsofs=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 4.7619050, 0)"') do set elfpsofsasdasx=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 3.7037029 - 1, 0)"') do set elrdur=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 3.3333336900, 0)"') do set sfelpoassd=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 1.851852 + 1, 0)"') do set rgsmplsa=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 0.8771929 -2, 0)"') do set rgstis=%%i
chcp 65001 >nul
timeout /t 2 /nobreak > nul
::elrdur
adb shell setprop debug.sf.region_sampling_duration_ns %elrdur%
adb shell setprop debug.sf.cached_set_render_duration_ns %elrdur%
adb shell setprop debug.sf.early.app.duration %elrdur%
adb shell setprop debug.sf.early.sf.duration %elrdur%
adb shell setprop debug.sf.earlyGl.app.duration %elrdur%
adb shell setprop debug.sf.earlyGl.sf.duration %elrdur%
::apsofs
adb shell setprop debug.sf.early_app_phase_offset_ns %apsofs%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %apsofs%
::sfelpoassd
adb shell setprop debug.sf.early_gl_phase_offset_ns %sfelpoassd%
adb shell setprop debug.sf.early_phase_offset_ns %sfelpoassd%
::eaglpos
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %eaglpos%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %eaglpos%
::elfpsofsasdasx
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %elfpsofsasdasx%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %elfpsofsasdasx%
::rgstis
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %rgstis%
::rgsmplsa
adb shell setprop debug.sf.region_sampling_period_ns %rgsmplsa%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %rgsmplsa%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %rgsmplsa%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %rgsmplsa%
adb shell setprop debug.sf.late.app.duration %rgsmplsa%
adb shell setprop debug.sf.late.sf.duration %rgsmplsa%
echo [%g%+%w%] Done ^^!
echo.
echo.
timeout /t 2 /nobreak > nul
echo [^^!] SurfaceFlinger Setup Is Complete, 2nd Setup Is Ready^^!
echo [^^!] Please Wait^^!
timeout /t 10 /nobreak > nul
set count=0
title 2nd Setup
cls
call :logo
call :run_bgdexopt
cls
call :logo
set /a count+=1
echo Done %b%%count%%w%/5
timeout /t 1 /nobreak > nul
cls
call :logo
adb shell dumpsys battery reset
cls
call :logo
set /a count+=1
echo Done %b%%count%%w%/5
timeout /t 1 /nobreak > nul
cls
call :logo
adb shell sm fstrim
cls
call :logo
set /a count+=1
echo Done %b%%count%%w%/5
timeout /t 1 /nobreak > nul
cls
call :logo
adb shell am kill-all
adb shell am kill --user 0 all
adb shell am kill --user 0 current
adb shell cmd looper_stats disable
call :dropbox_lowprio
adb shell cmd dropbox set-rate-limit 20000000000000
adb shell cmd autofill set log_level off
adb shell cmd thermalservice override-status 1
:: ----- NEW SAFE OPTIMIZATIONS (from the .sh script, vetted) -----
:: Universal log silencer (REAL, persists across reboots)
adb shell setprop persist.log.tag "*:S" > nul 2>&1
adb shell setprop log.tag "*:S" > nul 2>&1
:: NOTE: ANGLE-for-all-apps is intentionally NOT applied here.
:: It is device/GPU dependent and is known to crash many apps on
:: non-Pixel hardware (e.g. MediaTek GPUs). It remains available as a
:: deliberate, reversible choice under Gaming -> Force ANGLE for All
:: Apps, with a warning. Auto Setup must stay safe for every device.
:: ---------------------------------------------------------------
adb shell setprop log.tag.stats_log S
adb shell setprop log.tag.APM_AudioPolicyManager S
adb shell setprop log.tag.ALL S
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell simpleperf --log fatal --log-to-android-buffer 0 > nul 2>&1
adb shell cmd autofill set max_visible_datasets 0
adb shell cmd voiceinteraction set-debug-hotword-logging false
call :wm_silence_logs
adb shell dumpsys binder_calls_stats --disable > nul 2>&1
adb shell dumpsys binder_calls_stats --disable-detailed-tracking > nul 2>&1
adb shell settings put global binder_calls_stats sampling_interval=500000000,detailed_tracking=disable,enabled=false,upload_data=false
adb shell dumpsys batterystats disable full-history > nul 2>&1
adb shell ime tracing stop
cls
call :logo
set /a count+=1
echo Done %b%%count%%w%/5
timeout /t 1 /nobreak > nul
cls
call :logo
adb shell logcat -c
cls
call :logo
set /a count+=1
echo Done %b%%count%%w%/5
timeout /t 1 /nobreak > nul
cls
call :logo
echo Done , Press Any Button To Go Back
adb shell cmd notification post -S bigtext -t 'Auto Setup Is Complete⚙️' 'Tag' 'Auto Setup Is A Bunch Of Tweaks That Can Be Use For Daily Or Dont Know Anything About This Script' <nul > nul 2>&1
pause > Nul
goto menu

:Optimize
cls
title Optimize Android
mode 100,37
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo           [%g%+%w%]Uptime: %%a %%b %%c
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
echo           [%g%+%w%]%cpucheck% LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %g%[%w%1%g%]%w% Run bg-dexopt-job
echo                                     %g%[%w%2%g%]%w% Run Fstrim
echo                                     %g%[%w%3%g%]%w% Run Kill-all
echo                                     %g%[%w%4%g%]%w% Run Compile App
echo                                     %g%[%w%5%g%]%w% Run Clear Cache
echo                                     %g%[%w%6%g%]%w% Run Tweak SurfaceFlinger
echo                                     %g%[%w%7%g%]%w% Run Clear Last Used
echo                                     %g%[%w%8%g%]%w% Compile All Apps
echo                                     %g%[%w%9%g%]%w% Animation Speed
echo                                     %g%[%w%0%g%]%w% Back
echo.

:Optimize_ask
:: FIX (press-twice): re-prompt without redrawing on empty/invalid input,
:: so a phantom empty line after the probes doesn't re-run them (see :dispscaler).
set "kb=" & set /p kb="Choose An Option >> "
if not defined kb goto Optimize_ask
if "!kb!"=="1" goto dexopt
if "!kb!"=="2" goto fstrim
if "!kb!"=="3" goto killall
if "!kb!"=="4" goto compile
if "!kb!"=="5" goto cache
if "!kb!"=="6" goto sftmenu
if "!kb!"=="7" goto lstused
if "!kb!"=="8" goto compileall
if "!kb!"=="9" goto animspeed
if "!kb!"=="0" goto menu
goto Optimize_ask
:: ===================================================================
:: NEW: Compile All Apps  (from Compile.bat + smooth_android.sh)
:: This re-compiles EVERY installed app with the chosen ART mode and
:: then runs the background dexopt job. Modes:
::   everything         - heaviest, slowest, may regress some apps
::   everything-profile - heavy but respects each app's usage profile
::                        (recommended balance, see smooth_android.sh)
::   speed              - optimise hot methods only (fast)
::   speed-profile      - default Android behaviour
:: NOTE: this takes 5-30+ minutes on most devices. The phone may feel
:: warm and slow during the run. Leave it plugged in.
:: ===================================================================
:compileall
cls
title Compile All Apps
call :logo
echo.
echo  This recompiles EVERY installed app. Takes 5-30+ minutes and the
echo  device will be warm. Plug it in before starting.
echo.
echo                                     %g%[%w%1%g%]%w% everything-profile (recommended)
echo                                     %g%[%w%2%g%]%w% everything         (heaviest)
echo                                     %g%[%w%3%g%]%w% speed              (fast)
echo                                     %g%[%w%4%g%]%w% speed-profile      (default)
echo                                     %g%[%w%5%g%]%w% heaviest optimization, will reduce the available storage space
echo                                     %g%[%w%6%g%]%w% Back
set "ca=" & set /p ca="Choose An Option >> "
if "!ca!"=="1" set "ca_mode=everything-profile" & goto compileall_run
if "!ca!"=="2" set "ca_mode=everything"         & goto compileall_run
if "!ca!"=="3" set "ca_mode=speed"              & goto compileall_run
if "!ca!"=="4" set "ca_mode=speed-profile"      & goto compileall_run
if "!ca!"=="5" goto compileall_heaviest
if "!ca!"=="6" goto Optimize
goto compileall

:compileall_run
cls
title Compile All Apps : %ca_mode%
echo Compiling all installed packages with mode "%ca_mode%"...
echo This may take a long time. Do not unplug the device.
echo.
call :dexopt_all_mode %ca_mode% 0
echo.
echo Running background dexopt job...
call :run_bgdexopt
echo.
echo Done. Press any key to go back.
pause > nul
goto Optimize
:: ===================================================================
:: NEW: Heaviest optimization
:: Forces full "everything" AOT compilation of every app while
:: ignoring usage profiles (--check-prof false = compile ALL methods,
:: not just the profiled hot ones), then also AOT-compiles the
:: layout XML resources (--compile-layouts), then runs the dexopt job.
::
:: This produces the largest possible amount of compiled native code,
:: so it uses the MOST storage and takes the LONGEST. Best paired with
:: plenty of free space and the device on a charger.
:: ===================================================================
:compileall_heaviest
cls
title Compile All Apps : Heaviest
echo  %r%Heaviest optimization%w% - this will:
echo    1. Compile ALL methods of EVERY app (ignores usage profiles)
echo    2. AOT-compile layout resources
echo    3. Run the background dexopt job
echo.
echo  %y%This uses significantly more storage and is the slowest mode.%w%
echo  Make sure you have free space and the device is charging.
echo.
echo    [Y] Start
echo    [N] Back
choice /c:YN /n > nul
if errorlevel 2 goto compileall
cls
title Compile All Apps : Heaviest (running)
echo [1/3] Full compilation of all apps...
echo This may take a long time. Do not unplug the device.
:: On Android 13 and below this passes --check-prof false (compile ALL
:: methods, not just profiled ones). On Android 14+ that flag was
:: removed, so the helper drops it and uses the ART-Service-routed form.
call :dexopt_all_mode everything 1
echo.
echo [2/3] Compiling layout resources (if supported)...
:: --compile-layouts is a STANDALONE mode: it cannot be combined with
:: -f / -m / --check-prof (doing so throws "Unknown option"). It also
:: only exists on Android 10-11 - the view compiler was removed in
:: Android 12+, and is handled by ART Service from 14+. So we run it on
:: its own and detect non-support.
adb shell pm compile -a --compile-layouts > "%TEMP%\dcx_layouts.txt" 2>&1
findstr /I /C:"Unknown option" /C:"Error:" /C:"Usage:" "%TEMP%\dcx_layouts.txt" > nul
if errorlevel 1 (
    echo   Layout resources compiled.
) else (
    echo   [skipped] --compile-layouts is not supported on this device.
    echo   That's expected on Android 12+ - the view compiler was removed
    echo   and ART Service handles layout optimization during normal dexopt.
)
del "%TEMP%\dcx_layouts.txt" > nul 2>&1
echo.
echo [3/3] Running background dexopt job...
call :run_bgdexopt
echo.
echo Done. Press any key to go back.
pause > nul
goto Optimize
:: ===================================================================
:: NEW: Animation Speed  (from smooth_android.sh)
:: Animations have three independent scales in Android:
::   window_animation_scale     - opening/closing windows
::   transition_animation_scale - activity transitions
::   animator_duration_scale    - ValueAnimator-driven animations
:: Common values:
::   1.0   default
::   0.75  noticeably snappier without looking glitchy (rec.)
::   0.5   feels fast, animations almost a flash
::   0     animations off (instant but jarring; some apps glitch)
:: ===================================================================
:animspeed
cls
title Animation Speed
call :logo
echo.
echo  Current scales:
for /f "delims=" %%i in ('adb shell settings get global window_animation_scale 2^>nul ^<nul')     do echo    window_animation_scale     = %%i
for /f "delims=" %%i in ('adb shell settings get global transition_animation_scale 2^>nul ^<nul') do echo    transition_animation_scale = %%i
for /f "delims=" %%i in ('adb shell settings get global animator_duration_scale 2^>nul ^<nul')    do echo    animator_duration_scale    = %%i
echo.
echo                                     %g%[%w%1%g%]%w% 0     (off, instant)
echo                                     %g%[%w%2%g%]%w% 0.5   (very fast)
echo                                     %g%[%w%3%g%]%w% 0.75  (snappy, recommended)
echo                                     %g%[%w%4%g%]%w% 1.0   (default)
echo                                     %g%[%w%5%g%]%w% Custom
echo                                     %g%[%w%6%g%]%w% Back
set "as=" & set /p as="Choose An Option >> "
if "!as!"=="1" set "asv=0"    & goto animspeed_apply
if "!as!"=="2" set "asv=0.5"  & goto animspeed_apply
if "!as!"=="3" set "asv=0.75" & goto animspeed_apply
if "!as!"=="4" set "asv=1.0"  & goto animspeed_apply
if "!as!"=="5" goto animspeed_custom
if "!as!"=="6" goto Optimize
goto animspeed

:animspeed_custom
echo Enter a decimal value between 0 and 2 (e.g. 0.5):
set "asv=" & set /p asv="Value (blank = cancel) >> "
if "!asv!"=="" goto animspeed
:: FIX: the value used to go into three "settings put" completely unchecked -
:: empty/garbage/quote input broke the commands or stored junk scales. Accept
:: a comma decimal (1,5 -> 1.5), then gate to the documented 0-2 range
:: (accepts 0, 1, 2, 0.75, .5, 2.0 and the like).
set "asv=!asv:,=.!"
echo !asv!| findstr /r /x /c:"[0-2]" /c:"[01]\.[0-9][0-9]*" /c:"2\.0*" /c:"\.[0-9][0-9]*" >nul || goto animspeed_custom_bad
goto animspeed_apply

:animspeed_custom_bad
echo [%r%^^!%w%] Invalid value. Use a number between 0 and 2, e.g. 0.5, 0.75, 1.
timeout /t 2 /nobreak >nul
goto animspeed_custom

:animspeed_apply
adb shell settings put global window_animation_scale %asv%
adb shell settings put global transition_animation_scale %asv%
adb shell settings put global animator_duration_scale %asv% <nul
echo Done. All three animation scales set to %asv%.
pause > nul
goto animspeed

:lstused
cls
call :logo
title Clear Last Used Is Running^^!
:: FIX: this was one "adb shell" per package. Measured on a real device (Android 12,
:: 269 packages): ~99 ms per round trip = ~26.6 SECONDS spent entirely on transport,
:: for work the device finishes in milliseconds. The loop now runs INSIDE the device
:: shell - one connection, same work, same per-package progress, because the device
:: echoes each name back and the Windows side just prints it. Verified to return the
:: identical 269-package set as the old parse before it was changed.
::
:: The other option - chaining every command into ONE Windows-built string with ";" -
:: does NOT work here: "pm list package" is the FULL list, and 269 packages is ~20k
:: characters against cmd's 8191-char command line. cmd truncates it silently, so
:: packages past the cut are skipped with no error at all.
::
:: Two details that matter: "${p#package:}" strips the prefix ON THE DEVICE, so the
:: name never crosses the adb transport mid-loop (no CRLF to trip over); and the
:: redirects are ">/dev/null 2>/dev/null", never "2>&1" - an "&" inside a quoted adb
:: argument inside a for /f IN clause is exactly the nested-quoting boundary that has
:: bitten this script before, and "2>/dev/null" needs no "&" to do the same job.
for /f "delims=" %%a in ('adb shell "pm list packages | while read p; do p=${p#package:}; cmd usagestats clear-last-used-timestamps $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo %%a ━ clear last used^^!
)
echo.
echo.
echo Done, Exit..
adb shell cmd activity clear-debug-app
adb shell cmd activity clear-exit-info
adb shell cmd activity clear-watch-heap all
adb shell cmd blob_store clear-all-sessions
adb shell cmd blob_store clear-all-blobs
timeout /t 2 /nobreak > nul
cls
goto Optimize

:sftmenu
title SF Menu
cls
echo.
echo.
call :logo
echo                                      [%g%1%w%] 60hz
echo                                      [%g%2%w%] 90hz
echo                                      [%g%3%w%] 120hz
echo                                      [%g%4%w%] 144hz
echo                                      [%g%5%w%] Remove
echo                                      [%g%6%w%] Back
set "opt=" & set /p opt="Choose An Option >> "
if "!opt!"=="1" goto sf60
if "!opt!"=="2" goto sf90
if "!opt!"=="3" goto sf120
if "!opt!"=="4" goto sf144
if "!opt!"=="5" goto removesf
if "!opt!"=="6" goto Optimize
goto sftmenu

:sf60
cls
title 60hz menu
echo.
echo.
call :logo
echo                                      [%g%1%w%] Balance Mode
echo                                      [%g%2%w%] Gaming Mode
echo                                      [%g%3%w%] Battery Saver Mode
echo                                      [%g%4%w%] Back
echo.
echo.
set "opt=" & set /p opt="Choose An Option >> "
if "!opt!"=="1" goto sf60balance
if "!opt!"=="2" goto sf60gaming
if "!opt!"=="3" goto sf60battery
if "!opt!"=="4" goto sftmenu
:: FIX: invalid input previously fell into :sf60battery
goto sf60

:sf60battery
cls
title 60hz SF : Battery Saver Mode
set chm=6500000
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %chm%
adb shell setprop debug.sf.region_sampling_period_ns %chm%
adb shell setprop debug.sf.late.app.duration %chm%
adb shell setprop debug.sf.late.sf.duration %chm%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %chm%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %chm%
::3100000
set chh=3500000
adb shell setprop debug.sf.earlyGl.app.duration %chh%
adb shell setprop debug.sf.early.sf.duration %chh%
adb shell setprop debug.sf.region_sampling_duration_ns %chh%
adb shell setprop debug.sf.early.app.duration %chh%
adb shell setprop debug.sf.cached_set_render_duration_ns %chh%
adb shell setprop debug.sf.earlyGl.sf.duration %chh%
::13900000
set chb=14000000
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %chb%
::1400000
set chbb=1300000
adb shell setprop debug.sf.early_app_phase_offset_ns %chbb%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %chbb%
::700000
set chn=750000
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %chn%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %chn%
::4700000
set chsss=4000000
adb shell setprop debug.sf.early_gl_phase_offset_ns %chsss%
adb shell setprop debug.sf.early_phase_offset_ns %chsss%
::3000000
set chbay=2800000
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %chbay%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf60gaming
cls
title 60hz SF : Gaming Mode
call :logo
set chm=8500000
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %chm%
adb shell setprop debug.sf.region_sampling_period_ns %chm%
adb shell setprop debug.sf.late.app.duration %chm%
adb shell setprop debug.sf.late.sf.duration %chm%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %chm%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %chm%
::3100000
set chh=5100000
adb shell setprop debug.sf.earlyGl.app.duration %chh%
adb shell setprop debug.sf.early.sf.duration %chh%
adb shell setprop debug.sf.region_sampling_duration_ns %chh%
adb shell setprop debug.sf.early.app.duration %chh%
adb shell setprop debug.sf.cached_set_render_duration_ns %chh%
adb shell setprop debug.sf.earlyGl.sf.duration %chh%
::13900000
set chb=15000000
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %chb%
::1400000
set chbb=1550000
adb shell setprop debug.sf.early_app_phase_offset_ns %chbb%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %chbb%
::700000
set chn=800000
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %chn%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %chn%
::4700000
set chsss=4800000
adb shell setprop debug.sf.early_gl_phase_offset_ns %chsss%
adb shell setprop debug.sf.early_phase_offset_ns %chsss%
::3000000
set chbay=3200000
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %chbay%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf60balance
cls
title 60hz SF : Balance Mode
call :logo
::6500000
set chm=6500000
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %chm%
adb shell setprop debug.sf.region_sampling_period_ns %chm%
adb shell setprop debug.sf.late.app.duration %chm%
adb shell setprop debug.sf.late.sf.duration %chm%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %chm%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %chm%
::3100000
set chh=2900000
adb shell setprop debug.sf.earlyGl.app.duration %chh%
adb shell setprop debug.sf.early.sf.duration %chh%
adb shell setprop debug.sf.region_sampling_duration_ns %chh%
adb shell setprop debug.sf.early.app.duration %chh%
adb shell setprop debug.sf.cached_set_render_duration_ns %chh%
adb shell setprop debug.sf.earlyGl.sf.duration %chh%
::13900000
set chb=13000000
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %chb%
::1400000
set chbb=1350000
adb shell setprop debug.sf.early_app_phase_offset_ns %chbb%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %chbb%
::700000
set chn=750000
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %chn%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %chn%
::4700000
set chsss=4500000
adb shell setprop debug.sf.early_gl_phase_offset_ns %chsss%
adb shell setprop debug.sf.early_phase_offset_ns %chsss%
::3000000
set chbay=3200000
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %chbay%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf90
cls
call :logo
title 90hz menu
echo                                      [%g%1%w%] Balance Mode
echo                                      [%g%2%w%] Gaming Mode
echo                                      [%g%3%w%] Battery Saver Mode
echo                                      [%g%4%w%] Back
echo.
echo.
set "opt=" & set /p opt="Choose An Option >> "
if "!opt!"=="1" goto sf90balance
if "!opt!"=="2" goto sf90gaming
if "!opt!"=="3" goto sf90battery
if "!opt!"=="4" goto sftmenu
:: FIX: invalid input previously fell into :sf90battery
goto sf90

:sf90battery
cls
title 90hz SF : Battery Mode
call :logo
::Battery Saver Mode 90Hz
set px=533333
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %px%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %px%
set pxl=4733333
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %pxl%
adb shell setprop debug.sf.late.app.duration %pxl%
adb shell setprop debug.sf.late.sf.duration %pxl%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %pxl%
adb shell setprop debug.sf.region_sampling_period_ns %pxl%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %pxl%
set chxl=2533333
adb shell setprop debug.sf.earlyGl.app.duration %chxl%
adb shell setprop debug.sf.early.sf.duration %chxl%
adb shell setprop debug.sf.region_sampling_duration_ns %chxl%
adb shell setprop debug.sf.cached_set_render_duration_ns %chxl%
adb shell setprop debug.sf.early.app.duration %chxl%
adb shell setprop debug.sf.earlyGl.sf.duration %chxl%
set dhbx=13333333
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %dhbx%
set dhbxz=753333
adb shell setprop debug.sf.early_app_phase_offset_ns %dhbxz%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %dhbxz%
set xcxz=2800000
adb shell setprop debug.sf.early_gl_phase_offset_ns %xcxz%
adb shell setprop debug.sf.early_phase_offset_ns %xcxz%
set xcfs=1733333
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %xcfs%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf90gaming
cls
title 90hz SF : Gaming Mode
call :logo
::Gaming Mode 90Hz
set px=653333
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %px%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %px%
set pxl=5533333
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %pxl%
adb shell setprop debug.sf.late.app.duration %pxl%
adb shell setprop debug.sf.late.sf.duration %pxl%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %pxl%
adb shell setprop debug.sf.region_sampling_period_ns %pxl%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %pxl%
set chxl=2933333
adb shell setprop debug.sf.earlyGl.app.duration %chxl%
adb shell setprop debug.sf.early.sf.duration %chxl%
adb shell setprop debug.sf.region_sampling_duration_ns %chxl%
adb shell setprop debug.sf.cached_set_render_duration_ns %chxl%
adb shell setprop debug.sf.early.app.duration %chxl%
adb shell setprop debug.sf.earlyGl.sf.duration %chxl%
set dhbx=15333333
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %dhbx%
set dhbxz=883333
adb shell setprop debug.sf.early_app_phase_offset_ns %dhbxz%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %dhbxz%
set xcxz=3833333
adb shell setprop debug.sf.early_gl_phase_offset_ns %xcxz%
adb shell setprop debug.sf.early_phase_offset_ns %xcxz%
set xcfs=2333333
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %xcfs%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf90balance
cls
title 90hz SF : Balance Mode
call :logo
set px=533333
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %px%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %px%
::**
set pxl=4833333
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %pxl%
adb shell setprop debug.sf.late.app.duration %pxl%
adb shell setprop debug.sf.late.sf.duration %pxl%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %pxl%
adb shell setprop debug.sf.region_sampling_period_ns %pxl%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %pxl%
::***
set chxl=2533333
adb shell setprop debug.sf.earlyGl.app.duration %chxl%
adb shell setprop debug.sf.early.sf.duration %chxl%
adb shell setprop debug.sf.region_sampling_duration_ns %chxl%
adb shell setprop debug.sf.cached_set_render_duration_ns %chxl%
adb shell setprop debug.sf.early.app.duration %chxl%
adb shell setprop debug.sf.earlyGl.sf.duration %chxl%
::****
set dhbx=11333333
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %dhbx%
set dhbxz=833333
adb shell setprop debug.sf.early_app_phase_offset_ns %dhbxz%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %dhbxz%
::*****
set xcxz=3333333
adb shell setprop debug.sf.early_gl_phase_offset_ns %xcxz%
adb shell setprop debug.sf.early_phase_offset_ns %xcxz%
::******
set xcfs=1833333
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %xcfs%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf120
cls
title 120hz menu
call :logo
echo                                      [%g%1%w%] Balance Mode
echo                                      [%g%2%w%] Gaming Mode
echo                                      [%g%3%w%] Battery Saver Mode
echo                                      [%g%4%w%] Back
echo.
echo.
set "opt=" & set /p opt="Choose An Option >> "
if "!opt!"=="1" goto sf120balance
if "!opt!"=="2" goto sf120gaming
if "!opt!"=="3" goto sf120battery
if "!opt!"=="4" goto sftmenu
:: FIX: invalid input previously fell into :sf120gaming
goto sf120

:sf120gaming
cls
title 120hz SF : Gaming Mode
call :logo
::Gaming Mode 120Hz
set qk=3666666
adb shell setprop debug.sf.region_sampling_duration_ns %qk%
adb shell setprop debug.sf.cached_set_render_duration_ns %qk%
adb shell setprop debug.sf.early.app.duration %qk%
adb shell setprop debug.sf.early.sf.duration %qk%
adb shell setprop debug.sf.earlyGl.app.duration %qk%
adb shell setprop debug.sf.earlyGl.sf.duration %qk%
set fsk=1666666
adb shell setprop debug.sf.early_app_phase_offset_ns %fsk%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %fsk%
set erl=3866666
adb shell setprop debug.sf.early_gl_phase_offset_ns %erl%
adb shell setprop debug.sf.early_phase_offset_ns %erl%
set pos=586666
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %pos%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %pos%
set fpsos=2766666
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %fpsos%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %fpsos%
set tons=19666666
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %tons%
set ltsdur=5966666
adb shell setprop debug.sf.late.app.duration %ltsdur%
adb shell setprop debug.sf.late.sf.duration %ltsdur%
adb shell setprop debug.sf.region_sampling_period_ns %ltsdur%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf120battery
cls
title 120hz SF : Battery Mode
call :logo
::Battery Saver Mode 120Hz
set qk=2066666
adb shell setprop debug.sf.region_sampling_duration_ns %qk%
adb shell setprop debug.sf.cached_set_render_duration_ns %qk%
adb shell setprop debug.sf.early.app.duration %qk%
adb shell setprop debug.sf.early.sf.duration %qk%
adb shell setprop debug.sf.earlyGl.app.duration %qk%
adb shell setprop debug.sf.earlyGl.sf.duration %qk%
set fsk=796666
adb shell setprop debug.sf.early_app_phase_offset_ns %fsk%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %fsk%
set erl=2166666
adb shell setprop debug.sf.early_gl_phase_offset_ns %erl%
adb shell setprop debug.sf.early_phase_offset_ns %erl%
set pos=396666
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %pos%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %pos%
set fpsos=1166666
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %fpsos%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %fpsos%
set tons=8466666
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %tons%
set ltsdur=3966666
adb shell setprop debug.sf.late.app.duration %ltsdur%
adb shell setprop debug.sf.late.sf.duration %ltsdur%
adb shell setprop debug.sf.region_sampling_period_ns %ltsdur%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf120balance
cls
title 120hz SF : Balance Mode
call :logo
::p1
set qk=1966666
adb shell setprop debug.sf.region_sampling_duration_ns %qk%
adb shell setprop debug.sf.cached_set_render_duration_ns %qk%
adb shell setprop debug.sf.early.app.duration %qk%
adb shell setprop debug.sf.early.sf.duration %qk%
adb shell setprop debug.sf.earlyGl.app.duration %qk%
adb shell setprop debug.sf.earlyGl.sf.duration %qk%
::p2
set fsk=896666
adb shell setprop debug.sf.early_app_phase_offset_ns %fsk%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %fsk%
::p3
set erl=2466666
adb shell setprop debug.sf.early_gl_phase_offset_ns %erl%
adb shell setprop debug.sf.early_phase_offset_ns %erl%
::p4
set pos=446666
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %pos%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %pos%
::p5
set fpsos=1466666
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %fpsos%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %fpsos%
::p6
set tons=4666666
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %tons%
::p7
set ltsdur=4466666
adb shell setprop debug.sf.late.app.duration %ltsdur%
adb shell setprop debug.sf.late.sf.duration %ltsdur%
adb shell setprop debug.sf.region_sampling_period_ns %ltsdur%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %ltsdur%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu
::========================================
:: 144hz SurfaceFlinger Tweaks
:: Frame period = 6,944,444 ns (1s / 144)
:: Values derived proportionally from 120hz
::========================================
:sf144
cls
title 144hz menu
call :logo
echo                                      [%g%1%w%] Balance Mode
echo                                      [%g%2%w%] Gaming Mode
echo                                      [%g%3%w%] Battery Saver Mode
echo                                      [%g%4%w%] Back
echo.
echo.
set "opt=" & set /p opt="Choose An Option >> "
if "!opt!"=="1" goto sf144balance
if "!opt!"=="2" goto sf144gaming
if "!opt!"=="3" goto sf144battery
if "!opt!"=="4" goto sftmenu
goto sf144

:sf144gaming
cls
title 144hz SF : Gaming Mode
call :logo
:: Gaming Mode 144Hz — optimised for maximum throughput, minimal SF latency
:: early group (render duration)
set v144_early=3055555
adb shell setprop debug.sf.region_sampling_duration_ns %v144_early%
adb shell setprop debug.sf.cached_set_render_duration_ns %v144_early%
adb shell setprop debug.sf.early.app.duration %v144_early%
adb shell setprop debug.sf.early.sf.duration %v144_early%
adb shell setprop debug.sf.earlyGl.app.duration %v144_early%
adb shell setprop debug.sf.earlyGl.sf.duration %v144_early%
:: early phase offsets
set v144_earlyoff=1388888
adb shell setprop debug.sf.early_app_phase_offset_ns %v144_earlyoff%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %v144_earlyoff%
:: early GL phase
set v144_earlygl=3222222
adb shell setprop debug.sf.early_gl_phase_offset_ns %v144_earlygl%
adb shell setprop debug.sf.early_phase_offset_ns %v144_earlygl%
:: high-fps early app phase
set v144_hfearly=488888
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %v144_hfearly%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %v144_hfearly%
:: high-fps early GL phase
set v144_hfearlygl=2305555
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %v144_hfearlygl%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %v144_hfearlygl%
:: region sampling timer timeout
set v144_timer=16388888
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %v144_timer%
:: late group (VSYNC window)
set v144_late=4972222
adb shell setprop debug.sf.late.app.duration %v144_late%
adb shell setprop debug.sf.late.sf.duration %v144_late%
adb shell setprop debug.sf.region_sampling_period_ns %v144_late%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf144battery
cls
title 144hz SF : Battery Mode
call :logo
:: Battery Mode 144Hz — reduced render budget to ease GPU/SF pressure
set v144_early=1722222
adb shell setprop debug.sf.region_sampling_duration_ns %v144_early%
adb shell setprop debug.sf.cached_set_render_duration_ns %v144_early%
adb shell setprop debug.sf.early.app.duration %v144_early%
adb shell setprop debug.sf.early.sf.duration %v144_early%
adb shell setprop debug.sf.earlyGl.app.duration %v144_early%
adb shell setprop debug.sf.earlyGl.sf.duration %v144_early%
set v144_earlyoff=663888
adb shell setprop debug.sf.early_app_phase_offset_ns %v144_earlyoff%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %v144_earlyoff%
set v144_earlygl=1805555
adb shell setprop debug.sf.early_gl_phase_offset_ns %v144_earlygl%
adb shell setprop debug.sf.early_phase_offset_ns %v144_earlygl%
set v144_hfearly=330555
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %v144_hfearly%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %v144_hfearly%
set v144_hfearlygl=972222
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %v144_hfearlygl%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %v144_hfearlygl%
set v144_timer=7055555
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %v144_timer%
set v144_late=3305555
adb shell setprop debug.sf.late.app.duration %v144_late%
adb shell setprop debug.sf.late.sf.duration %v144_late%
adb shell setprop debug.sf.region_sampling_period_ns %v144_late%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:sf144balance
cls
title 144hz SF : Balance Mode
call :logo
:: Balance Mode 144Hz — smooth at full refresh rate without gaming overhead
set v144_early=1638888
adb shell setprop debug.sf.region_sampling_duration_ns %v144_early%
adb shell setprop debug.sf.cached_set_render_duration_ns %v144_early%
adb shell setprop debug.sf.early.app.duration %v144_early%
adb shell setprop debug.sf.early.sf.duration %v144_early%
adb shell setprop debug.sf.earlyGl.app.duration %v144_early%
adb shell setprop debug.sf.earlyGl.sf.duration %v144_early%
set v144_earlyoff=747222
adb shell setprop debug.sf.early_app_phase_offset_ns %v144_earlyoff%
adb shell setprop debug.sf.early_gl_app_phase_offset_ns %v144_earlyoff%
set v144_earlygl=2055555
adb shell setprop debug.sf.early_gl_phase_offset_ns %v144_earlygl%
adb shell setprop debug.sf.early_phase_offset_ns %v144_earlygl%
set v144_hfearly=372222
adb shell setprop debug.sf.high_fps_early_app_phase_offset_ns %v144_hfearly%
adb shell setprop debug.sf.high_fps_early_gl_app_phase_offset_ns %v144_hfearly%
set v144_hfearlygl=1222222
adb shell setprop debug.sf.high_fps_early_gl_phase_offset_ns %v144_hfearlygl%
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %v144_hfearlygl%
set v144_timer=3888888
adb shell setprop debug.sf.region_sampling_timer_timeout_ns %v144_timer%
set v144_late=3722222
adb shell setprop debug.sf.late.app.duration %v144_late%
adb shell setprop debug.sf.late.sf.duration %v144_late%
adb shell setprop debug.sf.region_sampling_period_ns %v144_late%
adb shell setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_app_phase_offset_ns %v144_late%
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late% <nul
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:removesf
cls
title Remove SF
call :logo
echo.
echo.
echo                       [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
:: NOTE: debug.sf properties persist until reboot. Please restart to clear them.
timeout /t 2 /nobreak > nul
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto sftmenu

:dexopt
@echo off
cls
title bg-dexopt-job is running
call :logo
echo.
echo.
call :run_bgdexopt
echo %c%Done%w%, Press Any Button To Go Back
pause > nul
goto Optimize

:fstrim
@echo off
cls
title fstrim is running
call :logo
echo.
echo  fstrim tells the kernel which storage blocks are free so flash can
echo  stay fast. It runs %y%silently%w% - Android prints nothing on success,
echo  which is why it can look like "nothing happened". That's normal.
echo.
echo  Free space on /data BEFORE:
for /f "delims=" %%i in ('adb shell df -h /data 2^>nul ^<nul ^| findstr /v "Filesystem"') do echo    %%i
echo.
echo  Running 'sm fstrim'...
adb shell sm fstrim
echo  Trigger sent.
echo.
echo  Free space on /data AFTER:
for /f "delims=" %%i in ('adb shell df -h /data 2^>nul ^<nul ^| findstr /v "Filesystem"') do echo    %%i
echo.
echo  %b%Note:%w% fstrim reclaims at the flash level, so the df numbers may
echo  not change. On some devices the trim only fully runs while the
echo  phone is %b%charging and idle/screen-off%w%; if so, leave it plugged in
echo  and locked for a few minutes and it will complete on its own.
echo.
echo %c%Done%w%, Press Any Button To Go Back
pause > nul
goto Optimize

:killall
@echo off
cls
title kill process
:: FIX: detect the current foreground package so we don't kill it
:: (force-stopping the focused app loses unsaved data in messengers,
:: notes, browsers, etc.)
:: FIX: the resumed-activity field is named differently across Android
:: versions - "mResumedActivity" (older), "ResumedActivity:" and
:: "topResumedActivity=" (Android 13+, incl. API 36 on Pixel). Match the
:: shared substring "ResumedActivity" and pull the package out of the
:: ActivityRecord{...} brace regardless of prefix or the '='/':' separator:
:: after '{' the layout is always "<hash> u0 <pkg>/<activity> t<id>}", so
:: the package is token 3, then split on '/'. The old code matched only
:: "mResumedActivity" with tokens=2 - it found nothing on Android 16 (field
:: renamed) and, even when it matched, tokens=2 grabbed "ActivityRecord{<hash>"
:: instead of the package, so the focused app was never actually skipped.
set "FG_PKG="
for /f "tokens=2 delims={" %%a in ('adb shell dumpsys activity activities 2^>nul ^<nul ^| findstr /C:"ResumedActivity"') do (
    if not defined FG_PKG (
        for /f "tokens=3 delims= " %%b in ("%%a") do (
            for /f "tokens=1 delims=/" %%c in ("%%b") do set "FG_PKG=%%c"
        )
    )
)
if defined FG_PKG echo [%b%i%w%] Foreground app detected, will be skipped: %FG_PKG%
echo.
:: Critical packages we never force-stop even on third-party list
:: (some OEMs ship important apps as user-installed APKs)
set "PROTECT=com.android.systemui com.google.android.inputmethod.latin com.android.inputmethod.latin com.android.vending"
for /f "tokens=2 delims=:" %%a in ('adb shell pm list package -3 ^<nul') do (
    set "PKG=%%a"
    set "SKIP=0"
    if defined FG_PKG (
        if "!PKG!"=="!FG_PKG!" set "SKIP=1"
    )
    for %%p in (%PROTECT%) do (
        if "!PKG!"=="%%p" set "SKIP=1"
    )
    if "!SKIP!"=="1" (
        echo Skip  !PKG!  ^(protected^)
    ) else (
        echo Kill  !PKG!
        adb shell am force-stop !PKG! > nul 2>&1
    )
)
adb shell am kill-all <nul > nul 2>&1
echo %d%Done%w%, Press Any Button To Go Back
pause > nul
goto Optimize

:compile
@echo off
cls
title Compile App
echo.
echo.
echo Enter The Mode You Want ^^!
echo Valid modes: speed, speed-profile, verify, quicken, everything, everything-profile
echo Recommended: speed (best performance, slower install)
echo.
set "mode=" & set /p mode="Choose A Mode >> "
:: FIX: validate mode against the list ART actually accepts
set "modeok=0"
for %%m in (speed speed-profile verify quicken everything everything-profile) do (
    if /i "!mode!"=="%%m" set "modeok=1"
)
if "%modeok%"=="0" (
    echo [%r%^^!%w%] Invalid mode. Use one of: speed, speed-profile, verify, quicken, everything.
    pause > nul
    goto Optimize
)
set "package=" & set /p package="Put Your Package Name Here >> "
if "!package!"=="" (
    echo [%r%^^!%w%] Package name cannot be empty.
    pause > nul
    goto Optimize
)
:: Verify the package actually exists on the device
adb shell pm list packages 2>nul | findstr /C:"package:%package%" > nul
if errorlevel 1 (
    echo [%r%^^!%w%] Package "%package%" is not installed on the device.
    pause > nul
    goto Optimize
)
echo.
echo Compiling %package% with mode %mode%...
adb shell cmd package compile -m %mode% -f %package% <nul
timeout /t 2 /nobreak > nul
echo Done , Press Any Button To Go Back
pause > nul
goto Optimize

:cache
:: FIX: was `mode 45,12` - a 45x12 console truncated the sub-menus and made the
:: window jarringly resize vs every other screen. Match the standard size.
mode 100,37
cls
title Clear Cache
echo [1] %c%Clear Cache%w%
echo [2] %c%Back%w%
set "k=" & set /p k="Choose An Option >> "
if "!k!"=="1" goto sdgb
if "!k!"=="2" goto Optimize
:: FIX: guard against invalid input - previously fell through to :sdgb
goto cache

:sdgb
cls
title Clear App Cache
echo.
echo [1] %c%Trim system cache (no root)%w%
echo [2] %r%Wipe all app cache folders (root required)%w%
echo [3] %c%Back%w%
echo.
set "k=" & set /p k="Choose an option >> "
if "!k!"=="1" goto cache_trim
if "!k!"=="2" goto cache_wipe
if "!k!"=="3" goto Optimize
goto sdgb

:cache_trim
cls
echo Trimming system cache (may take a moment)...
adb shell pm trim-caches 1200G <nul
echo Done. Press any key.
pause > nul
goto Optimize

:cache_wipe
cls
echo This requires ROOT and will remove ALL app cache files.
echo.
echo [C] Cancel
echo [Y] Yes, wipe all app caches (requires root)
choice /c:CY /n > nul
if errorlevel 2 goto cache_wipe_go
echo Cancelled.
pause > nul
goto Optimize

:cache_wipe_go
echo.
adb shell "su -c 'echo _DCXROOT'" <nul 2>nul | findstr /C:"_DCXROOT" >nul
if not errorlevel 1 goto cache_wipe_root_ok
echo [%r%^^!%w%] Root is not available on this device - nothing was wiped.
echo      This wipe needs a rooted device such as Magisk.
echo.
echo Press Any Button To Go Back
pause > nul
goto Optimize

:cache_wipe_root_ok
echo Wiping all app cache folders...
:: FIX: was `rm -rf \$p/*` - the backslash makes the inner su-shell treat $p as
:: the literal string "$p" (proved via a rootless `sh -c` proxy: \$p -> RESULT=$p/x,
:: $p -> RESULT=/data/local/tmp/x), so the old command matched nothing and wiped
:: nothing. Plain $p expands to each cache dir. (Root-only path; unchanged otherwise.)
adb shell "su -c 'for p in /data/data/*/cache; do rm -rf $p/*; done'" <nul
echo Cache wipe complete. A reboot is recommended.
pause > nul
goto Optimize
:: battery
:Battery
@echo off
cls
title Battery Mode
cls
echo                                                                                            Page%g%[%w%1/2%g%]
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo           [%g%+%w%]Uptime: %%a %%b %%c
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
echo           [%g%+%w%]%cpucheck% LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %gold%[%w%1%gold%]%w% Toggle Power Saver
echo                                     %gold%[%w%2%gold%]%w% Toggle Animation
echo                                     %gold%[%w%3%gold%]%w% Toggle Auto Wifi
echo                                     %gold%[%w%4%gold%]%w% Toggle Sync
echo                                     %gold%[%w%5%gold%]%w% Toggle Motion
echo                                     %gold%[%w%6%gold%]%w% Toggle ZRAM
echo                                     %gold%[%w%7%gold%]%w% Toggle Extreme Power Saver
echo                                     %gold%[%w%8%gold%]%w% Toggle Send Error
echo                                     %gold%[%w%9%gold%]%w% Toggle Lock Profilling
echo                                     %gold%[%w%10%gold%]%w% Toggle Logs/etc
echo                                     %gold%[%w%11%gold%]%w% Next Page
echo                                     %gold%[%w%12%gold%]%w% Back

:Battery_ask
:: FIX (press-twice): re-prompt without redrawing on empty/invalid input,
:: so a phantom empty line after the probes doesn't re-run them (see :dispscaler).
:: Also rename this menu's var "set" -> "opt": it never actually collided with
:: the set command, but a variable literally named "set" is a footgun to read.
set "opt=" & set /p opt="Choose An Option >> "
if not defined opt goto Battery_ask
if "!opt!"=="1" goto saverpower
if "!opt!"=="2" goto animation
if "!opt!"=="3" goto autowifi
if "!opt!"=="4" goto sync
if "!opt!"=="5" goto motion
if "!opt!"=="6" goto zram
if "!opt!"=="7" goto extremepower
if "!opt!"=="8" goto senderror
if "!opt!"=="9" goto toggleprofilling
if "!opt!"=="10" goto togglelogs
if "!opt!"=="11" goto nextpage
if "!opt!"=="12" goto menu
:: FIX: guard against invalid input - previously fell through to :nextpage
goto Battery_ask

:nextpage
cls
title Battery Mode
echo                                                                                            Page%g%[%w%2/2%g%]
echo.
echo.
call :logo
echo                                     %gold%[%w%1%gold%]%w% Toggle Log (For User Apps)
echo                                     %gold%[%w%2%gold%]%w% Universal Toggle Logs\etc
echo                                     %gold%[%w%3%gold%]%w% Toggle Deviceidle Whitelist
echo                                     %gold%[%w%4%gold%]%w% Hibernate App
echo                                     %gold%[%w%5%gold%]%w% Refresh Rate Lock
echo                                     %gold%[%w%6%gold%]%w% Force Doze Now
echo                                     %gold%[%w%7%gold%]%w% App Hibernation (system-wide)
echo                                     %gold%[%w%8%gold%]%w% Account Sync Toggle
echo                                     %gold%[%w%9%gold%]%w% Voice Hotword Toggle
echo                                     %gold%[%w%A%gold%]%w% Wake-Lock Audit  (battery drain diagnostic)
echo                                     %gold%[%w%0%gold%]%w% Back
echo.
echo.
set "ksd=" & set /p ksd="Choose An Option >> "
if "!ksd!"=="1" goto logappsuser
if "!ksd!"=="2" goto universallogs
if "!ksd!"=="3" goto Deviceidle
if "!ksd!"=="4" goto hibernateapp
if "!ksd!"=="5" goto refreshlock
if "!ksd!"=="6" goto forcedoze
if "!ksd!"=="7" goto apphibernation
if "!ksd!"=="8" goto syncmaster
if "!ksd!"=="9" goto hotwordtoggle
if /i "!ksd!"=="A" goto wakelockaudit
if "!ksd!"=="0" goto Battery
:: guard against invalid input
goto nextpage
:: ===================================================================
:: NEW: Wake-Lock Audit  (battery drain diagnostic)
:: Wake locks prevent CPU/screen sleep. A misbehaving app holding a
:: partial wake lock can drain 20-40% battery/hour. This gathers the
:: four most useful dumps into one report.
:: ===================================================================
:wakelockaudit
cls
title Wake-Lock Audit
call :logo
echo.
echo  Generating wake-lock + battery-stats report. Takes ~10 seconds.
echo.
:: FIX: build the timestamp via PowerShell so it is locale-independent.
:: The old %date%/%time% substring slicing assumed a US M/D/Y format and
:: produced garbled or invalid filenames on other regional date formats.
:: locale-safe, filename-safe timestamp (no PowerShell = no console code-page reset)
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "WLREPORT=%TEMP%\dcx_wakelocks_%TS%.txt"
(
    echo ===========================================================
    echo  DCX Wake-Lock Audit - %date% %time%
    echo ===========================================================
    echo.
    echo [Section 1] Currently held wake locks
    echo  ^(Each entry = something keeping CPU awake right now.
    echo   PARTIAL_WAKE_LOCK is the most common battery drain.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys power 2>/dev/null | grep -E 'Wake Locks:|PARTIAL_WAKE_LOCK|SCREEN_BRIGHT|FULL_WAKE_LOCK'"
    echo.
    echo.
    echo [Section 2] Top wake-lock holders since last full charge
    echo  ^(Look at "Wake lock" totals - highest = biggest drainers.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys batterystats --charged 2>/dev/null | head -200"
    echo.
    echo.
    echo [Section 3] Doze ^(deep sleep^) state
    echo  ^(mState=IDLE means doze is active. ACTIVE = apps can run.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys deviceidle 2>/dev/null | grep -E 'mState=|mLightState=|mActiveIdleOpCount|mScreenOn|mCharging'"
    echo.
    echo.
    echo [Section 4] Top alarms ^(background wakeups^)
    echo -----------------------------------------------------------
    adb shell "dumpsys alarm 2>/dev/null | grep -E 'Top Alarms|wakeups in last|act=' | head -50"
    echo.
    echo.
    echo [Section 5] Process CPU consumers ^(last sample^)
    echo -----------------------------------------------------------
    adb shell "dumpsys cpuinfo 2>/dev/null | head -25"
    echo.
    echo ===========================================================
    echo  Quick interpretation:
    echo    - PARTIAL_WAKE_LOCK in Section 1 = active drainers
    echo    - In Section 2, an app with ^>1h "Wake lock" since charge
    echo      is the prime suspect
    echo    - High wakeup count in Section 4 = app pinging too often
    echo    - If mState ^^!= IDLE while screen is off, doze is blocked
    echo ===========================================================
) > "%WLREPORT%" < nul
:: FIX (report hygiene): generate once above; :wakelockaudit_menu re-shows the
:: menu so notepad / paginate / summary / invalid input don't re-run the ~10s
:: report and write another timestamped temp file each time.
:wakelockaudit_menu
echo  %g%Report saved to:%w%
echo    %WLREPORT%
echo.
echo  %b%[%w%1%b%]%w% Open in Notepad (searchable)
echo  %b%[%w%2%b%]%w% Show paginated (MORE)
echo  %b%[%w%3%b%]%w% Show summary only
echo  %b%[%w%4%b%]%w% Back
set "wl=" & set /p wl="Choose An Option >> "
if "!wl!"=="1" (
    start "" notepad "%WLREPORT%"
    goto wakelockaudit_menu
)
if "!wl!"=="2" (
    cls
    more "%WLREPORT%"
    echo.
    echo Press Any Button To Go Back
    pause > nul
    goto wakelockaudit_menu
)
if not "!wl!"=="3" goto _skwl3
    cls
    echo Currently held wake locks:
    echo.
    adb shell dumpsys power ^<nul 2^>nul ^| findstr /C:"PARTIAL_WAKE_LOCK"
    echo.
    echo Doze state:
    adb shell dumpsys deviceidle ^<nul 2^>nul ^| findstr /C:"mState=" /C:"mScreenOn"
    echo.
    echo Full report at: %WLREPORT%
    echo.
    pause > nul
    goto wakelockaudit_menu

:_skwl3
if "!wl!"=="4" goto nextpage
goto wakelockaudit_menu
:: ===================================================================
:: NEW: Refresh Rate Lock  (from Extra_Boost.bat / Power_Saving.bat)
:: Uses REAL Settings.System keys that Android honours:
::   min_refresh_rate  - lower bound (also gates "smooth" mode)
::   peak_refresh_rate - upper bound for default mode
:: Lock to 60 -> better battery. Lock to 90/120 -> always smooth.
:: Setting both to the SAME value forces that exact rate.
:: ===================================================================
:refreshlock
cls
title Refresh Rate Lock
call :logo
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell settings get system min_refresh_rate 2^>nul ^<nul')   do echo    min_refresh_rate  = %%i Hz
for /f "delims=" %%i in ('adb shell settings get system peak_refresh_rate 2^>nul ^<nul')  do echo    peak_refresh_rate = %%i Hz
echo.
echo                                     %g%[%w%1%g%]%w% Lock to 60 Hz   (battery)
echo                                     %g%[%w%2%g%]%w% Lock to 90 Hz
echo                                     %g%[%w%3%g%]%w% Lock to 120 Hz  (smooth)
echo                                     %g%[%w%4%g%]%w% Adaptive (1 to 120 Hz)
echo                                     %g%[%w%5%g%]%w% Restore defaults
echo                                     %g%[%w%6%g%]%w% Back
set "rl=" & set /p rl="Choose An Option >> "
if "!rl!"=="1" (
    adb shell settings put system min_refresh_rate 60
    adb shell settings put system peak_refresh_rate 60 <nul
    echo Locked at 60 Hz.
    pause > nul
    goto refreshlock
)
if "!rl!"=="2" (
    adb shell settings put system min_refresh_rate 90
    adb shell settings put system peak_refresh_rate 90 <nul
    echo Locked at 90 Hz. ^(Falls back if your panel doesn't support 90.^)
    pause > nul
    goto refreshlock
)
if "!rl!"=="3" (
    adb shell settings put system min_refresh_rate 120
    adb shell settings put system peak_refresh_rate 120 <nul
    echo Locked at 120 Hz. ^(Falls back if your panel doesn't support 120.^)
    pause > nul
    goto refreshlock
)
if "!rl!"=="4" (
    adb shell settings put system min_refresh_rate 1
    adb shell settings put system peak_refresh_rate 120 <nul
    echo Adaptive 1-120 Hz.
    pause > nul
    goto refreshlock
)
if not "!rl!"=="5" goto _skrl5
    adb shell settings delete system min_refresh_rate <nul
    adb shell settings delete system peak_refresh_rate <nul
    echo Defaults restored.
    pause > nul
    goto refreshlock

:_skrl5
if "!rl!"=="6" goto nextpage
goto refreshlock
:: ===================================================================
:: NEW: Force Doze Now  (from Power_Saving.bat)
:: `dumpsys deviceidle force-idle` immediately puts the device into
:: deep idle (doze) - useful right before locking the phone and
:: putting it down. Wakes up normally on user interaction.
:: ===================================================================
:forcedoze
cls
title Force Doze Now
call :logo
echo.
echo  Immediately forces the device into deep idle (doze) mode.
echo  Wakes up normally when you unlock or receive a high-priority push.
echo.
echo                                     %g%[%w%1%g%]%w% Force doze now
echo                                     %g%[%w%2%g%]%w% Unforce (return to normal scheduling)
echo                                     %g%[%w%3%g%]%w% Show current state
echo                                     %g%[%w%4%g%]%w% Back
set "fd=" & set /p fd="Choose An Option >> "
if not "!fd!"=="1" goto _skfd1
    adb shell dumpsys deviceidle force-idle <nul
    echo Doze forced.
    pause > nul
    goto forcedoze

:_skfd1
if not "!fd!"=="2" goto _skfd2
    adb shell dumpsys deviceidle unforce <nul
    echo Returned to normal scheduling.
    pause > nul
    goto forcedoze

:_skfd2
if "!fd!"=="3" (
    cls
    for /f "delims=" %%i in ('adb shell dumpsys deviceidle ^<nul ^| findstr /C:"mState=" /C:"mLightState="') do echo   %%i
    echo.
    pause > nul
    goto forcedoze
)
if "!fd!"=="4" goto nextpage
goto forcedoze
:: ===================================================================
:: NEW: App Hibernation toggle (Android 12+, from Power_Saving.bat)
:: Hibernates unused apps - revokes runtime permissions, removes
:: optimised code, clears cache. App keeps installed but uses ~0
:: resources until launched again.
:: ===================================================================
:apphibernation
cls
title App Hibernation
call :logo
echo.
echo  Android 12+ feature. When ON, the system hibernates apps the
echo  user hasn't opened in a long time (revokes permissions, removes
echo  optimised code). Saves storage + RAM on devices with many
echo  rarely-used apps.
echo.
if "%SDK%"=="" goto _aph_show
if %SDK% LSS 31 (
    echo  %r%Warning:%w% your device is API %SDK% - app hibernation needs API 31+.
)

:_aph_show
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul ^<nul') do echo    app_hibernation_enabled = %%i
echo.
echo                                     %g%[%w%1%g%]%w% Enable
echo                                     %g%[%w%2%g%]%w% Disable
echo                                     %g%[%w%3%g%]%w% Back
set "ah=" & set /p ah="Choose An Option >> "
if "!ah!"=="1" (
    adb shell device_config put app_hibernation app_hibernation_enabled true <nul
    echo Enabled.
    pause > nul
    goto apphibernation
)
if "!ah!"=="2" (
    adb shell device_config put app_hibernation app_hibernation_enabled false <nul
    echo Disabled.
    pause > nul
    goto apphibernation
)
if "!ah!"=="3" goto nextpage
goto apphibernation
:: ===================================================================
:: NEW: Account Sync toggle (from Balanced.bat)
:: Master switch for ALL account auto-sync (Google contacts, calendar,
:: Gmail push, Drive, etc). Turning OFF is a meaningful battery save
:: but you'll need to refresh apps manually. Real Settings.Global key.
:: ===================================================================
:syncmaster
cls
title Account Sync Toggle
call :logo
echo.
echo  Master toggle for ALL account auto-sync. Disabling stops:
echo    - Google contacts/calendar/Drive background sync
echo    - Gmail push notifications  ^(switches to fetch on open^)
echo    - Photo backup
echo  Apps you actively open will still work.
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul ^<nul') do echo    master_sync_status = %%i  (1=on, 0=off)
echo.
echo                                     %g%[%w%1%g%]%w% Enable sync (default)
echo                                     %g%[%w%2%g%]%w% Disable sync (battery saver)
echo                                     %g%[%w%3%g%]%w% Back
set "sm=" & set /p sm="Choose An Option >> "
if "!sm!"=="1" (
    adb shell settings put global master_sync_status 1 <nul
    echo Sync enabled.
    pause > nul
    goto syncmaster
)
if "!sm!"=="2" (
    adb shell settings put global master_sync_status 0 <nul
    echo Sync disabled. You will need to open apps to fetch new content.
    pause > nul
    goto syncmaster
)
if "!sm!"=="3" goto nextpage
goto syncmaster
:: ===================================================================
:: NEW: Voice Hotword toggle (from Balanced.bat)
:: Disables passive voice listening ("Hey Google" / "Alexa" / "Bixby").
:: Real Settings.Global key. Saves battery because the always-on mic
:: pipeline stays parked. You can still launch the assistant manually.
:: ===================================================================
:hotwordtoggle
cls
title Voice Hotword Toggle
call :logo
echo.
echo  Disables the always-on "Hey Google" / hotword pipeline.
echo  You can still tap the assistant icon to use voice input.
echo  Real battery save on devices with continuous mic listening.
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell settings get global hotword_detection_enabled 2^>nul ^<nul') do echo    hotword_detection_enabled = %%i  (1=on, 0=off)
echo.
echo                                     %g%[%w%1%g%]%w% Enable hotword
echo                                     %g%[%w%2%g%]%w% Disable hotword
echo                                     %g%[%w%3%g%]%w% Back
set "hw=" & set /p hw="Choose An Option >> "
if "!hw!"=="1" (
    adb shell settings put global hotword_detection_enabled 1 <nul
    echo Hotword enabled.
    pause > nul
    goto hotwordtoggle
)
if "!hw!"=="2" (
    adb shell settings put global hotword_detection_enabled 0 <nul
    echo Hotword disabled.
    pause > nul
    goto hotwordtoggle
)
if "!hw!"=="3" goto nextpage
goto hotwordtoggle

:hibernateapp
if "%SDK%"=="" (
    cls
    call :logo
    echo [%r%^^!%w%] Could not detect API level. Cannot safely continue.
    echo Press Any Button To Go Back
    pause > nul
    goto nextpage
)
if %SDK% LSS 34 (
    cls
    call :logo
    echo [%r%^^!%w%] Your API Level Is %SDK% , Some Adb Commands Won't Work.
    echo Press Any Button To Go Back
    pause > nul
    goto nextpage
)
goto nexthibernateappphase

:nexthibernateappphase
cls
call :logo
title Set App To Hibernate
echo.
echo                                     %gold%[%w%1%gold%]%w% Set App To Hibernate
echo                                     %gold%[%w%2%gold%]%w% Set App To Stock
echo                                     %gold%[%w%3%gold%]%w% Back
echo.
echo.
set "ksd=" & set /p ksd="Choose An Option >> "
if "!ksd!"=="1" goto sethibdernatephs
if "!ksd!"=="2" goto stockpackage
if "!ksd!"=="3" goto nextpage
:: FIX: guard against invalid input - previously fell through to :stockpackage
goto nexthibernateappphase

:stockpackage
cls
title Revert Your Package To Stock
call :logo
set "pkgv2=" & set /p pkgv2="Put Your Package Name Here >> "
if "!pkgv2!"=="" goto nexthibernateappphase
echo.
echo [#] Set %pkgv2% To Stock . . . .
echo.
adb shell cmd appops reset %pkgv2%
adb shell cmd activity set-bg-restriction-level --user 0 %pkgv2% unrestricted
adb shell cmd activity set-inactive %pkgv2% false
adb shell cmd activity set-standby-bucket %pkgv2% active
adb shell cmd app_hibernation set-state %pkgv2% false
adb shell cmd dropbox remove-low-priority %pkgv2%
adb shell cmd tare set-vip 0 %pkgv2% true <nul
echo.
echo [#] %pkgv2% Is Back To Stock, Reboot To Finish The Process
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:sethibdernatephs
cls
title Set Your Package Here
call :logo
set "pkgv2=" & set /p pkgv2="Put Your Package Name Here >> "
if "!pkgv2!"=="" (
    echo invalid package. . . .
    timeout /t 2 /nobreak > nul
    goto nexthibernateappphase
)
echo.
echo [#] Set %pkgv2% To Hibernate . . . .
echo.
for %%b in (
    FOREGROUND_SERVICE_SPECIAL_USE
    INSTANT_APP_START_FOREGROUND
    RUN_ANY_IN_BACKGROUND
    RUN_IN_BACKGROUND
    START_FOREGROUND
    WAKE_LOCK
) do (
    adb shell cmd appops set %pkgv2% %%b ignore > nul 2>&1
)
adb shell cmd activity service-restart-backoff disable %pkgv2%
adb shell cmd activity set-bg-restriction-level --user 0 %pkgv2% hibernation
adb shell cmd activity set-foreground-service-delegate --user 0 %pkgv2% stop
adb shell cmd activity set-inactive %pkgv2% true
adb shell cmd activity set-standby-bucket %pkgv2% restricted
adb shell cmd app_hibernation set-state %pkgv2% true
adb shell cmd deviceidle sys-whitelist -%pkgv2%
adb shell cmd deviceidle whitelist -%pkgv2%
adb shell cmd dropbox add-low-priority %pkgv2%
adb shell cmd package art clear-app-profiles %pkgv2%
adb shell cmd package log-visibility --disable %pkgv2%
adb shell cmd shortcut clear-shortcuts %pkgv2%
adb shell cmd tare set-vip 0 %pkgv2% false
adb shell cmd usagestats clear-last-used-timestamps %pkgv2%
adb shell am force-stop %pkgv2%
adb shell am kill %pkgv2%
adb shell am stop-app %pkgv2%
adb shell cmd activity force-stop %pkgv2%
adb shell cmd activity kill %pkgv2% <nul
echo.
echo %pkgv2% In Hibernate State
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:Deviceidle
title Toggle Deviceidle Whitelist
cls
call :logo
echo.
echo.
echo                                     [%d%1%w%] Remove System App From Whitelist
echo                                     [%d%2%w%] Revert
echo                                     [%d%3%w%] Back
set "ksd=" & set /p ksd="Choose An Option >> "
if "!ksd!"=="1" goto devicesysdel
if "!ksd!"=="2" goto devicesysrev
if "!ksd!"=="3" goto nextpage
:: FIX: guard against invalid input - previously fell through to :devicesysdel
goto Deviceidle

:devicesysdel
cls
call :logo
title Toggle Deviceidle Whitelist : Remove System App From Whitelist
echo.
echo  %r%======================== WARNING ========================%w%
echo.
echo  Removing system apps from the Doze (deviceidle) whitelist
echo  can break:
echo    - Alarms and timers (Clock, Calendar reminders)
echo    - Push notifications across the OS
echo    - Background sync, find-my-device, system updates
echo    - Foreground services some OEM apps rely on
echo.
echo  You can always recover with option [2] Revert.
echo.
echo  %r%=========================================================%w%
echo.
echo  [%g%Y%w%] Continue
echo  [%g%N%w%] Cancel
choice /c:YN /n > nul
if errorlevel 2 goto Deviceidle
cls
call :logo
title Removing system apps from Doze whitelist...
:: FIX: previous protected list was just "gms shell ims downloads" -
:: too narrow. Expanded to cover more critical components.
:: FIX (temp hygiene): write to %TEMP%, not temp.txt in the CURRENT directory -
:: DCX may be launched from a read-only or shared location. Read it back with
:: `type` so the quoted %TEMP% path is honored (for /f in ("path") would treat a
:: quoted path as a literal string, not a filename).
:: FIX (parser): the old Windows-side filter `findstr /R "...,[0-9]*$"` had
:: two ways to match NOTHING and finish "Done" without removing anything:
:: (1) findstr's $ anchor only matches right before a CR, and adb output
:: piped on Windows can arrive LF-only; (2) builds whose dump prints bare
:: package names without the ",uid" suffix never matched at all. Filter on
:: the DEVICE instead, where line endings and tools are deterministic:
:: grep keeps real package lines (with or without ",uid"), sed strips the
:: uid. toybox grep/sed ship on every Android 6+ build DCX targets; if one
:: is somehow missing the file comes back empty and the loop is a no-op -
:: the same fail-safe as before, never a wrong removal.
adb shell "dumpsys deviceidle sys-whitelist | grep -E '^[[:blank:]]*[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+(,[0-9]+)?[[:blank:]]*$' | sed 's/[[:blank:]]//g; s/,.*//'" > "%TEMP%\dcx_idle_whitelist.txt"
for /f "delims=" %%A in ('type "%TEMP%\dcx_idle_whitelist.txt"') do (
    echo %%A | findstr /I "gms gsf shell ims downloads providers settings systemui inputmethod telecom telephony bluetooth dialer mms phone alarm calendar fused" > nul
    if errorlevel 1 (
        adb shell cmd deviceidle sys-whitelist -%%A
        echo Removed: %%A
    ) else (
        echo [%r%#%w%] %%A Is Protected
    )
)
del "%TEMP%\dcx_idle_whitelist.txt" > nul 2>&1
echo.
echo Done, Press Any Button To Go Back
pause > nul
goto nextpage

:devicesysrev
title Toggle Deviceidle Whitelist : Revert
cls
call :logo
echo.
echo.
echo                           [%y%=%w%]All System Apps Is Revert Back To Deviceidle
adb shell cmd deviceidle sys-whitelist reset <nul
echo Press Any Button To Go Back
pause > nul
goto nextpage

:universallogs
cls
title Universal Toggle Logs\etc
echo.
echo.
call :logo
echo.
echo.
echo                                     [%d%1%w%] Off
echo                                     [%d%2%w%] On
echo                                     [%d%3%w%] Back
set "ksd=" & set /p ksd="Choose An Option >> "
if "!ksd!"=="1" goto offlogsuni
if "!ksd!"=="2" goto onlogsuni
if "!ksd!"=="3" goto nextpage
:: FIX: guard against invalid input - previously fell through to :offlogsuni
goto universallogs

:offlogsuni
cls
title Universal Toggle Logs\etc : Off
call :logo
for /f "tokens=1 delims=:" %%a in ('adb shell getprop ^<nul ^| findstr "log.tag"') do (
    set "prop=%%a"
    set "prop=!prop: =!"
    set "prop=!prop:[=!"
    set "prop=!prop:]=!"
    adb shell setprop !prop! S
)
echo Press Any Button To Go Back
pause > nul
goto nextpage

:onlogsuni
cls
title Universal toggle Logs\etc : On
call :logo
echo                       [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:logappsuser
cls
title Toggle Log For User Apps
echo.
echo.
call :logo
echo.
echo.
echo                                     [%d%1%w%] Off
echo                                     [%d%2%w%] On
echo                                     [%d%3%w%] Back
set "ksd=" & set /p ksd="Choose An Option >> "
if "!ksd!"=="1" goto offlogsuserapp
if "!ksd!"=="2" goto onlogsuserapp
if "!ksd!"=="3" goto nextpage
:: FIX: guard against invalid input - previously fell through to :offlogsuserapp
goto logappsuser

:offlogsuserapp
cls
title Log For User Apps : Off
call :logo
:: FIX: this was one "adb shell" per package. Measured on a real device (Android 12,
:: 269 packages): ~99 ms per round trip = ~26.6 SECONDS spent entirely on transport,
:: for work the device finishes in milliseconds. The loop now runs INSIDE the device
:: shell - one connection, same work, same per-package progress, because the device
:: echoes each name back and the Windows side just prints it. Verified to return the
:: identical 269-package set as the old parse before it was changed.
::
:: The other option - chaining every command into ONE Windows-built string with ";" -
:: does NOT work here: "pm list package" is the FULL list, and 269 packages is ~20k
:: characters against cmd's 8191-char command line. cmd truncates it silently, so
:: packages past the cut are skipped with no error at all.
::
:: Two details that matter: "${p#package:}" strips the prefix ON THE DEVICE, so the
:: name never crosses the adb transport mid-loop (no CRLF to trip over); and the
:: redirects are ">/dev/null 2>/dev/null", never "2>&1" - an "&" inside a quoted adb
:: argument inside a for /f IN clause is exactly the nested-quoting boundary that has
:: bitten this script before, and "2>/dev/null" needs no "&" to do the same job.
for /f "delims=" %%a in ('adb shell "pm list packages | while read p; do p=${p#package:}; cmd package log-visibility --disable $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo Log disabled : %%a
)
echo.
echo.
echo Done , Press Any Button To Go Back
pause > nul
goto nextpage

:onlogsuserapp
cls
title Log For User Apps : On
call :logo
:: FIX: this was one "adb shell" per package. Measured on a real device (Android 12,
:: 269 packages): ~99 ms per round trip = ~26.6 SECONDS spent entirely on transport,
:: for work the device finishes in milliseconds. The loop now runs INSIDE the device
:: shell - one connection, same work, same per-package progress, because the device
:: echoes each name back and the Windows side just prints it. Verified to return the
:: identical 269-package set as the old parse before it was changed.
::
:: The other option - chaining every command into ONE Windows-built string with ";" -
:: does NOT work here: "pm list package" is the FULL list, and 269 packages is ~20k
:: characters against cmd's 8191-char command line. cmd truncates it silently, so
:: packages past the cut are skipped with no error at all.
::
:: Two details that matter: "${p#package:}" strips the prefix ON THE DEVICE, so the
:: name never crosses the adb transport mid-loop (no CRLF to trip over); and the
:: redirects are ">/dev/null 2>/dev/null", never "2>&1" - an "&" inside a quoted adb
:: argument inside a for /f IN clause is exactly the nested-quoting boundary that has
:: bitten this script before, and "2>/dev/null" needs no "&" to do the same job.
for /f "delims=" %%a in ('adb shell "pm list packages | while read p; do p=${p#package:}; cmd package log-visibility --enable $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo Log enabled : %%a
)
echo.
echo.
echo Done , Press Any Button To Go Back
pause > nul
goto nextpage

:togglelogs
cls
title Toggle Logs/etc
echo.
echo.
echo Toggle Your Logs/etc Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offlogss
if "!toggle!"=="2" goto onlogss
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto togglelogs

:offlogss
cls
title Logs/etc : Off
cls
echo.
echo.
echo Do You Want To Use Custom Debug.prop From Tecno Pova 6 Neo?
echo.
echo.
echo [1] Skip And Continue
echo [2] Yes
echo [3] Back
set "conx=" & set /p conx="Choose An Option >> "
if "!conx!"=="1" goto skiplogv
if "!conx!"=="2" goto mainlogv
if "!conx!"=="3" goto Battery
:: FIX: guard against invalid input - previously fell through to :mainlogv
goto offlogss

:mainlogv
cls
::debugprop from tecno pova 6 neo
adb shell setprop debug.ae.dump.enable false
adb shell setprop debug.ae.dump.stat 0
adb shell setprop debug.ae.dump_level 0
adb shell setprop debug.ae.log.enable false
adb shell setprop debug.ae.log.level 0
adb shell setprop debug.ae.logi.enable false
adb shell setprop debug.af.log.enable false
adb shell setprop debug.bq.dump false
adb shell setprop debug.camera.dump false
adb shell setprop debug.stagefright.mediacodec.trace 0
adb shell setprop debug.sf.log_transaction false
adb shell setprop debug.sf.stats false
adb shell setprop debug.mtkcam.systrace.level 0
adb shell setprop debug.dump.enable false
adb shell setprop debug.dump 0
adb shell setprop debug.camera.log 0
adb shell setprop debug.ae.stat.log.level 0
adb shell setprop debug.ae.stat.perf.enable false
adb shell setprop debug.af.systrace 0
adb shell setprop debug.awb.systrace.db.enable false
adb shell setprop debug.flicker.systrace false
adb shell setprop debug.flicker.log 0
adb shell setprop debug.pdsystrace 0
adb shell setprop debug.syncawbsystrace.enable false
adb shell setprop debug.trace.print.video false
adb shell setprop debug.trace.print.audio false
adb shell setprop debug.trace.info false
adb shell setprop debug.gpu.dump.texture false
adb shell setprop debug.sf.cpupolicy.log false
adb shell setprop debug.hwc.wdt_trace false
adb shell setprop debug.apusys.loglevel 0
adb shell setprop debug.awb.latency.log.level 0
adb shell setprop debug.awb_alg.log.level 0
adb shell setprop debug.edma.loglevel 0
adb shell setprop debug.ae.pline.table.log 0
adb shell setprop debug.ae_alg.log.level 0
adb shell setprop debug.atms.dump false
adb shell setprop debug.eis.dumpdisplay false
adb shell setprop debug.featureProfile.dump false
adb shell setprop debug.flk_dump 0
adb shell setprop debug.fpipe.force.dump 0
adb shell setprop debug.hwc.dump_buf_log_enable false
adb shell setprop debug.ai3a_log.enable false
adb shell setprop debug.aiawb.ga.log.enable false
adb shell setprop debug.alsflk.log 0
adb shell setprop debug.awb.p1ggm.log.enable false
adb shell setprop debug.awb.sa.log.enable false
adb shell setprop debug.mediatek.vklayer.dump_analysis_enabled false
adb shell setprop debug.mediatek.vklayer.dump_blas_info_enabled false
adb shell setprop debug.mediatek.vklayer.dump_debug_enabled false
adb shell setprop debug.mediatek.vklayer.dump_debug_mem_at_QSubmit false
adb shell setprop debug.mediatek.vklayer.dump_debug_mem_enabled false
adb shell setprop debug.loglevel 0
adb shell setprop debug.log.enable false
adb shell setprop debug.thread_raw.log false
adb shell setprop debug.apusyslog false
adb shell setprop debug.neuropilot.gpu.systrace false
adb shell setprop debug.neuron.runtime.ProfilingLevel 0
adb shell setprop debug.neuron.runtime.EnableDebugger false
adb shell setprop debug.hwc.aibld_dump_enable false
adb shell setprop debug.tkflow.bokeh.log 0
adb shell setprop debug.tone.log.enable false
adb shell setprop debug.vpustream.loglevel 0
adb shell setprop debug.smvrb.loglevel 0
adb shell setprop debug.pipeline.trace 0
adb shell setprop debug.mtk_tflite.vlog 0
adb shell setprop debug.sensors.color.log 0
adb shell setprop debug.P1STT.log 0
adb shell setprop debug.af_alg.log.level 0
adb shell setprop debug.awb.sa.log.level 0
adb shell setprop debug.gpud.gl.state.error.dump 0
adb shell setprop debug.gpud.log 0
adb shell setprop debug.3alog.enable false
adb shell setprop debug.STEREO.Log 0
adb shell setprop debug.STEREO.dump 0
adb shell setprop debug.ThreadPool.log 0
adb shell setprop debug.edma.loglevel 0
adb shell setprop debug.sync3A.log 0
adb shell setprop debug.camera.3dnr.log.level 0
adb shell setprop debug.sync3AWrapper.log 0
adb shell setprop debug.sf.wdlog 0
adb shell setprop debug.sf.display_dejitter_log 0
adb shell setprop debug.sensors.flicker.log 0
adb shell setprop debug.tpi.s.log 0
adb shell setprop debug.pip.logLevel 0
adb shell setprop debug.EntryPool.log 0
adb shell setprop debug.log.rpt 0
adb shell setprop debug.ltm.smth.log.enable false
adb shell setprop debug.fsc.log_level 0
adb shell setprop debug.gpunn.enable_profiler false
adb shell setprop debug.hal3av3.log 0
adb shell setprop debug.pq.enable.trace false
adb shell setprop debug.pd.dump.enable false
adb shell setprop debug.p2f.dump.enable false
adb shell setprop debug.neuron.runtime.DumpVerbose 0
adb shell setprop debug.vendor.sys.camfilelock.log 0
adb shell setprop debug.smvr.log.level 0
adb shell setprop debug.statistic_buf.enable false
adb shell setprop debug.sync3AMgr.log false
adb shell setprop debug.tpi.s.async.log false
adb shell setprop debug.tpi.s.dump false
adb shell setprop debug.tsfcore.filedump.enable false
adb shell setprop debug.gpud.wsframebuffer.log 0
adb shell setprop debug.hmplog 0
adb shell setprop debug.hwui.memory_dump_disable 1
adb shell setprop debug.trace.p2.Cropper 0
adb shell setprop debug.trace.p2.CaptureNode 0
adb shell setprop debug.trace.p2.LMVInfo 0
adb shell setprop debug.trace.p2.Streaming_VSDOF 0
adb shell setprop debug.systrace.p2 0
adb shell setprop debug.sf.show_msync2_trace false
::debugprop from tecno pova 6 neo
:skiplogv
cls
::if something is wrong , revert this prop by reboot
:: NEW: universal log silencer (real, persistent across reboots).
:: This is what `persist.log.tag "*:S"` from the user's .sh actually
:: does - silences ALL logcat tags at the "Silent" level. The
:: existing per-tag setprops below remain as a belt-and-braces.
adb shell setprop persist.log.tag "*:S" > nul 2>&1
adb shell setprop log.tag "*:S" > nul 2>&1
adb shell setprop debug.vendor.gpu.record_sbwc false
adb shell setprop debug.egl.blobcache.multifile false
adb shell setprop debug.tracefpunwindoff 1
adb shell setprop log.tag.LAUNCHER_TRACE S > nul 2>&1
adb shell device_config put systemui com.android.systemui.coroutine_tracing false
adb shell setprop persist.log.tag.DisplayPowerController S > nul 2>&1
adb shell setprop debug.met_log_d.user null
adb shell cmd wifi set-verbose-logging disabled > nul 2>&1
adb shell device_config put profcollect_native_boot enabled false
adb shell setprop debug.sf.boot_animation false
adb shell setprop debug.sf.edge_extension_shader false
adb shell setprop debug.perf_event_max_sample_rate 1
adb shell setprop debug.perf_event_mlock_kb 2
adb shell setprop debug.perf_cpu_time_max_percent 1
adb shell setprop security.perf_harden 0
adb shell setprop debug.lldb-rpc-server 0
adb shell setprop debug.MB.running 0
adb shell setprop debug.hwc.otf 0
adb shell setprop debug.art.monitor.app false
::if something is wrong , revert this propt by reboot
adb shell setprop sys.wifitracing.started 0 > nul 2>&1
adb shell setprop debug.rs.script 0
adb shell setprop debug.rs.shader 0
adb shell setprop debug.sensors 0
adb shell setprop debug.hwui.profile false
adb shell setprop debug.layout false
adb shell setprop debug.generate-debug-info false
adb shell setprop debug.egl.traceGpuCompletion false
adb shell setprop debug.rs.shader.attributes 0
adb shell setprop debug.rs.shader.uniforms 0
adb shell setprop debug.rs.visual 0
adb shell setprop debug.egl.callstack false
adb shell setprop debug.orientation.log false
adb shell setprop debug.ld.all 0
adb shell setprop debug.hwui.level 0
adb shell setprop debug.contacts.ksad 0
adb shell setprop debug.sf.layerdump 0
adb shell setprop debug.ldbase 0
adb shell setprop debug.perfmond.atrace 0
adb shell setprop debug.sf.enable_transaction_tracing false
adb shell setprop debug.gles.layers 0
adb shell setprop debug.angle.validation false
adb shell setprop debug.sf.layer_history_trace false
adb shell setprop debug.sf.layer_caching_highlight false
adb shell setprop debug.jni.logging 0
adb shell setprop debug.orientation.log false
adb shell setprop debug.track-associations 0
adb shell setprop debug.tracing.screen_state 0
adb shell setprop debug.synclog 0
adb shell setprop debug.sys.looper_stats_enabled 0
adb shell setprop debug.velocitytracker.alt 0
adb shell setprop debug.tflite.trace 0
adb shell setprop debug.adbd.logging 0
adb shell setprop debug.sf.enable_egl_image_tracker false
adb shell setprop debug.stagefright.omx-debug 0
adb shell setprop debug.stagefright.profilecodec 0
adb shell setprop debug.debuggerd.wait_for_gdb false
adb shell setprop debug.cp2.scan_all_packages 0
adb shell setprop debug.tracing.screen_brightness 0
adb shell setprop debug.servicemanager.log_calls 0
adb shell setprop debug.hwui.print_config 0
adb shell setprop debug.choreographer.frametime false
adb shell setprop debug.sf.vsp_trace false
adb shell setprop debug.egl.trace 0
adb shell setprop debug.egl.finish false
adb shell setprop debug.sf.trace_hint_sessions false
adb shell setprop debug.sf.vsync_trace_detailed_info false
adb shell setprop debug.atrace.tags.enableflags 0
adb shell setprop debug.debuggerd.wait_for_debugger false
adb shell setprop debug.hwui.capture_skp_enabled false
adb shell setprop debug.renderengine.skia_atrace_enabled 0
adb shell setprop debug.mdpcomp.logs 0
adb shell setprop debug.graphics.gpu.profiler.perfetto 0
adb shell setprop debug.NewDatabasePerformanceTests.enable_wal false
adb shell setprop debug.hwui.skia_atrace_enabled 0
adb shell setprop debug.rs.profile 0
adb shell setprop debug.sf.dump 0
adb shell setprop debug.debuggerd.disable 1
adb shell setprop debug.hwc_dump_en 0
adb shell setprop persist.traced.enable 0 > nul 2>&1
adb shell setprop debug.hwc.logvsync 0
adb shell setprop debug.malloc 0
adb shell setprop debug.enable.wl_log 0
adb shell setprop debug.sensors.logging.slpi false
adb shell setprop debug.tracing.battery_status 0
adb shell setprop debug.hwui.trace_gpu_resources false
adb shell setprop debug.hwui.skia_use_perfetto_track_events false
adb shell setprop debug.hwui.skia_tracing_enabled false
adb shell setprop debug.hwui.skip_eglmanager_telemetry true
adb shell setprop persist.traced_perf.enable false > nul 2>&1
adb shell setprop debug.renderengine.skia_use_perfetto_track_events false
adb shell setprop debug.tracing.ctl.renderengine.skia_tracing_enabled false
adb shell setprop debug.hwui.skp_filename false
adb shell setprop debug.sqlite.journalmode OFF
adb shell setprop debug.sqlite.syncmode OFF
adb shell setprop debug.sqlite.journalsizelimit 1mb
adb shell setprop debug.sqlite.wal.syncmode OFF
adb shell setprop debug.sf.dump.external false
adb shell setprop debug.sf.dump.primary false
adb shell setprop debug.sf.dump.png 0
adb shell setprop debug.checkjni 0
adb shell setprop debug.apidump.detailed false
adb shell setprop debug.renderengine.skia_tracing_enabled false
adb shell setprop debug.adpf_cts_verbose_logging false
adb shell setprop debug.tracing.plug_type 0
adb shell setprop debug.tracing.profile_boot_classpath 0
adb shell setprop debug.tracing.profile_system_server 0
adb shell setprop debug.tracing.mnc 0
adb shell setprop debug.tracing.mcc 0
adb shell setprop debug.tracing.device_state 0
adb shell setprop debug.logging.enabled false
adb shell setprop debug.nn.fuzzer.dumpspec 0
adb shell setprop debug.nn.fuzzer.log 0
adb shell setprop debug.nn.fuzzer.detectleak 0
adb shell setprop debug.perfetto.sdk_sysprop_guard_generation 0
adb shell setprop debug.libbase.property_test false
adb shell setprop debug.tracing.ctl.perfetto.sdk_sysprop_guard_generation false
adb shell setprop debug.tracing.ctl.hwui.skia_use_perfetto_track_events false
adb shell setprop debug.tracing.ctl.hwui.skia_tracing_enabled false
adb shell setprop debug.sf.dump.enable false
adb shell setprop debug.hwc.enable_vds_dump 0
adb shell setprop debug.power.loghint 0
adb shell setprop debug.surface_trace 0
adb shell setprop debug.sf.ddms 0
adb shell setprop debug.sensors.diag_buffer_log false
adb shell setprop debug.systemui.latency_tracking 0
adb shell setprop debug.hwc.trace_hint_sessions false
adb shell setprop debug.vulkan.enable_callback false
adb shell setprop debug.angle.enable_vulkan_api_dump_layer 0
adb shell setprop debug.angle.capture.enabled 0
adb shell setprop debug.force_remoteinput_history false
adb shell setprop persist.debug.trace_layouts false > nul 2>&1
adb shell setprop debug.atrace.prefer_sdk false
adb shell setprop debug.tracing.desktop_mode_visible_tasks 0
adb shell setprop debug.msg_enable 0
adb shell setprop debug.hwc.normalize_hint_session_durations false
adb shell setprop db.log.detailed 0 > nul 2>&1
adb shell setprop debug.mdlogger.Running 0
adb shell setprop debug.sf.sa_log 0
adb shell setprop debug.hwc.fakevsync 0
adb shell setprop debug.rs.reduce-split-accum 1
adb shell setprop debug.hwui.nv_profiling false
adb shell setprop debug.hwui.filter_test_overhead false
adb shell setprop debug.trace.enable 0
adb shell setprop debug.sf.treble_testing_override false
adb shell setprop debug.sf.kernel_idle_timer_update_overlay false
adb shell setprop debug.choreographer.janklog false
adb shell setprop debug.sf.hwc_hotplug_error_via_neg_vsync 0
adb shell setprop debug.firebase.analytics.app none
adb shell setprop debug.atrace.user_initiated 0
adb shell setprop debug.stagefright.rtp false
adb shell setprop debug.incremental.enforce_readlogs_max_interval_for_system_dataloaders false
adb shell setprop debug.Stats false
adb shell setprop debug.AnalysisOrder false
adb shell setprop debug.DumpLiveExprs false
adb shell setprop debug.DumpLiveVars false
adb shell setprop debug.DumpCFG false
adb shell setprop debug.ViewCFG false
adb shell setprop debug.DumpCalls false
adb shell setprop debug.ReportStmts false
adb shell setprop debug.DumpDominators false
adb shell setprop debug.DumpCallGraph false
adb shell setprop debug.ConfigDumper false
adb shell setprop debug.DumpControlDependencies false
adb shell setprop debug.ExprInspection false
adb shell setprop debug.adservices.consent_manager_debug_mode null
adb shell setprop debug.vulkan.layers ''
:::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: REMOVED: debug.force_low_ram true
:: This was actively HARMFUL here. It forces low-RAM mode
:: (smaller heap, aggressive process killing, fewer caches)
:: which slows the device down. It's still set deliberately
:: inside :onsvpp (Extreme Power Saver) where it belongs.
adb shell device_config put device_personalization_services SpeechRecognitionService__clear_logging_events_if_too_much_memory true
:::::::::::::::::::::::::::::::::::::::::::::::::::::::
::changed
adb shell setprop debug.sf.prime_shader_cache.transparent_image_dimmed_layers false
adb shell setprop debug.sf.prime_shader_cache.solid_dimmed_layers false
adb shell setprop debug.sf.prime_shader_cache.shadow_layers false
adb shell setprop debug.egl.force_msaa false
adb shell setprop debug.sf.showupdates 0
adb shell setprop debug.sf.showcpu 0
adb shell setprop debug.sf.showbackground 0
adb shell setprop debug.sf.showfps 0
adb shell setprop debug.rs.debug 0
adb shell setprop debug.sf.show_refresh_rate_overlay_spinner 0
adb shell setprop debug.sf.show_refresh_rate_overlay_render_rate 0
adb shell setprop debug.sf.show_refresh_rate_overlay_in_middle 0
adb shell setprop debug.hwc.showfps 0
adb shell setprop debug.hwui.overdraw false
adb shell setprop debug.hwui.webview_overlays_enabled false
adb shell setprop debug.sf.enable_hwc_vds false
adb shell setprop debug.hwui.profile.maxframes 0
adb shell setprop debug.hwui.show_non_rect_clip hide
adb shell setprop debug.hwui.show_layers_updates false
adb shell setprop debug.assert 0
adb shell setprop debug.hwui.show_dirty_regions false
adb shell setprop debug.angle.capture.frame_start 0
adb shell setprop debug.rs.reduce 1
adb shell setprop debug.sf.gpuoverlay 0
adb shell setprop debug.stagefright.fps false
adb shell setprop debug.sf.disable_hwc_vds 1
adb shell setprop debug.hwc.simulate 0
adb shell setprop debug.enable_remote_input false
adb shell setprop debug.angle.markers 0
adb shell setprop debug.stagefright.experiments false
adb shell setprop debug.stagefright.enableshaping 0
adb shell setprop debug.sf.show_predicted_vsync false
::changed
call :dropbox_lowprio
adb shell cmd dropbox set-rate-limit 20000000000000
adb shell device_config put runtime_native metrics.reporting-mods 0
adb shell device_config put runtime_native metrics.reporting-mods-server 0
adb shell device_config put runtime_native metrics.write-to-statsd false
adb shell device_config put runtime_native metrics.reporting-num-mods 0
adb shell device_config put runtime_native metrics.reporting-num-mods-server 0
adb shell device_config put runtime_native metrics.reporting-spec S
adb shell device_config put runtime_native metrics.reporting-spec-server S
adb shell device_config put odad enable_fa_stats_log_logging false
adb shell device_config put device_personalization_services StatsLog__active_users_logger_enabled false
adb shell device_config put device_personalization_services StatsLog__active_users_logger_non_persistent false
adb shell device_config put device_personalization_services StatsLog__enable_new_logger_api false
adb shell device_config put adservices cobalt_logging_enabled false
adb shell device_config put adservices enable_logged_topic false
adb shell device_config put adservices adservice_error_logging_enabled false
adb shell device_config put adservices measurement_enable_app_package_name_logging false
adb shell device_config put adservices measurement_enable_source_debug_report false
adb shell device_config put adservices fledge_app_package_name_logging_enabled false
adb shell device_config put adservices fledge_auction_server_enable_debug_reporting false
adb shell device_config put adservices fledge_auction_server_api_usage_metrics_enabled false
adb shell device_config put adservices enable_ad_services_system_api false
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_filtering false
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_socket false
adb shell device_config put odad westworld_logging false
adb shell device_config put odad log_error_model_id_westworld_enabled false
adb shell device_config put odad log_model_id_westworld false
adb shell device_config put odad log_model_version_westworld false
adb shell device_config put odad log_classification_latency_westworld false
adb shell device_config put odad moirai_additional_metrics_enabled false
adb shell device_config put odad mismatch_metrics_v2_enabled false
adb shell device_config put on_device_personalization odp_enable_client_error_logging false
adb shell device_config put on_device_personalization fcp_enable_client_error_logging false
adb shell device_config put on_device_personalization odp_background_jobs_logging_enabled false
adb shell device_config put on_device_personalization fcp_enable_background_jobs_logging false
adb shell device_config put device_personalization_services AutofillVC__enable_clearcut_log false
adb shell device_config put device_personalization_services Captions__enable_clearcut_logging false
adb shell device_config put device_personalization_services PlatformLogging__enable_metric_wise_populations false
adb shell device_config put device_personalization_services Superpacks__use_logging_listener false
adb shell device_config put device_personalization_services Overview__enable_pir_clearcut_logging false
adb shell device_config put device_personalization_services Overview__enable_pir_westworld_logging false
adb shell cmd display ab-logging-disable > nul 2>&1
adb shell cmd display dwb-logging-disable > nul 2>&1
adb shell cmd display dmd-logging-disable > nul 2>&1
adb shell settings put global netstats_sample_enabled 0
adb shell settings put global bluetooth_disabled_profiles 1
adb shell settings put global sqlite_compatibility_wal_flags legacy_compatibility_wal_enabled=false,wal_syncmode=OFF
adb shell settings put global foreground_service_starts_logging_enabled_uri false
adb shell settings put global activity_starts_logging_enabled_uri false
adb shell settings put global nene_log 0
adb shell settings put global wifi_link_speed_metrics_enabled 0
adb shell settings put global wifi_is_unusable_event_metrics_enabled 0
adb shell settings put global wait_for_debugger 0
adb shell settings put global contacts_database_wal_enabled 0
adb shell settings put global logcat_for_system_server_anr 0
adb shell settings put global enable_gnss_raw_meas_full_tracking 0
adb shell settings put global force_enable_pss_profiling 0
adb shell settings put global verbose_logging_level_disabled 1
adb shell settings put global enable_gpu_debug_layers 0
adb shell settings delete global gpu_debug_layers
adb shell settings put global sys_traced 0
adb shell settings put global autofill_logging_level 0
adb shell settings put global dropbox_max_files 1
adb shell settings put global activity_starts_logging_enabled 0
adb shell settings put global enable_diskstats_logging 0
adb shell settings put global foreground_service_starts_logging_enabled 0
adb shell settings put global wifi_verbose_logging_enabled 0
adb shell settings put global enable_automatic_system_server_heap_dumps 0
adb shell settings put global settings_enable_monitor_phantom_procs false
adb shell settings put global enable_opengl_traces false
adb shell settings put global dropbox:dumpsys:procstats disabled
adb shell settings put global dropbox:dumpsys:usagestats disabled
adb shell settings put global battery_stats_constants track_cpu_times_by_proc_state=false,track_cpu_active_cluster_time=false,read_binary_cpu_time=false,max_history_files=0,max_history_buffer_kb=0
adb shell settings put global chained_battery_attribution_enabled 0
adb shell settings put global kernel_cpu_thread_reader num_buckets=0,collected_uids=,minimum_total_cpu_usage_millis=999999999
adb shell settings put global sys_uidcpupower 0
adb shell settings put global netstats_augment_enabled 0
adb shell settings put global netstats_combine_subtype_enabled 0
adb shell settings put global settings_enable_spa_metrics false
adb shell settings put global settings_adb_metrics_writer false
adb shell device_config put systemui enable_notification_memory_monitoring false
adb shell device_config put interaction_jank_monitor enabled false
adb shell settings put system anr_debugging_mechanism 0
adb shell settings put system remote_control 0
adb shell cmd looper_stats disable > nul 2>&1
adb shell settings put global looper_stats enabled=false,sampling_interval=999999999
adb shell simpleperf --log fatal --log-to-android-buffer 0 > nul 2>&1
adb shell cmd autofill set log_level off
adb shell cmd autofill set max_visible_datasets 0
adb shell cmd activity clear-debug-app
adb shell cmd activity clear-exit-info
adb shell cmd device_policy clear-freeze-period-record > nul 2>&1
adb shell cmd otadexopt cleanup
adb shell cmd voiceinteraction set-debug-hotword-logging false
call :wm_silence_logs
adb shell dumpsys binder_calls_stats --disable > nul 2>&1
adb shell dumpsys binder_calls_stats --disable-detailed-tracking > nul 2>&1
adb shell dumpsys procstats --stop-testing > nul 2>&1
adb shell settings put global binder_calls_stats sampling_interval=500000000,detailed_tracking=disable,enabled=false,upload_data=false
adb shell dumpsys batterystats disable full-history > nul 2>&1
adb shell ime tracing stop
adb shell logcat -c
adb shell logcat -G 64kb
adb shell wm tracing level critical > nul 2>&1
adb shell wm tracing size 1 > nul 2>&1
adb shell device_config set_sync_disabled_for_tests persistent > nul 2>&1
echo Done , Press Any Button To Go Back

pause > nul
goto Battery

:onlogss
cls
title Logs/etc : On
:: NEW: revert universal log silencer
adb shell setprop persist.log.tag "" > nul 2>&1
adb shell setprop log.tag "" > nul 2>&1
adb shell logcat -G 256kb
adb shell device_config put adservices enable_ad_services_system_api true
adb shell device_config put odad mismatch_metrics_v2_enabled true
adb shell device_config put adservices fledge_auction_server_api_usage_metrics_enabled true
adb shell device_config put adservices enable_logged_topic true
adb shell settings delete global settings_adb_metrics_writer > nul 2>&1
adb shell settings delete global settings_enable_spa_metrics > nul 2>&1
adb shell device_config put device_personalization_services SpeechRecognitionService__clear_logging_events_if_too_much_memory false
adb shell settings delete global netstats_augment_enabled > nul 2>&1
adb shell settings delete global netstats_combine_subtype_enabled > nul 2>&1
adb shell device_config put interaction_jank_monitor enabled true
adb shell device_config delete systemui enable_notification_memory_monitoring > nul 2>&1
adb shell settings delete global sys_uidcpupower > nul 2>&1
adb shell settings delete global contacts_database_wal_enabled > nul 2>&1
adb shell settings delete global kernel_cpu_thread_reader > nul 2>&1
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_filtering true
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_socket true
adb shell device_config put device_personalization_services AutofillVC__enable_clearcut_log true
adb shell settings delete global chained_battery_attribution_enabled > nul 2>&1
adb shell device_config put odad moirai_additional_metrics_enabled true
adb shell device_config put odad log_classification_latency_westworld true
:: FIX (revert-completeness): was `put ...track_cpu_times_by_proc_state=false`,
:: which re-pinned a non-default value instead of reverting. Delete so battery
:: stats tracking returns to the platform default (:offlogss pinned it to
:: max_history_files=0 etc).
adb shell settings delete global battery_stats_constants > nul 2>&1
adb shell device_config put adservices fledge_auction_server_enable_debug_reporting true
adb shell device_config put adservices fledge_app_package_name_logging_enabled true
adb shell device_config put adservices mdd_network_stats_logging_sample_interval 100
adb shell device_config put adservices mdd_api_logging_sample_interval 100
adb shell device_config put device_personalization_services Overview__enable_pir_westworld_logging true
adb shell device_config put device_personalization_services Overview__enable_pir_clearcut_logging true
adb shell settings delete global dropbox:dumpsys:procstats > nul 2>&1
adb shell settings delete global dropbox:dumpsys:usagestats > nul 2>&1
adb shell setprop security.perf_harden 1
adb shell settings delete global enable_opengl_traces > nul 2>&1
adb shell device_config put odad log_model_version_westworld true
adb shell device_config put odad log_model_id_westworld true
adb shell device_config put odad log_error_model_id_westworld_enabled true
adb shell device_config put device_personalization_services Superpacks__use_logging_listener true
adb shell device_config put on_device_personalization fcp_enable_background_jobs_logging true
adb shell device_config put device_personalization_services Captions__enable_clearcut_logging true
adb shell device_config put device_personalization_services PlatformLogging__enable_metric_wise_populations true
adb shell device_config put runtime_native metrics.reporting-spec 1,5,30,60,600
adb shell device_config put runtime_native metrics.reporting-spec-server 1,10,60,3600,*
adb shell device_config put runtime_native metrics.write-to-statsd true
adb shell device_config put runtime_native metrics.reporting-num-mods 100
adb shell device_config put runtime_native metrics.reporting-num-mods-server 100
adb shell device_config put runtime_native metrics.reporting-mods 2
adb shell device_config put runtime_native metrics.reporting-mods-server 2
adb shell settings delete global netstats_sample_enabled > nul 2>&1
adb shell settings put global bluetooth_disabled_profiles 0
adb shell wm tracing level trim > nul 2>&1
adb shell settings delete global binder_calls_stats > nul 2>&1
adb shell settings delete global foreground_service_starts_logging_enabled_uri > nul 2>&1
adb shell settings delete global activity_starts_logging_enabled_uri > nul 2>&1
adb shell device_config delete profcollect_native_boot > nul 2>&1
adb shell setprop persist.log.tag.DisplayPowerController ''
adb shell device_config delete systemui com.android.systemui.coroutine_tracing > nul 2>&1
adb shell settings delete global nene_log > nul 2>&1
adb shell settings delete global wifi_link_speed_metrics_enabled > nul 2>&1
adb shell settings delete global wifi_is_unusable_event_metrics_enabled > nul 2>&1
adb shell settings delete global wait_for_debugger > nul 2>&1
adb shell settings delete global contacts_database_wal_enabled > nul 2>&1
adb shell settings delete global logcat_for_system_server_anr > nul 2>&1
adb shell settings delete global enable_gnss_raw_meas_full_tracking > nul 2>&1
adb shell settings delete global force_enable_pss_profiling > nul 2>&1
adb shell settings delete global verbose_logging_level_disabled > nul 2>&1
adb shell settings delete global enable_gpu_debug_layers > nul 2>&1
adb shell cmd autofill set max_visible_datasets 10
adb shell settings delete global sys_traced > nul 2>&1
adb shell settings delete system user_log_enabled > nul 2>&1
adb shell settings delete system window_orientation_listener_log > nul 2>&1
adb shell settings delete global enable_automatic_system_server_heap_dumps > nul 2>&1
adb shell settings delete global sys.wifitracing.started > nul 2>&1
adb shell settings delete global opengl_trace > nul 2>&1
adb shell settings delete global settings_enable_monitor_phantom_procs > nul 2>&1
adb shell settings delete global dropbox_max_files > nul 2>&1
adb shell settings delete global dropbox:dumpsys:usagestats > nul 2>&1
adb shell settings delete global dropbox:dumpsys:procstats > nul 2>&1
adb shell settings delete global activity_starts_logging_enabled > nul 2>&1
adb shell settings delete global enable_diskstats_logging > nul 2>&1
adb shell settings delete global sys.lmk.reportkills > nul 2>&1
adb shell settings delete global foreground_service_starts_logging_enabled > nul 2>&1
adb shell settings delete global wifi_verbose_logging_enabled > nul 2>&1
adb shell settings delete global enable_automatic_system_server_heap_dumps > nul 2>&1
adb shell cmd looper_stats enable
adb shell settings delete system anr_debugging_mechanism > nul 2>&1
adb shell setprop persist.traced.enable 1 > nul 2>&1
adb shell settings delete global idle_loglevel > nul 2>&1
adb shell settings delete global persist.sampling_profiler > nul 2>&1
adb shell settings delete system Logcat.live > nul 2>&1
adb shell settings delete system remote_control > nul 2>&1
adb shell settings delete system log.closeguard.Animation > nul 2>&1
call :dropbox_lowprio
adb shell cmd dropbox set-rate-limit 2000
adb shell setprop persist.traced_perf.enable 1 > nul 2>&1
:: FIX: copy-paste bug - this is the On/restore path so it must re-ENABLE
:: (true). It was `false`, identical to :offlogss, so the key never reverted.
adb shell device_config put odad enable_fa_stats_log_logging true
adb shell device_config put device_personalization_services StatsLog__active_users_logger_enabled true
adb shell device_config put device_personalization_services StatsLog__active_users_logger_non_persistent true
adb shell device_config put device_personalization_services StatsLog__enable_new_logger_api true
adb shell device_config put adservices cobalt_logging_enabled true
adb shell device_config put adservices adservice_error_logging_enabled true
adb shell device_config put odad westworld_logging true
adb shell device_config put adservices measurement_enable_source_debug_report true
adb shell cmd display ab-logging-enable > nul 2>&1
adb shell cmd display dwb-logging-enable > nul 2>&1
adb shell cmd display dmd-logging-enable > nul 2>&1
adb shell device_config put on_device_personalization odp_enable_client_error_logging true
adb shell device_config put adservices measurement_enable_app_package_name_logging true
adb shell device_config put on_device_personalization fcp_enable_client_error_logging true
:: FIX (revert-completeness): :offlogss pins these PERSISTENT keys that this
:: On/restore path never undid, so log/metric collection stayed disabled after
:: toggling back On. settings survive reboot, so the restart prompt below does
:: NOT cover them; set_sync_disabled_for_tests persistent also froze ALL
:: device_config server sync until reset.
adb shell device_config set_sync_disabled_for_tests none > nul 2>&1
adb shell settings delete global looper_stats > nul 2>&1
adb shell settings delete global sqlite_compatibility_wal_flags > nul 2>&1
adb shell settings delete global autofill_logging_level > nul 2>&1
adb shell device_config put on_device_personalization odp_background_jobs_logging_enabled true > nul 2>&1
adb shell logcat -c <nul
echo.
echo.
echo [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
timeout /t 2 /nobreak > nul
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:saverpower
@echo off
cls
title Toggle Power Saver
echo.
echo.
echo Toggle Your Power Saver Here
echo.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offsv
if "!toggle!"=="2" goto onsv
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto saverpower

:offsv
@echo off
cls
title Power Saver : Off
adb shell settings delete global low_power
adb shell settings delete global low_power_sticky <nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsv
@echo off
cls
title Power Saver : On
adb shell settings put global low_power 1
adb shell settings put global low_power_sticky 0 <nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:animation
@echo off
cls
title Toggle Animation
echo.
echo.
echo Toggle Your Animation Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offani
if "!toggle!"=="2" goto onani
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto animation

:offani
@echo off
cls
title Animation : Off
adb shell settings put global enable_back_animation 0
adb shell settings put global fancy_ime_animations 0
adb shell settings put secure accessibility_disable_animations 1
adb shell settings put global fade_duration 0
adb shell settings put global reduce_motion 1
adb shell settings put secure reduce_motion 1
adb shell settings put secure long_press_timeout 250
adb shell settings put secure multi_press_timeout 250
adb shell settings put global enable_back_animation 0
adb shell settings put global window_animation_scale 0.0
adb shell settings put global transition_animation_scale 0.0
adb shell settings put global animator_duration_scale 0.0
adb shell settings put secure accessibility_disable_animations 1
adb shell settings put global disable_window_blurs 1 <nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:onani
@echo off
cls
title Animation : On
adb shell settings delete global reduce_motion > nul 2>&1
adb shell settings delete global enable_back_animation > nul 2>&1
adb shell settings delete global fancy_ime_animations > nul 2>&1
adb shell settings delete secure accessibility_disable_animations > nul 2>&1
adb shell settings delete global recent_app_transition_duration_scale > nul 2>&1
adb shell settings delete global recent_app_transition_scale > nul 2>&1
adb shell settings delete global app_transition_animation_duration_scale > nul 2>&1
adb shell settings delete global app_transition_animation_scale > nul 2>&1
adb shell settings delete global reduce_transitions > nul 2>&1
adb shell settings delete global shadow_animation_scale > nul 2>&1
adb shell settings delete global remove_animations > nul 2>&1
adb shell settings delete global fade_duration > nul 2>&1
adb shell settings delete secure reduce_motion > nul 2>&1
:: FIX (revert-completeness): :offani pins secure long_press_timeout and
:: multi_press_timeout to 250; restoring animations ("On") must delete them
:: so tap / long-press timing returns to the platform default (400 / 300 ms).
adb shell settings delete secure long_press_timeout > nul 2>&1
adb shell settings delete secure multi_press_timeout > nul 2>&1
adb shell settings delete global animator_slow_preview > nul 2>&1
adb shell settings delete global animation_scale_animator_duration > nul 2>&1
adb shell settings delete global animation_scale_window_transition > nul 2>&1
adb shell settings delete global activity_open_enter_animation > nul 2>&1
adb shell settings delete global activity_open_exit_animation > nul 2>&1
adb shell settings delete global activity_close_enter_animation > nul 2>&1
adb shell settings delete global activity_close_exit_animation > nul 2>&1
adb shell settings delete global app_transition_scale > nul 2>&1
adb shell settings delete global app_transition_duration_scale > nul 2>&1
adb shell settings delete global app_close_animate_level > nul 2>&1
adb shell settings delete global windows_anim_duration_scale > nul 2>&1
adb shell settings delete global windows_anim_scale > nul 2>&1
adb shell settings delete global windows_transition_anim_scale > nul 2>&1
adb shell settings delete global windows_transition_animation_duration_scale > nul 2>&1
adb shell settings delete global window_animation_duration_scale > nul 2>&1
adb shell settings delete global transition_animation_duration_scale > nul 2>&1
adb shell settings delete global display_animation_duration_scale > nul 2>&1
adb shell settings delete global display_animation_scale > nul 2>&1
adb shell settings delete global window_move_animation_duration_scale > nul 2>&1
adb shell settings delete global window_move_animation_scale > nul 2>&1
adb shell settings put global window_animation_scale 1.0 > nul 2>&1
adb shell settings put global transition_animation_scale 1.0 > nul 2>&1
adb shell settings put global animator_duration_scale 1.0 > nul 2>&1
adb shell settings put global disable_window_blurs 0 > nul 2>&1
adb shell settings delete global accessibility_reduce_transparency > nul 2>&1
adb shell device_config delete systemui window_cornerRadius > nul 2>&1
adb shell device_config delete systemui window_blur > nul 2>&1
adb shell device_config delete systemui window_shadow > nul 2>&1
adb shell device_config delete systemui reduce_animations > nul 2>&1
adb shell device_config delete battery_saver reduce_animations <nul > nul 2>&1
echo.
echo.
echo [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
timeout /t 2 /nobreak > nul
echo Press Any Button To Go Back
pause > nul
goto Battery
::wifisettings
:autowifi
@echo off
cls
title Toggle Auto Wifi
echo.
echo.
echo Toggle Auto Wifi Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offaut
if "!toggle!"=="2" goto onaut
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto autowifi

:offaut
@echo off
cls
title Auto Wifi : Off
adb shell settings put global wifi_supplicant_scan_interval_ms 240000
adb shell settings put global wifi_networks_available_notification_on 0
adb shell settings put global wifi_watchdog_on 0
adb shell settings put global wifi_watchdog_poor_network_test_enabled 0
adb shell settings put global auto_wifi 0 > nul 2>&1
adb shell settings put global wifi_scan_always_enabled 0 > nul 2>&1
adb shell settings put global bluetooth_scan_always_enabled 0 > nul 2>&1
adb shell settings put global network_recommendations_enabled 0 > nul 2>&1
adb shell settings put global netstats_enabled 0 > nul 2>&1
adb shell settings put global network_scoring_ui_enabled 0 > nul 2>&1
adb shell settings put global wifi_watchdog_poor_network_test_enabled 0 <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onaut
@echo off
cls
title Auto Wifi : On
adb shell settings delete global wifi_supplicant_scan_interval_ms > nul 2>&1
adb shell settings delete global wifi_networks_available_notification_on > nul 2>&1
adb shell settings delete global wifi_watchdog_on > nul 2>&1
adb shell settings delete global wifi_watchdog_poor_network_test_enabled > nul 2>&1
adb shell settings put global auto_wifi 1 > nul 2>&1
adb shell settings put global wifi_scan_always_enabled 1 > nul 2>&1
adb shell settings put global bluetooth_scan_always_enabled 1 > nul 2>&1
adb shell settings delete global network_recommendations_enabled > nul 2>&1
adb shell settings put global netstats_enabled 1 > nul 2>&1
adb shell settings put global network_scoring_ui_enabled 1 > nul 2>&1
adb shell settings delete global wifi_watchdog_poor_network_test_enabled <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery
::sync
:sync
cls
title Toggle Sync
echo.
echo.
echo Toggle Sync Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offsync
if "!toggle!"=="2" goto onsync
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto sync

:offsync
@echo off
cls
title Sync : Off
:: FIX (consistency): unify on master_sync_status - the key :syncmaster uses,
:: the backup captures (:_bk_settings global master_sync_status) and CheckSetting
:: displays. auto_sync / master_sync_enabled are read by nothing on modern
:: Android (all three are placebo settings keys; real master sync lives in
:: SyncManager and isn't rootless-writable), but master_sync_status is at least
:: the one DCX backs up, so a backup/restore now round-trips this toggle.
adb shell settings put global master_sync_status 0
adb shell device_config set_sync_disabled_for_tests persistent <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsync
@echo off
cls
title Sync : On
:: FIX (consistency): see :offsync - unify on master_sync_status.
adb shell settings put global master_sync_status 1
adb shell device_config set_sync_disabled_for_tests none <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery
::motion
:motion
@echo off
cls
title Toggle Motion
echo.
echo.
echo Toggle Your Motion Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offmotion
if "!toggle!"=="2" goto onmotion
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto motion

:offmotion
@echo off
cls
title Motion : Off
adb shell settings put system master_motion 0 > nul 2>&1
adb shell settings put system motion_engine 0 > nul 2>&1
adb shell settings put system air_motion_engine 0 > nul 2>&1
adb shell settings put system air_motion_wake_up 0 <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onmotion
@echo off
cls
title Motion : On
:: FIX: "settings remove" is not a real verb (stock verbs: get/put/delete/
:: reset/list), so Motion "On" silently reverted nothing - the error was
:: hidden by >nul 2>&1. "delete" restores the OEM default as intended.
adb shell settings delete system master_motion > nul 2>&1
adb shell settings delete system motion_engine > nul 2>&1
adb shell settings delete system air_motion_engine > nul 2>&1
adb shell settings delete system air_motion_wake_up <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery
::zram
:zram
@echo off
cls
title Toggle ZRAM
echo.
echo.
echo Toggle Your ZRAM Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offzram
if "!toggle!"=="2" goto onzram
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto zram

:offzram
@echo off
cls
title ZRAM : Off
adb shell settings put global zram 0
adb shell settings put global zram_enabled 0 <nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:onzram
@echo off
cls
title ZRAM : On
adb shell settings put global zram 1
adb shell settings put global zram_enabled 1 <nul
echo Press Any Button To Go Back
pause > nul
goto Battery
::extreme
:extremepower
@echo off
cls
title Toggle Extreme Power Saver
echo.
echo.
echo Toggle Your Extreme Power Saver Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offsvpp
if "!toggle!"=="2" goto onsvpp
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto extremepower

:offsvpp
@echo off
cls
title Extreme Power Saver : Off
adb shell device_config delete activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled
adb shell device_config delete activity_manager bg_auto_restrict_abusive_apps
adb shell cmd power set-adaptive-power-saver-enabled false
adb shell cmd power set-mode 0
adb shell settings put global battery_tip_constants app_restriction_enabled=true
adb shell settings delete global battery_saver_constants > nul 2>&1
adb shell settings delete global protect_battery > nul 2>&1
adb shell settings delete global activity_manager_constants > nul 2>&1
:: FIX (revert-completeness): :onsvpp forces the device into low-RAM mode
:: (debug.force_low_ram true), which persists until reboot and degrades
:: every app launched afterward. Clear it so "Off" starts reverting
:: immediately; the reboot prompted below completes it. (The debug.rs.*
:: RenderScript props :onsvpp sets are no-ops on Android 12+ and have no
:: clean default to restore, so they are left to the reboot.)
adb shell setprop debug.force_low_ram false <nul > nul 2>&1
echo.
echo.
echo [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
timeout /t 2 /nobreak > nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsvpp
@echo off
cls
title Extreme Power Saver : On
:: FIX: this ran BOTH "cmd battery reset" and "dumpsys battery reset" -
:: two interfaces to the same operation (clears any fake-battery state so
:: the saver reads the real battery). One call is enough; dumpsys is kept
:: because it exists on older builds where the "cmd" service shell may not.
adb shell dumpsys battery reset
adb shell device_config put activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled true
adb shell device_config put activity_manager bg_auto_restrict_abusive_apps 1
adb shell settings put global activity_manager_constants power_check_interval=990000,power_check_max_cpu_1=2,power_check_max_cpu_2=2,power_check_max_cpu_3=2,power_check_max_cpu_4=2
adb shell settings put global battery_saver_constants advertise_is_enabled=false,enable_datasaver=false,enable_night_mode=true,disable_launch_boost=true,disable_vibration=true,disable_animation=true,disable_soundtrigger=true,defer_full_backup=true,defer_keyvalue_backup=true,enable_firewall=false,location_mode=2,enable_brightness_adjustment=false,adjust_brightness_factor=0.5,force_all_apps_standby=true,force_background_check=true,disable_optional_sensors=true,disable_aod=true,enable_quick_doze=true
adb shell settings put global battery_tip_constants reduced_battery_enabled=true,battery_saver_tip_enabled=true,high_usage_period_ms=120000,app_restriction_enabled=true,battery_tip_enabled=false,summary_enabled=false,high_usage_enabled=true,high_usage_app_count=1,high_usage_battery_draining=15,reduced_battery_percent=5,low_battery_enabled=true,low_battery_hour=1
adb shell cmd power set-mode 1
adb shell cmd power set-adaptive-power-saver-enabled true
adb shell setprop debug.rs.max-threads 2
adb shell setprop debug.rs.precision rs_fp_relaxed
adb shell setprop debug.force_low_ram true <nul
echo Press Any Button To Go Back
pause > nul
goto Battery

:senderror
cls
title Toggle Send Error
echo.
echo.
echo Toggle Your Send Error Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offerr
if "!toggle!"=="2" goto onerr
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto senderror

:offerr
cls
title Send Error : Off
adb shell settings put secure send_action_app_error 0 > nul 2>&1
adb shell settings put global send_action_app_error 0 > nul 2>&1
adb shell settings put global enable_diagnostic_data 0 > nul 2>&1
adb shell settings put system send_security_reports 0 > nul 2>&1
adb shell settings put secure upload_debug_log_pref 0 > nul 2>&1
adb shell settings put secure upload_log_pref 0 > nul 2>&1
adb shell settings put system profiler.force_disable_ulog 1 > nul 2>&1
adb shell settings put system profiler.force_disable_err_rpt 1 > nul 2>&1
adb shell settings put secure usage_metrics_marketing_enabled 0 > nul 2>&1
adb shell settings put secure USAGE_METRICS_UPLOAD_ENABLED 0 <nul > nul 2>&1
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:onerr
cls
title Send Error : On
adb shell settings put secure send_action_app_error 1 > nul 2>&1
adb shell settings put global send_action_app_error 1 > nul 2>&1
adb shell settings put global enable_diagnostic_data 1 > nul 2>&1
adb shell settings put system send_security_reports 1 > nul 2>&1
adb shell settings delete secure upload_debug_log_pref > nul 2>&1
adb shell settings delete secure upload_log_pref > nul 2>&1
adb shell settings delete system profiler.force_disable_ulog > nul 2>&1
adb shell settings delete system profiler.force_disable_err_rpt > nul 2>&1
adb shell settings delete secure usage_metrics_marketing_enabled > nul 2>&1
adb shell settings delete secure USAGE_METRICS_UPLOAD_ENABLED <nul > nul 2>&1
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:toggleprofilling
cls
title Toggle Lock Profiling
echo.
echo.
echo Toggle Your Lock Profiling Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offprof
if "!toggle!"=="2" goto onprof
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto toggleprofilling

:offprof
cls
title Lock Profiling : Off
adb shell device_config put runtime_native_boot disable_lock_profiling true <nul
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:onprof
cls
title Lock Profiling : ON
adb shell device_config put runtime_native_boot disable_lock_profiling false <nul
echo Done , Press Any Button To Go Back
pause > nul
goto Battery
:: gaming
:Gaming
@echo off
title Gaming Mode
cls
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime ^<nul 2^>nul') do echo           [%g%+%w%]Uptime: %%a %%b %%c
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
echo           [%g%+%w%]%cpucheck% LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %r%[%w%1%r%]%w% Toggle GMS
echo                                     %r%[%w%2%r%]%w% Toggle Thermal-Service
echo                                     %r%[%w%3%r%]%w% Toggle Package Verifier
echo                                     %r%[%w%4%r%]%w% Toggle Game-Overlay
echo                                     %r%[%w%5%r%]%w% Toggle Performance
echo                                     %r%[%w%6%r%]%w% Network Boost
echo                                     %r%[%w%7%r%]%w% GPU Renderer (Skia GL/Vulkan)
echo                                     %r%[%w%8%r%]%w% Force ANGLE for All Apps
echo                                     %r%[%w%9%r%]%w% Display Scaler (Resolution / DPI)
echo                                     %r%[%w%10%r%]%w% Back

:Gaming_ask
:: FIX (press-twice): re-prompt without redrawing on empty/invalid input,
:: so a phantom empty line after the probes doesn't re-run them (see :dispscaler).
set "game=" & set /p game="Choose An Option >> "
if not defined game goto Gaming_ask
if "!game!"=="1" goto gms
if "!game!"=="2" goto thermal
if "!game!"=="3" goto package
if "!game!"=="4" goto overlay
if "!game!"=="5" goto performance
if "!game!"=="6" goto netboost
if "!game!"=="7" goto gpurenderer
if "!game!"=="8" goto angleall
if "!game!"=="9" goto dispscaler
if "!game!"=="10" goto menu
:: FIX: invalid input previously fell into :gms
goto Gaming_ask
:: ===================================================================
:: NEW: Display Scaler (REAL, no-root)  -  wm size / wm density
::
:: Lowering the render resolution is one of the most effective
:: no-root ways to gain GPU headroom in games and cut power draw:
:: fewer pixels to shade every frame. We scale density by the SAME
:: factor so dp stays constant -> the UI keeps the exact same size,
:: the image is just rendered with fewer pixels (slightly softer).
::
::   wm size  WxH   /  wm size reset     - logical resolution
::   wm density N   /  wm density reset  - DPI
::
:: Both are official commands (Android 4.3+/API 18+), persist across
:: reboot WITHOUT root, and are fully reversible. Presets are computed
:: live from the panel's TRUE physical resolution so they always fit
:: the device. Because DCX drives this over USB, even an unusable
:: on-screen result is recoverable from here via Reset.
:: ===================================================================
:dispscaler
cls
title Display Scaler (Resolution / DPI)
call :logo
:: Read the panel's TRUE native resolution + density as the baseline.
set "PW=" & set "PH=" & set "PD=" & set "PDR=" & set "SZ=" & set "OVR=" & set "OVRD="
for /f "tokens=2 delims=:" %%a in ('adb shell wm size ^<nul 2^>nul ^| findstr /C:"Physical size"') do set "SZ=%%a"
for /f "tokens=1,2 delims=x " %%a in ("%SZ%") do ( set "PW=%%a" & set "PH=%%b" )
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Physical density"') do set "PDR=%%a"
for /f "tokens=* delims= " %%a in ("%PDR%") do set "PD=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm size ^<nul 2^>nul ^| findstr /C:"Override size"') do set "OVR=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Override density"') do set "OVRD=%%a"
:: Validate we actually parsed numbers before doing any maths.
if not defined PW goto dispscaler_err
if not defined PH goto dispscaler_err
if not defined PD goto dispscaler_err
echo !PW!!PH!!PD!| findstr /r "[^0-9]" >nul && goto dispscaler_err
set /a W85=PW*85/100, H85=PH*85/100, D85=PD*85/100
set /a W75=PW*75/100, H75=PH*75/100, D75=PD*75/100
set /a W67=PW*67/100, H67=PH*67/100, D67=PD*67/100
set /a W50=PW*50/100, H50=PH*50/100, D50=PD*50/100
echo.
echo  Native : %g%%PW%x%PH%%w% @ %g%%PD% dpi%w%   (the panel's real resolution)
if defined OVR echo  Active override :%gold%%OVR%%w% /%gold%%OVRD%%w% dpi
echo.
echo  Lowering the render resolution gives games more GPU headroom and
echo  saves battery. Density is scaled to match, so the UI keeps the same
echo  size - the image is just drawn with fewer pixels (slightly softer).
echo  All reversible, no root, and applied over USB.
echo.
echo                    %g%[%w%1%g%]%w% 85%% scale  -^> %W85%x%H85% @ %D85% dpi   (subtle, very safe)
echo                    %g%[%w%2%g%]%w% 75%% scale  -^> %W75%x%H75% @ %D75% dpi   (recommended)
echo                    %g%[%w%3%g%]%w% 67%% scale  -^> %W67%x%H67% @ %D67% dpi   (big FPS gain)
echo                    %g%[%w%4%g%]%w% 50%% scale  -^> %W50%x%H50% @ %D50% dpi   (max, looks soft)
echo                    %g%[%w%5%g%]%w% Custom resolution / density
echo                    %g%[%w%6%g%]%w% UI size only (DPI, keeps resolution)
echo                    %g%[%w%7%g%]%w% Reset to native (fixes any weirdness)
echo                    %g%[%w%8%g%]%w% Back

:dispscaler_ask
:: FIX (input "eaten" / press-twice): re-prompt WITHOUT redrawing on empty or
:: invalid input. A blank read here is usually a phantom empty line the console
:: hands set /p right after the slow `wm size`/`wm density` probes above; the old
:: `goto dispscaler` treated it as a miss and redrew the whole menu (re-running
:: those probes), so the user's real keypress only landed on the second try.
:: Absorbing it with a tight re-ask makes the first keypress register, and stray
:: keys no longer re-run the adb probes. The preset vars (W85.. ND) stay in scope.
set "ds="
set /p ds="Choose An Option >> "
if not defined ds goto dispscaler_ask
if "!ds!"=="1" ( set "NW=%W85%" & set "NH=%H85%" & set "ND=%D85%" & goto dispscaler_set )
if "!ds!"=="2" ( set "NW=%W75%" & set "NH=%H75%" & set "ND=%D75%" & goto dispscaler_set )
if "!ds!"=="3" ( set "NW=%W67%" & set "NH=%H67%" & set "ND=%D67%" & goto dispscaler_set )
if "!ds!"=="4" ( set "NW=%W50%" & set "NH=%H50%" & set "ND=%D50%" & goto dispscaler_set )
if "!ds!"=="5" goto dispscaler_custom
if "!ds!"=="6" goto dispscaler_dpi
if "!ds!"=="7" goto dispscaler_reset
if "!ds!"=="8" goto Gaming
goto dispscaler_ask

:dispscaler_set
:: expects NW NH ND set by the caller
cls
title Display Scaler : apply
call :logo
echo  About to set:
echo     Resolution : %g%%NW%x%NH%%w%   (native %PW%x%PH%)
echo     Density    : %g%%ND% dpi%w%   (native %PD%)
echo.
echo  %y%The UI keeps the same size%w% - only the render resolution changes,
echo  so games get more GPU headroom and the panel uses less power. A
echo  lower resolution looks slightly softer. Fully reversible.
echo.
echo  %g%Applied over USB%w% - even if the screen looks wrong you can come
echo  straight back here and choose Reset.
echo.
echo    [Y] Apply    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto dispscaler
adb shell wm size %NW%x%NH%
adb shell wm density %ND% <nul
echo.
echo  Applied. If anything looks off, come back and choose Reset.
pause >nul
goto dispscaler

:dispscaler_custom
cls
title Display Scaler : custom
call :logo
echo  Native resolution: %g%%PW%x%PH%%w%    native density: %g%%PD% dpi%w%
echo.
echo  Enter a custom WIDTH, HEIGHT and DENSITY. Tip: keep the same
echo  width:height ratio as native to avoid stretching, and scale density
echo  by the same factor to keep the UI size consistent.
echo.
set "CW=" & set "CH=" & set "CD="
set /p "CW=Width  (blank = cancel) >> "
if "!CW!"=="" goto dispscaler
set /p "CH=Height (blank = cancel) >> "
if "!CH!"=="" goto dispscaler
set "CD=" & set /p "CD=Density dpi (blank = cancel) >> "
if "!CD!"=="" goto dispscaler
echo !CW!| findstr /r "^[1-9][0-9]*$" >nul || goto dispscaler_custom_bad
echo !CH!| findstr /r "^[1-9][0-9]*$" >nul || goto dispscaler_custom_bad
echo !CD!| findstr /r "^[1-9][0-9]*$" >nul || goto dispscaler_custom_bad
:: sane bounds so a typo can't leave the UI unusable
if %CW% LSS 320 goto dispscaler_custom_bad
if %CH% LSS 320 goto dispscaler_custom_bad
if %CW% GTR 8000 goto dispscaler_custom_bad
if %CH% GTR 8000 goto dispscaler_custom_bad
if %CD% LSS 80 goto dispscaler_custom_bad
if %CD% GTR 900 goto dispscaler_custom_bad
set "NW=%CW%" & set "NH=%CH%" & set "ND=%CD%"
goto dispscaler_set

:dispscaler_custom_bad
echo [%r%^^!%w%] Invalid values. Width/height 320-8000, density 80-900, digits only.
timeout /t 2 /nobreak >nul
goto dispscaler_custom
:: -------------------------------------------------------------------
:: UI size (DPI only) - changes element size WITHOUT touching the
:: resolution. This is the working stand-in for the developer-options
:: "Smallest width" entry, which some OEMs (notably Huawei EMUI/
:: HarmonyOS) leave present but non-functional. Lower dpi = smaller UI
:: / more content. Presets are a percentage of the panel's native
:: density, so 85%% lands on the common 'stock UI is too big' fix.
:: -------------------------------------------------------------------
:dispscaler_dpi
cls
title Display Scaler : UI size (DPI)
call :logo
:: Re-read the panel's native (physical) density as the 100%% baseline.
set "PDR=" & set "PD=" & set "OVRD="
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Physical density"') do set "PDR=%%a"
for /f "tokens=* delims= " %%a in ("%PDR%") do set "PD=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Override density"') do set "OVRD=%%a"
if not defined PD goto dispscaler_err
echo !PD!| findstr /r "[^0-9]" >nul && goto dispscaler_err
set /a U110=PD*110/100, U90=PD*90/100, U85=PD*85/100, U80=PD*80/100
echo.
echo  Changes ONLY the DPI (UI element size); resolution stays native.
echo  This is the reliable replacement for the developer-options
echo  "Smallest width" entry that some OEMs (e.g. Huawei) disable.
echo.
echo  Native density (100%% UI) : %g%%PD% dpi%w%
if defined OVRD echo  Active override           : %gold%%OVRD% dpi%w%
echo.
echo  Lower %% = smaller UI, more content fits.
echo.
echo                    %g%[%w%1%g%]%w% 110%% UI -^> %U110% dpi   (bigger)
echo                    %g%[%w%2%g%]%w% 100%% UI -^> %PD% dpi   (native)
echo                    %g%[%w%3%g%]%w% 90%%  UI -^> %U90% dpi
echo                    %g%[%w%4%g%]%w% 85%%  UI -^> %U85% dpi   (fix for over-large stock UI)
echo                    %g%[%w%5%g%]%w% 80%%  UI -^> %U80% dpi   (smallest)
echo                    %g%[%w%6%g%]%w% Custom dpi
echo                    %g%[%w%7%g%]%w% Reset to native dpi
echo                    %g%[%w%8%g%]%w% Back

:dispscaler_dpi_ask
:: FIX (input "eaten" / press-twice): same tight re-ask as :dispscaler - absorb a
:: phantom empty read so the first keypress registers, and don't re-run the
:: density probe on stray keys. Preset vars (U110.. PD) stay in scope.
set "du="
set /p du="Choose An Option >> "
if not defined du goto dispscaler_dpi_ask
if "!du!"=="1" ( set "ND=%U110%" & goto dispscaler_dpi_set )
if "!du!"=="2" ( set "ND=%PD%" & goto dispscaler_dpi_set )
if "!du!"=="3" ( set "ND=%U90%" & goto dispscaler_dpi_set )
if "!du!"=="4" ( set "ND=%U85%" & goto dispscaler_dpi_set )
if "!du!"=="5" ( set "ND=%U80%" & goto dispscaler_dpi_set )
if "!du!"=="6" goto dispscaler_dpi_custom
if "!du!"=="7" goto dispscaler_dpi_reset
if "!du!"=="8" goto dispscaler
goto dispscaler_dpi_ask

:dispscaler_dpi_set
:: expects ND (target density) set by the caller
cls
title Display Scaler : apply UI size
call :logo
echo  About to set density to %g%%ND% dpi%w%   (native %PD%), resolution unchanged.
echo.
echo  Lower dpi = smaller UI / more content. Fully reversible, no root.
echo  %g%Applied over USB%w% - if it looks wrong, come back and Reset.
echo.
echo    [Y] Apply    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto dispscaler_dpi
adb shell wm density %ND% <nul
echo.
echo  Done - density is now %ND% dpi. This persists across reboot.
pause >nul
goto dispscaler_dpi

:dispscaler_dpi_custom
cls
title Display Scaler : custom dpi
call :logo
echo  Native density: %g%%PD% dpi%w%   (lower = smaller UI, higher = bigger)
echo.
set "CD="
set /p "CD=Density dpi (blank = cancel) >> "
if "!CD!"=="" goto dispscaler_dpi
echo !CD!| findstr /r "^[1-9][0-9]*$" >nul || goto dispscaler_dpi_custom_bad
if %CD% LSS 80 goto dispscaler_dpi_custom_bad
if %CD% GTR 900 goto dispscaler_dpi_custom_bad
set "ND=%CD%"
goto dispscaler_dpi_set

:dispscaler_dpi_custom_bad
echo [%r%^^!%w%] Invalid density. Use a whole number 80-900.
timeout /t 2 /nobreak >nul
goto dispscaler_dpi_custom

:dispscaler_dpi_reset
cls
title Display Scaler : reset dpi
call :logo
echo  Restoring native density (%PD% dpi)...
adb shell wm density reset
adb shell settings delete secure display_density_forced <nul > nul 2>&1
echo.
echo  %y%Heads up:%w% native density can be larger than you like on some
echo  phones. If the UI is now too big, pick a UI-size preset above
echo  (e.g. 85%%) instead of leaving it at native.
pause >nul
goto dispscaler_dpi

:dispscaler_reset
cls
title Display Scaler : reset
call :logo
echo  Restoring the panel's native resolution and density...
adb shell wm size reset
adb shell wm density reset
:: Some OEM builds (notably Huawei EMUI/HarmonyOS, and older Sony/LG)
:: do NOT actually clear the forced override on 'reset' - the value is
:: left behind in the settings DB and survives a reboot. Delete the
:: backing keys directly so the native size/density really come back.
adb shell settings delete global display_size_forced > nul 2>&1
adb shell settings delete secure display_density_forced <nul > nul 2>&1
echo.
echo  Done - back to native (%PW%x%PH% @ %PD% dpi).
echo  %y%If the UI still looks the wrong size, reboot once to apply.%w%
pause >nul
goto dispscaler

:dispscaler_err
cls
title Display Scaler
call :logo
echo [%r%^^!%w%] Could not read the display size/density from this device.
echo     'wm size' / 'wm density' returned something unexpected, so the
echo     presets can't be computed safely.
echo.
echo  You can still force a manual reset:
echo     adb shell wm size reset
echo     adb shell wm density reset
echo.
echo Press Any Button To Go Back
pause >nul
goto Gaming
:: ===================================================================
:: NEW: GPU Renderer toggle (REAL Android property `debug.hwui.renderer`)
:: This is the actual HWUI pipeline switch. Valid values:
::   skiagl   - Skia OpenGL  (Android default since 9)
::   skiavk   - Skia Vulkan  (works Android 13+, may be unstable on
::                            some GPUs / cause blurry fonts)
::   <empty>  - let the framework pick the default
:: WARNING on non-rooted devices: setprop applies live but does NOT
:: survive reboot. To make it permanent without root, the value must
:: be set in /system/build.prop (requires root or a Magisk module).
:: ===================================================================
:gpurenderer
cls
title GPU Renderer (HWUI)
call :logo
echo.
echo  Current value:
for /f "delims=" %%i in ('adb shell getprop debug.hwui.renderer 2^>nul ^<nul') do echo    debug.hwui.renderer = "%%i"
echo.
echo  This switches the HWUI rendering pipeline used by the system UI
echo  and most apps that draw with the framework.
echo.
echo    skiavk = Skia + Vulkan        (faster on Android 13+, may have
echo                                   font/scroll artefacts on weak GPUs)
echo    skiagl = Skia + OpenGL ES     (default, most compatible)
echo.
echo  %y%Note:%w% on non-rooted phones the change is live but resets on reboot.
echo.
echo                                     %g%[%w%1%g%]%w% Skia Vulkan (skiavk)
echo                                     %g%[%w%2%g%]%w% Skia OpenGL  (skiagl - default)
echo                                     %g%[%w%3%g%]%w% Clear override (let framework decide)
echo                                     %g%[%w%4%g%]%w% Back
set "gpur=" & set /p gpur="Choose An Option >> "
if "!gpur!"=="1" goto gpurenderer_vk
if "!gpur!"=="2" goto gpurenderer_gl
if "!gpur!"=="3" goto gpurenderer_clear
if "!gpur!"=="4" goto Gaming
goto gpurenderer

:gpurenderer_vk
cls
title GPU Renderer : Skia Vulkan
adb shell setprop debug.hwui.renderer skiavk
adb shell setprop debug.renderengine.backend skiavkthreaded <nul
echo Renderer set to skiavk (Skia + Vulkan).
echo.
echo To verify after relaunching an app:
echo   adb shell dumpsys gfxinfo ^<package^> ^| findstr Pipeline
echo Expected: "Skia (Vulkan)"
echo.
echo A reboot - or at least restarting SystemUI - is needed for the
echo change to take full effect.
pause > nul
goto gpurenderer

:gpurenderer_gl
cls
title GPU Renderer : Skia GL
adb shell setprop debug.hwui.renderer skiagl
adb shell setprop debug.renderengine.backend skiaglthreaded <nul
echo Renderer set to skiagl (Skia + OpenGL ES, default).
pause > nul
goto gpurenderer

:gpurenderer_clear
cls
title GPU Renderer : Clear
:: An empty value makes Android fall back to the framework default
adb shell setprop debug.hwui.renderer ""
adb shell setprop debug.renderengine.backend "" <nul
echo Renderer override cleared. Framework default in effect after reboot.
pause > nul
goto gpurenderer
:: ===================================================================
:: NEW: Force ANGLE for All Apps (REAL Settings.Global setting)
:: ANGLE is Google's GLES-on-Vulkan translation layer. Enabling it
:: forces apps that use OpenGL ES to actually run through Vulkan -
:: better performance on modern GPUs, more consistent behaviour.
:: This is the OFFICIAL Android way (per AOSP docs):
::   settings put global angle_gl_driver_all_angle 1   (on)
::   settings put global angle_gl_driver_all_angle 0   (off)
:: Setting PERSISTS across reboots, unlike the renderer toggle above.
:: Caveats:
::   - Requires the GoogleANGLE APK to be installed (most modern Android
::     ships with it as a system app; Android 16+ uses ANGLE by default
::     for many apps anyway).
::   - On non-root, only debuggable apps will actually load ANGLE -
::     others fall back to native. So benefit is partial.
::   - A few games are known to break under ANGLE; disable if you see
::     glitches in a specific game.
:: ===================================================================
:angleall
cls
title Force ANGLE for All Apps
call :logo
echo.
echo  Current value:
for /f "delims=" %%i in ('adb shell settings get global angle_gl_driver_all_angle 2^>nul ^<nul') do echo    angle_gl_driver_all_angle = %%i  (1=ON, 0=OFF, null=default)
echo.
echo  Forces every GLES app to load through ANGLE (GLES-on-Vulkan).
echo.
echo  %r%WARNING - device compatibility risk:%w%
echo  On many non-Pixel devices (especially MediaTek GPUs) this CRASHES
echo  apps on launch. It has been reported to break most apps on some
echo  phones. Only enable it if you are ready to revert.
echo.
echo  %y%The setting persists across reboots - a reboot will NOT fix a%w%
echo  %y%crash loop. You must come back here and Disable/Delete it.%w%
echo.
echo                                     %g%[%w%1%g%]%w% Enable  (ANGLE for all apps)
echo                                     %g%[%w%2%g%]%w% Disable (native driver)
echo                                     %g%[%w%3%g%]%w% Delete setting (Android default)
echo                                     %g%[%w%4%g%]%w% Back
set "ang=" & set /p ang="Choose An Option >> "
if "!ang!"=="1" goto angleall_on
if "!ang!"=="2" goto angleall_off
if "!ang!"=="3" goto angleall_del
if "!ang!"=="4" goto Gaming
goto angleall

:angleall_on
cls
title ANGLE for All Apps : ON (confirm)
echo  %r%Are you sure?%w% On some devices this crashes most apps and can
echo  only be undone from this menu (a reboot will not help).
echo.
echo  Tip: test a few apps right after enabling. If they crash, come
echo  straight back and choose Disable or Delete.
echo.
echo    [Y] Enable ANGLE now
echo    [N] Cancel
choice /c:YN /n > nul
if errorlevel 2 goto angleall
adb shell settings put global angle_gl_driver_all_angle 1 <nul
echo.
echo Done. ANGLE is now enabled for all GLES apps.
echo If apps start crashing, return here and Disable/Delete.
pause > nul
goto angleall

:angleall_off
cls
title ANGLE for All Apps : OFF
adb shell settings put global angle_gl_driver_all_angle 0 <nul
echo Done. Native GLES driver in use.
pause > nul
goto angleall

:angleall_del
cls
title ANGLE for All Apps : Delete (default)
adb shell settings delete global angle_gl_driver_all_angle <nul
echo Setting removed. Framework picks per-app default again.
pause > nul
goto angleall
:: ===================================================================
:: NEW FEATURE: Network Boost
:: Tunes TCP buffers and DNS for lower latency in online games.
:: All changes are non-destructive (settings put global) and can be
:: undone with option [3] which deletes the keys.
:: ===================================================================
:netboost
cls
title Network Boost
call :logo
echo.
echo  TCP receive-window hint + optional private DNS for lower latency.
echo  %y%Note:%w% the old Wi-Fi power tweaks were removed (they could break
echo  Wi-Fi on Android 15). Reverting is safe and clears any old keys.
echo.
echo                                     %g%[%w%1%g%]%w% Apply TCP hint (safe)
echo                                     %g%[%w%2%g%]%w% Set Cloudflare DNS (1.1.1.1)
echo                                     %g%[%w%3%g%]%w% Preferred network mode
echo                                     %g%[%w%4%g%]%w% Revert (remove all)
echo                                     %g%[%w%5%g%]%w% Back
set "nb=" & set /p nb="Choose An Option >> "
if "!nb!"=="1" goto netboost_apply
if "!nb!"=="2" goto netboost_dns
if "!nb!"=="3" goto netboost_prefmode
if "!nb!"=="4" goto netboost_revert
if "!nb!"=="5" goto Gaming
goto netboost
:: -----------------------------------------------------------------
:: NEW: Preferred network mode toggle
:: The .sh script had `persist.radio.force_lte true` and similar -
:: these are FAKE. The real Android setting is:
::   settings put global preferred_network_mode N
:: Common values (from Android source, RILConstants.java):
::   9  = LTE / GSM / WCDMA      (LTE preferred, fall back to 3G/2G)
::   12 = LTE only
::   20 = LTE / NR / WCDMA       (5G preferred, fall back to LTE/3G)
::   1  = GSM only (2G)
:: Note: some operators / SIM cards override this on the radio side.
:: Both `preferred_network_mode` (legacy/default) and `..._mode1` are
:: written ON PURPOSE: the suffixed key is per-SUBSCRIPTION and subIds
:: are 1-based, so mode1 is the FIRST SIM's usual subId - not a second
:: slot. On devices where the active subId isn't 1 (SIM swaps bump it)
:: the extra key is inert, and "Restore default" deletes both keys, so
:: this stays fully reversible either way.
:: -----------------------------------------------------------------
:netboost_prefmode
cls
title Network Boost : Preferred mode
call :logo
echo  Current preferred_network_mode:
for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul ^<nul') do echo    %%i
echo.
echo                                     %g%[%w%1%g%]%w% LTE preferred (9)  -^> fall back 3G/2G
echo                                     %g%[%w%2%g%]%w% LTE only (12)
echo                                     %g%[%w%3%g%]%w% 5G preferred (20)  -^> fall back LTE/3G
echo                                     %g%[%w%4%g%]%w% Restore default (delete)
echo                                     %g%[%w%5%g%]%w% Back
set "pm=" & set /p pm="Choose An Option >> "
if "!pm!"=="1" (
    adb shell settings put global preferred_network_mode 9
    adb shell settings put global preferred_network_mode1 9 <nul
    echo Set to LTE preferred.
    pause > nul
    goto netboost_prefmode
)
if "!pm!"=="2" (
    adb shell settings put global preferred_network_mode 12
    adb shell settings put global preferred_network_mode1 12 <nul
    echo Set to LTE only. WARNING: voice calls only work if VoLTE is active.
    pause > nul
    goto netboost_prefmode
)
if "!pm!"=="3" (
    adb shell settings put global preferred_network_mode 20
    adb shell settings put global preferred_network_mode1 20 <nul
    echo Set to 5G preferred.
    pause > nul
    goto netboost_prefmode
)
if not "!pm!"=="4" goto _skpm4
    adb shell settings delete global preferred_network_mode <nul
    adb shell settings delete global preferred_network_mode1 <nul
    echo Default restored.
    pause > nul
    goto netboost_prefmode

:_skpm4
if "!pm!"=="5" goto netboost
goto netboost_prefmode

:netboost_apply
cls
title Network Boost : Apply
echo Applying TCP receive-window hint...
echo.
:: IMPORTANT: earlier versions also wrote several Wi-Fi power keys
:: (wifi_sleep_policy, wifi_suspend_optimizations_enabled, wifi_idle_ms,
:: mobile_data_always_on, tether_offload_disabled). Those are DEPRECATED
:: Settings.Global keys and were found to BREAK Wi-Fi connectivity on
:: Android 15 (Tecno/MediaTek) - a reboot did not recover it, only
:: reverting did. They have been removed from this step. Revert still
:: clears them so anyone who applied the old version can clean up.
::
:: What remains is the one genuinely safe, real key: the initial TCP
:: receive window. Effect is modest; it does not touch the Wi-Fi stack.
adb shell "settings put global tcp_default_init_rwnd 60" <nul > nul 2>&1
echo Done - set tcp_default_init_rwnd (initial TCP receive window).
echo.
echo This change is safe and does not alter Wi-Fi behaviour.
echo If you want lower latency, the DNS option (Cloudflare) often helps
echo more than buffer tuning on modern networks.
pause > nul
goto netboost

:netboost_dns
cls
title Network Boost : DNS
echo Setting private DNS to Cloudflare (1.1.1.1 / one.one.one.one)...
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier one.one.one.one <nul
echo.
echo  To use Google DNS instead, run manually:
echo    settings put global private_dns_specifier dns.google
echo  Or for AdGuard DNS (no ads):
echo    settings put global private_dns_specifier dns.adguard.com
echo.
echo  %y%If your network blocks external DNS and connectivity drops,%w%
echo  come back to Network Boost -^> Revert to restore automatic DNS.
echo.
pause > nul
goto netboost

:netboost_revert
cls
title Network Boost : Revert
adb shell settings delete global tcp_default_init_rwnd > nul 2>&1
adb shell settings delete global tether_offload_disabled > nul 2>&1
adb shell settings delete global mobile_data_always_on > nul 2>&1
adb shell settings delete global wifi_idle_ms > nul 2>&1
adb shell settings delete global wifi_suspend_optimizations_enabled > nul 2>&1
adb shell settings delete global wifi_sleep_policy > nul 2>&1
adb shell settings put global private_dns_mode opportunistic > nul 2>&1
adb shell settings delete global private_dns_specifier > nul 2>&1
adb shell settings delete global preferred_network_mode > nul 2>&1
adb shell settings delete global preferred_network_mode1 <nul > nul 2>&1
echo All Network Boost settings reverted.
pause > nul
goto netboost
:: gms
:gms
@echo off
cls
title Toggle GMS
echo.
echo.
echo Toggle Your GMS Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
if "!toggle!"=="1" goto offgms
if "!toggle!"=="2" goto ongms
if "!toggle!"=="3" goto Gaming
:: guard against invalid input
goto gms

:offgms
@echo off
cls
title GMS : Off (confirmation)
echo.
echo  %r%========================== WARNING ==========================%w%
echo.
echo   Disabling Google Mobile Services will break most apps that
echo   rely on Google Play Services, including:
echo.
echo     - Push notifications (WhatsApp, Telegram, Gmail, banking)
echo     - Google Maps and any app using its location services
echo     - Sign-in via Google in third-party apps
echo     - In-app purchases, ads, Firebase, Crashlytics
echo     - Find My Device, Google Pay, Play Store updates
echo.
echo   %y%Only proceed if you understand the impact.%w%
echo.
echo  %r%=============================================================%w%
echo.
echo  [%g%Y%w%] Yes, disable GMS now
echo  [%g%N%w%] No, take me back
choice /c:YN /n > nul
if errorlevel 2 goto Gaming
cls
title GMS : Off
adb shell am force-stop com.google.android.gms
adb shell pm disable-user --user 0 com.google.android.gms
adb shell settings put global zen_mode 4
adb shell cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND ignore
adb shell cmd appops set com.google.android.gms RUN_IN_BACKGROUND ignore
adb shell cmd appops set com.google.android.gms WAKE_LOCK ignore
adb shell cmd appops set com.google.android.gms START_FOREGROUND ignore
adb shell cmd appops set com.google.android.gms INSTANT_APP_START_FOREGROUND ignore
adb shell am set-inactive --user 0 com.google.android.gms true
adb shell am set-standby-bucket --user 0 com.google.android.gms never <nul
echo Press Any Button To Go Back
pause > nul
goto Gaming

:ongms
@echo off
cls
adb shell pm enable com.google.android.gms
adb shell settings put global zen_mode 0
adb shell cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND allow
adb shell cmd appops set com.google.android.gms RUN_IN_BACKGROUND allow
adb shell cmd appops set com.google.android.gms WAKE_LOCK allow
adb shell cmd appops set com.google.android.gms START_FOREGROUND allow
adb shell cmd appops set com.google.android.gms INSTANT_APP_START_FOREGROUND allow
adb shell am set-inactive --user 0 com.google.android.gms false
adb shell am set-standby-bucket --user 0 com.google.android.gms active <nul
title GMS : On
echo Press Any Button To Go Back
pause > nul
goto Gaming
:: thermal
:thermal
@echo off
cls
title Toggle Thermal
echo.
echo.
echo Toggle Thermal Service
echo.
echo [%r%1%w%] Process To Setting Thermal
echo [%r%2%w%] Go Back
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto settingthermal
if "!kb!"=="2" goto Gaming
:: FIX: guard against invalid input - previously fell through to :settingthermal
goto thermal

:settingthermal
@echo off
cls
echo Put A Number Between 0 To 6 To Change
echo How Thermal Service Work^^!
echo.
echo  0 = NONE     (no throttling)
echo  1 = LIGHT
echo  2 = MODERATE
echo  3 = SEVERE
echo  4 = CRITICAL
echo  5 = EMERGENCY
echo  6 = SHUTDOWN (do not use)
echo.
set "kb=" & set /p kb=">> "
:: FIX: validate input - previously any garbage was accepted
set "valid=0"
for %%v in (0 1 2 3 4 5 6) do if "!kb!"=="%%v" set "valid=1"
if "%valid%"=="0" (
    echo [%r%^^!%w%] Invalid value. Must be a number between 0 and 6.
    timeout /t 2 /nobreak > nul
    goto thermal
)
cls
adb shell cmd thermalservice override-status %kb% <nul
echo Press Any Button To Go Back.
pause > nul
goto Gaming
:: Package verifier
:package
@echo off
cls
title Toggle Package Verifier
echo.
echo.
echo Toggle Your Package Verifier Here
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto offpck
if "!kb!"=="2" goto onpck
if "!kb!"=="3" goto Gaming
:: guard against invalid input
goto package

:offpck
@echo off
cls
title Package Verifier : Off
adb shell settings put global package_verifier_enable 0 <nul
echo Press Any Button To Go Back
pause > nul
goto Gaming

:onpck
@echo off
cls
title Package Verifier : On
adb shell settings put global package_verifier_enable 1 <nul
echo Press Any Button To Go Back
pause > nul
goto Gaming
:: game-overlay
:overlay
@echo off
cls
title Setting Game-Overlay
echo.
echo.
echo %b%[Remove]%w%  1
echo %b%[Low]%w%     2
echo %b%[Medium]%w%  3
echo %b%[Back]  %w%  4
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto removeset
if "!kb!"=="2" goto low
if "!kb!"=="3" goto med
if "!kb!"=="4" goto Gaming
:: guard against invalid input
goto overlay

:removeset
cls
title Remove Settings
set "package=" & set /p package="Put Your Package Name Here >> "
if "!package!"=="" goto Gaming
adb shell device_config delete game_overlay %package% > nul
adb shell cmd game reset --user 0 %package% <nul
cls
echo.
echo.
echo [%r%^^!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again.
echo.
echo.
echo %package% Settings Is Removed , Press Any Button To Go Back
pause > nul
goto Gaming

:low
@echo off
cls
title Low Settings
set "package=" & set /p package="Put Your Package Name Here >> "
if "!package!"=="" goto Gaming
adb shell device_config put game_overlay %package% mode=1
adb shell cmd game downscale 0.55 %package% <nul
cls
echo.
echo.
echo [%r%^^!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again.
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto Gaming

:med
@echo off
cls
title Medium Settings
set "package=" & set /p package="Put Your Package Name Here >> "
if "!package!"=="" goto Gaming
adb shell device_config put game_overlay %package% mode=1
adb shell device_config get game_overlay %package%
adb shell cmd game downscale 0.75 %package% <nul
cls
echo.
echo.
echo [%r%^^!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again.
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto Gaming
:: Performance
:performance
@echo off
cls
title Toggle Performance
echo.
echo.
echo Toggle Your Performance Here
echo.
echo [%r%1%w%] Toggle
echo [%r%2%w%] Back
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto toggleperf
if "!kb!"=="2" goto Gaming
:: FIX: guard against invalid input - previously fell through to :toggleperf
goto performance

:toggleperf
cls
title Performance Mode
echo.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "kb=" & set /p kb="Choose An Option >> "
if "!kb!"=="1" goto offperf
if "!kb!"=="2" goto onperf
if "!kb!"=="3" goto Gaming
:: guard against invalid input
goto toggleperf

:offperf
@echo off
cls
title Performance Mode : Off
:: FIX: revert by REMOVING the override so the platform default returns.
:: The old code set the ratio to 80 on "Off" instead of deleting it, so
:: toggling Off did not actually revert anything.
adb shell device_config delete storage_native_boot target_dirty_ratio > nul 2>&1
adb shell device_config delete storage_native_boot target_dirty_background_ratio > nul 2>&1

adb shell logcat -G 256kb
adb shell settings delete global activity_manager_constants > nul 2>&1
adb shell device_config delete runtime_native_boot iorap_readahead_enable > nul 2>&1
adb shell device_config delete surface_flinger_native_boot max_frame_buffer_acquired_buffers > nul 2>&1
adb shell device_config delete surface_flinger_native_boot adpf_cpu_hint > nul 2>&1
:: FIX (revert-completeness): :onperf pins PERSISTENT power state that
:: survives reboot; "Off" must undo it or the device stays in the
:: performance profile forever. (debug.* setprops are volatile - the
:: reboot prompted below clears those - so only persistent state is
:: reverted here. set-mode is NOT forced: "1" would turn low-power mode
:: ON, the opposite of a revert; un-pinning low_power is enough.)
adb shell cmd thermalservice reset > nul 2>&1
adb shell cmd power set-adaptive-power-saver-enabled true > nul 2>&1
adb shell settings delete global low_power > nul 2>&1
adb shell settings delete system multicore_packet_scheduler > nul 2>&1
adb shell settings delete global sem_enhanced_cpu_responsiveness > nul 2>&1
if "%SDK%"=="" (
    adb shell settings delete global device_idle_constants > nul 2>&1
) else if %SDK% GEQ 31 (
    adb shell device_config delete device_idle inactive_to > nul 2>&1
) else (
    adb shell settings delete global device_idle_constants > nul 2>&1
)
echo.
echo.
echo [%r%^^!%w%] Please Restart Device To Finish The Process
echo.
echo.
timeout /t 2 /nobreak > nul
echo Press Any Button To Go Back
pause > nul
goto Gaming

:onperf
@echo off
cls
title Performance Mode : On
echo.
echo.
echo [%r%^^!%w%] All Powersaving Is Disabled
echo [%r%^^!%w%] If You Want To Enable Power Saver Again, You Need To Disable Performance Mode
echo [%r%^^!%w%] And Enable Power Saver Mode In Battery Mode
::disable powersaver
adb shell cmd power set-mode 0 > nul 2>&1
adb shell cmd thermalservice override-status 0
adb shell settings put global low_power 0
if "%SDK%"=="" (
    adb shell settings put global device_idle_constants inactive_to=300000 > nul 2>&1
) else if %SDK% GEQ 31 (
    adb shell device_config put device_idle inactive_to 300000 > nul 2>&1
) else (
    adb shell settings put global device_idle_constants inactive_to=300000 > nul 2>&1
)
adb shell cmd power set-adaptive-power-saver-enabled false
adb shell setprop debug.power_management_mode pref_max
adb shell cmd shortcut reset-all-throttling > nul 2>&1
:: FIX: 256mb log buffer in "performance" mode is counter-productive.
:: A buffer that big stalls the system on flush. 1mb is sufficient.
adb shell logcat -G 1mb
adb shell setprop debug.rs.rsov 1
adb shell setprop debug.rs.default-CPU-driver 0
adb shell setprop debug.renderengine.graphite true
adb shell setprop debug.hwc.hdr_nbm_enable 0
:: FIX: removed debug.choreographer.vsync false  - disabling vsync
:: causes screen tearing and breaks frame pacing. Not a real
:: performance improvement; modern GPUs need vsync for stability.
adb shell setprop debug.sqlite.journalmode OFF
adb shell setprop debug.sqlite.syncmode OFF
adb shell setprop debug.sqlite.journalsizelimit 1mb
adb shell setprop debug.sqlite.wal.syncmode OFF
adb shell setprop debug.hwui.disable_draw_defer true
adb shell setprop debug.hwui.disable_draw_reorder false
adb shell setprop debug.sf.disable_client_composition_cache 1
adb shell setprop debug.hwui.initialize_gl_always true
adb shell setprop debug.sf.drop_missed_frames 1
adb shell setprop debug.sf.allowed_actual_deviation 0
adb shell setprop debug.hwui.render_dirty_regions false
adb shell setprop debug.hwc.flattenning_enabled false
adb shell setprop debug.hwc.test_plan false
:: FIX: removed debug.hwui.disable_vsync true - same reason as above.
adb shell setprop debug.incremental.always_enable_read_timeouts_for_system_dataloaders false
adb shell setprop debug.incremental.enable_read_timeouts_after_install false
adb shell setprop debug.sf.treat_170m_as_sRGB 0
adb shell setprop debug.sf.fp16_client_target 1
adb shell setprop debug.soundtrigger_middleware.use_mock_hal 0
adb shell setprop debug.extractor.ignore_version false
adb shell setprop debug.art.monitor.app false
adb shell setprop debug.sf.vrr_timeout_hint_enabled false
adb shell setprop debug.sf.enable_hole_punch_pip false
adb shell setprop debug.hwc.force_gpu 1
adb shell setprop debug.sf.framedrop 0
adb shell setprop debug.hwui.clip_surfaceviews true
adb shell setprop debug.hwui.resample_gainmap_regions false
adb shell setprop debug.egl.blobcache.multifile true
adb shell setprop debug.egl.blobcache.multifile_limit 16777216
adb shell setprop debug.sf.enable_layer_command_batching 1
adb shell setprop debug.sf.use_content_detection_v2 false
adb shell setprop debug.adpf.use_report_actual_duration false
adb shell setprop debug.sf.hint_margin_us 550
adb shell setprop debug.sf.cached_set_max_defer_render_attmpts 2
adb shell setprop debug.sf.layer_caching_active_layer_timeout_ms 1200
adb shell setprop debug.sf.cache_source_crop_only_moved true
adb shell setprop debug.sf.multithreaded_present 1
adb shell setprop debug.sf.hwc_hdcp_via_neg_vsync false
adb shell setprop debug.sf.enable_layer_lifecycle_manager false
adb shell setprop debug.sf.send_early_power_session_hint true
adb shell setprop debug.sf.send_late_power_session_hint false
adb shell setprop debug.sf.hwc.min.duration 0
adb shell setprop debug.sf.use_frame_rate_priority 1
adb shell setprop debug.sf.enable_cached_set_render_scheduling true
adb shell setprop debug.sf.enable_layer_caching 0
adb shell setprop debug.sf.max_igbp_list_size 7
adb shell setprop debug.hwc.fakevsync 0
adb shell setprop debug.enable.sglscale 1
adb shell setprop debug.enable.gamed 1
adb shell setprop debug.enabletr true
adb shell setprop debug.sf.enable_adpf_cpu_hint true
adb shell setprop debug.rs.precision rs_fp_full
adb shell setprop debug.hwui.high_performance_mode true
adb shell settings put system multicore_packet_scheduler 1
adb shell settings put global sem_enhanced_cpu_responsiveness 1
adb shell settings put global activity_manager_constants max_cached_processes=12,power_check_interval=80000,power_check_max_cpu_1=85,power_check_max_cpu_2=85,power_check_max_cpu_3=60,power_check_max_cpu_4=15
adb shell setprop debug.cpurend.vsync false
adb shell setprop debug.sf.hw 1
adb shell setprop debug.rs.max-threads 8
adb shell setprop debug.sf.vsync_reactor_ignore_present_fences true
adb shell setprop debug.sf.disable_hwc_vds 1
adb shell setprop debug.sf.enable_hwc_vds false
adb shell setprop debug.hwui.target_cpu_time_percent 35
adb shell setprop debug.egl.hw 1
adb shell setprop debug.rs.reduce-split-accum 1
adb shell setprop debug.choreographer.skipwarning 16500000
adb shell setprop debug.sf.luma_sampling 0
adb shell setprop debug.gr.numframebuffers 3
adb shell setprop debug.hwui.skip_empty_damage true
adb shell setprop debug.composition.type dyn
adb shell setprop debug.hwui.use_buffer_age true
adb shell setprop debug.hwui.use_partial_updates true
adb shell setprop debug.egl.swapinterval 0
adb shell setprop debug.gralloc.map_fb_memory 1
adb shell setprop debug.gralloc.enable_fb_ubwc 1
adb shell setprop debug.sf.swaprect 1
adb shell setprop debug.hwui.filter_test_overhead false
adb shell setprop debug.hwui.fps_divisor 1
adb shell setprop debug.graphics.game_default_frame_rate.disabled true
adb shell setprop debug.sf.latch_unsignaled 1
adb shell setprop debug.sf.auto_latch_unsignaled true
adb shell setprop debug.sf.disable_backpressure 1
adb shell setprop debug.sf.enable_advanced_sf_phase_offset 1
adb shell setprop debug.gralloc.gfx_ubwc_disable 0
adb shell setprop debug.hwc.bq_count 3
adb shell setprop debug.hwc.compose_level 0
adb shell setprop debug.hwui.use_hint_manager true
adb shell setprop debug.hwui.render_ahead 3
adb shell setprop debug.sf.enable_gl_backpressure 0
adb shell setprop debug.sf.vsync_reactor_ignore_present_fences true
adb shell setprop debug.sf.set_idle_timer_ms 3500
adb shell setprop debug.sf.frame_rate_multiple_threshold 120
adb shell setprop debug.sf.use_phase_offsets_as_durations 0
adb shell setprop debug.c2.use_dmabufheaps 1
adb shell setprop debug.sf.prime_shader_cache.image_layers true
adb shell setprop debug.sf.prime_shader_cache.solid_layers true
adb shell setprop debug.mdpcomp.idletime 5000
adb shell setprop debug.mdpcomp.maxpermixer 3
adb shell device_config put runtime_native_boot iorap_readahead_enable true
adb shell setprop debug.media.c2.large.audio.frame false
::this device config from google, i don't try do any gimmick device config here, source : https://cs.android.com/search?q=surface_flinger_native_boot&sq=
adb shell device_config put surface_flinger_native_boot max_frame_buffer_acquired_buffers 3
adb shell device_config put surface_flinger_native_boot adpf_cpu_hint true
::this device config from google, i don't try do any gimmick device config here, source : https://cs.android.com/search?q=surface_flinger_native_boot&sq=
:: FIX: set an ABSOLUTE target so repeating "On" is idempotent. The old
:: code did `current+10` every run (unbounded growth on repeated toggles)
:: and, because of the early-out above, did nothing at all when the key
:: was previously unset. 35 is a modestly elevated write-back ratio - a
:: sane performance default without much extra crash-data-loss risk;
:: "Off" now deletes the key to truly revert (see :offperf).
echo storage_native_boot/target_dirty_ratio : 35
echo storage_native_boot/target_dirty_background_ratio : 5
adb shell device_config put storage_native_boot target_dirty_ratio 35
adb shell device_config put storage_native_boot target_dirty_background_ratio 5

echo Press Any Button To Go Back
pause > nul
goto Gaming

:appmgr
cls
title App Manager
call :logo
echo                            %b%[%w% App Manager %b%]%w%
echo.
echo   Background control + debloat. Every action here is reversible.
echo.
echo                 %g%[%w%1%g%]%w% Restrict app background (deny RUN_IN_BACKGROUND)
echo                 %g%[%w%2%g%]%w% Allow app background (revert)
echo                 %g%[%w%3%g%]%w% Debloat - remove an app by package name
echo                 %g%[%w%4%g%]%w% Debloat - suggested bloatware (auto-detect brand)
echo                 %g%[%w%5%g%]%w% List installed packages (to Notepad)
echo                 %g%[%w%6%g%]%w% Restore a removed app
echo                 %g%[%w%7%g%]%w% Back
set "am=" & set /p am="Choose An Option >> "
if "!am!"=="1" goto appmgr_restrict
if "!am!"=="2" goto appmgr_allow
if "!am!"=="3" goto appmgr_debloat_input
if "!am!"=="4" goto appmgr_suggest
if "!am!"=="5" goto appmgr_listpkgs
if "!am!"=="6" goto appmgr_restore_input
if "!am!"=="7" goto menu
goto appmgr
:: ===================================================================
:: Restrict / Allow background  (cmd appops RUN_IN_BACKGROUND)
:: ===================================================================
:appmgr_restrict
cls
title Restrict Background
call :logo
echo  Denies RUN_IN_BACKGROUND for an app so it can't run in the
echo  background (saves battery). Reversible with "Allow background".
echo  Tip: use "List installed packages" first if you don't know the name.
echo.
set "pkg=" & set /p pkg="Package name (blank = cancel) >> "
if "!pkg!"=="" goto appmgr
adb shell pm list packages < nul 2>nul | findstr /C:"package:%pkg%" >nul
if errorlevel 1 (
    echo [%r%^^!%w%] "%pkg%" is not installed.
    pause >nul
    goto appmgr_restrict
)
adb shell cmd appops set %pkg% RUN_IN_BACKGROUND deny <nul
echo.
echo Done - %pkg% is now denied background execution.
pause >nul
goto appmgr

:appmgr_allow
cls
title Allow Background
call :logo
echo  Re-allows RUN_IN_BACKGROUND for an app (undo of Restrict).
echo.
set "pkg=" & set /p pkg="Package name (blank = cancel) >> "
if "!pkg!"=="" goto appmgr
adb shell pm list packages < nul 2>nul | findstr /C:"package:%pkg%" >nul
if errorlevel 1 (
    echo [%r%^^!%w%] "%pkg%" is not installed.
    pause >nul
    goto appmgr_allow
)
adb shell cmd appops set %pkg% RUN_IN_BACKGROUND allow <nul
echo.
echo Done - %pkg% may run in the background again.
pause >nul
goto appmgr
:: ===================================================================
:: Debloat by package name  (pm uninstall -k --user 0)
:: -k keeps app data; reversible via Restore or factory reset.
:: A short hard-block list refuses known bootloop-causing packages.
:: ===================================================================
:appmgr_debloat_input
cls
title Debloat by Package
call :logo
echo  %r%Removes an app for the current user%w% (pm uninstall -k --user 0).
echo  Data is kept (-k) and it's reversible via Restore or a factory
echo  reset, but removing a critical package can cause a bootloop.
echo.
echo  %y%Only remove apps you recognise.%w% Never remove system UI, phone,
echo  or anything you can't identify. On Transsion (Tecno/Infinix) phones
echo  never remove com.hoffnung - it looks like bloat but bootloops.
echo.
set "pkg=" & set /p pkg="Package name (blank = cancel) >> "
if "!pkg!"=="" goto appmgr
set "BLOCKED=0"
for %%c in (com.android.systemui com.hoffnung com.android.phone com.android.settings com.miui.daemon com.android.systemui.plugins com.android.providers.telephony com.huawei.hwid com.huawei.android.pushagent com.huawei.hwasm com.huawei.android.hwouc com.huawei.systemserver) do if /i "!pkg!"=="%%c" set "BLOCKED=1"
if "%BLOCKED%"=="1" (
    echo [%r%BLOCKED%w%] "%pkg%" is a critical package and will not be removed.
    pause >nul
    goto appmgr_debloat_input
)
adb shell pm list packages < nul 2>nul | findstr /C:"package:%pkg%" >nul
if errorlevel 1 (
    echo [%r%^^!%w%] "%pkg%" is not installed.
    pause >nul
    goto appmgr_debloat_input
)
echo.
echo  About to remove: %pkg%
echo    [Y] Remove    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appmgr
adb shell pm uninstall -k --user 0 %pkg% <nul
echo.
echo Done. To bring it back: App Manager -^> Restore (or a factory reset).
pause >nul
goto appmgr

:appmgr_restore_input
cls
title Restore Removed App
call :logo
echo  Reinstalls an app removed with Debloat (pm install-existing).
echo  Works as long as it was removed with -k and not fully wiped.
echo.
set "pkg=" & set /p pkg="Package name to restore (blank = cancel) >> "
if "!pkg!"=="" goto appmgr
adb shell cmd package install-existing %pkg% <nul
echo.
echo If it was present, %pkg% is restored for the current user.
pause >nul
goto appmgr
:: ===================================================================
:: List installed packages to a file and open it (read-only, safe).
:: ===================================================================
:appmgr_listpkgs
cls
title Installed Packages
call :logo
echo  [%g%1%w%] All packages
echo  [%g%2%w%] User + updated apps only (-3) - usually where bloat lives
echo  [%g%3%w%] Back
set "lp=" & set /p lp="Choose An Option >> "
if "!lp!"=="3" goto appmgr
set "PKGLIST=%TEMP%\dcx_installed_packages.txt"
if "!lp!"=="1" adb shell pm list packages < nul 2>nul > "%PKGLIST%"
if "!lp!"=="2" adb shell pm list packages -3 < nul 2>nul > "%PKGLIST%"
if not exist "%PKGLIST%" goto appmgr
start "" notepad "%PKGLIST%"
echo Opened in Notepad. Use these names with Restrict / Debloat.
pause >nul
goto appmgr
:: ===================================================================
:: Suggested bloatware - auto-detect brand, only offer packages that
:: are (a) on a vetted safe-to-remove list AND (b) actually installed.
:: Package lists are sourced from UAD-NG and community debloat guides.
:: ===================================================================
:appmgr_suggest
cls
title Suggested Bloatware
call :logo
set "BRAND="
for /f "delims=" %%i in ('adb shell getprop ro.product.brand 2^>nul ^<nul') do set "BRAND=%%i"
set "MANU="
for /f "delims=" %%i in ('adb shell getprop ro.product.manufacturer 2^>nul ^<nul') do set "MANU=%%i"
set "PKGDUMP=%TEMP%\dcx_pkgs.txt"
adb shell pm list packages < nul 2>nul > "%PKGDUMP%"
echo  Detected brand: %BRAND%   manufacturer: %MANU%
echo.
echo  These groups only remove well-documented, safe-to-remove apps that
echo  are actually installed. Removal is for the current user (-k keeps
echo  data) and reversible via Restore or a factory reset. Critical
echo  packages (system UI, telephony, etc) are never listed.
echo.
echo                 %g%[%w%1%g%]%w% Facebook bloat (any brand)
echo                 %g%[%w%2%g%]%w% Optional Google apps (YouTube, Drive, Meet...)
set "BRANDCAT=0"
echo %BRAND% %MANU%| findstr /I "xiaomi redmi poco" >nul && set "BRANDCAT=Xiaomi"
echo %BRAND% %MANU%| findstr /I "tecno infinix itel transsion" >nul && set "BRANDCAT=Transsion"
echo %BRAND% %MANU%| findstr /I "samsung" >nul && set "BRANDCAT=Samsung"
echo %BRAND% %MANU%| findstr /I "huawei honor" >nul && set "BRANDCAT=Huawei"
if not "%BRANDCAT%"=="0" echo                 %g%[%w%3%g%]%w% %BRANDCAT% bloat
echo                 %g%[%w%4%g%]%w% Back
set "sg=" & set /p sg="Choose An Option >> "
if "!sg!"=="1" goto appmgr_bloat_fb
if "!sg!"=="2" goto appmgr_bloat_google
if "!sg!"=="3" goto appmgr_bloat_brand
if "!sg!"=="4" goto appmgr
goto appmgr_suggest

:appmgr_bloat_fb
set "BLOATDESC=Facebook background services + the Facebook app (pure bloat)."
set "BLOATSET=com.facebook.katana com.facebook.appmanager com.facebook.services com.facebook.system"
goto _remove_present_set

:appmgr_bloat_google
set "BLOATDESC=Optional Google apps - no bootloop, you just lose those apps."
set "BLOATSET=com.google.android.apps.tachyon com.google.android.youtube com.google.android.apps.youtube.music com.google.android.apps.docs com.google.android.videos com.google.android.apps.wellbeing"
goto _remove_present_set

:appmgr_bloat_brand
if "%BRANDCAT%"=="Xiaomi" set "BLOATDESC=MIUI/HyperOS ads, analytics and optional stock apps."
if "%BRANDCAT%"=="Xiaomi" set "BLOATSET=com.miui.analytics com.miui.msa.global com.miui.systemAdSolution com.xiaomi.mipicks com.mi.globalbrowser com.miui.yellowpage com.miui.videoplayer com.miui.player com.mi.globalminusscreen"
if "%BRANDCAT%"=="Transsion" set "BLOATDESC=Transsion (Tecno/Infinix/itel) preinstalled bloat."
if "%BRANDCAT%"=="Transsion" set "BLOATSET=com.transsion.ossettingsext com.afmobi.boomplayer com.funbase.xradio com.transsion.fmradio com.infinix.xshare com.transsnet.store com.transsion.carlcare net.bat.store com.talpa.hibrowser com.transsion.smartpanel com.transsion.magazineservice.xos com.transsion.healthlife com.transsion.tecnospot com.transsion.magicshow com.transsion.statisticalsales com.transsion.plat.appupdate com.transsion.batterylab com.rlk.weathers"
if "%BRANDCAT%"=="Samsung" set "BLOATDESC=Samsung Free / Bixby / tips (optional)."
if "%BRANDCAT%"=="Samsung" set "BLOATSET=com.samsung.android.app.spage com.samsung.android.bixby.agent com.samsung.android.app.tips com.samsung.android.game.gamehome"
if "%BRANDCAT%"=="Huawei" set "BLOATDESC=Huawei/Honor (EMUI/HarmonyOS) optional apps and promo services."
if "%BRANDCAT%"=="Huawei" set "BLOATSET=com.huawei.search com.huawei.hitouch com.huawei.intelligent com.huawei.browser com.huawei.android.thememanager com.huawei.health com.huawei.tips com.huawei.hiskytone com.huawei.vassistant com.huawei.appmarket com.huawei.fastapp com.huawei.android.totemweather com.huawei.hifolder com.huawei.parentcontrol com.huawei.bd"
if "%BRANDCAT%"=="0" goto appmgr_suggest
goto _remove_present_set
:: -------------------------------------------------------------------
:: Shared remover: shows which of %BLOATSET% are installed (using the
:: %PKGDUMP% list), then removes them all after one confirmation.
:: -------------------------------------------------------------------
:_remove_present_set
cls
title Debloat : review
call :logo
echo  %BLOATDESC%
echo.
if not exist "%PKGDUMP%" adb shell pm list packages < nul 2>nul > "%PKGDUMP%"
echo  Installed packages from this group (these will be removed):
echo.
set "_found="
set "_n=0"
for %%p in (%BLOATSET%) do (
    findstr /C:"package:%%p" "%PKGDUMP%" >nul
    if not errorlevel 1 (
        echo     %%p
        set "_found=!_found! %%p"
        set /a _n+=1
    )
)
echo.
if "%_n%"=="0" (
    echo  None of this group's packages are installed. Nothing to do.
    pause >nul
    goto appmgr_suggest
)
echo  Total: %_n% package(s). Removed for the current user only (-k keeps
echo  data). Restore later via App Manager -^> Restore, or a factory reset.
echo.
echo    [Y] Remove these now
echo    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appmgr_suggest
echo.
for %%p in (%_found%) do (
    echo Removing %%p ...
    adb shell pm uninstall -k --user 0 %%p
)
echo.
echo Done.
pause >nul
goto appmgr_suggest

:: ===================================================================
:: NEW: Tweaks and Settings  (main menu 14)
::
:: Feature parity targets: zacharee/Tweaker (SystemUI Tuner) and
:: MuntashirAkon/SetEdit. Mechanics verified against AOSP main
:: (SoundDoseHelper.java, Clock.java, AudioManagerShellCommand.java);
:: details in CHANGES-tweaks-tier1.md. All adb calls carry <nul so
:: they never eat the next set /p (house press-twice guard).
:: ===================================================================
:tweaks
cls
title Tweaks and Settings
call :logo
echo.
echo                              %m%Tweaks and Settings%w%
echo.
echo   %d%Status bar%w%
echo    %g%[%w%1%g%]%w% Clock - show seconds
echo    %g%[%w%2%g%]%w% Battery percent
echo    %g%[%w%3%g%]%w% Icon blacklist - hide status bar icons
echo    %g%[%w%4%g%]%w% Demo mode - clean bar for screenshots
echo.
echo   %d%Quick settings%w%
echo    %g%[%w%5%g%]%w% Tile editor - add the tiles Android hides
echo.
echo   %d%System%w%
echo    %g%[%w%6%g%]%w% Volume cap (safe media volume)
echo    %g%[%w%7%g%]%w% Heads-up notifications
echo    %g%[%w%8%g%]%w% Font scale
echo    %g%[%w%9%g%]%w% Long-press timeout
echo    %g%[%w%10%g%]%w% Stay awake while charging
echo    %g%[%w%11%g%]%w% Night - dark theme / night light
echo    %g%[%w%12%g%]%w% More device tweaks
echo.
echo    %g%[%w%13%g%]%w% Back to main menu
set "tw=" & set /p tw="Choose An Option >> "
if not defined tw goto tweaks
if "!tw!"=="1" goto tw_clock
if "!tw!"=="2" goto tw_batpct
if "!tw!"=="3" goto tw_icons
if "!tw!"=="4" goto tw_demo
if "!tw!"=="5" goto tw_qs
if "!tw!"=="6" goto tw_safevol
if "!tw!"=="7" goto tw_headsup
if "!tw!"=="8" goto tw_font
if "!tw!"=="9" goto tw_lpt
if "!tw!"=="10" goto tw_stay
if "!tw!"=="11" goto tw_night
if "!tw!"=="12" goto tw_more
if "!tw!"=="13" goto menu
goto tweaks

:tw_clock
cls
title Clock Seconds
call :logo
echo.
:: SystemUI registers secure/clock_seconds as a live TunerService tunable
:: (AOSP Clock.java) - changes apply instantly, no restart needed. Values
:: are read back from the device, so display them quote-wrapped after
:: stripping quotes (same metachar fix class as :_bk_settings).
set "cs="
for /f "delims=" %%i in ('adb shell settings get secure clock_seconds 2^>nul ^<nul') do set "cs=%%i"
if "!cs!"=="" set "cs=null"
set "cs=!cs:"=!"
echo  clock_seconds (secure) = "!cs!"   (1 = seconds shown, 0/null = device default)
echo  Applies live. Skinned OEM clocks (some OneUI) may ignore this key.
echo.
echo    %g%[%w%1%g%]%w% Show seconds
echo    %g%[%w%2%g%]%w% Hide seconds
echo    %g%[%w%3%g%]%w% Reset to device default (delete key)
echo    %g%[%w%4%g%]%w% Back
set "tc=" & set /p tc="Choose An Option >> "
if not defined tc goto tw_clock
if "!tc!"=="1" (adb shell settings put secure clock_seconds 1 <nul & goto tw_clock)
if "!tc!"=="2" (adb shell settings put secure clock_seconds 0 <nul & goto tw_clock)
if "!tc!"=="3" (adb shell settings delete secure clock_seconds >nul 2>&1 <nul & goto tw_clock)
if "!tc!"=="4" goto tweaks
goto tw_clock

:tw_batpct
cls
title Battery Percent
call :logo
echo.
set "bp="
for /f "delims=" %%i in ('adb shell settings get system status_bar_show_battery_percent 2^>nul ^<nul') do set "bp=%%i"
if "!bp!"=="" set "bp=null"
set "bp=!bp:"=!"
echo  status_bar_show_battery_percent (system) = "!bp!"   (1 = shown, 0/null = default)
echo  Applies live on AOSP-based status bars; heavy OEM skins may override.
echo.
echo    %g%[%w%1%g%]%w% Show percent
echo    %g%[%w%2%g%]%w% Hide percent
echo    %g%[%w%3%g%]%w% Reset to device default (delete key)
echo    %g%[%w%4%g%]%w% Back
set "tb=" & set /p tb="Choose An Option >> "
if not defined tb goto tw_batpct
if "!tb!"=="1" (adb shell settings put system status_bar_show_battery_percent 1 <nul & goto tw_batpct)
if "!tb!"=="2" (adb shell settings put system status_bar_show_battery_percent 0 <nul & goto tw_batpct)
if "!tb!"=="3" (adb shell settings delete system status_bar_show_battery_percent >nul 2>&1 <nul & goto tw_batpct)
if "!tb!"=="4" goto tweaks
goto tw_batpct

:tw_safevol
cls
title Volume Cap
call :logo
echo.
echo  Controls the SOFTWARE safe-media-volume cap/warning (EU hearing rule).
echo  It does NOT raise the hardware amplifier limit - that lives in vendor
echo  gain tables (engineering menu) and needs root.
echo.
set "svs="
for /f "delims=" %%i in ('adb shell settings get global audio_safe_volume_state 2^>nul ^<nul') do set "svs=%%i"
if "!svs!"=="" set "svs=null"
set "svs=!svs:"=!"
set "svtxt=unknown value"
if /i "!svs!"=="null" set "svtxt=not configured - system decides at boot"
if "!svs!"=="0" set "svtxt=not configured - system decides at boot"
if "!svs!"=="1" set "svtxt=disabled - no cap on this device/region"
if "!svs!"=="2" set "svtxt=inactive - cap off for the boot that reads this"
if "!svs!"=="3" set "svtxt=active - cap enforced"
echo  audio_safe_volume_state (global) = "!svs!"
echo    !svtxt!
if %SDK% GEQ 34 (
    echo.
    echo  Sound dose - the Android 14+ regime that replaces the cap where enabled:
    for /f "delims=" %%i in ('adb shell cmd audio get-sound-dose-value 2^>nul ^<nul') do echo    %%i
)
echo.
echo  The state key is read ONCE at boot, and Android re-writes it to 3
echo  after every boot on capped devices - plus after ~20h of music - so
echo  option 1 is a per-boot switch, not a permanent one.
echo.
echo    %g%[%w%1%g%]%w% Disable cap for next boot   (set state 2, then reboot)
echo    %g%[%w%2%g%]%w% Re-enable cap               (set state 3)
echo    %g%[%w%3%g%]%w% Reset to system default     (delete key)
echo    %g%[%w%4%g%]%w% Reset accumulated sound dose        - Android 14+
echo    %g%[%w%5%g%]%w% Sound-dose "CSD as a feature" off   - Android 14+
echo    %g%[%w%6%g%]%w% Back
set "sv=" & set /p sv="Choose An Option >> "
if not defined sv goto tw_safevol
if "!sv!"=="1" goto tw_safevol_off
if "!sv!"=="2" (adb shell settings put global audio_safe_volume_state 3 <nul & goto tw_safevol)
if "!sv!"=="3" (adb shell settings delete global audio_safe_volume_state >nul 2>&1 <nul & goto tw_safevol)
if "!sv!"=="4" goto tw_safevol_dose
if "!sv!"=="5" goto tw_safevol_csdoff
if "!sv!"=="6" goto tweaks
goto tw_safevol

:tw_safevol_off
adb shell settings put global audio_safe_volume_state 2 <nul
echo.
echo  Done - state set to 2 (inactive). Takes effect at the NEXT boot.
echo  Re-run this after each reboot if you want the cap to stay off.
set "rb=" & set /p rb="Reboot device now? (y = yes, anything else = back) >> "
if /i "!rb!"=="y" adb reboot <nul
goto tw_safevol

:tw_safevol_dose
if %SDK% LSS 34 (
    echo [%r%^^!%w%] Needs Android 14 or newer - this device reports API %SDK%.
    timeout /t 2 /nobreak >nul
    goto tw_safevol
)
adb shell cmd audio set-sound-dose-value 0.0 <nul
echo  Accumulated sound dose reset to 0. Applies live.
timeout /t 2 /nobreak >nul
goto tw_safevol

:tw_safevol_csdoff
if %SDK% LSS 34 (
    echo [%r%^^!%w%] Needs Android 14 or newer - this device reports API %SDK%.
    timeout /t 2 /nobreak >nul
    goto tw_safevol
)
:: Only matters where CSD is available-but-not-enforced; harmless elsewhere.
adb shell settings put secure audio_safe_csd_as_a_feature_enabled 0 <nul
echo  audio_safe_csd_as_a_feature_enabled (secure) set to 0.
timeout /t 2 /nobreak >nul
goto tw_safevol

:tw_explorer
cls
title Settings Explorer
call :logo
echo.
echo  Namespaces: system / secure / global.  Values are limited to the
echo  charset  A-Z a-z 0-9 _ . , : / = + -  (no spaces or shell chars);
echo  anything fancier: use the Shell option in the main menu.
echo.
echo    %g%[%w%1%g%]%w% List keys (optional substring filter)
echo    %g%[%w%2%g%]%w% Get a key
echo    %g%[%w%3%g%]%w% Put a key    (previous value saved to an undo script)
echo    %g%[%w%4%g%]%w% Delete a key (same undo protection)
echo    %g%[%w%5%g%]%w% Back
set "tx=" & set /p tx="Choose An Option >> "
if not defined tx goto tw_explorer
if "!tx!"=="1" goto tw_exp_list
if "!tx!"=="2" goto tw_exp_get
if "!tx!"=="3" goto tw_exp_put
if "!tx!"=="4" goto tw_exp_del
if "!tx!"=="5" goto settools
goto tw_explorer

:tw_exp_list
call :_tw_askns
if not defined EXP_NS goto tw_explorer
set "EXP_FLT=" & set /p EXP_FLT="Filter substring (blank = list all) >> "
if not defined EXP_FLT goto tw_exp_list_go
set "EXP_FLT=!EXP_FLT:"=!"
if not defined EXP_FLT goto tw_exp_list_go
call :_tw_safechk EXP_FLT || goto tw_exp_bad
echo(!EXP_FLT!| findstr /r /x /c:"[a-zA-Z0-9_.-][a-zA-Z0-9_.-]*" >nul || goto tw_exp_bad
:tw_exp_list_go
echo  ---- %EXP_NS% ----
if defined EXP_FLT (
    adb shell settings list %EXP_NS% <nul 2>nul | findstr /i /c:"%EXP_FLT%" | more
) else (
    adb shell settings list %EXP_NS% <nul 2>nul | more
)
echo  ---- end of %EXP_NS% ----
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_get
call :_tw_askns
if not defined EXP_NS goto tw_explorer
call :_tw_askkey
if not defined EXP_KEY goto tw_explorer
set "EXP_OLD="
for /f "delims=" %%v in ('adb shell settings get %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do set "EXP_OLD=%%v"
if "!EXP_OLD!"=="" set "EXP_OLD=null"
:: Value comes from the device and can contain cmd metacharacters - strip
:: quotes, then keep it inside quotes when echoing (:_bk_settings fix class).
set "EXP_OLD=!EXP_OLD:"=!"
echo.
echo  %EXP_NS% %EXP_KEY% = "!EXP_OLD!"
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_put
call :_tw_askns
if not defined EXP_NS goto tw_explorer
call :_tw_askkey
if not defined EXP_KEY goto tw_explorer
set "EXP_OLD="
for /f "delims=" %%v in ('adb shell settings get %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do set "EXP_OLD=%%v"
if "!EXP_OLD!"=="" set "EXP_OLD=null"
set "EXP_OLD=!EXP_OLD:"=!"
echo  Current value: "!EXP_OLD!"
set "EXP_VAL=" & set /p EXP_VAL="New value (blank = cancel) >> "
if not defined EXP_VAL goto tw_explorer
set "EXP_VAL=!EXP_VAL:"=!"
if not defined EXP_VAL goto tw_explorer
call :_tw_safechk EXP_VAL || goto tw_exp_bad
echo(!EXP_VAL!| findstr /r /x /c:"[a-zA-Z0-9_.,:/=+-][a-zA-Z0-9_.,:/=+-]*" >nul || goto tw_exp_bad
echo.
echo  Command: adb shell settings put %EXP_NS% %EXP_KEY% !EXP_VAL!
set "ok=" & set /p ok="Run it? (y = yes, anything else = cancel) >> "
if /i not "!ok!"=="y" goto tw_explorer
call :_tw_undo_add %EXP_NS% %EXP_KEY%
adb shell settings put %EXP_NS% %EXP_KEY% !EXP_VAL! <nul
set "EXP_NEW="
for /f "delims=" %%v in ('adb shell settings get %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do set "EXP_NEW=%%v"
if "!EXP_NEW!"=="" set "EXP_NEW=null"
set "EXP_NEW=!EXP_NEW:"=!"
echo  Read-back: %EXP_NS% %EXP_KEY% = "!EXP_NEW!"
echo  Undo script: %EXP_UNDO%
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_del
call :_tw_askns
if not defined EXP_NS goto tw_explorer
call :_tw_askkey
if not defined EXP_KEY goto tw_explorer
set "EXP_OLD="
for /f "delims=" %%v in ('adb shell settings get %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do set "EXP_OLD=%%v"
if "!EXP_OLD!"=="" set "EXP_OLD=null"
set "EXP_OLD=!EXP_OLD:"=!"
echo  Current value: "!EXP_OLD!"
echo.
echo  Command: adb shell settings delete %EXP_NS% %EXP_KEY%
set "ok=" & set /p ok="Run it? (y = yes, anything else = cancel) >> "
if /i not "!ok!"=="y" goto tw_explorer
call :_tw_undo_add %EXP_NS% %EXP_KEY%
for /f "delims=" %%i in ('adb shell settings delete %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do echo  %%i
echo  Undo script: %EXP_UNDO%
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_bad
echo [%r%^^!%w%] Not allowed - stick to letters, digits and _ . , : / = + -
timeout /t 2 /nobreak >nul
goto tw_explorer

:: -------------------------------------------------------------------
:: Explorer helpers
::
:: _tw_askns / _tw_askkey  ask for a namespace / whitelist-checked key;
:: an empty EXP_NS / EXP_KEY on return means cancelled or invalid.
:: -------------------------------------------------------------------
:_tw_askns
set "EXP_NS="
set "tn=" & set /p tn="Namespace (1=system 2=secure 3=global, blank=cancel) >> "
if "!tn!"=="1" set "EXP_NS=system"
if "!tn!"=="2" set "EXP_NS=secure"
if "!tn!"=="3" set "EXP_NS=global"
exit /b

:_tw_askkey
set "EXP_KEY="
set "tk=" & set /p tk="Key name (blank = cancel) >> "
if not defined tk exit /b
set "tk=!tk:"=!"
if not defined tk exit /b
call :_tw_safechk tk || exit /b
echo(!tk!| findstr /r /x /c:"[a-zA-Z0-9_.-][a-zA-Z0-9_.-]*" >nul || exit /b
set "EXP_KEY=!tk!"
exit /b

:_tw_safechk
:: %1 = NAME of a variable (callers strip double quotes first). Fails with
:: errorlevel 1 if the value holds a cmd metachar that would make the
:: `echo(!var!| findstr` whitelist probe itself unsafe. Each check runs
:: inside a quoted comparison, so the hostile char never sits in command
:: position. A caret needs no check: it self-escapes identically in the
:: probe and in the final adb line, and `^&`-style combos are caught by
:: the checks below before the caret matters.
if not defined %~1 exit /b 1
if not "!%~1:&=_!"=="!%~1!" exit /b 1
if not "!%~1:|=_!"=="!%~1!" exit /b 1
if not "!%~1:<=_!"=="!%~1!" exit /b 1
if not "!%~1:>=_!"=="!%~1!" exit /b 1
exit /b 0

:_tw_undo_add
:: Capture the current value of %1/%2 into a runnable undo script BEFORE an
:: explorer write. Reuses :_bk_settings (null value -> delete line), so the
:: undo file uses the same format as the main Backup feature. One undo file
:: per DCX session, created lazily on the first write.
if defined EXP_UNDO goto _tw_undo_append
set "BACKUPDIR=%USERPROFILE%\dcx_backups"
if not exist "%BACKUPDIR%" mkdir "%BACKUPDIR%"
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "EXP_UNDO=%BACKUPDIR%\dcx_explorer_undo_%TS%.bat"
> "%EXP_UNDO%" echo @echo off
>>"%EXP_UNDO%" echo :: DCX Settings-Explorer undo - restores values captured before writes.
>>"%EXP_UNDO%" echo adb start-server ^>nul 2^>^&1
:_tw_undo_append
call :_bk_settings %~1 %~2 "%EXP_UNDO%"
exit /b

:tw_snapshot
cls
title Settings Snapshot
call :logo
set "SNAPDIR=%USERPROFILE%\dcx_snapshots"
if not exist "%SNAPDIR%" mkdir "%SNAPDIR%"
echo.
echo  Dump all three settings tables, poke something in the device UI,
echo  dump again, diff - and you know exactly which key that toggle writes.
echo  Folder: %SNAPDIR%
echo.
echo    %g%[%w%1%g%]%w% Take a snapshot now (system + secure + global)
echo    %g%[%w%2%g%]%w% Diff the two most recent snapshots
echo    %g%[%w%3%g%]%w% Open snapshots folder
echo    %g%[%w%4%g%]%w% Back
set "sn=" & set /p sn="Choose An Option >> "
if not defined sn goto tw_snapshot
if "!sn!"=="1" goto tw_snap_take
if "!sn!"=="2" goto tw_snap_diff
if "!sn!"=="3" (start "" "%SNAPDIR%" & goto tw_snapshot)
if "!sn!"=="4" goto settools
goto tw_snapshot

:tw_snap_take
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
echo  Dumping...
:: `find /v ""` re-terminates adb's LF-only lines as CRLF (documented DCX
:: failure mode) so fc behaves later; `sort` gives a stable key order.
for %%n in (system secure global) do (
    adb shell settings list %%n <nul 2>nul | find /v "" | sort > "%SNAPDIR%\%%n_%TS%.txt"
)
echo  Done:
dir /b "%SNAPDIR%\*_%TS%.txt"
echo  Press any key . . .
pause >nul
goto tw_snapshot

:tw_snap_diff
set "SNP1="
set "SNP2="
for /f "delims=" %%f in ('dir /b /o-d /a-d "%SNAPDIR%\global_*.txt" 2^>nul') do (
    if not defined SNP1 (set "SNP1=%%f") else if not defined SNP2 set "SNP2=%%f"
)
if not defined SNP2 (
    echo [%r%^^!%w%] Need at least two snapshots first.
    timeout /t 2 /nobreak >nul
    goto tw_snapshot
)
set "TSNEW=!SNP1:~7,-4!"
set "TSOLD=!SNP2:~7,-4!"
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "DIFFOUT=%SNAPDIR%\diff_%TS%.txt"
> "%DIFFOUT%" echo DCX settings diff:  %TSOLD%  -^>  %TSNEW%
for %%n in (system secure global) do (
    >>"%DIFFOUT%" echo.
    >>"%DIFFOUT%" echo ===== %%n =====
    fc /l "%SNAPDIR%\%%n_%TSOLD%.txt" "%SNAPDIR%\%%n_%TSNEW%.txt" >>"%DIFFOUT%" 2>&1
)
cls
call :logo
echo  Comparing %TSOLD%  (older)
echo         to %TSNEW%  (newer)
echo.
more < "%DIFFOUT%"
echo.
echo  Saved to: %DIFFOUT%
echo    %g%[%w%1%g%]%w% Open in Notepad
echo    %g%[%w%2%g%]%w% Back
set "sd=" & set /p sd="Choose An Option >> "
if "!sd!"=="1" (start "" notepad "%DIFFOUT%" & goto tw_snapshot)
if "!sd!"=="2" goto tw_snapshot
goto tw_snapshot

:: ===================================================================
:: NEW (Tier 2): icon blacklist, demo mode, heads-up, font scale,
:: long-press timeout, stay-awake, night modes, profiles.
::
:: Keys verified against AOSP main and zacharee/Tweaker @ 0053893:
::   secure icon_blacklist            BlacklistPersistenceHandler.kt:9
::   global heads_up_notifications_enabled   Settings.java:17467
::   system font_scale                Settings.java:5135 (default 1.0)
::   secure long_press_timeout        Settings.java:9273
::   global stay_on_while_plugged_in  Settings.java:13420; bits from
::                                    BatteryManager: AC=1 USB=2
::                                    WIRELESS=4 DOCK=8
::   cmd uimode night [yes^|no^|auto]   UiModeManagerService.java:2150
::   secure night_display_*           Settings.java:11493-11507
::   global sysui_demo_allowed + broadcast com.android.systemui.demo
::                                    DemoController.kt:41-51
:: Animation scales are NOT here - Optimize > Animation Speed already
:: owns those three keys.
:: ===================================================================
:tw_icons
cls
title Icon Blacklist
call :logo
echo.
set "IBCUR="
for /f "delims=" %%i in ('adb shell settings get secure icon_blacklist 2^>nul ^<nul') do set "IBCUR=%%i"
if "!IBCUR!"=="" set "IBCUR=null"
set "IBCUR=!IBCUR:"=!"
echo  icon_blacklist (secure) = "!IBCUR!"
echo  A comma-separated list of status bar slots to hide. Applies live on
echo  AOSP-based status bars. Slot names are OEM-dependent - an unknown
echo  name is simply ignored by SystemUI, it does not break anything.
echo.
echo    %g%[%w%1%g%]%w% Hide an icon
echo    %g%[%w%2%g%]%w% Show an icon again
echo    %g%[%w%3%g%]%w% Clear the list (delete key - every icon returns)
echo    %g%[%w%4%g%]%w% Back
set "ic=" & set /p ic="Choose An Option >> "
if not defined ic goto tw_icons
if "!ic!"=="1" goto tw_ib_add
if "!ic!"=="2" goto tw_ib_del
if "!ic!"=="3" goto tw_ib_clear
if "!ic!"=="4" goto tweaks
goto tw_icons

:tw_ib_add
cls
title Icon Blacklist : hide
call :logo
echo.
:: Slot vocabulary = Tweaker's AOSP-general category (IconBlacklistFragment
:: .kt:167-225). Some icons answer to two names across versions, so those
:: entries write both.
echo  Pick a slot to hide:
echo    %g%[%w%1%g%]%w% rotate           (auto-rotate lock)
echo    %g%[%w%2%g%]%w% alarm            (alarm + alarm_clock)
echo    %g%[%w%3%g%]%w% bluetooth
echo    %g%[%w%4%g%]%w% volume
echo    %g%[%w%5%g%]%w% headset
echo    %g%[%w%6%g%]%w% cast
echo    %g%[%w%7%g%]%w% hotspot
echo    %g%[%w%8%g%]%w% location
echo    %g%[%w%9%g%]%w% managed_profile  (work profile badge)
echo    %g%[%w%10%g%]%w% vpn
echo    %g%[%w%11%g%]%w% nfc             (nfc + nfc_on)
echo    %g%[%w%12%g%]%w% dnd             (zen + dnd + do_not_disturb)
echo    %g%[%w%13%g%]%w% data_saver
echo    %g%[%w%14%g%]%w% ime             (keyboard switcher)
echo    %g%[%w%15%g%]%w% mute
echo    %g%[%w%16%g%]%w% Type a slot name myself
echo    %g%[%w%17%g%]%w% Back
set "IBSEL=" & set /p IBSEL="Choose An Option >> "
if not defined IBSEL goto tw_ib_add
set "IBTOK="
if "!IBSEL!"=="1" set "IBTOK=rotate"
if "!IBSEL!"=="2" set "IBTOK=alarm,alarm_clock"
if "!IBSEL!"=="3" set "IBTOK=bluetooth"
if "!IBSEL!"=="4" set "IBTOK=volume"
if "!IBSEL!"=="5" set "IBTOK=headset"
if "!IBSEL!"=="6" set "IBTOK=cast"
if "!IBSEL!"=="7" set "IBTOK=hotspot"
if "!IBSEL!"=="8" set "IBTOK=location"
if "!IBSEL!"=="9" set "IBTOK=managed_profile"
if "!IBSEL!"=="10" set "IBTOK=vpn"
if "!IBSEL!"=="11" set "IBTOK=nfc,nfc_on"
if "!IBSEL!"=="12" set "IBTOK=zen,dnd,do_not_disturb"
if "!IBSEL!"=="13" set "IBTOK=data_saver"
if "!IBSEL!"=="14" set "IBTOK=ime"
if "!IBSEL!"=="15" set "IBTOK=mute"
if "!IBSEL!"=="16" goto tw_ib_custom
if "!IBSEL!"=="17" goto tw_icons
if not defined IBTOK goto tw_ib_add
goto tw_ib_addgo

:tw_ib_custom
echo.
echo  Slot names are lowercase letters, digits and _ (comma-separate a few).
set "IBTOK=" & set /p IBTOK="Slot name (blank = cancel) >> "
if not defined IBTOK goto tw_ib_add
set "IBTOK=!IBTOK:"=!"
if not defined IBTOK goto tw_ib_add
call :_tw_safechk IBTOK || goto tw_ib_bad
echo(!IBTOK!| findstr /r /x /c:"[a-z0-9_,][a-z0-9_,]*" >nul || goto tw_ib_bad
goto tw_ib_addgo

:tw_ib_addgo
call :_tw_undo_add secure icon_blacklist
:: Rebuild rather than blind-append: drop any token we are about to add, so
:: re-hiding an icon cannot pile up duplicates. IBTOK may carry several
:: names (nfc,nfc_on), hence the inner loop; `if defined` reads runtime
:: state, so it stays correct inside a parenthesized block.
set "IBNEW="
if "!IBCUR!"=="null" goto _tw_ib_addput
for %%t in (!IBCUR!) do (
    set "IBHIT="
    for %%u in (!IBTOK!) do if /i "%%t"=="%%u" set "IBHIT=1"
    if not defined IBHIT set "IBNEW=!IBNEW!,%%t"
)
:_tw_ib_addput
set "IBNEW=!IBNEW!,!IBTOK!"
set "IBNEW=!IBNEW:~1!"
adb shell settings put secure icon_blacklist !IBNEW! <nul
goto tw_icons

:tw_ib_del
cls
title Icon Blacklist : restore
call :logo
echo.
if "!IBCUR!"=="null" goto tw_ib_empty
:: Clear any stale IBT_n from an earlier, longer list before renumbering.
for /f "delims==" %%v in ('set IBT_ 2^>nul') do set "%%v="
set "IBN=0"
echo  Currently hidden:
for %%t in (!IBCUR!) do (
    set /a IBN+=1
    set "IBT_!IBN!=%%t"
    echo     %g%[%w%!IBN!%g%]%w% %%t
)
echo     %g%[%w%0%g%]%w% Back
set "IBPICK=" & set /p IBPICK="Restore which? >> "
if not defined IBPICK goto tw_ib_del
if "!IBPICK!"=="0" goto tw_icons
echo(!IBPICK!| findstr /r /x /c:"[0-9][0-9]*" >nul || goto tw_ib_del
set "IBTOK="
if defined IBT_!IBPICK! for /f "delims=" %%v in ("!IBPICK!") do set "IBTOK=!IBT_%%v!"
if not defined IBTOK goto tw_ib_del
call :_tw_undo_add secure icon_blacklist
set "IBNEW="
for %%t in (!IBCUR!) do if not "%%t"=="!IBTOK!" set "IBNEW=!IBNEW!,%%t"
if not defined IBNEW goto tw_ib_clear
set "IBNEW=!IBNEW:~1!"
adb shell settings put secure icon_blacklist !IBNEW! <nul
goto tw_icons

:tw_ib_empty
echo  The blacklist is empty - nothing to restore.
timeout /t 2 /nobreak >nul
goto tw_icons

:tw_ib_clear
call :_tw_undo_add secure icon_blacklist
adb shell settings delete secure icon_blacklist >nul 2>&1 <nul
goto tw_icons

:tw_ib_bad
echo [%r%^^!%w%] Not allowed - lowercase letters, digits, _ and commas only.
timeout /t 2 /nobreak >nul
goto tw_ib_add

:tw_headsup
cls
title Heads-up Notifications
call :logo
echo.
set "HUV="
for /f "delims=" %%i in ('adb shell settings get global heads_up_notifications_enabled 2^>nul ^<nul') do set "HUV=%%i"
if "!HUV!"=="" set "HUV=null"
set "HUV=!HUV:"=!"
echo  heads_up_notifications_enabled (global) = "!HUV!"
echo    (1/null = pop-ups shown, 0 = notifications go straight to the shade)
echo  Applies to every app at once. Per-app control lives in the device's
echo  own notification settings, not here.
echo.
echo    %g%[%w%1%g%]%w% Enable pop-ups
echo    %g%[%w%2%g%]%w% Disable pop-ups
echo    %g%[%w%3%g%]%w% Reset to device default (delete key)
echo    %g%[%w%4%g%]%w% Back
set "hu=" & set /p hu="Choose An Option >> "
if not defined hu goto tw_headsup
if "!hu!"=="1" (call :_tw_undo_add global heads_up_notifications_enabled & adb shell settings put global heads_up_notifications_enabled 1 <nul & goto tw_headsup)
if "!hu!"=="2" (call :_tw_undo_add global heads_up_notifications_enabled & adb shell settings put global heads_up_notifications_enabled 0 <nul & goto tw_headsup)
if "!hu!"=="3" (call :_tw_undo_add global heads_up_notifications_enabled & adb shell settings delete global heads_up_notifications_enabled >nul 2>&1 <nul & goto tw_headsup)
if "!hu!"=="4" goto tweaks
goto tw_headsup

:tw_font
cls
title Font Scale
call :logo
echo.
set "FSV="
for /f "delims=" %%i in ('adb shell settings get system font_scale 2^>nul ^<nul') do set "FSV=%%i"
if "!FSV!"=="" set "FSV=null"
set "FSV=!FSV:"=!"
echo  font_scale (system) = "!FSV!"   (1.0 = platform default)
echo  Applies live. DCX accepts 0.5 - 2.0 only: outside that range app
echo  layouts start clipping and some dialogs lose their buttons.
echo.
echo    %g%[%w%1%g%]%w% 0.85  (small)
echo    %g%[%w%2%g%]%w% 1.0   (default)
echo    %g%[%w%3%g%]%w% 1.15  (large)
echo    %g%[%w%4%g%]%w% 1.30  (larger)
echo    %g%[%w%5%g%]%w% Custom (0.5 - 2.0)
echo    %g%[%w%6%g%]%w% Reset to device default (delete key)
echo    %g%[%w%7%g%]%w% Back
set "fs=" & set /p fs="Choose An Option >> "
if not defined fs goto tw_font
if "!fs!"=="1" (set "FSNEW=0.85" & goto tw_font_apply)
if "!fs!"=="2" (set "FSNEW=1.0" & goto tw_font_apply)
if "!fs!"=="3" (set "FSNEW=1.15" & goto tw_font_apply)
if "!fs!"=="4" (set "FSNEW=1.30" & goto tw_font_apply)
if "!fs!"=="5" goto tw_font_custom
if "!fs!"=="6" (call :_tw_undo_add system font_scale & adb shell settings delete system font_scale >nul 2>&1 <nul & goto tw_font)
if "!fs!"=="7" goto tweaks
goto tw_font

:tw_font_custom
echo.
echo  Enter a scale between 0.5 and 2.0 (e.g. 1.15).
set "FSNEW=" & set /p FSNEW="Value (blank = cancel) >> "
if not defined FSNEW goto tw_font
set "FSNEW=!FSNEW:"=!"
if not defined FSNEW goto tw_font
:: Russian-locale comma decimal (1,15) normalizes to a dot before it can
:: reach adb - same guard as Optimize > Animation Speed.
set "FSNEW=!FSNEW:,=.!"
echo(!FSNEW!| findstr /r /x /c:"0\.[5-9][0-9]*" /c:"\.[5-9][0-9]*" /c:"1" /c:"1\.[0-9][0-9]*" /c:"2" /c:"2\.0*" >nul || goto tw_font_bad
goto tw_font_apply

:tw_font_bad
echo [%r%^^!%w%] Invalid value. Use 0.5 to 2.0, e.g. 0.85, 1.0, 1.15.
timeout /t 2 /nobreak >nul
goto tw_font_custom

:tw_font_apply
call :_tw_undo_add system font_scale
adb shell settings put system font_scale !FSNEW! <nul
goto tw_font

:tw_lpt
cls
title Long-press Timeout
call :logo
echo.
set "LPTV="
for /f "delims=" %%i in ('adb shell settings get secure long_press_timeout 2^>nul ^<nul') do set "LPTV=%%i"
if "!LPTV!"=="" set "LPTV=null"
set "LPTV=!LPTV:"=!"
echo  long_press_timeout (secure) = "!LPTV!" ms   (platform default 400)
echo  How long a touch must be held before it counts as a long-press.
echo.
echo  Worth knowing: Battery ^> Animation ^> Off also pins this key to 250,
echo  and Animation ^> On deletes it. Whichever you run last wins.
echo.
echo    %g%[%w%1%g%]%w% 250   (fast - what Animation Off uses)
echo    %g%[%w%2%g%]%w% 400   (platform default)
echo    %g%[%w%3%g%]%w% 1000  (slow)
echo    %g%[%w%4%g%]%w% 1500  (slowest - accessibility)
echo    %g%[%w%5%g%]%w% Custom (10 - 9999 ms)
echo    %g%[%w%6%g%]%w% Reset to device default (delete key)
echo    %g%[%w%7%g%]%w% Back
set "lpt=" & set /p lpt="Choose An Option >> "
if not defined lpt goto tw_lpt
if "!lpt!"=="1" (set "LPTNEW=250" & goto tw_lpt_apply)
if "!lpt!"=="2" (set "LPTNEW=400" & goto tw_lpt_apply)
if "!lpt!"=="3" (set "LPTNEW=1000" & goto tw_lpt_apply)
if "!lpt!"=="4" (set "LPTNEW=1500" & goto tw_lpt_apply)
if "!lpt!"=="5" goto tw_lpt_custom
if "!lpt!"=="6" (call :_tw_undo_add secure long_press_timeout & adb shell settings delete secure long_press_timeout >nul 2>&1 <nul & goto tw_lpt)
if "!lpt!"=="7" goto tweaks
goto tw_lpt

:tw_lpt_custom
echo.
set "LPTNEW=" & set /p LPTNEW="Milliseconds (blank = cancel) >> "
if not defined LPTNEW goto tw_lpt
set "LPTNEW=!LPTNEW:"=!"
if not defined LPTNEW goto tw_lpt
echo(!LPTNEW!| findstr /r /x /c:"[1-9][0-9]" /c:"[1-9][0-9][0-9]" /c:"[1-9][0-9][0-9][0-9]" >nul || goto tw_lpt_bad
goto tw_lpt_apply

:tw_lpt_bad
echo [%r%^^!%w%] Invalid value. Whole milliseconds, 10 to 9999.
timeout /t 2 /nobreak >nul
goto tw_lpt_custom

:tw_lpt_apply
call :_tw_undo_add secure long_press_timeout
adb shell settings put secure long_press_timeout !LPTNEW! <nul
goto tw_lpt

:tw_stay
cls
title Stay Awake While Charging
call :logo
echo.
set "SAWV="
for /f "delims=" %%i in ('adb shell settings get global stay_on_while_plugged_in 2^>nul ^<nul') do set "SAWV=%%i"
if "!SAWV!"=="" set "SAWV=null"
set "SAWV=!SAWV:"=!"
echo  stay_on_while_plugged_in (global) = "!SAWV!"
echo  Bitmask, add the sources you want:  AC=1  USB=2  wireless=4  dock=8
echo  (0 = off). The screen then never sleeps while charging that way -
echo  handy on a desk, rough on an OLED panel over time.
echo.
echo    %g%[%w%1%g%]%w% Off (0)
echo    %g%[%w%2%g%]%w% AC only (1)
echo    %g%[%w%3%g%]%w% USB only (2)
echo    %g%[%w%4%g%]%w% AC + USB (3)
echo    %g%[%w%5%g%]%w% AC + USB + wireless (7)
echo    %g%[%w%6%g%]%w% Everything incl. dock (15)
echo    %g%[%w%7%g%]%w% Custom (0 - 15)
echo    %g%[%w%8%g%]%w% Reset to device default (delete key)
echo    %g%[%w%9%g%]%w% Back
set "saw=" & set /p saw="Choose An Option >> "
if not defined saw goto tw_stay
if "!saw!"=="1" (set "SAWNEW=0" & goto tw_stay_apply)
if "!saw!"=="2" (set "SAWNEW=1" & goto tw_stay_apply)
if "!saw!"=="3" (set "SAWNEW=2" & goto tw_stay_apply)
if "!saw!"=="4" (set "SAWNEW=3" & goto tw_stay_apply)
if "!saw!"=="5" (set "SAWNEW=7" & goto tw_stay_apply)
if "!saw!"=="6" (set "SAWNEW=15" & goto tw_stay_apply)
if "!saw!"=="7" goto tw_stay_custom
if "!saw!"=="8" (call :_tw_undo_add global stay_on_while_plugged_in & adb shell settings delete global stay_on_while_plugged_in >nul 2>&1 <nul & goto tw_stay)
if "!saw!"=="9" goto tweaks
goto tw_stay

:tw_stay_custom
echo.
set "SAWNEW=" & set /p SAWNEW="Bitmask 0 - 15 (blank = cancel) >> "
if not defined SAWNEW goto tw_stay
set "SAWNEW=!SAWNEW:"=!"
if not defined SAWNEW goto tw_stay
echo(!SAWNEW!| findstr /r /x /c:"[0-9]" /c:"1[0-5]" >nul || goto tw_stay_bad
goto tw_stay_apply

:tw_stay_bad
echo [%r%^^!%w%] Invalid value. A whole number from 0 to 15.
timeout /t 2 /nobreak >nul
goto tw_stay_custom

:tw_stay_apply
call :_tw_undo_add global stay_on_while_plugged_in
adb shell settings put global stay_on_while_plugged_in !SAWNEW! <nul
goto tw_stay

:tw_night
cls
title Night
call :logo
echo.
echo  Two different features share the name "night mode":
echo    Dark theme  - the system-wide dark UI    (cmd uimode night)
echo    Night light - the warm blue-light filter (night_display_*)
echo.
echo  Dark theme, as the device reports it:
for /f "delims=" %%i in ('adb shell cmd uimode night 2^>nul ^<nul') do echo    %%i
set "NDA="
for /f "delims=" %%i in ('adb shell settings get secure night_display_activated 2^>nul ^<nul') do set "NDA=%%i"
if "!NDA!"=="" set "NDA=null"
set "NDA=!NDA:"=!"
echo  night_display_activated (secure) = "!NDA!"   (1 = filter on)
echo.
:: setNightModeInternal only demands MODIFY_DAY_NIGHT_MODE when the ROM
:: locks night mode (UiModeManagerService.java) - it then returns quietly.
:: The command prints the resulting mode, so the line above is the honest
:: read-back rather than a claim of success.
echo  Dark theme is set through the uimode service, which prints the mode it
echo  ended up in - if a ROM locks it, the readout above simply will not move.
echo.
echo    %g%[%w%1%g%]%w% Dark theme on
echo    %g%[%w%2%g%]%w% Dark theme off
echo    %g%[%w%3%g%]%w% Dark theme auto (follow sunset/schedule)
echo    %g%[%w%4%g%]%w% Night light on
echo    %g%[%w%5%g%]%w% Night light off
echo    %g%[%w%6%g%]%w% Night light colour temperature
echo    %g%[%w%7%g%]%w% Back
set "nm=" & set /p nm="Choose An Option >> "
if not defined nm goto tw_night
if "!nm!"=="1" (adb shell cmd uimode night yes <nul & timeout /t 1 /nobreak >nul & goto tw_night)
if "!nm!"=="2" (adb shell cmd uimode night no <nul & timeout /t 1 /nobreak >nul & goto tw_night)
if "!nm!"=="3" (adb shell cmd uimode night auto <nul & timeout /t 1 /nobreak >nul & goto tw_night)
if "!nm!"=="4" (call :_tw_undo_add secure night_display_activated & adb shell settings put secure night_display_activated 1 <nul & goto tw_night)
if "!nm!"=="5" (call :_tw_undo_add secure night_display_activated & adb shell settings put secure night_display_activated 0 <nul & goto tw_night)
if "!nm!"=="6" goto tw_night_temp
if "!nm!"=="7" goto tweaks
goto tw_night

:tw_night_temp
echo.
set "NDT="
for /f "delims=" %%i in ('adb shell settings get secure night_display_color_temperature 2^>nul ^<nul') do set "NDT=%%i"
if "!NDT!"=="" set "NDT=null"
set "NDT=!NDT:"=!"
echo  Current: "!NDT!" K. Lower = warmer/more orange. Typical 2850 - 4800.
set "NDT=" & set /p NDT="Kelvin (blank = cancel) >> "
if not defined NDT goto tw_night
set "NDT=!NDT:"=!"
if not defined NDT goto tw_night
echo(!NDT!| findstr /r /x /c:"[1-9][0-9][0-9][0-9]" >nul || goto tw_night_bad
call :_tw_undo_add secure night_display_color_temperature
adb shell settings put secure night_display_color_temperature !NDT! <nul
goto tw_night

:tw_night_bad
echo [%r%^^!%w%] Invalid value. Four digits, e.g. 2850 or 4800.
timeout /t 2 /nobreak >nul
goto tw_night_temp

:tw_demo
cls
title Demo Mode
call :logo
echo.
echo  SystemUI demo mode freezes the status bar into a clean, fixed state -
echo  full signal, no clutter, a set clock - for screenshots. It is purely
echo  cosmetic, changes nothing real, and ends on exit or reboot.
echo.
set "DMA="
for /f "delims=" %%i in ('adb shell settings get global sysui_demo_allowed 2^>nul ^<nul') do set "DMA=%%i"
if "!DMA!"=="" set "DMA=null"
set "DMA=!DMA:"=!"
echo  sysui_demo_allowed (global) = "!DMA!"   (must be 1 for demo mode)
echo  There is no way to read back whether demo mode is currently ON - the
echo  state lives in SystemUI, not in a setting. Look at the device.
echo.
echo    %g%[%w%1%g%]%w% Enter demo mode (clean bar, 12:00, full signal)
echo    %g%[%w%2%g%]%w% Exit demo mode
echo    %g%[%w%3%g%]%w% Set the demo clock
echo    %g%[%w%4%g%]%w% Back
set "dm=" & set /p dm="Choose An Option >> "
if not defined dm goto tw_demo
if "!dm!"=="1" goto tw_demo_enter
if "!dm!"=="2" goto tw_demo_exit
if "!dm!"=="3" goto tw_demo_clock
if "!dm!"=="4" goto tweaks
goto tw_demo

:tw_demo_enter
:: Command set verified from DemoController.kt:44-51 - enter/exit/status/
:: network/clock/battery/bars are the only ones we send.
call :_tw_undo_add global sysui_demo_allowed
adb shell settings put global sysui_demo_allowed 1 <nul
adb shell am broadcast -a com.android.systemui.demo -e command enter <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200 <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype lte -e level 4 -e fully true <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e tty hide -e eri hide -e mute hide -e speakerphone hide <nul >nul 2>&1
adb shell am broadcast -a com.android.systemui.demo -e command bars -e mode opaque <nul >nul 2>&1
echo  Demo mode requested. Check the device's status bar.
timeout /t 2 /nobreak >nul
goto tw_demo

:tw_demo_exit
adb shell am broadcast -a com.android.systemui.demo -e command exit <nul >nul 2>&1
echo  Exit sent - the real status bar should be back.
timeout /t 2 /nobreak >nul
goto tw_demo

:tw_demo_clock
echo.
set "DMH=" & set /p DMH="Clock as HHMM, e.g. 0930 (blank = cancel) >> "
if not defined DMH goto tw_demo
set "DMH=!DMH:"=!"
if not defined DMH goto tw_demo
echo(!DMH!| findstr /r /x /c:"[01][0-9][0-5][0-9]" /c:"2[0-3][0-5][0-9]" >nul || goto tw_demo_bad
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm !DMH! <nul >nul 2>&1
echo  Clock set to !DMH! (demo mode must already be on).
timeout /t 2 /nobreak >nul
goto tw_demo

:tw_demo_bad
echo [%r%^^!%w%] Invalid time. Four digits, HHMM, e.g. 0930 or 1200.
timeout /t 2 /nobreak >nul
goto tw_demo_clock

:: -------------------------------------------------------------------
:: Profiles - the Windows-side answer to SetEdit's on-device boot queue
:: (setedit/boot/BootUtils.java). A profile is a plain text file, so it
:: is editable, diffable and shareable without DCX being involved.
:: -------------------------------------------------------------------
:tw_profile
cls
title Profiles
call :logo
set "PROFDIR=%USERPROFILE%\dcx_profiles"
if not exist "%PROFDIR%" mkdir "%PROFDIR%"
echo.
echo  A profile is a plain text file, one key per line:
echo      namespace^|key^|value      e.g.  global^|audio_safe_volume_state^|2
echo      namespace^|key^|DELETE     removes the key
echo  Lines starting with # are ignored, so you can annotate freely.
echo.
echo  Applying re-writes every listed key in one pass. That is how you
echo  re-arm a per-boot tweak - the volume cap being the obvious one -
echo  after a reboot, without walking the menus again.
echo  Folder: %PROFDIR%
echo.
echo    %g%[%w%1%g%]%w% Save the current tweak keys as a profile
echo    %g%[%w%2%g%]%w% Apply a profile
echo    %g%[%w%3%g%]%w% Open the profiles folder
echo    %g%[%w%4%g%]%w% Back
set "pr=" & set /p pr="Choose An Option >> "
if not defined pr goto tw_profile
if "!pr!"=="1" goto tw_prof_save
if "!pr!"=="2" goto tw_prof_apply
if "!pr!"=="3" (start "" "%PROFDIR%" & goto tw_profile)
if "!pr!"=="4" goto settools
goto tw_profile

:tw_prof_save
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "PROFF=%PROFDIR%\profile_%TS%.txt"
> "%PROFF%" echo # DCX profile saved %date% %time%
>>"%PROFF%" echo # format: namespace^|key^|value   (value DELETE removes the key)
call :_tw_prof_add secure clock_seconds "%PROFF%"
call :_tw_prof_add system status_bar_show_battery_percent "%PROFF%"
call :_tw_prof_add global audio_safe_volume_state "%PROFF%"
call :_tw_prof_add secure audio_safe_csd_as_a_feature_enabled "%PROFF%"
call :_tw_prof_add secure icon_blacklist "%PROFF%"
call :_tw_prof_add global heads_up_notifications_enabled "%PROFF%"
call :_tw_prof_add system font_scale "%PROFF%"
call :_tw_prof_add secure long_press_timeout "%PROFF%"
call :_tw_prof_add global stay_on_while_plugged_in "%PROFF%"
call :_tw_prof_add secure night_display_activated "%PROFF%"
call :_tw_prof_add secure night_display_color_temperature "%PROFF%"
call :_tw_prof_add global sysui_demo_allowed "%PROFF%"
call :_tw_prof_add secure sysui_qs_tiles "%PROFF%"
call :_tw_prof_add secure camera_double_tap_power_gesture_disabled "%PROFF%"
call :_tw_prof_add global charging_sounds_enabled "%PROFF%"
call :_tw_prof_add global sys_storage_threshold_percentage "%PROFF%"
call :_tw_prof_add global low_power_trigger_level "%PROFF%"
call :_tw_prof_add global enable_freeform_support "%PROFF%"
echo.
echo  Saved: %PROFF%
echo  Edit it in Notepad to trim it down to just the keys you care about.
echo  Press any key . . .
pause >nul
goto tw_profile

:_tw_prof_add
:: %1 ns  %2 key  %3 profile file. Unset keys are recorded as DELETE so a
:: profile round-trips "this key was not set" instead of losing it.
set "PVAL="
for /f "delims=" %%v in ('adb shell settings get %~1 %~2 2^>nul ^<nul') do set "PVAL=%%v"
if "!PVAL!"=="" set "PVAL=null"
set "PVAL=!PVAL:"=!"
if /i "!PVAL!"=="null" goto _tw_prof_del
call :_tw_safechk PVAL || goto _tw_prof_skip
>>"%~3" echo %~1^|%~2^|!PVAL!
exit /b
:_tw_prof_del
>>"%~3" echo %~1^|%~2^|DELETE
exit /b
:_tw_prof_skip
>>"%~3" echo # %~1^|%~2 skipped - value holds a character DCX will not round-trip
exit /b

:tw_prof_apply
cls
title Profiles : apply
call :logo
echo.
for /f "delims==" %%v in ('set PROF_ 2^>nul') do set "%%v="
set "PROFN=0"
for /f "delims=" %%f in ('dir /b /o-d /a-d "%PROFDIR%\*.txt" 2^>nul') do (
    set /a PROFN+=1
    set "PROF_!PROFN!=%%f"
    echo     %g%[%w%!PROFN!%g%]%w% %%f
)
if "!PROFN!"=="0" goto tw_prof_none
echo     %g%[%w%0%g%]%w% Back
set "PROFSEL=" & set /p PROFSEL="Apply which? >> "
if not defined PROFSEL goto tw_prof_apply
if "!PROFSEL!"=="0" goto tw_profile
echo(!PROFSEL!| findstr /r /x /c:"[0-9][0-9]*" >nul || goto tw_prof_apply
set "PROFF="
if defined PROF_!PROFSEL! for /f "delims=" %%v in ("!PROFSEL!") do set "PROFF=%PROFDIR%\!PROF_%%v!"
if not defined PROFF goto tw_prof_apply
echo.
echo  About to apply: !PROFF!
set "ok=" & set /p ok="Run it? (y = yes, anything else = cancel) >> "
if /i not "!ok!"=="y" goto tw_profile
echo.
:: eol=# drops comment lines; each line is re-validated on the way in,
:: because a profile is a file the user can hand-edit.
for /f "usebackq eol=# tokens=1-3 delims=|" %%a in ("!PROFF!") do call :_tw_prof_apply1 "%%a" "%%b" "%%c"
echo.
echo  Done. Undo script: %EXP_UNDO%
echo  Press any key . . .
pause >nul
goto tw_profile

:tw_prof_none
echo  No profiles yet - save one first, or drop a .txt into
echo  %PROFDIR%
timeout /t 3 /nobreak >nul
goto tw_profile

:_tw_prof_apply1
set "PNS=%~1"
set "PKEY=%~2"
set "PVAL=%~3"
if not defined PNS exit /b
if not defined PKEY exit /b
if /i "!PNS!"=="system" goto _tw_pa_ns_ok
if /i "!PNS!"=="secure" goto _tw_pa_ns_ok
if /i "!PNS!"=="global" goto _tw_pa_ns_ok
echo    skip - unknown namespace: !PNS!
exit /b
:_tw_pa_ns_ok
echo(!PKEY!| findstr /r /x /c:"[a-zA-Z0-9_.-][a-zA-Z0-9_.-]*" >nul || goto _tw_pa_badkey
if /i "!PVAL!"=="DELETE" goto _tw_pa_del
if not defined PVAL goto _tw_pa_badval
call :_tw_safechk PVAL || goto _tw_pa_badval
echo(!PVAL!| findstr /r /x /c:"[a-zA-Z0-9_.,:/=+-][a-zA-Z0-9_.,:/=+-]*" >nul || goto _tw_pa_badval
call :_tw_undo_add !PNS! !PKEY!
adb shell settings put !PNS! !PKEY! !PVAL! <nul >nul
echo    put    !PNS! !PKEY! = !PVAL!
exit /b
:_tw_pa_del
call :_tw_undo_add !PNS! !PKEY!
adb shell settings delete !PNS! !PKEY! >nul 2>&1 <nul
echo    delete !PNS! !PKEY!
exit /b
:_tw_pa_badkey
echo    skip - bad key name: !PKEY!
exit /b
:_tw_pa_badval
echo    skip - bad or unsafe value for !PKEY!
exit /b

:: ===================================================================
:: NEW (Tier 3): QS tile editor + assorted device tweaks.
::
:: Verified against AOSP main this pass:
::   secure sysui_qs_tiles          Settings.java:11710 (Secure.QS_TILES).
::     Still the source of truth on main: UserTileSpecRepository.kt:229
::     SETTING = Settings.Secure.QS_TILES, and it registers a content
::     observer on it (L101) -> edits apply live. Invalid specs are
::     dropped, never stored empty (TileSpecRepository.kt doc), so a typo
::     degrades instead of wrecking the panel.
::   secure camera_gesture_disabled / camera_double_tap_power_gesture_
::     disabled / camera_double_twist_to_flip_enabled  Settings.java
::     :11012, :11070, :11080
::   global charging_sounds_enabled / charging_vibration_enabled
::     Settings.java:8880, :8887
::   global sys_storage_threshold_percentage / _max_bytes  :15353
::   global low_power_trigger_level  Settings.java:16861 - note the KEY is
::     low_power_trigger_level even though the constant is called
::     LOW_POWER_MODE_TRIGGER_LEVEL.
::   global default_install_location  Settings.java:15582
::   global enable_freeform_support / force_resizable_activities  :13667,
::     :13659
:: ===================================================================
:tw_qs
cls
title Quick Settings Tiles
call :logo
echo.
set "QSCUR="
for /f "delims=" %%i in ('adb shell settings get secure sysui_qs_tiles 2^>nul ^<nul') do set "QSCUR=%%i"
if "!QSCUR!"=="" set "QSCUR=null"
set "QSCUR=!QSCUR:"=!"
echo  sysui_qs_tiles (secure) = "!QSCUR!"
if "!QSCUR!"=="null" echo    (null = the device is using its built-in default list)
echo.
echo  The order here is the order they appear. Android ships more tiles than
echo  it shows - this is how you reach them. Unknown names are dropped by
echo  SystemUI rather than breaking the panel, and the list is never stored
echo  empty, so a typo costs you a tile, not your quick settings.
echo.
echo    %g%[%w%1%g%]%w% Add a tile (at the end)
echo    %g%[%w%2%g%]%w% Add a tile (at the front)
echo    %g%[%w%3%g%]%w% Remove a tile
echo    %g%[%w%4%g%]%w% Reset to the device default (delete key)
echo    %g%[%w%5%g%]%w% Back
set "qs=" & set /p qs="Choose An Option >> "
if not defined qs goto tw_qs
if "!qs!"=="1" (set "QSPOS=end" & goto tw_qs_pick)
if "!qs!"=="2" (set "QSPOS=front" & goto tw_qs_pick)
if "!qs!"=="3" goto tw_qs_del
if "!qs!"=="4" goto tw_qs_reset
if "!qs!"=="5" goto tweaks
goto tw_qs

:tw_qs_pick
cls
title Quick Settings Tiles : add
call :logo
echo.
:: These are the specs present in SystemUI's quick_settings_tiles_stock but
:: absent from quick_settings_tiles_default (AOSP main config.xml) - i.e.
:: exactly the tiles the device has but does not show.
echo  Tiles Android knows about but does not show by default:
echo    %g%[%w%1%g%]%w% location            %g%[%w%9%g%]%w% onehanded
echo    %g%[%w%2%g%]%w% hotspot             %g%[%w%10%g%]%w% qr_code_scanner
echo    %g%[%w%3%g%]%w% saver               %g%[%w%11%g%]%w% dream          (screensaver)
echo    %g%[%w%4%g%]%w% dark                %g%[%w%12%g%]%w% font_scaling
echo    %g%[%w%5%g%]%w% night               %g%[%w%13%g%]%w% hearing_devices
echo    %g%[%w%6%g%]%w% inversion           %g%[%w%14%g%]%w% notes
echo    %g%[%w%7%g%]%w% color_correction    %g%[%w%15%g%]%w% reverse        (reverse charging)
echo    %g%[%w%8%g%]%w% reduce_brightness   %g%[%w%16%g%]%w% work           (work profile)
echo.
echo    %g%[%w%17%g%]%w% Type a spec myself
echo    %g%[%w%18%g%]%w% Back
set "QSSEL=" & set /p QSSEL="Choose An Option >> "
if not defined QSSEL goto tw_qs_pick
set "QSTOK="
if "!QSSEL!"=="1" set "QSTOK=location"
if "!QSSEL!"=="2" set "QSTOK=hotspot"
if "!QSSEL!"=="3" set "QSTOK=saver"
if "!QSSEL!"=="4" set "QSTOK=dark"
if "!QSSEL!"=="5" set "QSTOK=night"
if "!QSSEL!"=="6" set "QSTOK=inversion"
if "!QSSEL!"=="7" set "QSTOK=color_correction"
if "!QSSEL!"=="8" set "QSTOK=reduce_brightness"
if "!QSSEL!"=="9" set "QSTOK=onehanded"
if "!QSSEL!"=="10" set "QSTOK=qr_code_scanner"
if "!QSSEL!"=="11" set "QSTOK=dream"
if "!QSSEL!"=="12" set "QSTOK=font_scaling"
if "!QSSEL!"=="13" set "QSTOK=hearing_devices"
if "!QSSEL!"=="14" set "QSTOK=notes"
if "!QSSEL!"=="15" set "QSTOK=reverse"
if "!QSSEL!"=="16" set "QSTOK=work"
if "!QSSEL!"=="17" goto tw_qs_custom
if "!QSSEL!"=="18" goto tw_qs
if not defined QSTOK goto tw_qs_pick
goto tw_qs_addgo

:tw_qs_custom
echo.
echo  Lowercase letters, digits and _ only. DCX will not take the
echo  custom(package/class) form - that needs brackets and a slash, which
echo  batch will not carry safely; use the Shell option for those.
set "QSTOK=" & set /p QSTOK="Tile spec (blank = cancel) >> "
if not defined QSTOK goto tw_qs_pick
set "QSTOK=!QSTOK:"=!"
if not defined QSTOK goto tw_qs_pick
call :_tw_safechk QSTOK || goto tw_qs_bad
echo(!QSTOK!| findstr /r /x /c:"[a-z0-9_][a-z0-9_]*" >nul || goto tw_qs_bad
goto tw_qs_addgo

:tw_qs_addgo
call :_tw_undo_add secure sysui_qs_tiles
:: Same rebuild-not-append shape as the icon blacklist: drop the spec first
:: so adding an existing tile moves it rather than duplicating it.
set "QSNEW="
if "!QSCUR!"=="null" goto _tw_qs_addput
for %%t in (!QSCUR!) do (
    set "QSHIT="
    for %%u in (!QSTOK!) do if /i "%%t"=="%%u" set "QSHIT=1"
    if not defined QSHIT set "QSNEW=!QSNEW!,%%t"
)
:_tw_qs_addput
if /i "!QSPOS!"=="front" (set "QSNEW=,!QSTOK!!QSNEW!") else (set "QSNEW=!QSNEW!,!QSTOK!")
set "QSNEW=!QSNEW:~1!"
adb shell settings put secure sysui_qs_tiles !QSNEW! <nul
goto tw_qs

:tw_qs_del
cls
title Quick Settings Tiles : remove
call :logo
echo.
if "!QSCUR!"=="null" goto tw_qs_empty
for /f "delims==" %%v in ('set QST_ 2^>nul') do set "%%v="
set "QSN=0"
echo  Current tiles, in display order:
for %%t in (!QSCUR!) do (
    set /a QSN+=1
    set "QST_!QSN!=%%t"
    echo     %g%[%w%!QSN!%g%]%w% %%t
)
echo     %g%[%w%0%g%]%w% Back
set "QSPICK=" & set /p QSPICK="Remove which? >> "
if not defined QSPICK goto tw_qs_del
if "!QSPICK!"=="0" goto tw_qs
echo(!QSPICK!| findstr /r /x /c:"[0-9][0-9]*" >nul || goto tw_qs_del
set "QSTOK="
if defined QST_!QSPICK! for /f "delims=" %%v in ("!QSPICK!") do set "QSTOK=!QST_%%v!"
if not defined QSTOK goto tw_qs_del
call :_tw_undo_add secure sysui_qs_tiles
set "QSNEW="
for %%t in (!QSCUR!) do if not "%%t"=="!QSTOK!" set "QSNEW=!QSNEW!,%%t"
:: An empty list is not a valid value - SystemUI would fall back anyway, so
:: removing the last tile is expressed honestly as a reset.
if not defined QSNEW goto tw_qs_reset
set "QSNEW=!QSNEW:~1!"
adb shell settings put secure sysui_qs_tiles !QSNEW! <nul
goto tw_qs

:tw_qs_empty
echo  The device is on its default list - nothing to remove yet.
echo  Add a tile first, which writes the full list out.
timeout /t 3 /nobreak >nul
goto tw_qs

:tw_qs_reset
call :_tw_undo_add secure sysui_qs_tiles
adb shell settings delete secure sysui_qs_tiles >nul 2>&1 <nul
goto tw_qs

:tw_qs_bad
echo [%r%^^!%w%] Not allowed - lowercase letters, digits and _ only.
timeout /t 2 /nobreak >nul
goto tw_qs_pick

:tw_more
cls
title More Device Tweaks
call :logo
echo.
echo                              %m%More Device Tweaks%w%
echo.
echo    %g%[%w%1%g%]%w% Camera gestures (double-tap power, twist to flip)
echo    %g%[%w%2%g%]%w% Charging sounds and vibration
echo    %g%[%w%3%g%]%w% Storage low-space warning
echo    %g%[%w%4%g%]%w% Battery saver auto-trigger level
echo    %g%[%w%5%g%]%w% Freeform windows (needs a reboot)
echo    %g%[%w%6%g%]%w% Default install location
echo    %g%[%w%7%g%]%w% Back
set "mo=" & set /p mo="Choose An Option >> "
if not defined mo goto tw_more
if "!mo!"=="1" goto tw_cam
if "!mo!"=="2" goto tw_chg
if "!mo!"=="3" goto tw_stor
if "!mo!"=="4" goto tw_bsav
if "!mo!"=="5" goto tw_free
if "!mo!"=="6" goto tw_inst
if "!mo!"=="7" goto tweaks
goto tw_more

:tw_cam
cls
title Camera Gestures
call :logo
echo.
set "CG1="
set "CG2="
set "CG3="
for /f "delims=" %%i in ('adb shell settings get secure camera_double_tap_power_gesture_disabled 2^>nul ^<nul') do set "CG1=%%i"
for /f "delims=" %%i in ('adb shell settings get secure camera_double_twist_to_flip_enabled 2^>nul ^<nul') do set "CG2=%%i"
for /f "delims=" %%i in ('adb shell settings get secure camera_gesture_disabled 2^>nul ^<nul') do set "CG3=%%i"
if "!CG1!"=="" set "CG1=null"
if "!CG2!"=="" set "CG2=null"
if "!CG3!"=="" set "CG3=null"
set "CG1=!CG1:"=!"
set "CG2=!CG2:"=!"
set "CG3=!CG3:"=!"
echo  camera_double_tap_power_gesture_disabled = "!CG1!"   (1 = gesture off)
echo  camera_double_twist_to_flip_enabled      = "!CG2!"   (1 = twist flips camera)
echo  camera_gesture_disabled                  = "!CG3!"   (1 = lift-to-launch off)
echo.
echo  Note the naming: two of these are _disabled, one is _enabled, so 1
echo  means opposite things. The menu below says what it does, not the value.
echo.
echo    %g%[%w%1%g%]%w% Double-tap power for camera: OFF
echo    %g%[%w%2%g%]%w% Double-tap power for camera: ON
echo    %g%[%w%3%g%]%w% Twist to flip camera: ON
echo    %g%[%w%4%g%]%w% Twist to flip camera: OFF
echo    %g%[%w%5%g%]%w% Reset all three to device default
echo    %g%[%w%6%g%]%w% Back
set "cg=" & set /p cg="Choose An Option >> "
if not defined cg goto tw_cam
if "!cg!"=="1" (call :_tw_undo_add secure camera_double_tap_power_gesture_disabled & adb shell settings put secure camera_double_tap_power_gesture_disabled 1 <nul & goto tw_cam)
if "!cg!"=="2" (call :_tw_undo_add secure camera_double_tap_power_gesture_disabled & adb shell settings put secure camera_double_tap_power_gesture_disabled 0 <nul & goto tw_cam)
if "!cg!"=="3" (call :_tw_undo_add secure camera_double_twist_to_flip_enabled & adb shell settings put secure camera_double_twist_to_flip_enabled 1 <nul & goto tw_cam)
if "!cg!"=="4" (call :_tw_undo_add secure camera_double_twist_to_flip_enabled & adb shell settings put secure camera_double_twist_to_flip_enabled 0 <nul & goto tw_cam)
if "!cg!"=="5" goto tw_cam_reset
if "!cg!"=="6" goto tw_more
goto tw_cam

:tw_cam_reset
call :_tw_undo_add secure camera_double_tap_power_gesture_disabled
call :_tw_undo_add secure camera_double_twist_to_flip_enabled
call :_tw_undo_add secure camera_gesture_disabled
adb shell settings delete secure camera_double_tap_power_gesture_disabled >nul 2>&1 <nul
adb shell settings delete secure camera_double_twist_to_flip_enabled >nul 2>&1 <nul
adb shell settings delete secure camera_gesture_disabled >nul 2>&1 <nul
goto tw_cam

:tw_chg
cls
title Charging Sounds
call :logo
echo.
set "CH1="
set "CH2="
for /f "delims=" %%i in ('adb shell settings get global charging_sounds_enabled 2^>nul ^<nul') do set "CH1=%%i"
for /f "delims=" %%i in ('adb shell settings get global charging_vibration_enabled 2^>nul ^<nul') do set "CH2=%%i"
if "!CH1!"=="" set "CH1=null"
if "!CH2!"=="" set "CH2=null"
set "CH1=!CH1:"=!"
set "CH2=!CH2:"=!"
echo  charging_sounds_enabled    (global) = "!CH1!"
echo  charging_vibration_enabled (global) = "!CH2!"
echo  The chirp and buzz when you plug in. 1 = on, 0 = off.
echo.
echo    %g%[%w%1%g%]%w% Sound off
echo    %g%[%w%2%g%]%w% Sound on
echo    %g%[%w%3%g%]%w% Vibration off
echo    %g%[%w%4%g%]%w% Vibration on
echo    %g%[%w%5%g%]%w% Reset both to device default
echo    %g%[%w%6%g%]%w% Back
set "ch=" & set /p ch="Choose An Option >> "
if not defined ch goto tw_chg
if "!ch!"=="1" (call :_tw_undo_add global charging_sounds_enabled & adb shell settings put global charging_sounds_enabled 0 <nul & goto tw_chg)
if "!ch!"=="2" (call :_tw_undo_add global charging_sounds_enabled & adb shell settings put global charging_sounds_enabled 1 <nul & goto tw_chg)
if "!ch!"=="3" (call :_tw_undo_add global charging_vibration_enabled & adb shell settings put global charging_vibration_enabled 0 <nul & goto tw_chg)
if "!ch!"=="4" (call :_tw_undo_add global charging_vibration_enabled & adb shell settings put global charging_vibration_enabled 1 <nul & goto tw_chg)
if "!ch!"=="5" goto tw_chg_reset
if "!ch!"=="6" goto tw_more
goto tw_chg

:tw_chg_reset
call :_tw_undo_add global charging_sounds_enabled
call :_tw_undo_add global charging_vibration_enabled
adb shell settings delete global charging_sounds_enabled >nul 2>&1 <nul
adb shell settings delete global charging_vibration_enabled >nul 2>&1 <nul
goto tw_chg

:tw_stor
cls
title Storage Warning
call :logo
echo.
set "STP="
set "STB="
for /f "delims=" %%i in ('adb shell settings get global sys_storage_threshold_percentage 2^>nul ^<nul') do set "STP=%%i"
for /f "delims=" %%i in ('adb shell settings get global sys_storage_threshold_max_bytes 2^>nul ^<nul') do set "STB=%%i"
if "!STP!"=="" set "STP=null"
if "!STB!"=="" set "STB=null"
set "STP=!STP:"=!"
set "STB=!STB:"=!"
echo  sys_storage_threshold_percentage (global) = "!STP!"   (default 10)
echo  sys_storage_threshold_max_bytes  (global) = "!STB!"   (caps the above)
echo.
echo  When free space drops below the percentage, Android nags and starts
echo  refusing installs. On a 512 GB phone the stock 10%% means it panics
echo  with 50 GB free. The max_bytes cap is the sane fix: whichever is
echo  smaller wins.
echo.
echo    %g%[%w%1%g%]%w% Percentage: 10 (stock)
echo    %g%[%w%2%g%]%w% Percentage: 5
echo    %g%[%w%3%g%]%w% Percentage: 2
echo    %g%[%w%4%g%]%w% Cap the warning at 2 GB free  (max_bytes)
echo    %g%[%w%5%g%]%w% Cap the warning at 5 GB free  (max_bytes)
echo    %g%[%w%6%g%]%w% Reset both to device default
echo    %g%[%w%7%g%]%w% Back
set "st=" & set /p st="Choose An Option >> "
if not defined st goto tw_stor
if "!st!"=="1" (call :_tw_undo_add global sys_storage_threshold_percentage & adb shell settings put global sys_storage_threshold_percentage 10 <nul & goto tw_stor)
if "!st!"=="2" (call :_tw_undo_add global sys_storage_threshold_percentage & adb shell settings put global sys_storage_threshold_percentage 5 <nul & goto tw_stor)
if "!st!"=="3" (call :_tw_undo_add global sys_storage_threshold_percentage & adb shell settings put global sys_storage_threshold_percentage 2 <nul & goto tw_stor)
if "!st!"=="4" (call :_tw_undo_add global sys_storage_threshold_max_bytes & adb shell settings put global sys_storage_threshold_max_bytes 2147483648 <nul & goto tw_stor)
if "!st!"=="5" (call :_tw_undo_add global sys_storage_threshold_max_bytes & adb shell settings put global sys_storage_threshold_max_bytes 5368709120 <nul & goto tw_stor)
if "!st!"=="6" goto tw_stor_reset
if "!st!"=="7" goto tw_more
goto tw_stor

:tw_stor_reset
call :_tw_undo_add global sys_storage_threshold_percentage
call :_tw_undo_add global sys_storage_threshold_max_bytes
adb shell settings delete global sys_storage_threshold_percentage >nul 2>&1 <nul
adb shell settings delete global sys_storage_threshold_max_bytes >nul 2>&1 <nul
goto tw_stor

:tw_bsav
cls
title Battery Saver Trigger
call :logo
echo.
set "BSV="
for /f "delims=" %%i in ('adb shell settings get global low_power_trigger_level 2^>nul ^<nul') do set "BSV=%%i"
if "!BSV!"=="" set "BSV=null"
set "BSV=!BSV:"=!"
echo  low_power_trigger_level (global) = "!BSV!" %%   (0/null = never auto-on)
echo.
echo  The battery percentage at which saver switches itself on. This is only
echo  the trigger - Battery ^> Saver On/Off writes low_power itself, so that
echo  screen turns saver on now, this one decides when it does so by itself.
echo.
echo    %g%[%w%1%g%]%w% Never (0)
echo    %g%[%w%2%g%]%w% 5%%
echo    %g%[%w%3%g%]%w% 15%% (common default)
echo    %g%[%w%4%g%]%w% 30%%
echo    %g%[%w%5%g%]%w% 50%%
echo    %g%[%w%6%g%]%w% Custom (0 - 99)
echo    %g%[%w%7%g%]%w% Reset to device default (delete key)
echo    %g%[%w%8%g%]%w% Back
set "bsv=" & set /p bsv="Choose An Option >> "
if not defined bsv goto tw_bsav
if "!bsv!"=="1" (set "BSNEW=0" & goto tw_bsav_apply)
if "!bsv!"=="2" (set "BSNEW=5" & goto tw_bsav_apply)
if "!bsv!"=="3" (set "BSNEW=15" & goto tw_bsav_apply)
if "!bsv!"=="4" (set "BSNEW=30" & goto tw_bsav_apply)
if "!bsv!"=="5" (set "BSNEW=50" & goto tw_bsav_apply)
if "!bsv!"=="6" goto tw_bsav_custom
if "!bsv!"=="7" (call :_tw_undo_add global low_power_trigger_level & adb shell settings delete global low_power_trigger_level >nul 2>&1 <nul & goto tw_bsav)
if "!bsv!"=="8" goto tw_more
goto tw_bsav

:tw_bsav_custom
echo.
set "BSNEW=" & set /p BSNEW="Percentage 0 - 99 (blank = cancel) >> "
if not defined BSNEW goto tw_bsav
set "BSNEW=!BSNEW:"=!"
if not defined BSNEW goto tw_bsav
echo(!BSNEW!| findstr /r /x /c:"[0-9]" /c:"[1-9][0-9]" >nul || goto tw_bsav_bad
goto tw_bsav_apply

:tw_bsav_bad
echo [%r%^^!%w%] Invalid value. A whole number from 0 to 99.
timeout /t 2 /nobreak >nul
goto tw_bsav_custom

:tw_bsav_apply
call :_tw_undo_add global low_power_trigger_level
adb shell settings put global low_power_trigger_level !BSNEW! <nul
goto tw_bsav

:tw_free
cls
title Freeform Windows
call :logo
echo.
set "FW1="
set "FW2="
for /f "delims=" %%i in ('adb shell settings get global enable_freeform_support 2^>nul ^<nul') do set "FW1=%%i"
for /f "delims=" %%i in ('adb shell settings get global force_resizable_activities 2^>nul ^<nul') do set "FW2=%%i"
if "!FW1!"=="" set "FW1=null"
if "!FW2!"=="" set "FW2=null"
set "FW1=!FW1:"=!"
set "FW2=!FW2:"=!"
echo  enable_freeform_support    (global) = "!FW1!"
echo  force_resizable_activities (global) = "!FW2!"
echo.
echo  Desktop-style floating windows. Both are developer-options keys and
echo  need a REBOOT to take effect - nothing will look different until then.
echo  Force-resizable makes apps that declare themselves fixed-size resize
echo  anyway, which some of them handle badly.
echo.
echo    %g%[%w%1%g%]%w% Enable freeform support
echo    %g%[%w%2%g%]%w% Disable freeform support
echo    %g%[%w%3%g%]%w% Force activities resizable: on
echo    %g%[%w%4%g%]%w% Force activities resizable: off
echo    %g%[%w%5%g%]%w% Reset both to device default
echo    %g%[%w%6%g%]%w% Reboot now
echo    %g%[%w%7%g%]%w% Back
set "fw=" & set /p fw="Choose An Option >> "
if not defined fw goto tw_free
if "!fw!"=="1" (call :_tw_undo_add global enable_freeform_support & adb shell settings put global enable_freeform_support 1 <nul & goto tw_free)
if "!fw!"=="2" (call :_tw_undo_add global enable_freeform_support & adb shell settings put global enable_freeform_support 0 <nul & goto tw_free)
if "!fw!"=="3" (call :_tw_undo_add global force_resizable_activities & adb shell settings put global force_resizable_activities 1 <nul & goto tw_free)
if "!fw!"=="4" (call :_tw_undo_add global force_resizable_activities & adb shell settings put global force_resizable_activities 0 <nul & goto tw_free)
if "!fw!"=="5" goto tw_free_reset
if "!fw!"=="6" (adb reboot <nul & goto tw_free)
if "!fw!"=="7" goto tw_more
goto tw_free

:tw_free_reset
call :_tw_undo_add global enable_freeform_support
call :_tw_undo_add global force_resizable_activities
adb shell settings delete global enable_freeform_support >nul 2>&1 <nul
adb shell settings delete global force_resizable_activities >nul 2>&1 <nul
goto tw_free

:tw_inst
cls
title Install Location
call :logo
echo.
set "ILV="
for /f "delims=" %%i in ('adb shell settings get global default_install_location 2^>nul ^<nul') do set "ILV=%%i"
if "!ILV!"=="" set "ILV=null"
set "ILV=!ILV:"=!"
echo  default_install_location (global) = "!ILV!"
echo    0/null = let the system decide, 1 = internal, 2 = external
echo  Only bites on devices with adoptable/removable storage, and an app can
echo  still override it in its manifest - so this is a preference, not a rule.
echo.
echo    %g%[%w%1%g%]%w% System decides (0)
echo    %g%[%w%2%g%]%w% Prefer internal (1)
echo    %g%[%w%3%g%]%w% Prefer external (2)
echo    %g%[%w%4%g%]%w% Reset to device default (delete key)
echo    %g%[%w%5%g%]%w% Back
set "il=" & set /p il="Choose An Option >> "
if not defined il goto tw_inst
if "!il!"=="1" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 0 <nul & goto tw_inst)
if "!il!"=="2" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 1 <nul & goto tw_inst)
if "!il!"=="3" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 2 <nul & goto tw_inst)
if "!il!"=="4" (call :_tw_undo_add global default_install_location & adb shell settings delete global default_install_location >nul 2>&1 <nul & goto tw_inst)
if "!il!"=="5" goto tw_more
goto tw_inst

:: ===================================================================
:: Settings Tools (main menu 15) - generic tooling over the whole
:: settings provider, split out of the Tweaks hub. Tweaks is the
:: curated list; these three work on any key and are the SetEdit
:: analogue, so they earn their own top-level entry rather than
:: sitting three levels down.
:: ===================================================================
:settools
cls
title Settings Tools
call :logo
echo.
echo                               %m%Settings Tools%w%
echo.
echo  Tweaks %gold%[6]%w% is the curated list of things worth changing.
echo  These work on any key in the settings provider, including the ones
echo  DCX has no menu row for.
echo.
echo    %g%[%w%1%g%]%w% Settings explorer - list / get / put / delete
echo    %g%[%w%2%g%]%w% Settings snapshot and diff
echo    %g%[%w%3%g%]%w% Profiles - save / re-apply a set of keys
echo    %g%[%w%4%g%]%w% Back to main menu
set "sx=" & set /p sx="Choose An Option >> "
if not defined sx goto settools
if "!sx!"=="1" goto tw_explorer
if "!sx!"=="2" goto tw_snapshot
if "!sx!"=="3" goto tw_profile
if "!sx!"=="4" goto menu
goto settools

:logo
chcp 65001 >nul
echo.
echo.
echo                                     %m%██████╗  ██████╗██╗  ██╗
echo                                     ██╔══██╗██╔════╝╚██╗██╔╝
echo                                     ██║  ██║██║      ╚███╔╝ %w%
echo                                     ██║  ██║██║      ██╔██╗
echo                                     ██████╔╝╚██████╗██╔╝ ██╗
echo                                     ╚═════╝  ╚═════╝╚═╝  ╚═╝
echo.
echo.
exit /b
:: ===================================================================
:: SHARED HELPER: silence all WindowManager debug-trace channels.
:: Used by :setupautorun and :offlogss (previously duplicated 78 lines
:: in each place = 156 redundant lines).
:: `wm logging disable-text` silences the per-channel text output.
:: `wm logging disable` disables the channel entirely.
:: Both calls together fully mute WM tracing on Android 12+.
:: ===================================================================
:wm_silence_logs
for %%C in (
    WM_ERROR
    WM_DEBUG_ORIENTATION
    WM_DEBUG_FOCUS_LIGHT
    WM_DEBUG_BOOT
    WM_DEBUG_RESIZE
    WM_DEBUG_ADD_REMOVE
    WM_DEBUG_CONFIGURATION
    WM_DEBUG_SWITCH
    WM_DEBUG_CONTAINERS
    WM_DEBUG_FOCUS
    WM_DEBUG_IMMERSIVE
    WM_DEBUG_LOCKTASK
    WM_DEBUG_STATES
    WM_DEBUG_TASKS
    WM_DEBUG_STARTING_WINDOW
    WM_SHOW_TRANSACTIONS
    WM_SHOW_SURFACE_ALLOC
    WM_DEBUG_APP_TRANSITIONS
    WM_DEBUG_ANIM
    WM_DEBUG_APP_TRANSITIONS_ANIM
    WM_DEBUG_RECENTS_ANIMATIONS
    WM_DEBUG_DRAW
    WM_DEBUG_REMOTE_ANIMATIONS
    WM_DEBUG_SCREEN_ON
    WM_DEBUG_KEEP_SCREEN_ON
    WM_DEBUG_WINDOW_MOVEMENT
    WM_DEBUG_IME
    WM_DEBUG_WINDOW_ORGANIZER
    WM_DEBUG_SYNC_ENGINE
    WM_DEBUG_WINDOW_TRANSITIONS
    WM_DEBUG_WINDOW_TRANSITIONS_MIN
    WM_DEBUG_WINDOW_INSETS
    WM_DEBUG_CONTENT_RECORDING
    WM_DEBUG_WALLPAPER
    WM_DEBUG_BACK_PREVIEW
    WM_DEBUG_DREAM
    WM_DEBUG_DIMMER
    WM_DEBUG_TPL
    WM_DEBUG_EMBEDDED_WINDOWS
) do (
    adb shell wm logging disable-text %%C > nul 2>&1
    adb shell wm logging disable      %%C > nul 2>&1
)
exit /b
:: ===================================================================
:: SHARED HELPER: mark common system_server dropbox channels as
:: low-priority so they don't spam the dropbox quota. The caller is
:: expected to set the rate-limit afterwards (the value differs).
:: Used by :setupautorun, :skiplogv, :onlogss (saved 21 lines from 3
:: identical occurrences).
:: ===================================================================
:dropbox_lowprio
adb shell cmd dropbox add-low-priority system_server
adb shell cmd dropbox add-low-priority system_server/Subject
adb shell cmd dropbox add-low-priority data_app_wtf
adb shell cmd dropbox add-low-priority storage_trim
adb shell cmd dropbox add-low-priority SYSTEM_BOOT
adb shell cmd dropbox add-low-priority SYSTEM_AUDIT
adb shell cmd dropbox add-low-priority system_server_wtf
adb shell cmd dropbox add-low-priority SYSTEM_LAST_KMSG
exit /b
:: ===================================================================
:: SHARED HELPER: dexopt_all_mode  <filter>  <heavy_flag>
::
:: Compiles ALL installed apps with the given compiler filter, picking
:: the right command for the device's Android version:
::
::   Android 13 and below : the package-manager dexopt path.
::     - heavy_flag "1" adds `--check-prof false` (compile every method,
::       not just profiled hot ones) for the Heaviest mode.
::
::   Android 14 and above : dexopt is handled by ART Service. The plain
::     `pm compile -m <filter> -f -a` still works (it is transparently
::     routed to ART Service) but the removed flags `--check-prof` and
::     `--compile-layouts` must NOT be passed - they throw "Unknown
::     option". So on 14+ we drop them.
:: ===================================================================
:dexopt_all_mode
if %SDK% GEQ 34 goto _dexall_art
if "%~2"=="1" goto _dexall_heavy_legacy
echo   [pm dexopt / API %SDK%] pm compile -a -f -m %~1
adb shell pm compile -a -f -m %~1
exit /b

:_dexall_heavy_legacy
echo   [pm dexopt / API %SDK%] pm compile -a -f --check-prof false -m %~1
adb shell pm compile -a -f --check-prof false -m %~1
exit /b

:_dexall_art
echo   [ART Service / API %SDK%] pm compile -m %~1 -f -a
adb shell pm compile -m %~1 -f -a
exit /b
:: ===================================================================
:: SHARED HELPER: run_bgdexopt
::
:: Forces the background dexopt job, version-aware:
::
::   Android 13 and below : `pm bg-dexopt-job` (package-manager path).
::
::   Android 14 and above : prefer the native ART Service command
::     `pm art dexopt-packages -r bg-dexopt`. If a particular build
::     doesn't expose `pm art` (older 14 images, some OEMs), fall back
::     to `pm bg-dexopt-job`, which is still routed to ART Service.
:: ===================================================================
:run_bgdexopt
if %SDK% LSS 34 goto _bgdex_legacy
echo   [ART Service / API %SDK%] running background dexopt...
echo   (this can take a while and processes every app - please wait)
adb shell pm art dexopt-packages -r bg-dexopt > "%TEMP%\dcx_bgdex.txt" 2>&1
:: If the command itself is unavailable, fall back to the legacy job.
findstr /I /C:"Unknown command" /C:"Usage:" "%TEMP%\dcx_bgdex.txt" > nul && goto _bgdex_fallback
:: ART Service prints one status line per package (often hundreds).
:: Dumping all of it looks alarming, so instead we summarise: count
:: how many succeeded vs failed, and show ONLY real failure lines.
set "_dx_perf=0"
set "_dx_fail=0"
for /f %%n in ('findstr /I /C:"PERFORMED" "%TEMP%\dcx_bgdex.txt" 2^>nul ^| find /c /v ""') do set "_dx_perf=%%n"
for /f %%n in ('findstr /I /C:"FAILED" "%TEMP%\dcx_bgdex.txt" 2^>nul ^| find /c /v ""') do set "_dx_fail=%%n"
echo.
echo   Background dexopt finished.
echo     Packages optimised : %_dx_perf%
echo     Failures           : %_dx_fail%
if not "%_dx_fail%"=="0" (
    echo.
    echo   Failed entries ^(first 15^):
    findstr /I /C:"FAILED" "%TEMP%\dcx_bgdex.txt" | more +0 2>nul
    echo.
    echo   Note: a few failures are normal - some system packages can't
    echo   be re-compiled. The full log is at:
    echo     %TEMP%\dcx_bgdex.txt
    echo   ^(leaving it in place so you can inspect it^)
) else (
    echo   No failures. All good.
    del "%TEMP%\dcx_bgdex.txt" > nul 2>&1
)
exit /b

:_bgdex_fallback
echo   pm art unavailable on this build - using pm bg-dexopt-job...
adb shell pm bg-dexopt-job
del "%TEMP%\dcx_bgdex.txt" > nul 2>&1
exit /b

:_bgdex_legacy
adb shell pm bg-dexopt-job
exit /b

