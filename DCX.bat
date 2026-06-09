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
    echo [%r%!%w%] ADB not found!
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
        for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
            if "%%b"=="device" set "DEVICE_OK=1"
        )
        if "!DEVICE_OK!"=="0" timeout /t 1 /nobreak > nul
    )
)
if "%DEVICE_OK%"=="0" (
    cls
    call :logo
    echo [%r%!%w%] No authorised device found.
    echo     - Enable USB debugging on the device
    echo     - Approve the RSA fingerprint prompt
    echo     - Check the cable / driver
    echo.
    echo     Run 'adb devices' manually to verify.
    echo.
    echo Press any key to exit...
    pause > nul
    adb kill-server > nul 2>&1
    exit /b
)
:: Retrieve the current Android API level safely
set "SDK="
for /f "delims=" %%i in ('adb shell getprop ro.build.version.sdk 2^>nul') do set "SDK=%%i"
:: Strip trailing CR if any
if defined SDK set "SDK=%SDK:~0,3%"
if defined SDK for /f "tokens=* delims= " %%a in ("%SDK%") do set "SDK=%%a"
:: Capture device model for friendlier messages
set "MODEL="
for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul') do set "MODEL=%%i"
echo [%g%+%w%] Device: %MODEL%   API level: %SDK%
timeout /t 1 /nobreak > nul
goto menu

:menu
cls
title Main Menu
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo           [%g%+%w%]Uptime: %%a %%b %%c
for /f "tokens=1 delims=:" %%i in ('adb shell dumpsys cpuinfo') do set cpucheck=%%i
echo           [%g%+%w%]%cpucheck% LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                           %r%Gaming%w%         %gold%Battery%w%   %g%Optimize Android%w%
echo                             [1]            [2]            [3]                                        
echo.
echo                            %d%Auto%w%       %d%CheckSetting%w%       %d%Github%w%
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
set /p kb="                            Choose An Option >> "
if "%kb%"=="1" goto Gaming
if "%kb%"=="2" goto Battery
if "%kb%"=="3" goto Optimize
if "%kb%"=="4" goto Auto
if "%kb%"=="5" goto Check
if "%kb%"=="6" goto github
if "%kb%"=="7" goto reboot
if "%kb%"=="8" goto exitscript
if "%kb%"=="9" goto shell
if "%kb%"=="10" goto benchmark
if "%kb%"=="11" goto backup
if "%kb%"=="12" goto restore
goto menu
:: ===================================================================
:: NEW: Backup / Restore of toggleable settings
::
:: Backup dumps current values of every Settings.Global / System key,
:: device_config flag and system property that DCX can toggle, into
:: a stand-alone .bat file in %USERPROFILE%\dcx_backups\. Restore just
:: `call`s that .bat - so the format is human-readable and you can
:: edit it before restoring.
:: ===================================================================
:backup
cls
title Backup Settings
call :logo
echo.
set "BACKUPDIR=%USERPROFILE%\dcx_backups"
if not exist "%BACKUPDIR%" mkdir "%BACKUPDIR%"
set "TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=%TS: =0%"
set "BAKFILE=%BACKUPDIR%\dcx_backup_%TS%.bat"
echo  Saving current settings to:
echo    %BAKFILE%
echo.
:: Build a restore script. Each captured value becomes a put/setprop
:: command; missing values become delete to clear any stale override.
(
    echo @echo off
    echo :: DCX Settings Backup created %date% %time%
    echo :: This file is a stand-alone restore script - run it with the
    echo :: same device connected to revert to the captured state.
    echo ::
    echo :: You can also edit it (delete lines you don't want to restore^^).
    echo.
    echo adb start-server ^>nul 2^>^&1
    echo echo Restoring DCX-managed settings...
    echo.
) > "%BAKFILE%"
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
call :_bk_devcfg   app_hibernation app_hibernation_enabled "%BAKFILE%"
call :_bk_prop     debug.hwui.renderer        "%BAKFILE%"
call :_bk_prop     debug.renderengine.backend "%BAKFILE%"
call :_bk_prop     persist.log.tag            "%BAKFILE%"
(
    echo.
    echo echo Done. Press any key to close.
    echo pause ^>nul
) >> "%BAKFILE%"
echo  %g%Backup complete.%w%
echo.
echo  %b%[%w%1%b%]%w% Open backups folder in Explorer
echo  %b%[%w%2%b%]%w% View this backup in Notepad
echo  %b%[%w%3%b%]%w% Back to main menu
set /p bk="Choose An Option >> "
if "%bk%"=="1" (
    start "" "%BACKUPDIR%"
    goto menu
)
if "%bk%"=="2" (
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
setlocal
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
for /f "delims=" %%v in ('adb shell settings get %_ns% %_key% 2^>nul') do set "_val=%%v"
if "%_val%"=="" set "_val=null"
if /i "%_val%"=="null" (
    echo adb shell settings delete %_ns% %_key% ^>nul 2^>^&1>> "%_out%"
) else (
    echo adb shell settings put %_ns% %_key% %_val%>> "%_out%"
)
endlocal
exit /b

:_bk_devcfg
setlocal
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
for /f "delims=" %%v in ('adb shell device_config get %_ns% %_key% 2^>nul') do set "_val=%%v"
if "%_val%"=="" set "_val=null"
if /i "%_val%"=="null" (
    echo :: %_ns%/%_key% was unset at backup time>> "%_out%"
) else (
    echo adb shell device_config put %_ns% %_key% %_val%>> "%_out%"
)
endlocal
exit /b

:_bk_prop
setlocal
set "_key=%~1"
set "_out=%~2"
set "_val="
for /f "delims=" %%v in ('adb shell getprop %_key% 2^>nul') do set "_val=%%v"
echo adb shell setprop %_key% "%_val%">> "%_out%"
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
set /p ri="Pick a backup to restore >> "
if "%ri%"=="0" goto menu
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
echo.
echo  %g%Restore complete.%w% Some changes may need a reboot to fully apply.
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
adb shell rm -f /data/local/tmp/_dcx_bench
echo.
echo.
echo [%g%Done%w%] Numbers vary - run twice after optimisation for comparison.
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
echo                   %d%Thanks For Using My Script, Goodbye And Have A Good Day!!%w%
echo.
echo.
timeout /t 3 /nobreak > nul
adb shell cmd notification post -S bigtext -t '⚙DCX⚙' 'Tag' 'Restart = Remove All Settings Applied, Please Use This Script At Least Once A Month To Keep Your Device Smooth, Bye!!' > nul 2>&1
adb kill-server
exit /b

:reboot
adb reboot
timeout /t 1 /nobreak > nul
adb disconnect
goto menu

:github
start https://github.com/C1nderC0ated/xprt/releases/tag/1.1.1.1
goto menu

:check
cls
title Device Info ^& Diagnostics
call :logo
echo.
echo  Generating full device report...
echo.
:: Build a timestamped report so old reports aren't overwritten
:: and the user can compare before/after applying tweaks.
set "TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=%TS: =0%"
set "REPORT=%TEMP%\dcx_report_%TS%.txt"
(
    echo ===========================================================
    echo  DCX Device Diagnostic Report - %date% %time%
    echo ===========================================================
    echo.
    echo [Hardware]
    for /f "delims=" %%i in ('adb shell getprop ro.product.manufacturer 2^>nul') do echo   Manufacturer        : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul')        do echo   Model               : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.device 2^>nul')       do echo   Device codename     : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.product.cpu.abi 2^>nul')      do echo   CPU ABI             : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.hardware 2^>nul')             do echo   SoC platform        : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.board.platform 2^>nul')       do echo   Board platform      : %%i
    echo.
    echo [Software]
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.release 2^>nul')        do echo   Android version     : %%i
    echo   API level           : %SDK%
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.security_patch 2^>nul') do echo   Security patch      : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.build.version.incremental 2^>nul')    do echo   Build incremental   : %%i
    for /f "delims=" %%i in ('adb shell getprop ro.build.type 2^>nul')                   do echo   Build type          : %%i
    echo.
    echo [Memory]
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "MemTotal"')     do echo   Total RAM           : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "MemAvailable"') do echo   Available RAM       : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "MemFree"')      do echo   Free RAM            : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "Buffers"')      do echo   Buffers             : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "^Cached"')      do echo   Cached              : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "SwapTotal"')    do echo   Swap total          : %%i kB
    for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "SwapFree"')     do echo   Swap free           : %%i kB
    echo.
    echo [Storage]
    adb shell df -h /data 2^>nul
    echo.
    echo [State]
    for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo   Uptime              : %%a %%b %%c
    for /f "delims=" %%i in ('adb shell dumpsys cpuinfo ^| findstr /C:"Load:"')      do echo   %%i
    for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"level:"')       do echo   Battery            %%i
    for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"temperature:"') do echo   Battery temp       %%i (deci-degrees C)
    for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"voltage:"')     do echo   Battery voltage    %%i
    for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"status:"')      do echo   Battery status     %%i
    for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"health:"')      do echo   Battery health     %%i
    echo.
    echo [Display]
    for /f "tokens=2 delims==" %%i in ('adb shell dumpsys SurfaceFlinger ^| findstr "refresh-rate"') do echo   Display refresh    : %%i Hz
    for /f "delims=" %%i in ('adb shell wm size 2^>nul')                                              do echo   %%i
    for /f "delims=" %%i in ('adb shell wm density 2^>nul')                                           do echo   %%i
    echo.
    echo [Graphics renderer - current values]
    for /f "delims=" %%i in ('adb shell getprop debug.hwui.renderer 2^>nul')   do echo   debug.hwui.renderer        : "%%i" (skiagl=default, skiavk=Skia Vulkan, empty=auto)
    for /f "delims=" %%i in ('adb shell getprop ro.hwui.renderer 2^>nul')      do echo   ro.hwui.renderer           : "%%i"
    for /f "delims=" %%i in ('adb shell settings get global angle_gl_driver_all_angle 2^>nul') do echo   angle_gl_driver_all_angle  : %%i (1=force ANGLE for all GLES apps, 0/null=off)
    for /f "delims=" %%i in ('adb shell getprop persist.log.tag 2^>nul')       do echo   persist.log.tag            : "%%i" (set to "*:S" to silence all logs)
    echo.
    echo [Animation / Refresh - current values]
    for /f "delims=" %%i in ('adb shell settings get global window_animation_scale 2^>nul')     do echo   window_animation_scale     : %%i
    for /f "delims=" %%i in ('adb shell settings get global transition_animation_scale 2^>nul') do echo   transition_animation_scale : %%i
    for /f "delims=" %%i in ('adb shell settings get global animator_duration_scale 2^>nul')    do echo   animator_duration_scale    : %%i
    for /f "delims=" %%i in ('adb shell settings get system min_refresh_rate 2^>nul')           do echo   min_refresh_rate (Hz)      : %%i
    for /f "delims=" %%i in ('adb shell settings get system peak_refresh_rate 2^>nul')          do echo   peak_refresh_rate (Hz)     : %%i
    echo.
    echo [Battery savers / Sync - current values]
    for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul')          do echo   master_sync_status         : %%i  (1=on, 0=off)
    for /f "delims=" %%i in ('adb shell settings get global hotword_detection_enabled 2^>nul')   do echo   hotword_detection_enabled  : %%i  (1=on, 0=off)
    for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul') do echo   app_hibernation_enabled    : %%i
    echo.
    echo [Network]
    for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul') do echo   Preferred network mode      : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_mode 2^>nul')       do echo   Private DNS mode           : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_specifier 2^>nul')  do echo   Private DNS host           : %%i
    echo.
    echo [Power state]
    for /f "delims=" %%i in ('adb shell settings get global low_power 2^>nul') do echo   Battery saver         : %%i
    adb shell cmd power get-mode 2^>nul
    echo.
    echo [Doze whitelist - first 20 entries]
    adb shell dumpsys deviceidle whitelist 2^>nul
    echo.
    echo [Top 10 RAM consumers]
    adb shell "dumpsys meminfo --oom 2>/dev/null | head -40"
    echo.
    echo [Currently focused app]
    adb shell dumpsys activity activities 2^>nul ^| findstr /C:"mResumedActivity"
    echo.
    echo ===========================================================
    echo  End of report
    echo ===========================================================
) > "%REPORT%"
echo  %g%Report saved to:%w%
echo    %REPORT%
echo.
echo  %b%[%w%1%b%]%w% Open report in Notepad (scrollable, searchable)
echo  %b%[%w%2%b%]%w% Show report in this window (paginated with MORE)
echo  %b%[%w%3%b%]%w% Show short summary here ^& go back
echo  %b%[%w%4%b%]%w% Back to main menu
echo.
set /p ck="Choose An Option >> "
if "%ck%"=="1" goto check_open
if "%ck%"=="2" goto check_paginate
if "%ck%"=="3" goto check_summary
if "%ck%"=="4" goto menu
goto check

:check_open
start "" notepad "%REPORT%"
goto check

:check_paginate
cls
title Device Diagnostics ^(paginated^)
more "%REPORT%"
echo.
echo Press Any Button To Go Back
pause > nul
goto check

:check_summary
cls
call :logo
echo                            %b%[%w% Quick Summary %b%]%w%
echo.
for /f "delims=" %%i in ('adb shell getprop ro.product.model 2^>nul') do echo   Device: %%i  ^(API %SDK%^)
for /f "tokens=2" %%i in ('adb shell cat /proc/meminfo ^| findstr "MemAvailable"') do echo   Free RAM: %%i kB
for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"level:"')       do echo  %%i
for /f "delims=" %%i in ('adb shell dumpsys battery ^| findstr /C:"temperature:"') do echo  %%i (deci-degrees C)
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo   Uptime: %%a %%b %%c
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto setupautorun
if "%kb%"=="2" goto menu

:setupautorun
cls && title SurfaceFlinger Setup!
call :logo
echo.
echo.
echo [%g%+%w%] Check Refresh Rate
timeout /t 1 /nobreak > nul
for /f "tokens=3 delims= " %%i in ('adb shell dumpsys SurfaceFlinger ^| findstr "refresh-rate"') do (
    set refresh_rate=%%i
)
set refresh_rate=%refresh_rate: =%
if "%refresh_rate%"=="" (
    echo [%r%!%w%] Could not detect refresh rate. Auto setup cannot continue.
    pause > nul
    goto menu
)
echo [%b%!%w%]Refresh rate : %refresh_rate%
timeout /t 1 /nobreak > nul
for /f "delims=" %%i in ('powershell -Command "[math]::Round(1 / %refresh_rate%, 10)"') do set result=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%result% * 1000000000, 0)"') do set final=%%i
echo [%g%+%w%] Check Result . . . .
echo.
timeout /t 1 /nobreak > nul
echo.
echo.
echo [%b%!%w%] SurfaceFlinger Setup. . .
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 18.518520, 0)"') do set eaglpos=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 8.771929, 0)"') do set apsofs=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 4.7619050, 0)"') do set elfpsofsasdasx=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 3.7037029 - 1, 0)"') do set elrdur=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 3.3333336900, 0)"') do set sfelpoassd=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 1.851852 + 1, 0)"') do set rgsmplsa=%%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round(%final% / 0.8771929 -2, 0)"') do set rgstis=%%i
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
echo [%g%+%w%] Done !
echo.
echo.
timeout /t 2 /nobreak > nul
echo [!] SurfaceFlinger Setup Is Complete, 2nd Setup Is Ready!
echo [!] Please Wait!
timeout /t 10 /nobreak > nul
set count=0
title 2nd Setup
cls
call :logo
adb shell cmd package bg-dexopt-job
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
:: ----- NEW SAFE OPTIMISATIONS (from the .sh script, vetted) -----
:: Universal log silencer (REAL, persists across reboots)
adb shell setprop persist.log.tag "*:S" > nul 2>&1
adb shell setprop log.tag "*:S" > nul 2>&1
:: Force ANGLE for all GLES apps (only effective on Android 12+ with
:: the ANGLE APK present, which is true on most modern devices).
if "%SDK%"=="" goto _skip_angle_auto
if %SDK% GEQ 31 (
    adb shell settings put global angle_gl_driver_all_angle 1 > nul 2>&1
)

:_skip_angle_auto
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
adb shell cmd notification post -S bigtext -t 'Auto Setup Is Complete⚙️' 'Tag' 'Auto Setup Is A Bunch Of Tweaks That Can Be Use For Daily Or Dont Know Anything About This Script' > nul 2>&1
pause > Nul
goto menu

:Optimize
cls
title Optimize Android
mode 100,37
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo           [%g%+%w%]Uptime: %%a %%b %%c
for /f "tokens=1 delims=:" %%i in ('adb shell dumpsys cpuinfo') do set cpucheck=%%i
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto dexopt
if "%kb%"=="2" goto fstrim
if "%kb%"=="3" goto killall
if "%kb%"=="4" goto compile
if "%kb%"=="5" goto cache
if "%kb%"=="6" goto sftmenu
if "%kb%"=="7" goto lstused
if "%kb%"=="8" goto compileall
if "%kb%"=="9" goto animspeed
if "%kb%"=="0" goto menu
goto Optimize
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
set /p ca="Choose An Option >> "
if "%ca%"=="1" set "ca_mode=everything-profile" & goto compileall_run
if "%ca%"=="2" set "ca_mode=everything"         & goto compileall_run
if "%ca%"=="3" set "ca_mode=speed"              & goto compileall_run
if "%ca%"=="4" set "ca_mode=speed-profile"      & goto compileall_run
if "%ca%"=="5" goto compileall_heaviest
if "%ca%"=="6" goto Optimize
goto compileall

:compileall_run
cls
title Compile All Apps : %ca_mode%
echo Compiling all installed packages with mode "%ca_mode%"...
echo This may take a long time. Do not unplug the device.
echo.
adb shell pm compile -a -f -m %ca_mode%
echo.
echo Running background dexopt job...
adb shell pm bg-dexopt-job
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
echo [1/3] Full compilation of all apps (--check-prof false -m everything)...
echo This may take a long time. Do not unplug the device.
adb shell pm compile -a -f --check-prof false -m everything
echo.
echo [2/3] Compiling layout resources (if supported)...
:: --compile-layouts is a STANDALONE mode: it cannot be combined with
:: -f / -m / --check-prof (doing so throws "Unknown option"). It also
:: only exists on Android 10-11 - the view compiler was removed in
:: Android 12+, and pm compile itself is gone on Android 14+ (replaced
:: by ART Service). So we run it on its own and detect non-support.
adb shell pm compile -a --compile-layouts > "%TEMP%\dcx_layouts.txt" 2>&1
findstr /I /C:"Unknown option" /C:"Error:" /C:"Usage:" "%TEMP%\dcx_layouts.txt" > nul
if errorlevel 1 (
    echo   Layout resources compiled.
) else (
    echo   [skipped] --compile-layouts is not supported on this device.
    echo   That's expected on Android 12+ - the view compiler was removed
    echo   and ART Service handles layout optimisation during normal dexopt.
)
del "%TEMP%\dcx_layouts.txt" > nul 2>&1
echo.
echo [3/3] Running background dexopt job...
adb shell pm bg-dexopt-job
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
for /f "delims=" %%i in ('adb shell settings get global window_animation_scale 2^>nul')     do echo    window_animation_scale     = %%i
for /f "delims=" %%i in ('adb shell settings get global transition_animation_scale 2^>nul') do echo    transition_animation_scale = %%i
for /f "delims=" %%i in ('adb shell settings get global animator_duration_scale 2^>nul')    do echo    animator_duration_scale    = %%i
echo.
echo                                     %g%[%w%1%g%]%w% 0     (off, instant)
echo                                     %g%[%w%2%g%]%w% 0.5   (very fast)
echo                                     %g%[%w%3%g%]%w% 0.75  (snappy, recommended)
echo                                     %g%[%w%4%g%]%w% 1.0   (default)
echo                                     %g%[%w%5%g%]%w% Custom
echo                                     %g%[%w%6%g%]%w% Back
set /p as="Choose An Option >> "
if "%as%"=="1" set "asv=0"    & goto animspeed_apply
if "%as%"=="2" set "asv=0.5"  & goto animspeed_apply
if "%as%"=="3" set "asv=0.75" & goto animspeed_apply
if "%as%"=="4" set "asv=1.0"  & goto animspeed_apply
if "%as%"=="5" goto animspeed_custom
if "%as%"=="6" goto Optimize
goto animspeed

:animspeed_custom
echo Enter a decimal value between 0 and 2 (e.g. 0.5):
set /p asv="Value >> "
goto animspeed_apply

:animspeed_apply
adb shell settings put global window_animation_scale %asv%
adb shell settings put global transition_animation_scale %asv%
adb shell settings put global animator_duration_scale %asv%
echo Done. All three animation scales set to %asv%.
pause > nul
goto animspeed

:lstused
cls
call :logo
title Clear Last Used Is Running!
for /f "tokens=2 delims=:" %%a in ('adb shell pm list package') do (
adb shell cmd usagestats clear-last-used-timestamps %%a
echo %%a ━ clear last used!
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto sf60
if "%set%"=="2" goto sf90
if "%set%"=="3" goto sf120
if "%set%"=="4" goto sf144
if "%set%"=="5" goto removesf
if "%set%"=="6" goto Optimize
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto sf60balance
if "%set%"=="2" goto sf60gaming
if "%set%"=="3" goto sf60battery
if "%set%"=="4" goto sftmenu
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay%
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay%
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %chbay%
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto sf90balance
if "%set%"=="2" goto sf90gaming
if "%set%"=="3" goto sf90battery
if "%set%"=="4" goto sftmenu
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs%
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs%
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
adb shell setprop debug.sf.high_fps_early_phase_offset_ns %xcfs%
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto sf120balance
if "%set%"=="2" goto sf120gaming
if "%set%"=="3" goto sf120battery
if "%set%"=="4" goto sftmenu
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur%
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur%
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %ltsdur%
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto sf144balance
if "%set%"=="2" goto sf144gaming
if "%set%"=="3" goto sf144battery
if "%set%"=="4" goto sftmenu
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late%
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late%
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
adb shell setprop debug.sf.high_fps_late_sf_phase_offset_ns %v144_late%
echo Done , Press Any Button To Go Back
pause > nul
goto sftmenu

:removesf
cls
title Remove SF
call :logo
echo.
echo.
echo                       [%r%!%w%] Please Restart Device To Finish The Process
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
adb shell cmd package bg-dexopt-job
echo %c%Done%w%, Press Any Button To Go Back
pause > nul
goto Optimize

:fstrim
@echo off
cls
title fstrim is running
call :logo
echo.
echo.
adb shell sm fstrim
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
set "FG_PKG="
for /f "tokens=2 delims= " %%a in ('adb shell dumpsys activity activities 2^>nul ^| findstr /C:"mResumedActivity"') do (
    if not defined FG_PKG (
        for /f "tokens=1 delims=/" %%b in ("%%a") do set "FG_PKG=%%b"
    )
)
if defined FG_PKG echo [%b%i%w%] Foreground app detected, will be skipped: %FG_PKG%
echo.
:: Critical packages we never force-stop even on third-party list
:: (some OEMs ship important apps as user-installed APKs)
set "PROTECT=com.android.systemui com.google.android.inputmethod.latin com.android.inputmethod.latin com.android.vending"
for /f "tokens=2 delims=:" %%a in ('adb shell pm list package -3') do (
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
adb shell am kill-all > nul 2>&1
echo %d%Done%w%, Press Any Button To Go Back
pause > nul
goto Optimize

:compile
@echo off
cls
title Compile App
echo.
echo.
echo Enter The Mode You Want !
echo Valid modes: speed, speed-profile, verify, quicken, everything
echo Recommended: speed (best performance, slower install)
echo.
set /p mode="Choose A Mode >> "

:: FIX: validate mode against the list ART actually accepts
set "modeok=0"
for %%m in (speed speed-profile verify quicken everything everything-profile) do (
    if /i "%mode%"=="%%m" set "modeok=1"
)
if "%modeok%"=="0" (
    echo [%r%!%w%] Invalid mode. Use one of: speed, speed-profile, verify, quicken, everything.
    pause > nul
    goto Optimize
)
set /p package="Put Your Package Name Here >> "
if "%package%"=="" (
    echo [%r%!%w%] Package name cannot be empty.
    pause > nul
    goto Optimize
)
:: Verify the package actually exists on the device
adb shell pm list packages 2>nul | findstr /C:"package:%package%" > nul
if errorlevel 1 (
    echo [%r%!%w%] Package "%package%" is not installed on the device.
    pause > nul
    goto Optimize
)
echo.
echo Compiling %package% with mode %mode%...
adb shell cmd package compile -m %mode% -f %package%
timeout /t 2 /nobreak > nul
echo Done , Press Any Button To Go Back
pause > nul
goto Optimize

:cache
mode 45,12
cls
title Clear Cache
echo [1] %c%Clear Cache%w%
echo [2] %c%Back%w%
set /p k="Choose An Option >> "
if "%k%"=="1" goto sdgb
if "%k%"=="2" goto Optimize

:sdgb
cls
title Clear App Cache
echo.
echo [1] %c%Trim system cache (no root)%w%
echo [2] %r%Wipe all app cache folders (root required)%w%
echo [3] %c%Back%w%
echo.
set /p k="Choose an option >> "
if "%k%"=="1" goto cache_trim
if "%k%"=="2" goto cache_wipe
if "%k%"=="3" goto Optimize
goto sdgb

:cache_trim
cls
echo Trimming system cache (may take a moment)...
adb shell pm trim-caches 1200G
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
echo Wiping all app cache folders...
adb shell "su -c 'for p in /data/data/*/cache; do rm -rf \$p/*; done'"
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
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo           [%g%+%w%]Uptime: %%a %%b %%c
for /f "tokens=1 delims=:" %%i in ('adb shell dumpsys cpuinfo') do set cpucheck=%%i
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
set /p set="Choose An Option >> "
if "%set%"=="1" goto saverpower
if "%set%"=="2" goto animation
if "%set%"=="3" goto autowifi
if "%set%"=="4" goto sync
if "%set%"=="5" goto motion
if "%set%"=="6" goto zram
if "%set%"=="7" goto extremepower
if "%set%"=="8" goto senderror
if "%set%"=="9" goto toggleprofilling
if "%set%"=="10" goto togglelogs
if "%set%"=="11" goto nextpage
if "%set%"=="12" goto menu

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
set /p ksd="Choose An Option >> "
if "%ksd%"=="1" goto logappsuser
if "%ksd%"=="2" goto universallogs
if "%ksd%"=="3" goto Deviceidle
if "%ksd%"=="4" goto hibernateapp
if "%ksd%"=="5" goto refreshlock
if "%ksd%"=="6" goto forcedoze
if "%ksd%"=="7" goto apphibernation
if "%ksd%"=="8" goto syncmaster
if "%ksd%"=="9" goto hotwordtoggle
if /i "%ksd%"=="A" goto wakelockaudit
if "%ksd%"=="0" goto Battery
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
set "TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TS=%TS: =0%"
set "WLREPORT=%TEMP%\dcx_wakelocks_%TS%.txt"

(
    echo ===========================================================
    echo  DCX Wake-Lock Audit - %date% %time%
    echo ===========================================================
    echo.
    echo [Section 1] Currently held wake locks
    echo  (Each entry = something keeping CPU awake right now.
    echo   PARTIAL_WAKE_LOCK is the most common battery drain.)
    echo -----------------------------------------------------------
    adb shell dumpsys power 2^>nul ^| findstr /C:"Wake Locks:" /C:"PARTIAL_WAKE_LOCK" /C:"SCREEN_BRIGHT" /C:"FULL_WAKE_LOCK"
    echo.
    echo.
    echo [Section 2] Top wake-lock holders since last full charge
    echo  (Look at "Wake lock" totals - highest = biggest drainers.)
    echo -----------------------------------------------------------
    adb shell "dumpsys batterystats --charged 2>/dev/null | head -200"
    echo.
    echo.
    echo [Section 3] Doze (deep sleep) state
    echo  (mState=IDLE means doze is active. ACTIVE = apps can run.)
    echo -----------------------------------------------------------
    adb shell dumpsys deviceidle 2^>nul ^| findstr /C:"mState=" /C:"mLightState=" /C:"mActiveIdleOpCount" /C:"mScreenOn" /C:"mCharging"
    echo.
    echo.
    echo [Section 4] Top alarms (background wakeups)
    echo -----------------------------------------------------------
    adb shell "dumpsys alarm 2>/dev/null | grep -E 'Top Alarms|wakeups in last|act=' | head -50"
    echo.
    echo.
    echo [Section 5] Process CPU consumers (last sample)
    echo -----------------------------------------------------------
    adb shell "dumpsys cpuinfo 2>/dev/null | head -25"
    echo.
    echo ===========================================================
    echo  Quick interpretation:
    echo    - PARTIAL_WAKE_LOCK in Section 1 = active drainers
    echo    - In Section 2, an app with ^>1h "Wake lock" since charge
    echo      is the prime suspect
    echo    - High wakeup count in Section 4 = app pinging too often
    echo    - If mState != IDLE while screen is off, doze is blocked
    echo ===========================================================
) > "%WLREPORT%"
echo  %g%Report saved to:%w%
echo    %WLREPORT%
echo.
echo  %b%[%w%1%b%]%w% Open in Notepad (searchable)
echo  %b%[%w%2%b%]%w% Show paginated (MORE)
echo  %b%[%w%3%b%]%w% Show summary only
echo  %b%[%w%4%b%]%w% Back
set /p wl="Choose An Option >> "
if "%wl%"=="1" (
    start "" notepad "%WLREPORT%"
    goto wakelockaudit
)
if "%wl%"=="2" (
    cls
    more "%WLREPORT%"
    echo.
    echo Press Any Button To Go Back
    pause > nul
    goto wakelockaudit
)
if "%wl%"=="3" (
    cls
    echo Currently held wake locks:
    echo.
    adb shell dumpsys power 2^>nul ^| findstr /C:"PARTIAL_WAKE_LOCK"
    echo.
    echo Doze state:
    adb shell dumpsys deviceidle 2^>nul ^| findstr /C:"mState=" /C:"mScreenOn"
    echo.
    echo Full report at: %WLREPORT%
    echo.
    pause > nul
    goto wakelockaudit
)
if "%wl%"=="4" goto nextpage
goto wakelockaudit
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
for /f "delims=" %%i in ('adb shell settings get system min_refresh_rate 2^>nul')   do echo    min_refresh_rate  = %%i Hz
for /f "delims=" %%i in ('adb shell settings get system peak_refresh_rate 2^>nul')  do echo    peak_refresh_rate = %%i Hz
echo.
echo                                     %g%[%w%1%g%]%w% Lock to 60 Hz   (battery)
echo                                     %g%[%w%2%g%]%w% Lock to 90 Hz
echo                                     %g%[%w%3%g%]%w% Lock to 120 Hz  (smooth)
echo                                     %g%[%w%4%g%]%w% Adaptive (1 to 120 Hz)
echo                                     %g%[%w%5%g%]%w% Restore defaults
echo                                     %g%[%w%6%g%]%w% Back
set /p rl="Choose An Option >> "
if "%rl%"=="1" (
    adb shell settings put system min_refresh_rate 60
    adb shell settings put system peak_refresh_rate 60
    echo Locked at 60 Hz.
    pause > nul
    goto refreshlock
)
if "%rl%"=="2" (
    adb shell settings put system min_refresh_rate 90
    adb shell settings put system peak_refresh_rate 90
    echo Locked at 90 Hz. ^(Falls back if your panel doesn't support 90.^)
    pause > nul
    goto refreshlock
)
if "%rl%"=="3" (
    adb shell settings put system min_refresh_rate 120
    adb shell settings put system peak_refresh_rate 120
    echo Locked at 120 Hz. ^(Falls back if your panel doesn't support 120.^)
    pause > nul
    goto refreshlock
)
if "%rl%"=="4" (
    adb shell settings put system min_refresh_rate 1
    adb shell settings put system peak_refresh_rate 120
    echo Adaptive 1-120 Hz.
    pause > nul
    goto refreshlock
)
if "%rl%"=="5" (
    adb shell settings delete system min_refresh_rate
    adb shell settings delete system peak_refresh_rate
    echo Defaults restored.
    pause > nul
    goto refreshlock
)
if "%rl%"=="6" goto nextpage
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
set /p fd="Choose An Option >> "
if "%fd%"=="1" (
    adb shell dumpsys deviceidle force-idle
    echo Doze forced.
    pause > nul
    goto forcedoze
)
if "%fd%"=="2" (
    adb shell dumpsys deviceidle unforce
    echo Returned to normal scheduling.
    pause > nul
    goto forcedoze
)
if "%fd%"=="3" (
    cls
    for /f "delims=" %%i in ('adb shell dumpsys deviceidle ^| findstr /C:"mState=" /C:"mLightState="') do echo   %%i
    echo.
    pause > nul
    goto forcedoze
)
if "%fd%"=="4" goto nextpage
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
for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul') do echo    app_hibernation_enabled = %%i
echo.
echo                                     %g%[%w%1%g%]%w% Enable
echo                                     %g%[%w%2%g%]%w% Disable
echo                                     %g%[%w%3%g%]%w% Back
set /p ah="Choose An Option >> "
if "%ah%"=="1" (
    adb shell device_config put app_hibernation app_hibernation_enabled true
    echo Enabled.
    pause > nul
    goto apphibernation
)
if "%ah%"=="2" (
    adb shell device_config put app_hibernation app_hibernation_enabled false
    echo Disabled.
    pause > nul
    goto apphibernation
)
if "%ah%"=="3" goto nextpage
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
for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul') do echo    master_sync_status = %%i  (1=on, 0=off)
echo.
echo                                     %g%[%w%1%g%]%w% Enable sync (default)
echo                                     %g%[%w%2%g%]%w% Disable sync (battery saver)
echo                                     %g%[%w%3%g%]%w% Back
set /p sm="Choose An Option >> "
if "%sm%"=="1" (
    adb shell settings put global master_sync_status 1
    echo Sync enabled.
    pause > nul
    goto syncmaster
)
if "%sm%"=="2" (
    adb shell settings put global master_sync_status 0
    echo Sync disabled. You will need to open apps to fetch new content.
    pause > nul
    goto syncmaster
)
if "%sm%"=="3" goto nextpage
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
for /f "delims=" %%i in ('adb shell settings get global hotword_detection_enabled 2^>nul') do echo    hotword_detection_enabled = %%i  (1=on, 0=off)
echo.
echo                                     %g%[%w%1%g%]%w% Enable hotword
echo                                     %g%[%w%2%g%]%w% Disable hotword
echo                                     %g%[%w%3%g%]%w% Back
set /p hw="Choose An Option >> "
if "%hw%"=="1" (
    adb shell settings put global hotword_detection_enabled 1
    echo Hotword enabled.
    pause > nul
    goto hotwordtoggle
)
if "%hw%"=="2" (
    adb shell settings put global hotword_detection_enabled 0
    echo Hotword disabled.
    pause > nul
    goto hotwordtoggle
)
if "%hw%"=="3" goto nextpage
goto hotwordtoggle

:hibernateapp
if "%SDK%"=="" (
    cls
    call :logo
    echo [%r%!%w%] Could not detect API level. Cannot safely continue.
    echo Press Any Button To Go Back
    pause > nul
    goto nextpage
)
if %SDK% LSS 34 (
    cls
    call :logo
    echo [%r%!%w%] Your API Level Is %SDK% , Some Adb Commands Won't Work.
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
set /p ksd="Choose An Option >> "
if "%ksd%"=="1" goto sethibdernatephs
if "%ksd%"=="2" goto stockpackage
if "%ksd%"=="3" goto nextpage

:stockpackage
cls
title Revert Your Package To Stock
call :logo
set /p pkgv2="Put Your Package Name Here >> "
echo.
echo [#] Set %pkgv2% To Stock . . . .
echo.
adb shell cmd appops reset %pkgv2%
adb shell cmd activity set-bg-restriction-level --user 0 %pkgv2% unrestricted
adb shell cmd activity set-inactive %pkgv2% false
adb shell cmd activity set-standby-bucket %pkgv2% active
adb shell cmd app_hibernation set-state %pkgv2% false
adb shell cmd dropbox remove-low-priority %pkgv2%
adb shell cmd tare set-vip 0 %pkgv2% true
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
set /p pkgv2="Put Your Package Name Here >> "
if "%pkgv2%"=="" (
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
adb shell cmd activity kill %pkgv2%
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
set /p ksd="Choose An Option >> "
if "%ksd%"=="1" goto devicesysdel
if "%ksd%"=="2" goto devicesysrev
if "%ksd%"=="3" goto nextpage

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
adb shell dumpsys deviceidle sys-whitelist | findstr /R "^[ ]*[a-zA-Z0-9_.]*,[0-9]*$" > temp.txt
for /f "tokens=1 delims=," %%A in (temp.txt) do (
    echo %%A | findstr /I "gms gsf shell ims downloads providers settings systemui inputmethod telecom telephony bluetooth dialer mms phone alarm calendar fused" > nul
    if errorlevel 1 (
        adb shell cmd deviceidle sys-whitelist -%%A
        echo Removed: %%A
    ) else (
        echo [%r%#%w%] %%A Is Protected
    )
)
del temp.txt
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
adb shell cmd deviceidle sys-whitelist reset
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
set /p ksd="Choose An Option >> "
if "%ksd%"=="1" goto offlogsuni
if "%ksd%"=="2" goto onlogsuni
if "%ksd%"=="3" goto nextpage

:offlogsuni
cls
title Universal Toggle Logs\etc : Off
call :logo
for /f "tokens=1 delims=:" %%a in ('adb shell getprop ^| findstr "log.tag"') do (
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
echo                       [%r%!%w%] Please Restart Device To Finish The Process
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
set /p ksd="Choose An Option >> "
if "%ksd%"=="1" goto offlogsuserapp
if "%ksd%"=="2" goto onlogsuserapp
if "%ksd%"=="3" goto nextpage

:offlogsuserapp
cls
title Log For User Apps : Off
call :logo
for /f "tokens=2 delims=:" %%a in ('adb shell pm list package') do (
adb shell cmd package log-visibility --disable %%a > nul 2>&1
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
for /f "tokens=2 delims=:" %%a in ('adb shell pm list package') do (
adb shell cmd package log-visibility --enable %%a > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offlogss
if "%toggle%"=="2" goto onlogss
if "%toggle%"=="3" goto Battery
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
set /p conx="Choose An Option >> "
if "%conx%"=="1" goto skiplogv
if "%conx%"=="2" goto mainlogv
if "%conx%"=="3" goto Battery

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

:endofflogs
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
adb shell settings put global battery_stats_constants track_cpu_times_by_proc_state=false
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
adb shell device_config put odad enable_fa_stats_log_logging false
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
adb shell logcat -c
echo.
echo.
echo [%r%!%w%] Please Restart Device To Finish The Process
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offsv
if "%toggle%"=="2" goto onsv
if "%toggle%"=="3" goto Battery
:: guard against invalid input
goto saverpower

:offsv
@echo off
cls
title Power Saver : Off
adb shell settings delete global low_power 
adb shell settings delete global low_power_sticky
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsv
@echo off
cls
title Power Saver : On
adb shell settings put global low_power 1
adb shell settings put global low_power_sticky 0
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offani
if "%toggle%"=="2" goto onani
if "%toggle%"=="3" goto Battery
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
adb shell settings put global disable_window_blurs 1
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
adb shell device_config delete battery_saver reduce_animations > nul 2>&1
echo.
echo.
echo [%r%!%w%] Please Restart Device To Finish The Process
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offaut
if "%toggle%"=="2" goto onaut
if "%toggle%"=="3" goto Battery
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
adb shell settings put global wifi_watchdog_poor_network_test_enabled 0 > nul 2>&1
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
adb shell settings delete global wifi_watchdog_poor_network_test_enabled > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offsync
if "%toggle%"=="2" goto onsync
if "%toggle%"=="3" goto Battery
:: guard against invalid input
goto sync

:offsync
@echo off
cls
title Sync : Off
adb shell settings put global auto_sync 0
adb shell settings put global master_sync_enabled 0
adb shell device_config set_sync_disabled_for_tests persistent > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsync
@echo off
cls
title Sync : On
adb shell settings put global auto_sync 1
adb shell settings put global master_sync_enabled 1
adb shell device_config set_sync_disabled_for_tests none > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offmotion
if "%toggle%"=="2" goto onmotion
if "%toggle%"=="3" goto Battery
:: guard against invalid input
goto motion

:offmotion
@echo off
cls
title Motion : Off
adb shell settings put system master_motion 0 > nul 2>&1
adb shell settings put system motion_engine 0 > nul 2>&1
adb shell settings put system air_motion_engine 0 > nul 2>&1
adb shell settings put system air_motion_wake_up 0 > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onmotion
@echo off
cls
title Motion : On
adb shell settings remove system master_motion > nul 2>&1
adb shell settings remove system motion_engine > nul 2>&1
adb shell settings remove system air_motion_engine > nul 2>&1
adb shell settings remove system air_motion_wake_up > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offzram
if "%toggle%"=="2" goto onzram
if "%toggle%"=="3" goto Battery
:: guard against invalid input
goto zram

:offzram
@echo off
cls
title ZRAM : Off
adb shell settings put global zram 0
adb shell settings put global zram_enabled 0
echo Press Any Button To Go Back
pause > nul
goto Battery

:onzram
@echo off
cls
title ZRAM : On
adb shell settings put global zram 1
adb shell settings put global zram_enabled 1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offsvpp
if "%toggle%"=="2" goto onsvpp
if "%toggle%"=="3" goto Battery
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
echo.
echo.
echo [%r%!%w%] Please Restart Device To Finish The Process
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
adb shell cmd battery reset
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
adb shell setprop debug.force_low_ram true
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offerr
if "%toggle%"=="2" goto onerr
if "%toggle%"=="3" goto Battery
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
adb shell settings put secure USAGE_METRICS_UPLOAD_ENABLED 0 > nul 2>&1
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
adb shell settings delete secure USAGE_METRICS_UPLOAD_ENABLED > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offprof
if "%toggle%"=="2" goto onprof
if "%toggle%"=="3" goto Battery
:: guard against invalid input
goto toggleprofilling

:offprof
cls
title Lock Profiling : Off
adb shell device_config put runtime_native_boot disable_lock_profiling true
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:onprof
cls
title Lock Profiling : ON
adb shell device_config put runtime_native_boot disable_lock_profiling false
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
for /f "tokens=3,4,5,6,7 delims= " %%a in ('adb shell uptime') do echo           [%g%+%w%]Uptime: %%a %%b %%c
for /f "tokens=1 delims=:" %%i in ('adb shell dumpsys cpuinfo') do set cpucheck=%%i
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
echo                                     %r%[%w%9%r%]%w% Back
set /p game="Choose An Option >> "
if "%game%"=="1" goto gms
if "%game%"=="2" goto thermal
if "%game%"=="3" goto package
if "%game%"=="4" goto overlay
if "%game%"=="5" goto performance
if "%game%"=="6" goto netboost
if "%game%"=="7" goto gpurenderer
if "%game%"=="8" goto angleall
if "%game%"=="9" goto menu
:: FIX: invalid input previously fell into :gms
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
for /f "delims=" %%i in ('adb shell getprop debug.hwui.renderer 2^>nul') do echo    debug.hwui.renderer = "%%i"
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
set /p gpur="Choose An Option >> "
if "%gpur%"=="1" goto gpurenderer_vk
if "%gpur%"=="2" goto gpurenderer_gl
if "%gpur%"=="3" goto gpurenderer_clear
if "%gpur%"=="4" goto Gaming
goto gpurenderer

:gpurenderer_vk
cls
title GPU Renderer : Skia Vulkan
adb shell setprop debug.hwui.renderer skiavk
adb shell setprop debug.renderengine.backend skiavkthreaded
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
adb shell setprop debug.renderengine.backend skiaglthreaded
echo Renderer set to skiagl (Skia + OpenGL ES, default).
pause > nul
goto gpurenderer

:gpurenderer_clear
cls
title GPU Renderer : Clear
:: An empty value makes Android fall back to the framework default
adb shell setprop debug.hwui.renderer ""
adb shell setprop debug.renderengine.backend ""
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
for /f "delims=" %%i in ('adb shell settings get global angle_gl_driver_all_angle 2^>nul') do echo    angle_gl_driver_all_angle = %%i  (1=ON, 0=OFF, null=default)
echo.
echo  Forces every GLES app to load through ANGLE (which renders on
echo  top of Vulkan). On Android 13+ with a Vulkan-capable GPU this
echo  typically gives more stable frame pacing for older games.
echo.
echo    Setting persists across reboots.
echo.
echo                                     %g%[%w%1%g%]%w% Enable  (ANGLE for all apps)
echo                                     %g%[%w%2%g%]%w% Disable (native driver)
echo                                     %g%[%w%3%g%]%w% Delete setting (Android default)
echo                                     %g%[%w%4%g%]%w% Back
set /p ang="Choose An Option >> "
if "%ang%"=="1" goto angleall_on
if "%ang%"=="2" goto angleall_off
if "%ang%"=="3" goto angleall_del
if "%ang%"=="4" goto Gaming
goto angleall

:angleall_on
cls
title ANGLE for All Apps : ON
adb shell settings put global angle_gl_driver_all_angle 1
echo Done. ANGLE is now enabled for all GLES apps.
echo If a specific game glitches, return here and disable.
pause > nul
goto angleall

:angleall_off
cls
title ANGLE for All Apps : OFF
adb shell settings put global angle_gl_driver_all_angle 0
echo Done. Native GLES driver in use.
pause > nul
goto angleall

:angleall_del
cls
title ANGLE for All Apps : Delete (default)
adb shell settings delete global angle_gl_driver_all_angle
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
echo  Tunes TCP buffer sizes and DNS for lower latency in online games.
echo  Reverting is safe (option 4 deletes all added settings).
echo.
echo                                     %g%[%w%1%g%]%w% Apply Network Boost
echo                                     %g%[%w%2%g%]%w% Set Cloudflare DNS (1.1.1.1)
echo                                     %g%[%w%3%g%]%w% Preferred network mode
echo                                     %g%[%w%4%g%]%w% Revert (remove all)
echo                                     %g%[%w%5%g%]%w% Back
set /p nb="Choose An Option >> "
if "%nb%"=="1" goto netboost_apply
if "%nb%"=="2" goto netboost_dns
if "%nb%"=="3" goto netboost_prefmode
if "%nb%"=="4" goto netboost_revert
if "%nb%"=="5" goto Gaming
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
:: -----------------------------------------------------------------
:netboost_prefmode
cls
title Network Boost : Preferred mode
call :logo
echo  Current preferred_network_mode:
for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul') do echo    %%i
echo.
echo                                     %g%[%w%1%g%]%w% LTE preferred (9)  -^> fall back 3G/2G
echo                                     %g%[%w%2%g%]%w% LTE only (12)
echo                                     %g%[%w%3%g%]%w% 5G preferred (20)  -^> fall back LTE/3G
echo                                     %g%[%w%4%g%]%w% Restore default (delete)
echo                                     %g%[%w%5%g%]%w% Back
set /p pm="Choose An Option >> "
if "%pm%"=="1" (
    adb shell settings put global preferred_network_mode 9
    adb shell settings put global preferred_network_mode1 9
    echo Set to LTE preferred.
    pause > nul
    goto netboost_prefmode
)
if "%pm%"=="2" (
    adb shell settings put global preferred_network_mode 12
    adb shell settings put global preferred_network_mode1 12
    echo Set to LTE only. WARNING: voice calls only work if VoLTE is active.
    pause > nul
    goto netboost_prefmode
)
if "%pm%"=="3" (
    adb shell settings put global preferred_network_mode 20
    adb shell settings put global preferred_network_mode1 20
    echo Set to 5G preferred.
    pause > nul
    goto netboost_prefmode
)
if "%pm%"=="4" (
    adb shell settings delete global preferred_network_mode
    adb shell settings delete global preferred_network_mode1
    echo Default restored.
    pause > nul
    goto netboost_prefmode
)
if "%pm%"=="5" goto netboost
goto netboost_prefmode

:netboost_apply
cls
title Network Boost : Apply
echo Applying TCP buffer tuning...
:: Larger TCP buffers reduce stalls on Wi-Fi / 4G / 5G.
:: tcp_rmem and tcp_wmem are 'min default max' in bytes.
adb shell "settings put global tcp_default_init_rwnd 60" > nul 2>&1
adb shell "settings put global tether_offload_disabled 0" > nul 2>&1
adb shell "settings put global mobile_data_always_on 1" > nul 2>&1
adb shell "settings put global wifi_idle_ms 7200000" > nul 2>&1
adb shell "settings put global wifi_suspend_optimizations_enabled 0" > nul 2>&1
:: Power-related: keep Wi-Fi alive during screen-off briefly so
:: matchmaking sockets don't reconnect every time the screen blinks.
adb shell "settings put global wifi_sleep_policy 2" > nul 2>&1
echo Done.
echo.
echo [%r%!%w%] A reboot helps the kernel pick up the new buffer sizes.
pause > nul
goto netboost

:netboost_dns
cls
title Network Boost : DNS
echo Setting private DNS to Cloudflare (1.1.1.1 / one.one.one.one)...
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier one.one.one.one
echo.
echo  To use Google DNS instead, run manually:
echo    settings put global private_dns_specifier dns.google
echo  Or for AdGuard DNS (no ads):
echo    settings put global private_dns_specifier dns.adguard.com
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
adb shell settings delete global preferred_network_mode1 > nul 2>&1
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
set /p toggle="Choose An Option >> "
if "%toggle%"=="1" goto offgms
if "%toggle%"=="2" goto ongms
if "%toggle%"=="3" goto Gaming
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
adb shell am set-standby-bucket --user 0 com.google.android.gms never
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
adb shell am set-standby-bucket --user 0 com.google.android.gms active
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto settingthermal
if "%kb%"=="2" goto Gaming

:settingthermal
@echo off
cls
echo Put A Number Between 0 To 6 To Change
echo How Thermal Service Work!
echo.
echo  0 = NONE     (no throttling)
echo  1 = LIGHT
echo  2 = MODERATE
echo  3 = SEVERE
echo  4 = CRITICAL
echo  5 = EMERGENCY
echo  6 = SHUTDOWN (do not use)
echo.
set /p kb=">> "
:: FIX: validate input - previously any garbage was accepted
set "valid=0"
for %%v in (0 1 2 3 4 5 6) do if "%kb%"=="%%v" set "valid=1"
if "%valid%"=="0" (
    echo [%r%!%w%] Invalid value. Must be a number between 0 and 6.
    timeout /t 2 /nobreak > nul
    goto thermal
)
cls
adb shell cmd thermalservice override-status %kb%
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto offpck
if "%kb%"=="2" goto onpck
if "%kb%"=="3" goto Gaming
:: guard against invalid input
goto package

:offpck
@echo off
cls
title Package Verifier : Off
adb shell settings put global package_verifier_enable 0
echo Press Any Button To Go Back
pause > nul
goto Gaming

:onpck
@echo off
cls
title Package Verifier : On
adb shell settings put global package_verifier_enable 1
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto removeset
if "%kb%"=="2" goto low
if "%kb%"=="3" goto med
if "%kb%"=="4" goto Gaming
:: guard against invalid input
goto overlay

:removeset
cls
title Remove Settings
set /p package="Put Your Package Name Here >> "
adb shell device_config delete game_overlay %package% > nul
adb shell cmd game reset --user 0 %package%
cls
echo.
echo.
echo [%r%!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again. 
echo.
echo.
echo %package% Settings Is Removed , Press Any Button To Go Back 
pause > nul 
goto Gaming

:low
@echo off
cls
title Low Settings
set /p package="Put Your Package Name Here >> "
adb shell device_config put game_overlay %package% mode=1
adb shell cmd game downscale 0.55 %package%
cls
echo.
echo.
echo [%r%!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again. 
echo.
echo.
echo Press Any Button To Go Back
pause > nul
goto Gaming

:med
@echo off
cls
title Medium Settings
set /p package="Put Your Package Name Here >> "
adb shell device_config put game_overlay %package% mode=1
adb shell device_config get game_overlay %package%
adb shell cmd game downscale 0.75 %package%
cls
echo.
echo.
echo [%r%!%w%] If %package% Is Glitching , Please Clear %package% Cache And Try it again. 
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
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto toggleperf
if "%kb%"=="2" goto Gaming

:toggleperf
cls
title Performance Mode
echo.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set /p kb="Choose An Option >> "
if "%kb%"=="1" goto offperf
if "%kb%"=="2" goto onperf
if "%kb%"=="3" goto Gaming
:: guard against invalid input
goto toggleperf

:offperf
@echo off
cls
title Performance Mode : Off
:: Check the key and save the value to a temporary file.
adb shell device_config get storage_native_boot target_dirty_ratio > reset_temp_result.txt
:: Retrieve and process the value.
set /p resultrs=<reset_temp_result.txt
if "%resultrs%"=="null" goto skipdeviceconfigandremove
if "%resultrs%"=="" goto skipdeviceconfigandremove
set resultrs=80
adb shell device_config put storage_native_boot target_dirty_ratio %resultrs%

:skipdeviceconfigandremove
del reset_temp_result.txt 2>nul
adb shell logcat -G 256kb
adb shell settings delete global activity_manager_constants > nul 2>&1
adb shell device_config put runtime_native_boot iorap_readahead_enable false > nul 2>&1
adb shell device_config delete surface_flinger_native_boot max_frame_buffer_acquired_buffers > nul 2>&1
adb shell device_config delete surface_flinger_native_boot adpf_cpu_hint > nul 2>&1
echo.
echo.
echo [%r%!%w%] Please Restart Device To Finish The Process
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
echo [%r%!%w%] All Powersaving Is Disabled
echo [%r%!%w%] If You Want To Enable Power Saver Again, You Need To Disable Performance Mode
echo [%r%!%w%] And Enable Power Saver Mode In Battery Mode
::disable powersaver
adb shell cmd power set-mode 0 > nul 2>&1
adb shell cmd thermalservice override-status 0
adb shell settings put global low_power 0
if "%SDK%"=="" (
    adb shell settings put global device_idle_constants inactive_to=300000 >nul
) else if %SDK% GEQ 31 (
    adb shell device_config put device_idle inactive_to 300000 >nul
) else (
    adb shell settings put global device_idle_constants inactive_to=300000 >nul
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
:: Check the key and save the value to a temporary file.
adb shell device_config get storage_native_boot target_dirty_ratio > temp_result.txt
:: Retrieve the value from the temporary file and store it in the variable `result`.
set /p result=<temp_result.txt
:: Check values ​​and process
if "%result%"=="null" (
    echo storage_native_boot/target_dirty_ratio is not detected.
    set "result="
) else if "%result%"=="" (
    echo storage_native_boot/target_dirty_ratio is not detected.
    set "result="
) else (
    echo Detected key storage_native_boot/target_dirty_ratio: %result%
)
:: Delete temporary files
del temp_result.txt
:: Check if the result is valid before performing the calculation.
if not defined result (
    goto skipcheckdeviceconfig
)
set /a aducsa=%result%+10
echo storage_native_boot/target_dirty_ratio : %aducsa%
adb shell device_config put storage_native_boot target_dirty_ratio %aducsa%

:skipcheckdeviceconfig
echo Press Any Button To Go Back
pause > nul
goto Gaming

:logo
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
