@echo off
:: Capture DCX's folder with delayed expansion off so an exclamation mark in it survives; from
:: here on it is read late as DCX_DIR. The outer setlocal keeps DCX_DIR out of the caller.
setlocal DisableDelayedExpansion
set "DCX_DIR=%~dp0"
:: The profile folders are captured the same way. Every path under the profile follows three rules
:: so any character in a user name survives, TEMP included:
::  - use it as a late read, never a percent read: that pastes it in before cmd splits commands;
::  - pass a file to a routine by the NAME of its variable, not as an argument: call re-parses it;
::  - a for /f or cmd /c child names the variable, percent doubled, and reads it from its env.
set "BACKUPDIR=%USERPROFILE%\dcx_backups"
set "SNAPDIR=%USERPROFILE%\dcx_snapshots"
set "PROFDIR=%USERPROFILE%\dcx_profiles"
set "PERFDIR=%USERPROFILE%\dcx_perf"
set "LOGDIR=%USERPROFILE%\dcx_logs"
:: DCX's own path: the command library reads its ::LIB~ lines from this file.
set "DCX_SELF=%~f0"
:: The console's code page before DCX switches it, digits only; every exit path puts it back.
set "DCX_CPSTART="
for /f "tokens=2 delims=:." %%a in ('chcp') do for /f %%b in ("%%a") do set "DCX_CPSTART=%%b"
setlocal EnableDelayedExpansion
if defined DCX_CPSTART for /f "eol=0 delims=0123456789" %%c in ("!DCX_CPSTART!") do set "DCX_CPSTART="
chcp 65001 > nul
mode 100,37
title DCX Menu
:: ESC and colour codes must be defined before anything prints in colour.
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
:: Use the adb folder next to DCX.bat: an admin or shortcut start begins in another directory.
if exist "!DCX_DIR!adb\" cd /d "!DCX_DIR!adb"
:: Put the adb folder on PATH: NoDefaultCurrentDirectoryInExePath=1 stops the current-dir search.
:: CD and PATH are read late so an exclamation mark in them survives. A folder holding a ; goes
:: on quoted, since ; separates PATH entries and cmd reads a quoted entry as one.
if exist adb.exe if "!CD:;=!"=="!CD!" set "PATH=!CD!;!PATH!"
if exist adb.exe if not "!CD:;=!"=="!CD!" set "PATH="!CD!";!PATH!"
:: Verify ADB is available
adb version > nul 2>&1
if %errorlevel% neq 0 (
    echo [%r%^^!%w%] ADB not found^^!
    echo     Please install ADB and ensure it is in your PATH
    echo     or place this script next to an 'adb' folder.
    echo.
    echo Press any key to exit...
    pause > nul
    call :_cp_restore
    exit /b
)
:: Each window keeps scratch files in its own folder, dcx_ID under TEMP, removed by :_tmp_cleanup.
:: mkdir is the reservation. RANDOM only proposes the ID - windows started in the same second draw
:: the same one - so a taken ID is skipped, up to 100 times; an unwritable TEMP stops it at once.
set "DCX_SID="
set "_sid_n=0"

:_sid_new
set /a _sid_n+=1
set "DCX_SID=!RANDOM!"
mkdir "!TEMP!\dcx_!DCX_SID!" >nul 2>&1 && goto _sid_done
if !_sid_n! LSS 100 if exist "!TEMP!\dcx_!DCX_SID!" goto _sid_new

:_sid_done
set "DCX_TMP=!TEMP!\dcx_!DCX_SID!"
:: Full path of the adb.exe in use: generated backup and undo files embed it, as they run elsewhere.
call :_resolve_adb
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
:: Wait for an authorised device before any adb shell call.
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
        rem No adb kill-server here: the adb server is shared with anything else using adb.
        call :_tmp_cleanup
        exit /b
    )
    if errorlevel 2 goto startup_wait
    rem Wireless path skips the probe: safe SDK/MODEL defaults; :wadb_back re-runs :detect_device.
    set "SDK=0"
    set "MODEL=(not connected yet)"
    goto wirelessadb
)
rem  Pick the target device before any adb shell runs: with two attached, every call would fail.
call :pick_device
rem  Must jump over :pick_device: falling into it runs its exit /b at top level and ends the script.
goto detect_device

:pick_device
:: Sets ANDROID_SERIAL, which every later adb call inherits, asking when more than one device is
:: attached - Enable over USB lists the same phone twice. Returns 1 when nothing is attached.
:: Clear the last run's arrays first so a stale entry cannot outlive its list.
for /f "delims==" %%v in ('set _pd_s[ 2^>nul') do set "%%v="
for /f "delims==" %%v in ('set _pd_d[ 2^>nul') do set "%%v="
set "_pd_n=0"
for /f "skip=1 tokens=1,2,*" %%a in ('adb devices -l ^<nul 2^>nul') do (
    if "%%b"=="device" (
        set /a _pd_n+=1
        set "_pd_s[!_pd_n!]=%%a"
        set "_pd_d[!_pd_n!]=%%c"
    )
)
if "%_pd_n%"=="0" (
    set "ANDROID_SERIAL="
    exit /b 1
)
if "%_pd_n%"=="1" (
    set "ANDROID_SERIAL=!_pd_s[1]!"
    exit /b 0
)

:_pd_ask
cls
call :logo
echo.
echo  %y%More than one device is attached.%w% adb cannot guess which one you mean, so
echo  pick the target - everything DCX does from here goes to it.
echo.
for /l %%i in (1,1,%_pd_n%) do call :_pd_row %%i
echo.
echo  If one entry is USB and another is Wi-Fi with the same model, that is the SAME
echo  phone reached two ways - either works, and "Enable over USB" leaves it like this.
echo.
set "_pd_c=" & set /p _pd_c="Device number >> "
call :_noin _pd_c || goto dcx_noinput
if not defined _pd_c goto _pd_ask
:: safechk first: it rejects shell metacharacters before the findstr pipe below can re-parse them.
call :_tw_safechk _pd_c || goto _pd_ask
echo(!_pd_c!| findstr /r /x /c:"[0-9][0-9]*" >nul || goto _pd_ask
if !_pd_c! LSS 1 goto _pd_ask
:: Require the entry itself: 01 passes the checks above, but _pd_s[01] does not exist and would
:: blank ANDROID_SERIAL. Do not use set /a here: it reads a leading zero as octal.
if not defined _pd_s[!_pd_c!] goto _pd_ask
if !_pd_c! GTR %_pd_n% goto _pd_ask
set "ANDROID_SERIAL=!_pd_s[%_pd_c%]!"
if not defined ANDROID_SERIAL goto _pd_ask
echo.
echo  [%g%+%w%] Targeting !ANDROID_SERIAL!
timeout /t 1 /nobreak > nul
exit /b 0

:_hdr_via
:: Sets _hdr_suffix to via USB or via Wi-Fi when a target is pinned, empty otherwise.
set "_hdr_suffix="
if not defined ANDROID_SERIAL exit /b
set "_hdr_suffix=   via USB"
call :_wifi_ser ANDROID_SERIAL && set "_hdr_suffix=   via Wi-Fi"
exit /b

:_pd_row
:: %1 = index. Labels the transport so a USB/Wi-Fi pair of the same phone is obvious.
set "_pd_i=%~1"
set "_pd_via=USB  "
:: Wi-Fi when the serial holds a colon, tested in this shell: a findstr pipe re-parses phone text.
set "_pd_x=!_pd_s[%_pd_i%]!"
call :_wifi_ser _pd_x && set "_pd_via=Wi-Fi"
echo     %g%[%w%%_pd_i%%g%]%w% !_pd_via!  !_pd_s[%_pd_i%]!   !_pd_d[%_pd_i%]!
exit /b

:detect_device
:: Retrieve the current Android API level safely
set "SDK="
for /f "delims=" %%i in ('adb shell getprop ro.build.version.sdk 2^>nul ^<nul') do set "SDK=%%i"
:: getprop prints the phone's text: read it late, never with a percent read. SDK is then held to
:: digits, because many lines compare it unquoted. Keeping three characters drops a trailing CR.
if defined SDK set "SDK=!SDK:~0,3!"
if defined SDK for /f "tokens=* delims= " %%a in ("!SDK!") do set "SDK=%%a"
if defined SDK set "SDK=!SDK: =!"
set "_sdkbad="
if defined SDK for /f "eol=0 delims=0123456789" %%c in ("!SDK!") do set "_sdkbad=1"
if defined _sdkbad set "SDK="
:: A failed or non-numeric read becomes 0, so the unquoted numeric compares never break.
if not defined SDK set "SDK=0"
:: The model is read and printed by :_dd_line. A late read keeps a trailing CR that makes the text
:: overwrite the line; a for /f over the quoted value drops it. Display-only captures use that trim.
call :_hdr_via
call :_dd_line
call :_ra_startup
timeout /t 1 /nobreak > nul
goto menu

:_dd_line
:: Prints the device line. MODEL is local to this routine - nothing else reads it.
:: Read with delayed expansion off and no eol, so an exclamation mark or a leading ; survives.
:: The inner for /f trims a trailing CR.
setlocal DisableDelayedExpansion
set "MODEL="
for /f delims^=^ eol^= %%i in ('adb shell getprop ro.product.model 2^>nul ^<nul') do for /f delims^=^ eol^= %%j in ("%%i") do set "MODEL=%%j"
setlocal EnableDelayedExpansion
echo [%g%+%w%] Device: !MODEL!   API level: !SDK!!_hdr_suffix!
endlocal
endlocal
exit /b

:menu
cls
title Main Menu
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
call :_uptime
if defined _upt echo           [%g%+%w%]Uptime: !_upt!
:: Read cpucheck late, never with a percent read: dumpsys prints the phone's text.
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
for /f "delims=" %%a in ("!cpucheck!") do set "cpucheck=%%a"
echo           [%g%+%w%]!cpucheck! LOAD
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
echo                           %b%Reboot%w%          %b%Exit%w%       %b%Shell ^& Tools%w%
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
:: Empty or invalid input re-prompts without a redraw, so a phantom empty line cannot re-run probes.
set "kb=" & set /p kb="                            Choose An Option >> "
call :_noin kb || goto dcx_noinput
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
:: Backup / Restore: Backup writes the current value of every DCX-managed key into a stand-alone,
:: editable .bat in dcx_backups. Restore calls it, checks its exit code and that the device stayed.
:: ===================================================================
:backup
cls
title Backup Settings
call :logo
echo.
:: Refuse unless the device is attached now: the startup check does not cover a long session.
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
if not exist "!BACKUPDIR!" mkdir "!BACKUPDIR!"
:: Filename-safe timestamp from date and time; no PowerShell, which would reset the code page.
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "BAKFILE=!BACKUPDIR!\dcx_backup_%TS%.bat"
echo  Saving current settings to:
echo    !BAKFILE!
echo.
:: Build the restore script: each captured value becomes a put or setprop line, unset a delete.
:: In the block below a literal close paren takes one caret; two leave it bare and end the block.
call :_bk_write_adb_boot BAKFILE
(
    echo :: DCX Settings Backup created %date% %time%
    echo :: Stand-alone restore - same device connected. Edit to skip keys.
    echo :: Labels BEFORE :dcx_main so restore lines stay in :dcx_main.
    echo :: Every restore line goes through :dcx_do ^(counts OK/FAIL^).
    echo goto :dcx_main
    echo.
    echo :dcx_do
    echo :: Runs one restore command and records whether it landed. Uses %%ADB%%
    echo :: from the header ^(not bare adb - this file is not next to adb\^).
    echo :: The command arrives in DCX_CMD rather than as an argument: CALL re-expands its
    echo :: arguments, and that second parse used to eat the phone's own values - a ringtone
    echo :: URI's %%%%20 became this file's empty second argument ^(Over%%%%20the%%%%20Horizon
    echo :: restored as Over0the0Horizon^) and a ^^ came back doubled.
    echo if defined DCX_CMD goto :dcx_do_run
    echo echo   [FAIL] a restore line is missing its command - this file may be truncated
    echo set /a DCX_FAIL+=1
    echo goto :eof
    echo :dcx_do_run
    echo "%%ADB%%" shell "%%DCX_CMD%%" ^>nul 2^>^&1
    echo set "DCX_RC=%%errorlevel%%"
    echo if not "%%DCX_RC%%"=="0" goto :dcx_do_fail
    echo set /a DCX_OK+=1
    echo set "DCX_CMD="
    echo goto :eof
    echo :dcx_do_fail
    echo set /a DCX_FAIL+=1
    echo echo   [FAIL] "%%DCX_CMD%%"
    echo set "DCX_CMD="
    echo goto :eof
    echo.
    echo :dcx_hold
    echo if defined DCX_CP0 chcp %%DCX_CP0%% ^>nul 2^>^&1
    echo if defined DCX_NOPAUSE exit /b 0
    echo echo.
    echo echo ----------------------------------------
    echo echo Press any key to close this window . . .
    echo pause
    echo exit /b 0
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
    echo call :dcx_hold
    echo exit /b %%DCX_FAIL%%
    echo.
    echo :dcx_main
    echo echo Restoring DCX-managed settings...
    echo set "DCX_OK=0" ^& set "DCX_FAIL=0"
) >> "!BAKFILE!" < nul
:: Capture every managed key into the file.
call :_bk_capture_all BAKFILE
:: Close :dcx_main. The helpers sit above :dcx_main, so this append stays inside the restore body.
>>"!BAKFILE!" echo goto :dcx_report
:: Require a real restore line, not just a file: a blocked folder makes every append fail silently.
set "_bkok=0"
if exist "!BAKFILE!" findstr /b /c:"call :dcx_do" "!BAKFILE!" >nul 2>&1 && set "_bkok=1"
if "%_bkok%"=="0" (
    echo  %r%Backup FAILED%w% - no usable restore file was written.
    echo    Tried: !BAKFILE!
    echo.
    echo  That folder is often blocked by antivirus or Controlled Folder Access.
    echo  Allow it, or run DCX from another location, then try again.
    echo.
    pause > nul
    goto menu
)
:: Count captured and skipped keys, so a backup taken through a connection drop is reported partial.
set "_bkn=0" & set "_bks=0"
:: The for /f child reads BAKFILE from its environment; the path itself would be expanded again.
for /f %%n in ('findstr /b /x /c:"call :dcx_do" "%%BAKFILE%%" 2^>nul ^| find /c /v ""') do set "_bkn=%%n"
for /f %%n in ('findstr /b /c:":: DCX_SKIP" "%%BAKFILE%%" 2^>nul ^| find /c /v ""') do set "_bks=%%n"
if not "%_bks%"=="0" goto _backup_partial
echo  %g%Backup complete.%w% %_bkn% values captured.
echo    !BAKFILE!
goto _backup_saved

:_backup_partial
echo  %y%Backup saved, but incomplete.%w% Captured %_bkn%, skipped %_bks%.
echo    !BAKFILE!
echo.
echo  A key is skipped either because the device did not answer for it - a Wi-Fi ADB
echo  drop, or the settings service still coming up after a reboot - or because its
echo  value holds a double quote, which no .bat line can carry. The file says which
echo  for each one: search it for DCX_SKIP.
echo.
echo  Skipped keys are simply absent, so a restore leaves them exactly as they are;
echo  it will not delete them. If the cause was a dropped connection, re-running
echo  Backup with the phone settled gives a complete file.

:_backup_saved
>"!BACKUPDIR!\dcx_last_backup.txt" echo !BAKFILE!
echo.
if defined DCX_ADB (
    echo  %y%Note:%w% restore .bat embeds adb path:
    echo    !DCX_ADB!
    echo  It will also try PATH / dcx_adb_path.txt. Double-clicking from
    echo  Explorer does NOT use DCX's local adb\ folder automatically.
) else (
    echo  %y%Warning:%w% could not embed a full adb path. Put platform-tools on
    echo  PATH before running the restore .bat outside DCX.
)
echo.
echo  %b%[%w%1%b%]%w% Open backups folder in Explorer
echo  %b%[%w%2%b%]%w% View this backup in Notepad
echo  %b%[%w%3%b%]%w% Back to main menu
set "bk=" & set /p bk="Choose An Option >> "
call :_noin bk || goto dcx_noinput
if "!bk!"=="1" (
    start "" "!BACKUPDIR!"
    goto menu
)
if "!bk!"=="2" (
    start "" notepad "!BAKFILE!"
    goto menu
)
goto menu
:: ===========================================================================
:: Helpers used by :backup. _resolve_adb / _bk_write_adb_boot: backup and undo files live in
:: dcx_backups, away from the adb folder, so they embed the full adb.exe path or fail loudly.
:_resolve_adb
:: Sets DCX_ADB. Found with delayed expansion off so an exclamation mark in the path survives.
:: Only a path holding one is escaped for the delayed pass of the endlocal hand-over: a line
:: without one skips that pass, so escaping every path would leave its carets doubled.
setlocal DisableDelayedExpansion
set "_ra="
for /f "delims=" %%A in ('where adb 2^>nul') do if not defined _ra set "_ra=%%~fA"
if not defined _ra for %%A in (adb.exe) do set "_ra=%%~fA"
if defined _ra if not exist "%_ra%" set "_ra="
:: Own line: a substitution read of an undefined _ra breaks the parse of its whole line, guard too.
if not defined _ra goto _resolve_adb_done
set "_rab="
if not "%_ra:!=%"=="%_ra%" set "_rab=1"
if defined _rab set "_ra=%_ra:^=^^%"
if defined _rab set "_ra=%_ra:!=^!%"

:_resolve_adb_done
endlocal & set "DCX_ADB=%_ra%"
if not exist "!BACKUPDIR!" mkdir "!BACKUPDIR!"
if defined DCX_ADB >"!BACKUPDIR!\dcx_adb_path.txt" echo !DCX_ADB!
exit /b 0

:_bk_write_adb_boot
:: Arg 1 = NAME of the variable holding the output file, never the path: call would re-parse it.
:: Overwrites the file with @echo off, the adb locator and start-server, echoed with delayed
:: expansion off. Generated files accept /nopause so DCX can run them without a hold at the end.
setlocal EnableDelayedExpansion
set "OUT=!%~1!"
:: The phone's own serial too: the connection name differs between USB and Wi-Fi.
call :_phone_sn
setlocal DisableDelayedExpansion
set "BAKED=%DCX_ADB%"
:: Record which device this file came from, so a restore refuses to apply it to another phone.
set "_bkser="
for /f "delims=" %%s in ('adb get-serialno 2^>nul') do set "_bkser=%%s"
:: The serial is phone text, percent-read in the block below and parsed again by the .bat: only
:: letters, digits and . : - _ [ ] pass. Otherwise the file goes untagged; screen and file say so.
setlocal EnableDelayedExpansion
set "_bkbad="
if defined _bkser for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:-_[]" %%c in ("!_bkser!") do set "_bkbad=1"
:: Double each percent sign in the adb path: the generated file expands percent pairs when it runs.
:: The file's Using adb line quotes the path, so an ampersand in the folder cannot split that echo.
if defined BAKED set "BAKED=!BAKED:%%=%%%%!"
endlocal & set "_bkbad=%_bkbad%" & set "BAKED=%BAKED%"
if defined _bkbad set "_bkser="
if defined _bkbad echo  [%y%WARN%w%] This device's serial holds characters DCX will not write into a .bat file,
if defined _bkbad echo         so the file is not tagged with it - Restore cannot check it is the same phone.
if /i "%_bkser%"=="unknown" set "_bkser="
:: The device check below runs adb devices through for /f, whose child cmd strips the outer quotes:
:: it gets an extra escaped pair to strip and expands ADB from its own environment, so the path is
:: never parsed twice. The PATH fallback reads where's first line directly, no shared temp file.
:: The file is UTF-8, but a double-click opens it at the PC's default code page, which would
:: mangle a non-ASCII value or adb path: switch before any such line, restore in :dcx_hold.
(
    echo @echo off
    echo setlocal
    echo :: DCX-generated restore/undo. Stored under dcx_backups - NOT next to adb\.
    echo for /f "tokens=2 delims=:." %%%%a in ^('chcp'^) do set "DCX_CP0=%%%%a"
    echo chcp 65001 ^>nul
    echo :: Pass /nopause when launched from DCX so control returns to the menu.
    echo set "DCX_NOPAUSE="
    echo if /i "%%~1"=="/nopause" set "DCX_NOPAUSE=1"
    echo set "ADB="
    if defined BAKED echo if exist "%BAKED%" set "ADB=%BAKED%"
    echo if not defined ADB if exist "%%~dp0dcx_adb_path.txt" ^(
    echo   set /p ADB=^<"%%~dp0dcx_adb_path.txt"
    echo ^)
    echo if defined ADB if not exist "%%ADB%%" set "ADB="
    echo if not defined ADB ^(
    echo   for /f "delims=" %%%%a in ^('where adb 2^^^>nul'^) do if not defined ADB set "ADB=%%%%a"
    echo ^)
    echo if defined ADB if not exist "%%ADB%%" set "ADB="
    echo if not defined ADB ^(
    echo   echo [ERROR] adb.exe not found.
    echo   echo   This script lives in "%%USERPROFILE%%\dcx_backups" and does not see
    echo   echo   the adb\ folder next to DCX.bat. Fix one of:
    echo   echo     [1] Add platform-tools to PATH
    echo   echo     [2] Re-run Backup / a Tweaks write from DCX - embeds adb path
    echo   echo     [3] Edit set ADB= near the top of this file
    echo   call :dcx_hold
    echo   exit /b 1
    echo ^)
    echo "%%ADB%%" version ^>nul 2^>^&1
    echo if errorlevel 1 ^(
    echo   echo [ERROR] Cannot run adb: "%%ADB%%"
    echo   call :dcx_hold
    echo   exit /b 1
    echo ^)
    echo echo Using adb: "%%ADB%%"
    echo "%%ADB%%" start-server ^>nul 2^>^&1
    if defined _bkser echo :: DCX_DEVICE %_bkser%
    if defined _bkser if defined _psn echo :: DCX_PHONE %_psn%
    if defined _bkser echo set "DCX_WANT=%_bkser%"
    if defined _bkbad echo :: DCX device serial not recorded - it holds characters DCX will not write here.
    if not defined _bkser if not defined _bkbad echo :: DCX device serial not recorded - adb did not report one.
    echo.
    echo :: These values came off ONE phone. Applying them to another writes that phone's
    echo :: resolution, density and every delete line onto this one, so the restore stops
    echo :: unless the device it was taken from is the one attached. Flat, not a ^( ^) block:
    echo :: a serial is tame, but nothing in a generated file should depend on that.
    echo if not defined DCX_WANT goto :dcx_dev_ok
    echo :: DCX sets DCX_RETARGET when this phone is attached under another connection name.
    echo if defined DCX_RETARGET set "DCX_WANT=%%DCX_RETARGET%%"
    echo set "DCX_HAVE="
    echo :: for /f hands its command to a child cmd: that strips the outer, escaped pair of quotes and reads ADB itself.
    echo for /f "tokens=1" %%%%d in ^('^^^""%%%%ADB%%%%" devices 2^^^>nul^^^"'^) do if /i "%%%%d"=="%%DCX_WANT%%" set "DCX_HAVE=1"
    echo if defined DCX_HAVE goto :dcx_dev_take
    echo echo [ERROR] This file was taken from device %%DCX_WANT%%, which is not attached.
    echo echo         Attached now:
    echo "%%ADB%%" devices
    echo echo         Connect that device and run this file again. Nothing was changed.
    echo call :dcx_hold
    echo exit /b 1
    echo :dcx_dev_take
    echo set "ANDROID_SERIAL=%%DCX_WANT%%"
    echo :dcx_dev_ok
) > "%OUT%"
:: Sets _bk_untagged to 1 or empty, so a caller that clears the screen next can hold the warning,
:: and _bk_ser to the connection name the file was tagged with.
endlocal & endlocal & set "_bk_untagged=%_bkbad%" & set "_bk_ser=%_bkser%"
exit /b 0

:_bk_write_hold_footer
:: Appends the :dcx_hold helper to the file whose variable NAME is arg 1, for backup and undo files.
setlocal EnableDelayedExpansion
set "OUT=!%~1!"
setlocal DisableDelayedExpansion
(
    echo.
    echo :dcx_hold
    echo if defined DCX_CP0 chcp %%DCX_CP0%% ^>nul 2^>^&1
    echo if defined DCX_NOPAUSE exit /b 0
    echo echo.
    echo echo ----------------------------------------
    echo echo Press any key to close this window . . .
    echo pause
    echo exit /b 0
) >> "%OUT%"
endlocal
endlocal
exit /b 0
:: ===========================================================================
:: _dcfg_warn - warn once that device_config put is accepted but may not stick on Android 14+
:: without root. Reads are unaffected. Call it at the top of any menu that relies on those puts.
:_dcfg_warn
if defined _DCFGWARNED goto :eof
:: only relevant on Android 14+ (API 34). A non-numeric SDK skips the compare safely.
set "_dcfg_hi="
for /f "delims=0123456789" %%n in ("%SDK%") do set "_dcfg_hi=1"
if defined _dcfg_hi goto :eof
if %SDK% LSS 34 goto :eof
:: SDK>=34: does the device have root? (device_config put works with su.)
adb shell "su -c 'echo _DCXROOT'" <nul 2>nul | findstr /C:"_DCXROOT" >nul
if not errorlevel 1 goto :eof
:: SDK>=34 and no root -> warn once.
set "_DCFGWARNED=1"
echo.
echo  %gold%Note (Android %SDK%):%w% since Android 14, changing hidden "device_config"
echo  flags over ADB needs root. Without it these writes are accepted but may%w%
echo  %gold%not actually stick%w% - the on-screen result can look done while nothing
echo  changed. Values DCX only *reads* are still accurate.
echo  For the app-hibernation case there is a no-root path: Developer Options ^>
echo  %gold%Disable child process restrictions%w%.
echo.
goto :eof

:_bk_settings
:: _bk_settings namespace key outvar: writes a restore line, a put or, for null, a delete.
:: Read with delayed expansion off so an exclamation mark in the value survives. No output means the
:: read failed, not unset - Android prints null for that - so it becomes a DCX_SKIP, never a delete.
:: outvar is the NAME of the variable holding the output file, not the path.
setlocal DisableDelayedExpansion
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
set "_got="
for /f "delims=" %%v in ('adb shell settings get %_ns% %_key% 2^>nul ^<nul') do set "_val=%%v" & set "_got=1"
setlocal EnableDelayedExpansion
if not defined _got goto _bk_settings_unread
:: adb hands the device shell the value bare, so the whole remote command goes as one argument
:: and the value is single-quoted inside it, embedded single quotes escaped POSIX-style.
set "_sv=!_val:'='\''!"
if /i "!_val!"=="null" (set "_BKCMD=settings delete %_ns% %_key%") else (set "_BKCMD=settings put %_ns% %_key% '!_sv!'")
call :_bk_emit "%_out%"
if errorlevel 1 (endlocal & endlocal & exit /b 1)
endlocal
endlocal
exit /b 0

:_bk_settings_unread
:: errorlevel 1: nothing restorable was written.
>>"!%_out%!" echo :: DCX_SKIP %_ns% %_key% - the device did not answer, value not captured
endlocal
endlocal
exit /b 1

:_bk_devcfg
:: device_config twin of :_bk_settings: read with delayed expansion off, value single-quoted.
setlocal DisableDelayedExpansion
set "_ns=%~1"
set "_key=%~2"
set "_out=%~3"
set "_val="
set "_got="
for /f "delims=" %%v in ('adb shell device_config get %_ns% %_key% 2^>nul ^<nul') do set "_val=%%v" & set "_got=1"
setlocal EnableDelayedExpansion
:: No output means the read failed, not unset: skip the key, never delete it.
if not defined _got goto _bk_devcfg_unread
:: Single-quote the value: adb hands the device shell the command bare.
set "_sv=!_val:'='\''!"
if /i "!_val!"=="null" (set "_BKCMD=device_config delete %_ns% %_key%") else (set "_BKCMD=device_config put %_ns% %_key% '!_sv!'")
call :_bk_emit "%_out%"
if errorlevel 1 (endlocal & endlocal & exit /b 1)
endlocal
endlocal
exit /b 0

:_bk_devcfg_unread
>>"!%_out%!" echo :: DCX_SKIP device_config %_ns% %_key% - the device did not answer
endlocal
endlocal
exit /b 1

:_bk_wm
:: Captures Display Scaler overrides - wm size and wm density; no override restores as reset.
:: wm always prints its Physical line, so any output proves the read worked; none means DCX_SKIP.
setlocal DisableDelayedExpansion
set "_out=%~1"
set "_osz="
set "_odz="
set "_szok="
set "_dnok="
:: Read with delayed expansion off so phone text stays literal; only digits - plus one x for the
:: size - are accepted, anything else becomes a DCX_SKIP comment.
for /f "tokens=1,* delims=:" %%a in ('adb shell wm size ^<nul 2^>nul') do (
    set "_szok=1"
    if /i "%%a"=="Override size" set "_osz=%%b"
)
for /f "tokens=1,* delims=:" %%a in ('adb shell wm density ^<nul 2^>nul') do (
    set "_dnok=1"
    if /i "%%a"=="Override density" set "_odz=%%b"
)
setlocal EnableDelayedExpansion
:: Test defined first: on an undefined variable the substitution yields the literal text ' ='.
if defined _osz set "_osz=!_osz: =!"
if defined _odz set "_odz=!_odz: =!"
set "_oszbad=" & set "_odzbad="
if defined _osz for /f "eol=x delims=0123456789x" %%c in ("!_osz!") do set "_oszbad=1"
if defined _odz for /f "eol=0 delims=0123456789" %%c in ("!_odz!") do set "_odzbad=1"
if not defined _szok goto _bk_wm_nosize
if defined _oszbad goto _bk_wm_oddsize
if defined _osz (set "_BKCMD=wm size !_osz!") else (set "_BKCMD=wm size reset")
call :_bk_emit "%_out%"
goto _bk_wm_density

:_bk_wm_oddsize
>>"!%_out%!" echo :: DCX_SKIP wm size - the device printed an override DCX does not recognise
goto _bk_wm_density

:_bk_wm_nosize
>>"!%_out%!" echo :: DCX_SKIP wm size - the device did not answer

:_bk_wm_density
if not defined _dnok goto _bk_wm_nodensity
if defined _odzbad goto _bk_wm_odddensity
if defined _odz (set "_BKCMD=wm density !_odz!") else (set "_BKCMD=wm density reset")
call :_bk_emit "%_out%"
endlocal & endlocal
exit /b

:_bk_wm_odddensity
>>"!%_out%!" echo :: DCX_SKIP wm density - the device printed an override DCX does not recognise
endlocal & endlocal
exit /b

:_bk_wm_nodensity
>>"!%_out%!" echo :: DCX_SKIP wm density - the device did not answer
endlocal & endlocal
exit /b

:_bk_dcfgsync
:: Captures device_config get_sync_disabled_for_tests - none/persistent/until_reboot.
:: Tweaks owns this toggle. An unreadable answer is a DCX_SKIP comment, never a guessed none,
:: and errorlevel 1, as :_bk_settings returns.
setlocal enabledelayedexpansion
set "_out=%~1"
call :_dcfgsync_read
if errorlevel 1 goto _bk_dcfgsync_unread
set "_BKCMD=device_config set_sync_disabled_for_tests '!DCS_VAL!'"
call :_bk_emit "%_out%"
if errorlevel 1 (endlocal & exit /b 1)
endlocal
exit /b 0

:_bk_dcfgsync_unread
>>"!%_out%!" echo :: DCX_SKIP device_config sync mode - not readable on this device
endlocal
exit /b 1

:_bk_prop
:: Read with delayed expansion off; the value is written single-quoted for the device shell.
:: getprop answers empty both when unset and when unreachable, so an empty answer probes first:
:: alive restores as setprop key '' - not a double-quote pair, cmd strips it; silent is DCX_SKIP.
setlocal DisableDelayedExpansion
set "_key=%~1"
set "_out=%~2"
set "_val="
for /f "delims=" %%v in ('adb shell getprop %_key% 2^>nul ^<nul') do set "_val=%%v"
setlocal EnableDelayedExpansion
if "!_val!"=="" goto _bk_prop_empty
:: Single-quote for the device shell, escaping any single quote inside.
set "_sv=!_val:'='\''!"
set "_BKCMD=setprop %_key% '!_sv!'"
call :_bk_emit "%_out%"
endlocal
endlocal
exit /b

:_bk_prop_empty
:: The echoed text is ours, so this comparison cannot be broken by a device value.
set "_alive="
for /f "delims=" %%a in ('adb shell echo _DCXRD ^<nul 2^>nul') do if "%%a"=="_DCXRD" set "_alive=1"
if not defined _alive (
    >>"!%_out%!" echo :: DCX_SKIP prop %_key% - the device did not answer
) else (
    >>"!%_out%!" echo :: prop %_key% was unset at backup time - restoring it to unset
    set "_BKCMD=setprop %_key% ''"
    call :_bk_emit "%_out%"
)
endlocal
endlocal
exit /b

:_bk_emit
:: Writes ONE restore command into the generated file, as two lines:
::     set "DCX_CMD=<command>"
::     call :dcx_do
:: In: _BKCMD = the remote command - in a variable, never a call argument: call re-parses those.
::     arg 1 = the NAME of the variable holding the file, read late, never the path itself.
:: Percent is doubled, the only escape; plain setlocal in the file keeps exclamation marks literal.
:: A value holding a double quote cannot survive the set line: DCX_SKIP comment, errorlevel 1.
setlocal EnableDelayedExpansion
set "_e=!_BKCMD!"
set _eq=!_e:"=!
if not "!_eq!"=="!_e!" goto _bk_emit_quoted
set "_e=!_e:%%=%%%%!"
>>"!%~1!" echo set "DCX_CMD=!_e!"
>>"!%~1!" echo call :dcx_do
endlocal
exit /b 0

:_bk_emit_quoted
>>"!%~1!" echo :: DCX_SKIP the value below holds a double quote, which cannot survive a .bat:
>>"!%~1!" echo ::   !_e!
endlocal
exit /b 1

:_bk_capture_all
:: arg 1 = the NAME of the variable holding the output file - BAKFILE, or _pvraw for the preview.
:: Backup and the restore preview share this one list so the keys they check cannot drift apart.
echo    [1/5] display, animation and refresh rate...
call :_bk_settings global window_animation_scale     "%~1"
call :_bk_settings global transition_animation_scale "%~1"
call :_bk_settings global animator_duration_scale    "%~1"
call :_bk_settings system min_refresh_rate           "%~1"
call :_bk_settings system peak_refresh_rate          "%~1"
call :_bk_settings global angle_gl_driver_all_angle  "%~1"
call :_bk_settings global master_sync_status         "%~1"
call :_bk_settings global hotword_detection_enabled  "%~1"
echo    [2/5] network, DNS and Wi-Fi...
call :_bk_settings global preferred_network_mode     "%~1"
call :_bk_settings global preferred_network_mode1    "%~1"
call :_bk_settings global private_dns_mode           "%~1"
call :_bk_settings global private_dns_specifier      "%~1"
call :_bk_settings global mobile_data_always_on      "%~1"
call :_bk_settings global tcp_default_init_rwnd      "%~1"
call :_bk_settings global wifi_idle_ms               "%~1"
call :_bk_settings global wifi_sleep_policy          "%~1"
echo    [3/5] battery, status bar and input...
call :_bk_settings global low_power                  "%~1"
call :_bk_settings secure clock_seconds              "%~1"
call :_bk_settings system status_bar_show_battery_percent "%~1"
call :_bk_settings global audio_safe_volume_state    "%~1"
call :_bk_settings secure audio_safe_csd_as_a_feature_enabled "%~1"
call :_bk_settings secure icon_blacklist             "%~1"
call :_bk_settings global heads_up_notifications_enabled "%~1"
call :_bk_settings system font_scale                 "%~1"
call :_bk_settings secure long_press_timeout         "%~1"
call :_bk_settings global stay_on_while_plugged_in   "%~1"
echo    [4/5] night mode, tiles and gestures...
call :_bk_settings secure ui_night_mode              "%~1"
call :_bk_settings secure night_display_activated    "%~1"
call :_bk_settings secure night_display_auto_mode    "%~1"
call :_bk_settings secure night_display_color_temperature "%~1"
call :_bk_settings global sysui_demo_allowed         "%~1"
call :_bk_settings secure sysui_qs_tiles             "%~1"
call :_bk_settings secure camera_gesture_disabled    "%~1"
call :_bk_settings secure camera_double_tap_power_gesture_disabled "%~1"
call :_bk_settings secure camera_double_twist_to_flip_enabled "%~1"
call :_bk_settings global charging_sounds_enabled    "%~1"
call :_bk_settings global charging_vibration_enabled "%~1"
call :_bk_settings global sys_storage_threshold_percentage "%~1"
call :_bk_settings global sys_storage_threshold_max_bytes "%~1"
call :_bk_settings global low_power_trigger_level    "%~1"
call :_bk_settings global default_install_location   "%~1"
call :_bk_settings global enable_freeform_support    "%~1"
call :_bk_settings global force_resizable_activities "%~1"
call :_bk_settings global zram_enabled               "%~1"
echo    [5/5] scanning, screen size and properties...
call :_bk_settings global wifi_scan_always_enabled   "%~1"
call :_bk_settings global ble_scan_always_enabled  "%~1"
call :_bk_settings global always_finish_activities   "%~1"
call :_bk_settings global package_verifier_enable    "%~1"
call :_bk_settings global low_power_sticky           "%~1"
call :_bk_settings global disable_window_blurs       "%~1"
call :_bk_settings global reduce_motion              "%~1"
call :_bk_settings secure reduce_motion              "%~1"
call :_bk_settings secure accessibility_disable_animations "%~1"
call :_bk_settings global enable_back_animation      "%~1"
call :_bk_settings global fancy_ime_animations       "%~1"
call :_bk_settings secure multi_press_timeout        "%~1"
call :_bk_devcfg   app_hibernation app_hibernation_enabled "%~1"
call :_bk_dcfgsync "%~1"
call :_bk_wm       "%~1"
call :_bk_prop     debug.hwui.renderer        "%~1"
call :_bk_prop     debug.renderengine.backend "%~1"
call :_bk_prop     persist.log.tag            "%~1"
exit /b 0
:: ===================================================================
:: Restore from backup file
:: ===================================================================
:restore
cls
title Restore Settings
call :logo
echo.
if not exist "!BACKUPDIR!" (
    echo  %r%No backups folder found.%w%
    echo  Run option [11] Backup first to create one.
    echo.
    pause > nul
    goto menu
)
echo  Available backups in !BACKUPDIR!:
echo  %y%Note:%w% older restore .bats that call bare "adb" need PATH or a
echo  re-Backup from this DCX ^(new files embed the adb.exe path^).
echo.
:: Numbered listing, newest first. The names stay in a file and are shown and picked with delayed
:: expansion off, so a name holding ! % or ^ is the file's own name; the pick is the listed line.
set "_bkl=!DCX_TMP!\bklist.txt"
dir /b /a-d /o-d "!BACKUPDIR!\dcx_backup_*.bat" >"!_bkl!" 2>nul
if not exist "!_bkl!" (
    echo  %r%Could not write the list of backups to !DCX_TMP!.%w%
    echo.
    pause > nul
    goto menu
)
setlocal DisableDelayedExpansion
set "i=0"
for /f "tokens=1* delims=:" %%a in ('findstr /n /r "." "%%_bkl%%" 2^>nul') do (
    set "i=%%a"
    if %%a LSS 10 (echo      [%%a] %%b) else if %%a LSS 100 (echo     [%%a] %%b) else (echo    [%%a] %%b)
)
endlocal & set "i=%i%"
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
call :_noin ri || goto dcx_noinput
if "!ri!"=="0" goto menu
:: Digits only: the call set below expands the reply a second time.
:: eol=0 so a reply starting with ; is still checked.
set "_ribad="
for /f "eol=0 delims=0123456789" %%c in ("!ri!") do set "_ribad=1"
if defined _ribad (
    echo  %r%Invalid selection.%w%
    pause > nul
    goto restore
)
:: Look up the chosen line. set /p takes the name from a file as it is, so ! % and ^ survive.
del "!DCX_TMP!\bkpick.txt" >nul 2>&1
setlocal DisableDelayedExpansion
for /f "tokens=1* delims=:" %%a in ('findstr /n /r "." "%%_bkl%%" 2^>nul') do if "%%a"=="%ri%" >"%DCX_TMP%\bkpick.txt" echo(%%b
endlocal
set "_chosen="
if exist "!DCX_TMP!\bkpick.txt" set /p "_chosen=" <"!DCX_TMP!\bkpick.txt"
if not defined _chosen (
    echo  %r%Invalid selection.%w%
    pause > nul
    goto restore
)
set "RESTOREFILE=!BACKUPDIR!\!_chosen!"

:restore_confirm
:: The file names its source phone in a DCX_DEVICE line; checking here explains a mismatch on
:: this screen. Older untagged files still restore, with a warning.
set "_rwant="
for /f "tokens=3" %%s in ('findstr /b /c:":: DCX_DEVICE " "%%RESTOREFILE%%" 2^>nul') do set "_rwant=%%s"
set "_rhave="
for /f "delims=" %%s in ('adb get-serialno 2^>nul') do set "_rhave=%%s"
:: Both serials are phone text, so they are only ever read late.
if /i "!_rhave!"=="unknown" set "_rhave="
echo.
echo  About to apply settings from:
echo    !RESTOREFILE!
:: A file written untagged on purpose says DCX device serial not recorded - it is not old.
set "_runrec="
if not defined _rwant findstr /b /c:":: DCX device serial not recorded" "!RESTOREFILE!" >nul 2>&1 && set "_runrec=1"
if defined _runrec echo  %y%This file does not say which phone it came from%w% - DCX could not record that
if defined _runrec echo  phone's serial when it wrote the file. Check it is the right phone.
if not defined _rwant if not defined _runrec echo  %y%This file predates device tagging%w% - check it is the right phone.
if defined _rwant echo  Taken from device: !_rwant!
if defined _rhave echo  Connected now:     !_rhave!
if defined _rwant if not defined _rhave goto _restore_nodev
call :_retarget RESTOREFILE
if defined DCX_RETARGET echo  %g%Same phone%w% ^(serial !_psn!^) over another connection - the restore goes to it.
if defined _rwant if not defined DCX_RETARGET if /i not "!_rwant!"=="!_rhave!" goto _restore_wrongdev
echo.
echo  %y%This will overwrite your current values for every key listed.%w%
echo.
echo    [Y] Proceed and restore
echo    [P] Preview - show what this would change, and change nothing
echo    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 is sent where No goes.
:: Test the highest first: 3 = N, 2 = P, 1 = Y, 0 = Ctrl+C.
choice /c:YPN /n > nul
if errorlevel 3 goto menu
if errorlevel 2 goto restore_preview
if not errorlevel 1 goto menu
goto _restore_run

:_restore_nodev
echo.
echo  %r%No device is answering%w% - nothing to restore onto.
echo.
pause > nul
goto menu

:_restore_wrongdev
echo.
echo  %r%That backup was taken over another connection or from another phone.%w% DCX could
echo  not confirm it is this phone, and restoring it onto another one would write its
echo  resolution, density and every delete line there. Connect !_rwant! ^(Wireless ADB
echo  [7] picks between USB and Wi-Fi entries^), or pick a backup taken from !_rhave!.
echo.
pause > nul
goto menu

:restore_preview
cls
title Restore preview - reads only, changes nothing
call :logo
echo.
echo  %g%Preview%w% - comparing !_chosen!
echo  against the phone as it is right now. %g%Nothing on the device is changed.%w%
echo.
:: Older files pass the command to :dcx_do as an argument, not in DCX_CMD: nothing to compare.
findstr /b /c:"call :dcx_do " "!RESTOREFILE!" >nul 2>&1 && goto restore_preview_old
:: This window's own folder, not one shared by every DCX window.
set "_pvdir=!DCX_TMP!\preview"
set "_pvraw=!_pvdir!\raw.txt"
if not exist "!_pvdir!" mkdir "!_pvdir!" 2>nul
del "!_pvdir!\backup.txt" "!_pvdir!\now.txt" "!_pvraw!" "!_pvdir!\slice.txt" "!_pvdir!\diff.txt" >nul 2>&1
:: The capture lines follow :dcx_main; only that slice is compared.
set "_pvsk="
for /f "tokens=1 delims=:" %%n in ('findstr /n /b /x /c:":dcx_main" "%%RESTOREFILE%%" 2^>nul') do set "_pvsk=%%n"
if not defined _pvsk goto restore_preview_bad
more +%_pvsk% "!RESTOREFILE!" > "!_pvdir!\slice.txt" 2>nul
findstr /b /c:"set " "!_pvdir!\slice.txt" | findstr /v /c:"DCX_OK" > "!_pvdir!\backup.txt"
echo  Reading the current values from the phone - about six seconds.
echo  %y%The window will not accept input until it finishes.%w%
echo.
call :_bk_capture_all _pvraw
findstr /b /c:"set " "!_pvraw!" > "!_pvdir!\now.txt"
:: Values never reach a command line: /g: reads patterns from a file; /x whole line, /l literal.
set "_pvold=0" & set "_pvnew=0" & set "_pvdiff="
for /f %%n in ('find /c /v "" ^< "%%_pvdir%%\backup.txt"') do set "_pvold=%%n"
for /f %%n in ('find /c /v "" ^< "%%_pvdir%%\now.txt"') do set "_pvnew=%%n"
:: Backup lines the phone does not hold now, compared whole in PowerShell: findstr /g: fails on a
:: line of 512 bytes or more (a long tile list) and an empty pattern file, and then counts 0.
set "DCX_PVA=!_pvdir!\backup.txt" & set "DCX_PVB=!_pvdir!\now.txt" & set "DCX_PVO=!_pvdir!\changes.txt"
del "!_pvdir!\changes.txt" >nul 2>&1
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { $u=New-Object Text.UTF8Encoding $false; $n=New-Object 'Collections.Generic.HashSet[string]' (,[string[]][IO.File]::ReadAllLines($env:DCX_PVB,$u)); $d=@([IO.File]::ReadAllLines($env:DCX_PVA,$u) | Where-Object { -not $n.Contains($_) }); [IO.File]::WriteAllLines($env:DCX_PVO,[string[]]$d,$u); exit 0 } catch { exit 1 }" <nul
chcp 65001 >nul <nul
set "DCX_PVA=" & set "DCX_PVB=" & set "DCX_PVO="
if exist "!_pvdir!\changes.txt" for /f %%n in ('find /c /v "" ^< "%%_pvdir%%\changes.txt"') do set "_pvdiff=%%n"
echo  ----------------------------------------------------------------
echo   In the backup : %_pvold% restore commands
echo   On the phone  : %_pvnew% values readable right now
:: A file with no commands is not a file with no differences - it gets its own message.
if "%_pvold%"=="0" goto restore_preview_nothing
if "%_pvnew%"=="0" goto restore_preview_nophone
if not defined _pvdiff goto restore_preview_nocompare
if "%_pvdiff%"=="0" goto restore_preview_same
echo   %y%Would change  : %_pvdiff%%w%
echo  ----------------------------------------------------------------
echo.
echo  Restoring would write these - the phone holds something else today:
set "_pvshown=0"
for /f "usebackq delims=" %%L in ("!_pvdir!\changes.txt") do (
    set /a _pvshown+=1
    if !_pvshown! LEQ 12 echo     %%L
)
if !_pvshown! GTR 12 (
    set /a _pvmore=!_pvshown!-12
    echo     ... and !_pvmore! more - the full side-by-side is below.
)
goto restore_preview_menu

:restore_preview_nothing
echo  ----------------------------------------------------------------
echo.
echo  %y%This file holds no restore commands at all%w% - there is nothing to compare
echo  and nothing it could put back. It was probably written while the device was
echo  unreachable. Take a fresh Backup.
goto restore_preview_menu

:restore_preview_nophone
echo  ----------------------------------------------------------------
echo.
echo  %y%The phone gave no values just now%w% - did it disconnect? With nothing read there is
echo  nothing to compare, so this says nothing about what a restore would change.
goto restore_preview_menu

:restore_preview_nocompare
echo  ----------------------------------------------------------------
echo.
echo  %y%The two lists could not be compared%w% ^(PowerShell did not run^). The side-by-side
echo  view below still shows both.
goto restore_preview_menu

:restore_preview_same
echo   %g%Would change  : nothing%w%
echo  ----------------------------------------------------------------
echo.
echo  Every value in this backup already matches the phone. Restoring it
echo  would be a no-op - which is worth knowing before you run it.

:restore_preview_menu
echo.
set "_UDA=!_pvdir!\backup.txt" & set "_UDB=!_pvdir!\now.txt" & set "_UDO=!_pvdir!\diff.txt" & set "_UDM=new"
call :_udiff
echo  %b%[%w%1%b%]%w% Open the full comparison in Notepad
echo  %b%[%w%2%b%]%w% Show it here (MORE)
echo  %b%[%w%3%b%]%w% Back to the restore prompt
set "pvk=" & set /p pvk="Choose An Option >> "
call :_noin pvk || goto dcx_noinput
if "!pvk!"=="1" (start "" notepad "!_pvdir!\diff.txt" & goto restore_preview_menu)
if "!pvk!"=="2" (cls & title Restore preview  -  SPACE=next page   Q=quit back to menu & more "!_pvdir!\diff.txt" & pause >nul & cls & call :logo & goto restore_confirm)
cls
call :logo
goto restore_confirm

:restore_preview_old
echo  %y%This backup was written by an older DCX.%w% Its restore lines pass the
echo  command to the helper as an argument instead of in a variable, so there is
echo  nothing here to line up against the current values - and reporting that as
echo  "no differences" would be a lie. Restoring it still works.
echo.
echo  Run Backup once on this DCX to get a file this can compare.
echo.
pause > nul
cls
call :logo
goto restore_confirm

:restore_preview_bad
echo  %r%Could not read that backup file.%w% It has no :dcx_main section, so it is
echo  either truncated or not a DCX backup at all. Restoring it is not advisable.
echo.
pause > nul
cls
call :logo
goto restore_confirm

:_restore_run
cls
echo  Running restore ^(output below^)...
echo.
:: Nested cmd so a restore .bat calling plain exit cannot close DCX; /nopause keeps the hold here.
:: The child expands RESTOREFILE itself - path parsed once; cmd /c strips the outer quote pair.
call :_retarget RESTOREFILE
cmd /c ""%%RESTOREFILE%%" /nopause"
set "_rrc=%errorlevel%"
set "DCX_RETARGET="
set "_rdev="
for /f "delims=" %%d in ('adb get-state 2^>nul') do set "_rdev=%%d"
echo.
echo  ----------------------------------------
if not "%_rrc%"=="0" (
    echo  %r%Restore finished with %_rrc% failed write^(s^)%w% - they are listed above.
    echo  The device may be in a mixed state. Reconnect it and restore again;
    echo  restoring twice is harmless.
) else if /i not "%_rdev%"=="device" (
    echo  %r%The device is no longer connected.%w% The restore may have stopped part-way.
    echo  Reconnect the device and run the restore again - restoring twice is harmless.
) else (
    echo  %g%Restore complete.%w% Some changes may need a reboot to fully apply.
)
:: Android 14+ without root can accept a device_config write and keep nothing; Preview shows it.
set "_rdcfg="
if "%_rrc%"=="0" if /i "%_rdev%"=="device" if !SDK! GEQ 34 findstr /c:"DCX_CMD=device_config " "!RESTOREFILE!" >nul 2>&1 && set "_rdcfg=1"
if defined _rdcfg echo  %y%Note:%w% Android 14+ without root can accept a device_config value without keeping it.
if defined _rdcfg echo  Restore this file again with [P] Preview to see whether those values now match.
echo  ----------------------------------------
echo.
echo  Press any key to return to the main menu . . .
pause >nul
goto menu

:benchmark
cls
title Benchmark
echo [%g%+%w%] Quick device benchmark.
echo.
echo  This runs three quick checks:
echo    1. CPU loop time           ^(lower is better^)
echo    2. Storage sequential write ^(higher M/s is better^)
echo    3. Storage sequential read  ^(higher M/s is better^)
echo.
echo  Total time: about 10-15 seconds.
echo.
echo.
echo [%b%1/3%w%] CPU loop test (1M iterations)...
:: Portable POSIX loop - seq is not on every Android.
adb shell "time sh -c 'i=0; while [ $i -lt 1000000 ]; do i=$((i+1)); done'" <nul
echo.
:: conv=fsync and iflag=direct keep the page cache out; /dev/zero so no generator is timed.
:: A dd lacking them fails and a labelled plain run follows. Android 6 and older report exit 0
:: anyway, so dd's own summary line, which says "bytes", must be there too.
echo [%b%2/3%w%] Storage sequential write ^(32 MB, flushed to storage^)...
adb shell "rm -f /data/local/tmp/_dcx_bench; dd if=/dev/zero of=/data/local/tmp/_dcx_bench bs=1048576 count=32 conv=fsync 2>/data/local/tmp/_dcx_bench.txt; r=$?; tail -1 /data/local/tmp/_dcx_bench.txt; exit $r" <nul >"!DCX_TMP!\bench.txt" 2>&1
set "_bnrc=!errorlevel!"
type "!DCX_TMP!\bench.txt" 2>nul
if not "!_bnrc!"=="0" goto _bench_wplain
findstr /i /c:"bytes" "!DCX_TMP!\bench.txt" >nul 2>&1 || goto _bench_wplain
goto _bench_read

:_bench_wplain
echo  [%y%i%w%] This phone's dd cannot flush ^(conv=fsync^) - timing a plain write instead.
echo      It includes the RAM cache, so it reads faster than the storage really is:
adb shell "dd if=/dev/zero of=/data/local/tmp/_dcx_bench bs=1048576 count=32 2>&1 | tail -1" <nul

:_bench_read
echo.
echo [%b%3/3%w%] Storage sequential read ^(32 MB, bypassing the cache^)...
adb shell "dd if=/data/local/tmp/_dcx_bench of=/dev/null bs=1048576 iflag=direct 2>/data/local/tmp/_dcx_bench.txt; r=$?; tail -1 /data/local/tmp/_dcx_bench.txt; exit $r" <nul >"!DCX_TMP!\bench.txt" 2>&1
set "_bnrc=!errorlevel!"
type "!DCX_TMP!\bench.txt" 2>nul
if not "!_bnrc!"=="0" goto _bench_rplain
findstr /i /c:"bytes" "!DCX_TMP!\bench.txt" >nul 2>&1 || goto _bench_rplain
goto _bench_end

:_bench_rplain
echo  [%y%i%w%] This phone's dd cannot bypass the cache ^(iflag=direct^) - reading through it.
echo      The file was just written, so this is memory speed, NOT storage speed:
adb shell "dd if=/data/local/tmp/_dcx_bench of=/dev/null bs=1048576 2>&1 | tail -1" <nul

:_bench_end
adb shell rm -f /data/local/tmp/_dcx_bench /data/local/tmp/_dcx_bench.txt <nul
echo.
echo.
echo [%g%Done%w%] Numbers vary - run twice after optimization for comparison.
echo.
echo Press Any Button To Go Back
pause > nul
goto menu

:shell
cls
title Shell and tools
call :logo
echo                          %b%[%w% Shell and tools %b%]%w%
echo.
echo                 %g%[%w%1%g%]%w% Interactive shell      (adb shell - type exit to come back)
echo                 %g%[%w%2%g%]%w% Command library        (ready-made commands, each explained)
echo                 %g%[%w%3%g%]%w% Logcat capture         (crash log, or record one app)
echo                 %g%[%w%4%g%]%w% Bootloader info        (fastboot, read-only, USB only)
echo                 %g%[%w%5%g%]%w% Sideload an update     (an official OTA package, through recovery)
echo                 %g%[%w%6%g%]%w% Back
set "shm=" & set /p shm="Choose An Option >> "
call :_noin shm || goto dcx_noinput
if "!shm!"=="1" goto shell_live
if "!shm!"=="2" goto cmdlib
if "!shm!"=="3" goto logcap
if "!shm!"=="4" goto fbinfo
if "!shm!"=="5" goto sideload
if "!shm!"=="6" goto menu
goto shell

:shell_live
set "_dvst="
for /f "delims=" %%d in ('adb get-state 2^>nul ^<nul') do set "_dvst=%%d"
if /i not "!_dvst!"=="device" goto shell_nodev
cls
title Shell
echo  Interactive adb shell on the phone. Type exit to come back to DCX.
adb shell
goto shell

:shell_nodev
echo  [%r%^^!%w%] No phone answers - check the cable or Wi-Fi ^(adb devices^).
pause >nul
goto shell
:: ===================================================================
:: Command library: ready-made adb shell commands, each with a note. Read-only ones run at once; a
:: change asks first and shows its undo, a delete asks in red. Entries are the ::LIB~ lines at the
:: end of this file: id~category~risk~min API~command~note~undo. Risk r = reads only, c = changes
:: something (undo given), d = deletes data or cannot be undone. {PKG} and {NUM} in a command are
:: asked for before it runs. Commands hold no double quote: Windows would strip it before adb.
:: ===================================================================
:cmdlib
call :_lib_load
if "!_lbn!"=="0" goto cmdlib_noload

:cmdlib_menu
cls
title Command library
call :logo
echo                          %b%[%w% Command library %b%]%w%
echo.
echo  Ready-made commands, each explained before it runs. Anything that changes the phone
echo  asks first and shows how to undo it. Output can be paged, opened in Notepad or saved.
echo.
echo                 %g%[%w%1%g%]%w% !_lbcatn[1]!  !_lbcn1!
echo                 %g%[%w%2%g%]%w% !_lbcatn[2]!  !_lbcn2!
echo                 %g%[%w%3%g%]%w% !_lbcatn[3]!  !_lbcn3!
echo                 %g%[%w%4%g%]%w% !_lbcatn[4]!  !_lbcn4!
echo                 %g%[%w%5%g%]%w% !_lbcatn[5]!  !_lbcn5!
echo                 %g%[%w%6%g%]%w% !_lbcatn[6]!  !_lbcn6!
echo                 %g%[%w%7%g%]%w% !_lbcatn[7]!  !_lbcn7!
echo                 %g%[%w%8%g%]%w% !_lbcatn[8]!  !_lbcn8!
echo                 %g%[%w%9%g%]%w% Search by word
echo                %g%[%w%10%g%]%w% Favourites
echo                 %g%[%w%0%g%]%w% Back
set "lbm=" & set /p lbm="Choose An Option >> "
call :_noin lbm || goto dcx_noinput
if "!lbm!"=="1" (set "_lbcat=1" & goto cmdlib_cat)
if "!lbm!"=="2" (set "_lbcat=2" & goto cmdlib_cat)
if "!lbm!"=="3" (set "_lbcat=3" & goto cmdlib_cat)
if "!lbm!"=="4" (set "_lbcat=4" & goto cmdlib_cat)
if "!lbm!"=="5" (set "_lbcat=5" & goto cmdlib_cat)
if "!lbm!"=="6" (set "_lbcat=6" & goto cmdlib_cat)
if "!lbm!"=="7" (set "_lbcat=7" & goto cmdlib_cat)
if "!lbm!"=="8" (set "_lbcat=8" & goto cmdlib_cat)
if "!lbm!"=="9" goto cmdlib_search
if "!lbm!"=="10" goto cmdlib_fav
if "!lbm!"=="0" goto shell
goto cmdlib_menu

:cmdlib_noload
echo [%r%^^!%w%] The command list could not be read from DCX.bat - was the file renamed or moved?
pause >nul
goto shell

:cmdlib_cat
:: _lbcat = a category number; _lbv[k] maps list number k to an entry.
call :_lib_clearv
for /l %%i in (1,1,!_lbn!) do if "!_lb_c[%%i]!"=="!_lbcat!" (
    set /a _lbk+=1
    set "_lbv[!_lbk!]=%%i"
)
for /f "delims=" %%c in ("!_lbcat!") do set "_lbtitle=!_lbcatn[%%c]!"
goto cmdlib_list

:cmdlib_search
echo.
set "lbw=" & set /p lbw="Word to look for, such as battery (blank = back) >> "
call :_noin lbw || goto dcx_noinput
if not defined lbw goto cmdlib_menu
:: Letters, digits, dot, dash and underscore only: the word goes into a substitution below.
set "_lbbad="
set "_lbwq=!lbw:"=#!"
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_lbwq!") do set "_lbbad=1"
if defined _lbbad goto cmdlib_search
call :_lib_clearv
for /l %%i in (1,1,!_lbn!) do (
    set "_lbs=#!_lb_d[%%i]! !_lb_x[%%i]!"
    if not "!_lbs:%lbw%=!"=="!_lbs!" (
        set /a _lbk+=1
        set "_lbv[!_lbk!]=%%i"
    )
)
set "_lbtitle=Commands with "!lbw!" in them"
goto cmdlib_list

:cmdlib_fav
call :_lib_clearv
if exist "!PROFDIR!\library_favourites.txt" for /f "usebackq delims=" %%f in ("!PROFDIR!\library_favourites.txt") do (
    set "_lbf=%%f"
    call :_lib_favadd
)
set "_lbtitle=Favourites - F on a command adds or removes it"
goto cmdlib_list

:cmdlib_list
cls
title Command library
call :logo
echo  %b%!_lbtitle!%w%
echo.
if "!_lbk!"=="0" echo  Nothing here yet.
for /l %%k in (1,1,!_lbk!) do call :_lib_row %%k
echo.
echo  %y%[change]%w% asks first and shows its undo.   %r%[deletes]%w% loses data or cannot be undone.
echo.
set "lbe=" & set /p lbe="Command number (Enter = back) >> "
call :_noin lbe || goto dcx_noinput
if not defined lbe goto cmdlib_menu
call :_lib_num lbe || goto cmdlib_list
if not defined _lbv[!lbe!] goto cmdlib_list
for /f "delims=" %%k in ("!lbe!") do set "_lbi=!_lbv[%%k]!"

:cmdlib_show
cls
title Command library
call :logo
for /f "delims=" %%i in ("!_lbi!") do (
    set "_lbx=!_lb_x[%%i]!"
    set "_lbu=!_lb_u[%%i]!"
    set "_lbrisk=!_lb_r[%%i]!"
    set "_lbapi=!_lb_a[%%i]!"
    set "_lbid=!_lb_id[%%i]!"
    set "_lbnote=!_lb_d[%%i]!"
)
set "_lbshow=!_lbx:{PKG}=<package>!"
set "_lbshow=!_lbshow:{NUM}=<number>!"
set "_lbushow=!_lbu:{PKG}=<package>!"
set "_lbushow=!_lbushow:{NUM}=<number>!"
echo  %b%!_lbnote!%w%
echo.
echo  Runs     adb shell !_lbshow!
if "!_lbrisk!"=="r" echo  Changes  nothing - it only reads.
if "!_lbrisk!"=="c" echo  Changes  %y%the phone%w%. Undo: !_lbushow!
if "!_lbrisk!"=="d" echo  Changes  %r%deletes data, or cannot be undone%w%.
echo  Needs    Android API !_lbapi! or newer. This phone reports API !SDK!.
if !SDK! GTR 0 if !SDK! LSS !_lbapi! echo  %y%This phone is older than that, so the command may not exist on it.%w%
set "_lbisfav="
findstr /x /c:"!_lbid!" "!PROFDIR!\library_favourites.txt" >nul 2>&1 && set "_lbisfav=1"
echo.
if defined _lbisfav echo    [R] Run    [F] Remove from favourites    [B] Back
if not defined _lbisfav echo    [R] Run    [F] Add to favourites    [B] Back
choice /c:RFB /n >nul
if errorlevel 3 goto cmdlib_list
if errorlevel 2 goto cmdlib_favtoggle
if not errorlevel 1 goto cmdlib_list
if not "!_lbx:{PKG}=!"=="!_lbx!" goto cmdlib_askpkg

:cmdlib_numcheck
if not "!_lbx:{NUM}=!"=="!_lbx!" goto cmdlib_asknum
goto cmdlib_confirm

:cmdlib_askpkg
echo.
set "lbp=" & set /p lbp="Package name or part of one (blank = back) >> "
call :_noin lbp || goto dcx_noinput
if not defined lbp goto cmdlib_show
call :_pkg_pick lbp inst || goto cmdlib_show
set "_PKGCHK=!lbp!"
call :_pkg_ok || goto cmdlib_badpkg
:: A storage app (contacts, messages, settings, calendar) holds data the whole phone uses.
if "!_lbrisk!"=="d" if not "!_PKGCHK:.providers.=!"=="!_PKGCHK!" goto cmdlib_store
adb shell pm path !_PKGCHK! <nul >nul 2>&1 || goto cmdlib_nopkg
set "_lbx=!_lbx:{PKG}=%_PKGCHK%!"
set "_lbu=!_lbu:{PKG}=%_PKGCHK%!"
goto cmdlib_numcheck

:cmdlib_badpkg
echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
pause >nul
goto cmdlib_show

:cmdlib_nopkg
echo  [%r%^^!%w%] !_PKGCHK! is not installed, or the phone did not answer.
pause >nul
goto cmdlib_show

:cmdlib_store
echo  [%r%x%w%] !_PKGCHK! stores data the whole phone uses, such as contacts, messages or
echo      settings. DCX will not delete it from here.
pause >nul
goto cmdlib_show

:cmdlib_asknum
set "lbn=" & set /p lbn="Number (blank = back) >> "
call :_noin lbn || goto dcx_noinput
if not defined lbn goto cmdlib_show
call :_lib_num lbn || goto cmdlib_asknum
if not "!lbn:~6!"=="" goto cmdlib_asknum
set "_lbx=!_lbx:{NUM}=%lbn%!"
set "_lbu=!_lbu:{NUM}=%lbn%!"

:cmdlib_confirm
if "!_lbrisk!"=="r" goto cmdlib_go
echo.
echo  It will run: adb shell !_lbx!
if "!_lbrisk!"=="c" echo  %y%This changes the phone.%w% Undo: !_lbu!
if "!_lbrisk!"=="d" echo  %r%This deletes data or cannot be undone.%w% Go on only if you are sure.
:: A settings write shows the value it replaces, so it can be put back by hand.
set "_lbset="
if /i "!_lbx:~0,13!"=="settings put " set "_lbset=1"
if defined _lbset for /f "tokens=3,4" %%a in ("!_lbx!") do adb shell settings get %%a %%b <nul >"!DCX_TMP!\lbnow.txt" 2>nul
if defined _lbset echo  Its value now, to put back if you want the old one:
if defined _lbset type "!DCX_TMP!\lbnow.txt" 2>nul
echo    [Y] Run it    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto cmdlib_show
if not errorlevel 1 goto cmdlib_show

:cmdlib_go
set "_lbd=!DCX_TMP!\cmdlib"
if not exist "!_lbd!\" md "!_lbd!" >nul 2>&1
if not exist "!_lbd!\" goto cmdlib_notmp
del /q "!_lbd!\*.txt" >nul 2>&1
echo.
echo  Running: adb shell !_lbx!
adb shell !_lbx! <nul >"!_lbd!\out.txt" 2>&1
set "_lbrc=!errorlevel!"
:: A redirect that failed sets no errorlevel, so the file itself is the proof the command ran.
if not exist "!_lbd!\out.txt" goto cmdlib_nofile
:: find re-terminates adb's LF-only lines, so Notepad and the line count see real lines.
find /v "" <"!_lbd!\out.txt" >"!_lbd!\view.txt" 2>nul
set "_lblines=0"
for /f %%c in ('find /c /v "" ^<"%%DCX_TMP%%\cmdlib\view.txt"') do set "_lblines=%%c"
echo  -----------------------------------------------------------------------------------------
if !_lblines! GTR 20 goto cmdlib_long
type "!_lbd!\view.txt"
goto cmdlib_result

:cmdlib_long
echo  !_lblines! lines - more than fits here. P pages through them, N opens them in Notepad.

:cmdlib_result
echo  -----------------------------------------------------------------------------------------
:: adb hands back the phone's exit code; Android 6 and older always report 0.
if "!_lbrc!"=="0" if !SDK! GTR 0 if !SDK! LSS 24 goto cmdlib_noexit
if "!_lbrc!"=="0" echo  [%g%OK%w%] The phone ran it and reported success ^(exit 0^).
if not "!_lbrc!"=="0" echo  [%y%WARN%w%] Exit !_lbrc!: the phone refused it, this Android lacks it, or the connection dropped.

:cmdlib_after
echo.
echo    [P] Page through it    [N] Open in Notepad    [S] Save to dcx_logs    [B] Back
choice /c:PNSB /n >nul
if errorlevel 4 goto cmdlib_show
if errorlevel 3 goto cmdlib_save
if errorlevel 2 goto cmdlib_notepad
if not errorlevel 1 goto cmdlib_show
more <"!_lbd!\view.txt"
goto cmdlib_after

:cmdlib_notepad
start "" notepad "!_lbd!\view.txt"
goto cmdlib_after

:cmdlib_save
if not exist "!LOGDIR!\" md "!LOGDIR!" >nul 2>&1
call :_lib_ts
set "_lbsave=!LOGDIR!\cmd_!_lbid!_!_lbts!.txt"
copy /y "!_lbd!\view.txt" "!_lbsave!" >nul 2>&1
if exist "!_lbsave!" echo  [%g%+%w%] Saved to !_lbsave!
if not exist "!_lbsave!" echo  [%r%^^!%w%] Could not save to !LOGDIR! - is the folder writable?
goto cmdlib_after

:cmdlib_noexit
echo  [%b%i%w%] Android 6 and older do not pass a command's exit code back - read the output above.
goto cmdlib_after

:cmdlib_nofile
echo  [%r%^^!%w%] Could not write !_lbd!\out.txt, so the result is unknown.
pause >nul
goto cmdlib_show

:cmdlib_notmp
echo  [%r%^^!%w%] Could not create the scratch folder !_lbd! - nothing was run.
pause >nul
goto cmdlib_show

:cmdlib_favtoggle
if not exist "!PROFDIR!\" md "!PROFDIR!" >nul 2>&1
set "_lbfav=!PROFDIR!\library_favourites.txt"
if defined _lbisfav goto cmdlib_favdel
>>"!_lbfav!" echo !_lbid!
findstr /x /c:"!_lbid!" "!_lbfav!" >nul 2>&1 && goto cmdlib_show
echo  [%r%^^!%w%] Could not write !_lbfav!
pause >nul
goto cmdlib_show

:cmdlib_favdel
findstr /v /x /c:"!_lbid!" "!_lbfav!" >"!_lbfav!.tmp" 2>nul
move /y "!_lbfav!.tmp" "!_lbfav!" >nul 2>&1
findstr /x /c:"!_lbid!" "!_lbfav!" >nul 2>&1 || goto cmdlib_show
echo  [%r%^^!%w%] Could not update !_lbfav!
pause >nul
goto cmdlib_show

:_lib_load
:: Fills the _lb_* arrays from this file's ::LIB~ lines; _lbn = entries read. The lines are DCX's
:: own text, read by a child findstr that names the path variable, so the path is not re-parsed.
for /f "delims==" %%v in ('set _lb_ 2^>nul') do set "%%v="
set "_lbn=0"
for /f "tokens=2-8 delims=~" %%a in ('findstr /b /c:"::LIB~" "%%DCX_SELF%%" 2^>nul') do (
    set /a _lbn+=1
    set "_lb_id[!_lbn!]=%%a"
    set "_lb_c[!_lbn!]=%%b"
    set "_lb_r[!_lbn!]=%%c"
    set "_lb_a[!_lbn!]=%%d"
    set "_lb_x[!_lbn!]=%%e"
    set "_lb_d[!_lbn!]=%%f"
    set "_lb_u[!_lbn!]=%%g"
)
set "_lbcatn[1]=Device info         "
set "_lbcatn[2]=Apps and packages   "
set "_lbcatn[3]=Battery and power   "
set "_lbcatn[4]=Display             "
set "_lbcatn[5]=Network             "
set "_lbcatn[6]=Diagnostics and logs"
set "_lbcatn[7]=Settings            "
set "_lbcatn[8]=Installing apps     "
for /l %%c in (1,1,8) do set "_lbcn%%c=0"
for /l %%i in (1,1,!_lbn!) do for /f "delims=12345678" %%c in ("x!_lb_c[%%i]!") do if "%%c"=="x" set /a "_lbcn!_lb_c[%%i]!+=1"
exit /b

:_lib_clearv
for /f "delims==" %%v in ('set _lbv[ 2^>nul') do set "%%v="
set "_lbk=0"
exit /b

:_lib_favadd
:: _lbf = one favourites line: an entry id, letters and digits only. Unknown ids are skipped.
if not defined _lbf exit /b
set "_lbf=!_lbf:"=#!"
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyz0123456789" %%c in ("!_lbf!") do exit /b
for /l %%i in (1,1,!_lbn!) do if "!_lb_id[%%i]!"=="!_lbf!" (
    set /a _lbk+=1
    set "_lbv[!_lbk!]=%%i"
)
exit /b

:_lib_row
:: %1 = list number. One line: the note, marked when the command changes or deletes something.
set "_lbj=!_lbv[%~1]!"
set "_lbtag="
if "!_lb_r[%_lbj%]!"=="c" set "_lbtag=  %y%[change]%w%"
if "!_lb_r[%_lbj%]!"=="d" set "_lbtag=  %r%[deletes]%w%"
set "_lbnum=  %~1"
echo    %g%[%w%!_lbnum:~-2!%g%]%w% !_lb_d[%_lbj%]!!_lbtag!
exit /b

:_lib_num
:: Arg 1 = NAME of a variable: errorlevel 0 if it holds a whole number, with no leading zero
:: unless it is 0 itself. Pipe-free, so the text is never re-parsed.
set "_lbq=!%~1!"
if not defined _lbq exit /b 1
set "_lbq=!_lbq:"=#!"
for /f "eol=0 delims=0123456789" %%c in ("!_lbq!") do exit /b 1
if "!_lbq!"=="0" exit /b 0
if "!_lbq:~0,1!"=="0" exit /b 1
exit /b 0

:_lib_ts
:: _lbts = a file-name-safe timestamp from date and time, as Backup builds it.
set "_lbts=%date%_%time%"
set "_lbts=%_lbts::=-%"
set "_lbts=%_lbts:/=-%"
set "_lbts=%_lbts:\=-%"
set "_lbts=%_lbts:.=-%"
set "_lbts=%_lbts:,=-%"
set "_lbts=%_lbts: =_%"
exit /b

:: ===================================================================
:: Bootloader info: reboots a USB phone into its bootloader, reads the bootloader's own facts with
:: fastboot getvar (read-only: the protocol defines getvar as reading a variable), shows them and
:: boots the phone back. fastboot honours FASTBOOT_DEVICE and ANDROID_SERIAL and waits forever for
:: a serial it cannot see, so every call goes through :_fb_run with -s and both cleared. Values the
:: phone sends are only ever printed by findstr from a file, never put into a variable.
:: ===================================================================
:fbinfo
cls
title Bootloader info
call :logo
echo                          %b%[%w% Bootloader info %b%]%w%
echo.
echo  Reads what the bootloader reports: whether it is unlocked, secure boot, the active slot,
echo  the bootloader and radio versions. Read-only - nothing is flashed, erased or unlocked.
echo  The phone leaves Android for its bootloader ^(fastboot mode^); DCX boots it back after.
echo.
echo  %y%USB only.%w% Windows needs a driver for the bootloader mode as well: Google's USB Driver for
echo  a Pixel, the maker's own driver for other phones. Without one, DCX waits and then says so.
echo.
set "_fbexe="
if exist "!DCX_DIR!adb\fastboot.exe" set "_fbexe=!DCX_DIR!adb\fastboot.exe"
if not defined _fbexe call :_fb_where
if not defined _fbexe goto fbinfo_noexe
set "_fbd=!DCX_TMP!\fastboot"
if exist "!_fbd!\" rd /s /q "!_fbd!" >nul 2>&1
md "!_fbd!" >nul 2>&1
if not exist "!_fbd!\" goto fbinfo_notmp
set "_fbser=" & set "_fbadb=!ANDROID_SERIAL!"
:: A phone already in fastboot mode needs no reboot.
call :_fb_list before
:: Already in fastboot: the adb target may be another phone, so the wait for Android uses this one.
if !_fbn! GEQ 1 (set "_fbadb=" & goto fbinfo_pick)
set "_dvst="
for /f "delims=" %%d in ('adb get-state 2^>nul ^<nul') do set "_dvst=%%d"
if /i not "!_dvst!"=="device" goto fbinfo_nodev
:: The bootloader has no Wi-Fi.
call :_wifi_ser _fbadb && goto fbinfo_wifi
echo    [Y] Reboot to the bootloader and read it    [N] Back
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto fbinfo_cancel
if not errorlevel 1 goto fbinfo_cancel
adb reboot bootloader <nul >nul 2>&1
if errorlevel 1 goto fbinfo_rebootfail
echo  Rebooting to the bootloader. Waiting for it to show up - up to 60 s. Q stops waiting.
set "_fbw=0"

:fbinfo_wait
call :_fb_list now
if !_fbn! GEQ 1 goto fbinfo_pick
set /a _fbw+=2
if !_fbw! GEQ 60 goto fbinfo_timeout
choice /c:QN /n /t 2 /d N >nul
if errorlevel 2 goto fbinfo_wait
goto fbinfo_stuck

:fbinfo_timeout
echo.
echo  [%r%^^!%w%] No phone in fastboot mode after 60 s. Usually Windows has no driver for it:
echo      Device Manager then lists the phone under Other devices with a yellow mark. Install
echo      Google's USB Driver ^(Pixel^) or the maker's driver, then try again.
echo      Some makers' bootloader key combos lead to a download mode that is not fastboot.
echo    [W] Wait 60 s more    [Q] Stop waiting
choice /c:WQ /n >nul
if errorlevel 2 goto fbinfo_stuck
if not errorlevel 1 goto fbinfo_stuck
set "_fbw=0"
goto fbinfo_wait

:fbinfo_stuck
echo.
echo  The phone may still be in its bootloader. To start Android: pick Start or Reboot with
echo  the volume keys and press power, or hold power for about 15 s.
goto fbinfo_end

:fbinfo_pick
:: Prefer the serial adb used; else a single listed phone; else ask.
if defined _fbadb for /l %%i in (1,1,!_fbn!) do if "!_fbs[%%i]!"=="!_fbadb!" set "_fbser=!_fbadb!"
if not defined _fbser if !_fbn! EQU 1 set "_fbser=!_fbs[1]!"
if defined _fbser goto fbinfo_read
echo.
echo  More than one phone is in fastboot mode:
for /l %%i in (1,1,!_fbn!) do echo     %g%[%w%%%i%g%]%w% !_fbs[%%i]!

:fbinfo_pick_ask
set "fbp=" & set /p fbp="Phone number (Enter = back) >> "
call :_noin fbp || goto dcx_noinput
if not defined fbp goto fbinfo_end
call :_lib_num fbp || goto fbinfo_pick_ask
if not defined _fbs[!fbp!] goto fbinfo_pick_ask
for /f "delims=" %%k in ("!fbp!") do set "_fbser=!_fbs[%%k]!"

:fbinfo_read
echo.
echo  Reading the bootloader of !_fbser!...
set "_fbargs=-s !_fbser! getvar product getvar variant getvar serialno getvar secure getvar unlocked getvar is-userspace getvar current-slot getvar slot-count getvar version-bootloader getvar version-baseband getvar battery-voltage getvar battery-soc-ok"
set "_fbout=!_fbd!\vars.txt"
call :_fb_run 20
if "!_fbrc!"=="124" goto fbinfo_hung
findstr /b /c:"Finished." "!_fbout!" >nul 2>&1 || goto fbinfo_readfail
cls
title Bootloader info - !_fbser!
call :logo
echo  %b%What the bootloader reports%w%   ^("not reported" = this bootloader does not answer it^)
echo.
for %%v in (product variant serialno secure unlocked is-userspace current-slot slot-count version-bootloader version-baseband battery-voltage battery-soc-ok) do call :_fb_show %%v
echo.
findstr /x /c:"unlocked: yes" "!_fbout!" >nul 2>&1 && echo  %y%Unlocked:%w% this bootloader accepts any image. Locking it again wipes the phone.
findstr /x /c:"unlocked: no" "!_fbout!" >nul 2>&1 && echo  Locked: only images signed by the maker boot.
findstr /x /c:"is-userspace: yes" "!_fbout!" >nul 2>&1 && echo  This is fastbootd, Android's own fastboot - not the bootloader itself.
echo.
echo    [R] Reboot to Android    [S] Save the full list ^(getvar all^) to dcx_logs    [L] Leave it here
:: Only R reboots: Ctrl+C makes choice return 0, which leaves the phone where it is.
choice /c:RSL /n >nul
if errorlevel 3 goto fbinfo_stuck
if errorlevel 2 goto fbinfo_saveall
if errorlevel 1 goto fbinfo_boot
goto fbinfo_stuck

:fbinfo_saveall
set "_fbargs=-s !_fbser! getvar all"
set "_fbout=!_fbd!\all.txt"
call :_fb_run 30
if not exist "!LOGDIR!\" md "!LOGDIR!" >nul 2>&1
call :_lib_ts
set "_fbsave=!LOGDIR!\bootloader_!_lbts!.txt"
find /v "" <"!_fbout!" >"!_fbsave!" 2>nul
if "!_fbrc!"=="124" echo  [%y%WARN%w%] getvar all stopped answering - the file holds what came before that.
if exist "!_fbsave!" echo  [%g%+%w%] Saved to !_fbsave!
if not exist "!_fbsave!" echo  [%r%^^!%w%] Could not save to !LOGDIR!
echo    [R] Reboot to Android    [L] Leave it here
choice /c:RL /n >nul
if errorlevel 2 goto fbinfo_stuck
if errorlevel 1 goto fbinfo_boot
goto fbinfo_stuck

:fbinfo_boot
:: A phone found already in fastboot mode has no adb serial yet; its USB serial is normally the same.
if not defined _fbadb set "_fbadb=!_fbser!"
echo.
echo  Rebooting to Android...
set "_fbargs=-s !_fbser! reboot"
set "_fbout=!_fbd!\reboot.txt"
call :_fb_run 15
findstr /c:"OKAY" "!_fbout!" >nul 2>&1 || goto fbinfo_bootfail
echo  [%g%+%w%] The bootloader accepted the reboot. Waiting for Android - up to 2 minutes.
set "_fbw=0"

:fbinfo_back
set "_dvst="
for /f "skip=1 tokens=1,2" %%a in ('adb devices ^<nul 2^>nul') do if "%%a"=="!_fbadb!" set "_dvst=%%b"
if "!_dvst!"=="device" goto fbinfo_backok
set /a _fbw+=3
if !_fbw! GEQ 120 goto fbinfo_backslow
timeout /t 3 /nobreak >nul
goto fbinfo_back

:fbinfo_backok
echo  [%g%OK%w%] The phone is back in Android.
goto fbinfo_end

:fbinfo_backslow
echo  [%y%WARN%w%] Android has not reconnected after 2 minutes. It may still be booting, or the
echo         USB debugging prompt is waiting on the phone. Reconnect from the main menu.
goto fbinfo_end

:fbinfo_bootfail
echo  [%r%^^!%w%] The bootloader did not accept the reboot. Start the phone with its power key:
echo      pick Start or Reboot with the volume keys and press power, or hold power for 15 s.
goto fbinfo_end

:fbinfo_hung
echo  [%r%^^!%w%] fastboot stopped answering after 20 s and was stopped. The phone is still in
echo      its bootloader.
goto fbinfo_boot_offer

:fbinfo_readfail
echo  [%r%^^!%w%] fastboot did not finish reading:
type "!_fbout!" 2>nul

:fbinfo_boot_offer
echo    [R] Try to reboot it to Android    [L] Leave it here
choice /c:RL /n >nul
if errorlevel 2 goto fbinfo_stuck
if not errorlevel 1 goto fbinfo_stuck
goto fbinfo_boot

:fbinfo_cancel
if exist "!_fbd!\" rd /s /q "!_fbd!" >nul 2>&1
goto shell

:fbinfo_noexe
echo  [%r%^^!%w%] fastboot.exe was not found next to adb.exe or on PATH. It ships in Google's
echo      SDK Platform-Tools, the same download as adb.
goto fbinfo_end

:fbinfo_notmp
echo  [%r%^^!%w%] Could not create the scratch folder !_fbd!
goto fbinfo_end

:fbinfo_nodev
echo  [%r%^^!%w%] No phone in Android with USB debugging allowed, and none in fastboot mode.
goto fbinfo_end

:fbinfo_wifi
echo  [%r%^^!%w%] The phone is connected over Wi-Fi ^(!_fbadb!^). The bootloader only talks over USB:
echo      plug in the cable, pick the USB entry under Wireless ADB - Select target, and retry.
goto fbinfo_end

:fbinfo_rebootfail
echo  [%r%^^!%w%] The phone refused to reboot to the bootloader, or the connection dropped.

:fbinfo_end
if exist "!_fbd!\" rd /s /q "!_fbd!" >nul 2>&1
echo.
echo Press Any Button To Go Back
pause >nul
goto shell

:_fb_list
:: Fills _fbs[1.._fbn] from fastboot devices: a USB serial, then the state. Returns at once and
:: exits 0 even with nothing attached. Network entries and the ? placeholder are left out. The
:: lines are the phone's text: each is read with delayed expansion off and checked before use.
for /f "delims==" %%v in ('set _fbs[ 2^>nul') do set "%%v="
set "_fbn=0"
fastboot devices <nul >"!_fbd!\devices.txt" 2>nul
type nul >"!_fbd!\devices.ok"
for /f "usebackq tokens=1,2" %%a in ("!_fbd!\devices.txt") do (
    setlocal DisableDelayedExpansion
    set "_fba=%%a"
    set "_fbb=%%b"
    call :_fb_take
    endlocal
)
for /f "usebackq delims=" %%s in ("!_fbd!\devices.ok") do (
    set /a _fbn+=1
    set "_fbs[!_fbn!]=%%s"
)
exit /b

:_fb_take
:: _fba/_fbb = one fastboot devices line, delayed expansion off. Keeps the serial when the state is
:: fastboot and the serial is letters, digits, dots, dashes and underscores.
setlocal EnableDelayedExpansion
if /i not "!_fbb!"=="fastboot" (endlocal & exit /b)
if not defined _fba (endlocal & exit /b)
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_fba!") do (endlocal & exit /b)
>>"!_fbd!\devices.ok" echo(!_fba!
endlocal
exit /b

:_fb_show
:: %1 = a getvar name. Prints the phone's own line for it from the output file, or not reported.
findstr /b /c:"%~1: " "!_fbout!" 2>nul || echo %~1: not reported
exit /b

:_fb_run
:: Runs fastboot with _fbargs, both streams into the file _fbout, under a watchdog of %1 s: on
:: Windows its USB reads have no timeout, so a stalled bootloader would hang DCX. _fbrc = its exit
:: code, 124 = stopped by the watchdog. The serial variables are cleared for this call only.
setlocal
set "ANDROID_SERIAL="
set "FASTBOOT_DEVICE="
set "DCX_FBX=!_fbexe!"
set "DCX_FBA=!_fbargs!"
set "DCX_FBO=!_fbout!"
set "DCX_FBT=%~1"
powershell -NoProfile -Command "$p = Start-Process -FilePath $env:DCX_FBX -ArgumentList $env:DCX_FBA -NoNewWindow -PassThru -RedirectStandardError ($env:DCX_FBO + '.raw') -RedirectStandardOutput ($env:DCX_FBO + '.out'); $null = $p.Handle; if (-not $p.WaitForExit([int]$env:DCX_FBT * 1000)) { $p.Kill(); exit 124 }; exit $p.ExitCode" <nul
set "_rc=!errorlevel!"
:: PowerShell resets the code page. chcp gets its own empty input: it reads a redirected one to the end.
chcp 65001 >nul <nul
:: find re-terminates LF-only lines, so the whole-line findstr /x checks above can match.
find /v "" <"!_fbout!.raw" >"!_fbout!" 2>nul
endlocal & set "_fbrc=%_rc%"
exit /b

:_fb_where
:: _fbexe = fastboot.exe, the bare name, when one is on PATH; Start-Process finds it there. Not the
:: path: carried out through endlocal & set, it would lose a ! to the caller's delayed expansion.
for %%f in (fastboot.exe) do if not "%%~$PATH:f"=="" set "_fbexe=fastboot.exe"
exit /b

:: ===================================================================
:: Sideload an update: sends an OTA package to the phone's recovery with adb sideload. In sideload
:: mode recovery answers success to adb whatever the install did, so adb's exit 0 only proves the
:: transfer. DCX records the build fingerprint first and compares it once Android is back: that is
:: the honest verdict. USB only - recovery's adb has no network side.
:: ===================================================================
:sideload
cls
title Sideload an update
call :logo
echo                        %b%[%w% Sideload an update package %b%]%w%
echo.
echo  Installs a full OTA update package ^(.zip^) through the phone's recovery, as the makers'
echo  own pages describe. Stock recovery checks the package's signature and refuses one made for
echo  another phone or an older build; your data stays. %y%A custom recovery checks nothing%w%: there,
echo  only send a package made for this exact phone and build, and if the phone asks whether to
echo  install although the signature check failed, answer No.
echo  USB only. Keep the cable in until the phone says the install has finished.
echo.
set "_sld=!DCX_TMP!\sideload"
if exist "!_sld!\" rd /s /q "!_sld!" >nul 2>&1
md "!_sld!" >nul 2>&1
if not exist "!_sld!\" goto sideload_notmp
call :_wifi_ser ANDROID_SERIAL && goto sideload_wifi

:sideload_ask
set "slf=" & set /p slf="Path of the .zip - drag it into this window (Enter = back) >> "
call :_noin slf || goto dcx_noinput
if not defined slf goto sideload_end
set "slf=!slf:"=!"
if not defined slf goto sideload_ask
:: A wildcard would make the for below match other files; no file name holds one. Tested by
:: substitution: a for variable holding the path would lose a ! to delayed expansion. *X=
:: replaces up to the first X, so **= changes the text only when it holds a star.
if not "!slf:**=!"=="!slf!" goto sideload_badfile
if not "!slf:?=!"=="!slf!" goto sideload_badfile
:: The path is read late everywhere: a %%~f of it would lose a ! to delayed expansion. A folder is
:: told by its attribute, which starts with d.
if not exist "!slf!" goto sideload_badfile
set "_sla="
for %%F in ("!slf!") do set "_sla=%%~aF"
if /i "!_sla:~0,1!"=="d" goto sideload_badfile
set "_slsz="
for %%F in ("!slf!") do if /i "%%~xF"==".zip" set "_slsz=%%~zF"
if not defined _slsz goto sideload_badfile
if "!_slsz!"=="0" goto sideload_badfile
set "_slmb=!_slsz:~0,-6!"
if not defined _slmb set "_slmb=0"
:: Recovery takes at most 2^18 blocks of 64 KiB (16 GiB); before Android 10 it read the size as a
:: 32-bit int (under 2 GiB). Compared in MB: cmd's if is 32-bit, a byte count can be larger.
if !_slmb! GTR 17179 goto sideload_toobig
if !SDK! GTR 0 if !SDK! LSS 29 if !_slmb! GEQ 2147 goto sideload_toobig
echo.
echo  File      !slf!
echo  Size      about !_slmb! MB
echo  Checksum  working out SHA-256...
certutil -hashfile "!slf!" SHA256 >"!_sld!\hash.txt" 2>nul
set "_slh="
for /f "usebackq delims=" %%h in ("!_sld!\hash.txt") do (
    set "_slx=%%h"
    call :_sl_hex
)
if defined _slh echo  SHA-256   !_slh!
if defined _slh echo            Compare it with the checksum on the page you downloaded it from.
if not defined _slh echo  [%y%WARN%w%] certutil could not hash the file - check it yourself before sending.
echo.
:: The build before the update, so the result can be checked once Android is back.
set "_slbefore="
adb shell getprop ro.build.fingerprint <nul >"!_sld!\before.txt" 2>nul
for %%F in ("!_sld!\before.txt") do if %%~zF GTR 1 set "_slbefore=1"
if defined _slbefore echo  Build now: & type "!_sld!\before.txt"
if not defined _slbefore echo  The build cannot be read now, so DCX cannot check the result later - read the phone's screen.
set "_slbat="
adb shell dumpsys battery <nul >"!_sld!\bat.txt" 2>nul
for /f "tokens=2 delims=:" %%a in ('findstr /r /c:"^ *level: *[0-9][0-9]*" "%%DCX_TMP%%\sideload\bat.txt" 2^>nul') do set "_slbat=%%a"
if defined _slbat set "_slbat=!_slbat: =!"
if defined _slbat for /f "delims=" %%x in ("!_slbat!") do set "_slbat=%%x"
if defined _slbat for /f "delims=0123456789" %%x in ("!_slbat!") do set "_slbat="
if defined _slbat if !_slbat! LSS 50 echo  %y%Battery at !_slbat!%%.%w% An install can take many minutes - charge to 50%% or more first.
echo.

:sideload_mode
echo  How should the phone get ready?
echo                 %g%[%w%1%g%]%w% Reboot it into sideload mode now   (Android 10 and newer)
echo                 %g%[%w%2%g%]%w% Reboot it into recovery - I pick "Apply update from ADB" myself
echo                 %g%[%w%3%g%]%w% It already waits: recovery shows "Apply update from ADB"
echo                 %g%[%w%4%g%]%w% Back
set "slm=" & set /p slm="Choose An Option >> "
call :_noin slm || goto dcx_noinput
set "_slopt=!slm!"
if "!slm!"=="1" goto sideload_reboot
if "!slm!"=="2" goto sideload_recovery
if "!slm!"=="3" goto sideload_wait0
if "!slm!"=="4" goto sideload_end
goto sideload_mode

:sideload_reboot
:: Android 6-9 need root for this and answer a refusal with exit 0; init does it from Android 10.
if !SDK! GTR 0 if !SDK! LSS 29 echo  This phone runs Android 9 or older: it cannot do that without root. Use option 2.
if !SDK! GTR 0 if !SDK! LSS 29 goto sideload_mode
adb reboot sideload <nul >nul 2>&1
if errorlevel 1 goto sideload_rebootfail
goto sideload_wait0

:sideload_recovery
adb reboot recovery <nul >nul 2>&1
if errorlevel 1 goto sideload_rebootfail
echo  On the phone, in recovery: pick "Apply update from ADB" with the volume keys, press power.

:sideload_wait0
echo  Waiting for the phone in sideload mode - up to 3 minutes. Q stops waiting.
set "_slw=0" & set "_slrec="

:sideload_wait
call :_sl_state
if "!_slst!"=="sideload" if defined _slser goto sideload_confirm
if "!_slst!"=="recovery" if not defined _slrec echo  The phone is in recovery: pick "Apply update from ADB" on it.
if "!_slst!"=="recovery" set "_slrec=1"
set /a _slw+=3
if !_slw! GEQ 180 goto sideload_waitlong
choice /c:QN /n /t 3 /d N >nul
if errorlevel 2 goto sideload_wait
goto sideload_end

:sideload_waitlong
echo.
echo  [%r%^^!%w%] No phone in sideload mode after 3 minutes.
if "!_slst!"=="device" if "!_slopt!"=="1" echo      It is back in Android: this phone does not support adb reboot sideload. Use option 2.
if "!_slst!"=="device" if not "!_slopt!"=="1" echo      It is in Android: recovery's "Apply update from ADB" screen was never reached.
echo      In recovery, "Apply update from ADB" must be on screen. If Windows lists the phone under
echo      Other devices with a yellow mark, recovery needs the USB driver too.
goto sideload_end

:sideload_confirm
echo.
echo  [%g%+%w%] The phone is in sideload mode.
echo  Send !slf! to !_slser! now? The phone checks it, then installs it. This takes several minutes.
echo  Answer within 5 minutes: recovery stops waiting for the package after that.
echo    [Y] Send it    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto sideload_cancel
if not errorlevel 1 goto sideload_cancel
echo.
adb -s !_slser! sideload "!slf!" 2>"!_sld!\err.txt"
set "_slrc=!errorlevel!"
echo.
type "!_sld!\err.txt" 2>nul
if not "!_slrc!"=="0" goto sideload_xferfail
echo  [%b%i%w%] The whole package reached the phone ^(adb exit 0^). That is not yet an install:
echo      in sideload mode the phone answers success either way. Read its screen now -
echo      "Install from ADB completed with status 0" means it installed; an error there means not.
echo      Then pick "Reboot system now" on the phone.
goto sideload_check

:sideload_xferfail
:: Only adb's own words tell these apart; each needs a different answer.
findstr /c:"sideload connection failed" "!_sld!\err.txt" >nul 2>&1 && goto sideload_nosend
findstr /c:"failed to stat file" /c:"failed to open file" "!_sld!\err.txt" >nul 2>&1 && goto sideload_nofile
findstr /c:"failed to read command:" "!_sld!\err.txt" >nul 2>&1 && goto sideload_unknown
echo  [%r%^^!%w%] The transfer stopped ^(adb exit !_slrc!^). If the phone had started installing, the
echo      result is unknown: read its screen, then pick "Reboot system now" on it.
goto sideload_check

:sideload_unknown
echo  [%y%WARN%w%] The phone closed the connection without its final signal. That also happens after a
echo         good install, always with Android 9 and older recoveries, so the result is unknown.
echo         Read the phone's screen, then pick "Reboot system now" on it.
goto sideload_check

:sideload_nosend
echo  [%r%^^!%w%] Nothing was sent: adb could not reach the phone in sideload mode. Check that recovery
echo      shows "Apply update from ADB" and that the cable is in, then try option 3.
goto sideload_end

:sideload_nofile
echo  [%r%^^!%w%] Nothing was sent: adb could not read the file. Copy it to a short path, such as
echo      C:\ota.zip, and try again.
goto sideload_end

:sideload_toobig
echo  [%r%x%w%] The phone's recovery cannot take a package of !_slmb! MB: the limit is 16 GiB, and
echo      2 GiB before Android 10. Nothing was sent.
goto sideload_end

:sideload_check
if not defined _slbefore goto sideload_end
echo.
echo    [W] Wait for Android and check the build    [S] Skip the check
choice /c:WS /n >nul
if errorlevel 2 goto sideload_end
if not errorlevel 1 goto sideload_end
echo  Waiting for Android - the first boot after an update can take 10 minutes. Q stops waiting.
set "_slw=0"

:sideload_back
call :_sl_state
if "!_slst!"=="device" goto sideload_compare
set /a _slw+=5
if !_slw! GEQ 900 goto sideload_backslow
choice /c:QN /n /t 5 /d N >nul
if errorlevel 2 goto sideload_back
goto sideload_end

:sideload_compare
adb shell getprop ro.build.fingerprint <nul >"!_sld!\after.txt" 2>nul
for %%F in ("!_sld!\after.txt") do if %%~zF LEQ 1 goto sideload_retry
echo  Build now:
type "!_sld!\after.txt"
fc /b "!_sld!\before.txt" "!_sld!\after.txt" >nul 2>&1
if errorlevel 2 goto sideload_backslow
if errorlevel 1 goto sideload_changed
echo  [%y%WARN%w%] The build is the same as before: the update did not install, or the package held
echo         the build the phone already had.
goto sideload_end

:sideload_retry
:: Listed as a device, but its shell did not answer yet: wait and read again, within the same limit.
set /a _slw+=5
if !_slw! GEQ 900 goto sideload_backslow
choice /c:QN /n /t 5 /d N >nul
if errorlevel 2 goto sideload_back
goto sideload_end

:sideload_changed
echo  [%g%OK%w%] The build changed - the update is installed.
goto sideload_end

:sideload_backslow
echo  [%y%WARN%w%] Android did not answer in 15 minutes, so the build could not be checked. Once it
echo         is up, compare Settings - About phone with the package you sent.
goto sideload_end

:sideload_cancel
echo  Nothing was sent. The phone still waits in sideload mode: pick "Reboot system now" on it.
goto sideload_end

:sideload_rebootfail
echo  [%r%^^!%w%] The phone did not accept the reboot, or the connection dropped.
goto sideload_end

:sideload_badfile
echo  [%r%x%w%] That is not an existing .zip file. Drag the file itself into the window.
goto sideload_ask

:sideload_wifi
echo  [%r%^^!%w%] The phone is connected over Wi-Fi ^(!ANDROID_SERIAL!^). Recovery only talks over USB:
echo      plug in the cable, pick the USB entry under Wireless ADB - Select target, and retry.
goto sideload_end

:sideload_notmp
echo  [%r%^^!%w%] Could not create the scratch folder !_sld!

:sideload_end
if exist "!_sld!\" rd /s /q "!_sld!" >nul 2>&1
echo.
echo Press Any Button To Go Back
pause >nul
goto shell

:_sl_state
:: _slst = adb's state for the target (device, sideload, recovery, ...; empty when it is not listed)
:: and _slser = the serial to sideload to. Recovery can list the phone under another serial, so a
:: single phone in sideload mode is taken only when the target is not listed at all: a target still
:: in Android or recovery must never hand the package to another phone. Lines are the phone's text,
:: read with delayed expansion off and checked before use.
set "_slst=" & set "_slser=" & set "_sl1=" & set "_sln=0"
adb devices <nul >"!_sld!\devices.txt" 2>nul
type nul >"!_sld!\devices.ok"
for /f "usebackq skip=1 tokens=1,2" %%a in ("!_sld!\devices.txt") do (
    setlocal DisableDelayedExpansion
    set "_sla1=%%a"
    set "_sla2=%%b"
    call :_sl_take
    endlocal
)
for /f "usebackq tokens=1,2" %%a in ("!_sld!\devices.ok") do (
    if "%%a"=="!ANDROID_SERIAL!" set "_slst=%%b"
    if "%%b"=="sideload" (
        set /a _sln+=1
        set "_sl1=%%a"
    )
)
if "!_slst!"=="sideload" set "_slser=!ANDROID_SERIAL!"
if not defined _slst if "!_sln!"=="1" set "_slser=!_sl1!"
if defined _slser set "_slst=sideload"
exit /b

:_sl_take
:: _sla1/_sla2 = one adb devices line (serial, state), delayed expansion off. Kept only when both
:: hold letters, digits, dots, dashes, underscores and colons.
setlocal EnableDelayedExpansion
if not defined _sla1 (endlocal & exit /b)
if not defined _sla2 (endlocal & exit /b)
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-" %%c in ("!_sla1!!_sla2!") do (endlocal & exit /b)
>>"!_sld!\devices.ok" echo(!_sla1! !_sla2!
endlocal
exit /b

:_sl_hex
:: _slx = one line of certutil's answer. Keeps it as _slh when it is 64 hex digits; older Windows
:: puts a space between bytes, so spaces are dropped first. The other lines are localized text.
if not defined _slx exit /b
set "_slx=!_slx: =!"
if not "!_slx:~63,1!"=="" if "!_slx:~64!"=="" (
    for /f "eol=0 delims=0123456789abcdefABCDEF" %%c in ("!_slx!") do exit /b
    set "_slh=!_slx!"
)
exit /b

:: ===================================================================
:: Logcat capture: the crash log the phone keeps, or a recording made while you reproduce a problem.
:: A recording is adb logcat in a hidden process started by PowerShell, which hands back its PID; Q
:: stops exactly that process, after checking it is still adb.exe. Nothing goes by window title:
:: with Windows Terminal as the console, the title belongs to the terminal itself. The PID is also
:: kept in dcx_logs, so a recording a closed window left running is stopped on the next visit.
:: ===================================================================
:logcap
cls
title Logcat capture
call :logo
echo                          %b%[%w% Logcat capture %b%]%w%
echo.
call :_lc_leftover
echo  Recordings and crash logs are saved in !LOGDIR!
echo.
echo                 %g%[%w%1%g%]%w% Crash log - the app crashes the phone still remembers
echo                 %g%[%w%2%g%]%w% Record one app while you reproduce a problem
echo                 %g%[%w%3%g%]%w% Record everything while you reproduce a problem
echo                 %g%[%w%4%g%]%w% Open the dcx_logs folder
echo                 %g%[%w%5%g%]%w% Back
set "lcm=" & set /p lcm="Choose An Option >> "
call :_noin lcm || goto dcx_noinput
if "!lcm!"=="1" goto logcap_crash
if "!lcm!"=="2" goto logcap_app
if "!lcm!"=="3" goto logcap_all
if "!lcm!"=="4" goto logcap_folder
if "!lcm!"=="5" goto shell
goto logcap

:logcap_folder
if not exist "!LOGDIR!\" md "!LOGDIR!" >nul 2>&1
start "" explorer "!LOGDIR!"
goto logcap

:logcap_crash
:: The crash buffer exists from Android 5.0.
if !SDK! GTR 0 if !SDK! LSS 21 goto logcap_old
if not exist "!LOGDIR!\" md "!LOGDIR!" >nul 2>&1
call :_lib_ts
set "_lcf=!LOGDIR!\crash_!_lbts!.txt"
echo.
echo  Reading the crash log...
adb logcat -b crash -d -v threadtime <nul >"!_lcf!" 2>nul
set "_lcrc=!errorlevel!"
if not "!_lcrc!"=="0" goto logcap_crash_fail
:: A redirect that failed sets no errorlevel: only the file proves adb ran.
if not exist "!_lcf!" goto logcap_nofile
call :_lc_count
echo.
if "!_lclines!"=="0" echo  The crash log is empty: nothing crashed since the phone started, or since it was cleared.
if "!_lclines!"=="0" goto logcap_view
echo  !_lclines! lines, !_lcfat! app crash^(es^). The apps that crashed:
findstr /c:"Process: " "!_lcf!" 2>nul
goto logcap_view

:logcap_crash_fail
echo  [%r%^^!%w%] The phone did not hand over its crash log ^(adb exit !_lcrc!^) - is it still connected?
del "!_lcf!" >nul 2>&1
goto logcap_end

:logcap_nofile
echo  [%r%^^!%w%] Could not write !_lcf! - is dcx_logs writable?
goto logcap_end

:logcap_old
echo  [%r%^^!%w%] This phone runs Android 4.4 or older, which keeps no separate crash log.
goto logcap_end

:logcap_app
echo.
set "lcp=" & set /p lcp="Package name or part of one (blank = back) >> "
call :_noin lcp || goto dcx_noinput
if not defined lcp goto logcap
call :_pkg_pick lcp inst || goto logcap
set "_PKGCHK=!lcp!"
call :_pkg_ok || goto logcap_badpkg
set "_pmpkg=!_PKGCHK!"
set "_pmuid=" & set "_pminst="
:: pm list packages -U exists from Android 8; older phones are checked with pm path and get no uid.
if !SDK! GEQ 26 call :_pm_uid
if !SDK! LSS 26 adb shell pm path !_PKGCHK! <nul >"!DCX_TMP!\lcpath.txt" 2>nul
if !SDK! LSS 26 findstr /b /c:"package:" "!DCX_TMP!\lcpath.txt" >nul 2>&1 && set "_pminst=1"
if not defined _pminst goto logcap_nopkg
set "_lcpkg=!_PKGCHK!"
goto logcap_rec

:logcap_badpkg
echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
goto logcap_end

:logcap_nopkg
echo  [%r%^^!%w%] !_PKGCHK! is not installed, or the phone did not answer.
goto logcap_end

:logcap_all
set "_lcpkg=" & set "_pmuid="

:logcap_rec
:: One app: Android 12+ filters on the phone (--uid); 7-11 adds the uid column and DCX filters the
:: saved file afterwards; older Android cannot tell apps apart in its log.
set "_lcmode=all"
if defined _lcpkg if defined _pmuid if !SDK! GEQ 31 set "_lcmode=uid"
if defined _lcpkg if defined _pmuid if !SDK! GEQ 26 if !SDK! LSS 31 set "_lcmode=col"
echo.
if defined _lcpkg if "!_lcmode!"=="all" echo  %y%This Android cannot tell apps apart in its log, so everything is recorded.%w%
:: Start from now, not with what the buffer already holds: -T takes epoch seconds from Android 7.
:: All digits would be read as a line count, hence the .000.
set "_lcsince="
if !SDK! GEQ 24 for /f "delims=" %%t in ('adb shell date +%%s 2^>nul ^<nul') do set "_lcsince=%%t"
if defined _lcsince for /f "delims=" %%t in ("!_lcsince!") do set "_lcsince=%%t"
if defined _lcsince call :_lib_num _lcsince || set "_lcsince="
set "_lcargs=logcat -v threadtime"
if "!_lcmode!"=="col" set "_lcargs=!_lcargs! -v uid"
set "_lcargs=!_lcargs! -b main -b system"
if !SDK! GEQ 21 set "_lcargs=!_lcargs! -b crash"
if "!_lcmode!"=="uid" set "_lcargs=!_lcargs! --uid=!_pmuid!"
if defined _lcsince set "_lcargs=!_lcargs! -T !_lcsince!.000"
if defined ANDROID_SERIAL set "_lcargs=-s !ANDROID_SERIAL! !_lcargs!"
if not exist "!LOGDIR!\" md "!LOGDIR!" >nul 2>&1
call :_lib_ts
set "_lcf=!LOGDIR!\logcat_!_lbts!.txt"
if defined _lcpkg set "_lcf=!LOGDIR!\logcat_!_lcpkg!_!_lbts!.txt"
call :_lc_start || goto logcap_startfail
echo  %m%Recording%w% - reproduce the problem on the phone now.   %g%Q%w% stops the recording.
echo  The window title shows how long it has run.
:: Elapsed time comes from the clock: a tick takes longer than its 3 s wait.
call :_pm_now
set "_pmstart=!_pmnow!"

:logcap_tick
choice /c:QN /n /t 3 /d N >nul
if errorlevel 2 goto logcap_tick_on
goto logcap_stop

:logcap_tick_on
call :_lc_alive || goto logcap_lost
call :_pm_el
title Recording - !_pmelt! - press Q to stop
goto logcap_tick

:logcap_lost
call :_pm_el
echo  [%y%WARN%w%] The recording stopped by itself after !_pmelt!: the phone disconnected, or
echo         adb could not reach it. What came before that is saved.
goto logcap_done

:logcap_stop
call :_lc_stop
call :_pm_el
echo  Stopped after !_pmelt!.

:logcap_done
title Logcat capture
del "!LOGDIR!\.recording.pid" >nul 2>&1
set "_lcpid="
for %%F in ("!_lcf!") do if %%~zF EQU 0 if exist "!_lcf!.err" type "!_lcf!.err"
del "!_lcf!.err" >nul 2>&1
if not "!_lcmode!"=="col" goto logcap_sum
:: Android 7-11: keep the app's own lines, matched on the uid column right after the time.
set "_lcall=!_lcf!"
set "_lcf=!LOGDIR!\logcat_!_lcpkg!_!_lbts!_app.txt"
:: /b anchors the match: a ^ on a line holding !var! is eaten by delayed expansion. logcat prints
:: uids 10000-10009 by their 5-letter names, u0_a0 .. u0_a9, so those are matched by name too.
set "_lcun="
if !_pmuid! GEQ 10000 if !_pmuid! LEQ 10009 set /a "_lcun=_pmuid-10000"
if defined _lcun findstr /b /r /c:"[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]* *!_pmuid! " /c:"[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]* *u0_a!_lcun! " "!_lcall!" >"!_lcf!" 2>nul
if not defined _lcun findstr /b /r /c:"[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]* *!_pmuid! " "!_lcall!" >"!_lcf!" 2>nul
echo  The whole log is in !_lcall!

:logcap_sum
call :_lc_count
echo.
if defined _lcpkg echo  !_lclines! lines from !_lcpkg!, !_lcfat! crash^(es^) - saved as !_lcf!
if not defined _lcpkg echo  !_lclines! lines, !_lcfat! app crash^(es^), !_lcanr! ANR^(s^) - saved as !_lcf!
if "!_lclines!"=="0" echo  Nothing was logged. If the app was idle, keep it busy while recording.

:logcap_view
echo.
echo    [N] Open it in Notepad    [P] Page through it    [B] Back
choice /c:NPB /n >nul
if errorlevel 3 goto logcap
if errorlevel 2 goto logcap_page
if not errorlevel 1 goto logcap
find /v "" <"!_lcf!" >"!DCX_TMP!\logview.txt" 2>nul
start "" notepad "!DCX_TMP!\logview.txt"
goto logcap_view

:logcap_page
more <"!_lcf!"
goto logcap_view

:logcap_startfail
echo  [%r%^^!%w%] The recording did not start: PowerShell could not run adb in the background.
del "!LOGDIR!\.recording.pid" >nul 2>&1

:logcap_end
echo.
echo Press Any Button To Go Back
pause >nul
goto logcap

:_lc_count
:: Counts in the file _lcf: _lclines lines, _lcfat app crashes (FATAL EXCEPTION), _lcanr ANRs. The
:: child commands name the path variable and read it through a redirect, with no pipe: each side of
:: a pipe is one more cmd, which would expand a %NAME% pair in the path again.
set "DCX_LCF=!_lcf!"
set "_lclines=0" & set "_lcfat=0" & set "_lcanr=0"
for /f %%c in ('find /c /v "" ^<"%%DCX_LCF%%" 2^>nul') do set "_lclines=%%c"
for /f %%c in ('find /c "FATAL EXCEPTION" ^<"%%DCX_LCF%%" 2^>nul') do set "_lcfat=%%c"
for /f %%c in ('find /c "ANR in " ^<"%%DCX_LCF%%" 2^>nul') do set "_lcanr=%%c"
set "DCX_LCF="
exit /b

:_lc_start
:: Starts adb with _lcargs as a hidden process writing to _lcf. _lcpid = its PID, also written to
:: dcx_logs\.recording.pid. errorlevel 1 if it did not start.
set "_lcpid="
set "DCX_LCX=!DCX_ADB!"
if not defined DCX_LCX set "DCX_LCX=adb.exe"
set "DCX_LCA=!_lcargs!"
set "DCX_LCF=!_lcf!"
set "DCX_LCP=!LOGDIR!\.recording.pid"
del "!DCX_LCP!" >nul 2>&1
powershell -NoProfile -Command "try { $p = Start-Process -FilePath $env:DCX_LCX -ArgumentList $env:DCX_LCA -WindowStyle Hidden -PassThru -RedirectStandardOutput $env:DCX_LCF -RedirectStandardError ($env:DCX_LCF + '.err'); [IO.File]::WriteAllText($env:DCX_LCP, [string]$p.Id) } catch { if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }; exit 1 }" <nul
:: PowerShell resets the code page. chcp gets its own empty input: it reads a redirected one to the end.
chcp 65001 >nul <nul
set "DCX_LCX=" & set "DCX_LCA=" & set "DCX_LCF="
if not exist "!DCX_LCP!" exit /b 1
set /p _lcpid=<"!DCX_LCP!"
call :_lib_num _lcpid || (set "_lcpid=" & exit /b 1)
exit /b 0

:_lc_alive
:: errorlevel 0 while the process _lcpid is still running as adb.exe. tasklist exits 0 either way,
:: so its answer is read instead.
if not defined _lcpid exit /b 1
tasklist /fi "PID eq !_lcpid!" /fi "IMAGENAME eq adb.exe" /nh <nul >"!DCX_TMP!\lcalive.txt" 2>nul
findstr /i /c:"adb.exe" "!DCX_TMP!\lcalive.txt" >nul 2>&1
exit /b

:_lc_stop
:: Ends the recording process, only while it is still adb.exe: a PID can be reused once it exits.
call :_lc_alive || exit /b 0
taskkill /pid !_lcpid! /f >nul 2>&1
timeout /t 1 /nobreak >nul
exit /b 0

:_lc_leftover
:: A recording a closed DCX window left running is stopped here. One that another DCX window is
:: making right now would be stopped too - the PID file cannot tell them apart.
if not exist "!LOGDIR!\.recording.pid" exit /b
set "_lcpid="
set /p _lcpid=<"!LOGDIR!\.recording.pid"
call :_lib_num _lcpid || set "_lcpid="
set "_lcwas="
if defined _lcpid call :_lc_alive && set "_lcwas=1"
if defined _lcwas echo  [%b%i%w%] An earlier recording was still running - it is stopped now.
if defined _lcwas echo.
if defined _lcwas call :_lc_stop
del "!LOGDIR!\.recording.pid" >nul 2>&1
set "_lcpid="
exit /b

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
adb shell cmd notification post -S bigtext -t '⚙DCX⚙' 'Tag' 'Most DCX settings stay after a restart - only debug properties reset. Use Restore or Tweaks Undo to go back. Bye' <nul > nul 2>&1
:: REMOVED: adb kill-server - the server is shared with other tools and their Wi-Fi sessions.
call :_tmp_cleanup
exit /b

:_tmp_cleanup
:: Removes this window's scratch folder, deleting known files by name. A kept compile log stays,
:: and so does its folder - rd without /s removes only an empty one. X or Ctrl+C skips this.
call :_cp_restore
if not defined DCX_TMP exit /b
if not exist "!DCX_TMP!\" exit /b
del "!DCX_TMP!\installed_packages.txt" "!DCX_TMP!\pkgs.txt" "!DCX_TMP!\qs_tokens.txt" "!DCX_TMP!\idle_whitelist.txt" "!DCX_TMP!\last_report_path.txt" "!DCX_TMP!\pf_sel.txt" "!DCX_TMP!\pf_preset.txt" "!DCX_TMP!\pf_before.txt" >nul 2>&1
call :_gm_tmpdel
if exist "!DCX_TMP!\preview\" rd /s /q "!DCX_TMP!\preview" >nul 2>&1
if exist "!DCX_TMP!\drain\" rd /s /q "!DCX_TMP!\drain" >nul 2>&1
if exist "!DCX_TMP!\killall\" rd /s /q "!DCX_TMP!\killall" >nul 2>&1
if exist "!DCX_TMP!\perf\" rd /s /q "!DCX_TMP!\perf" >nul 2>&1
if exist "!DCX_TMP!\appcheck\" rd /s /q "!DCX_TMP!\appcheck" >nul 2>&1
if exist "!DCX_TMP!\pkgpick\" rd /s /q "!DCX_TMP!\pkgpick" >nul 2>&1
if exist "!DCX_TMP!\cmdlib\" rd /s /q "!DCX_TMP!\cmdlib" >nul 2>&1
if exist "!DCX_TMP!\fastboot\" rd /s /q "!DCX_TMP!\fastboot" >nul 2>&1
if exist "!DCX_TMP!\sideload\" rd /s /q "!DCX_TMP!\sideload" >nul 2>&1
del "!DCX_TMP!\mdns.txt" "!DCX_TMP!\mdns_ok.txt" "!DCX_TMP!\pair.txt" "!DCX_TMP!\connect.txt" >nul 2>&1
del "!DCX_TMP!\lcalive.txt" "!DCX_TMP!\logview.txt" "!DCX_TMP!\lcpath.txt" "!DCX_TMP!\lbnow.txt" >nul 2>&1
del "!DCX_TMP!\bench.txt" "!DCX_TMP!\usb.txt" "!DCX_TMP!\bklist.txt" "!DCX_TMP!\bkpick.txt" "!DCX_TMP!\pkchk.txt" "!DCX_TMP!\exp_list.txt" >nul 2>&1
rd "!DCX_TMP!" >nul 2>&1
exit /b

:_cp_restore
:: Every exit path comes through here: put back the code page the console had before DCX.
if defined DCX_CPSTART chcp !DCX_CPSTART! >nul <nul
exit /b

:_noin
:: arg 1 = the variable set /p just filled; call after every prompt. set /p cannot tell closed
:: input from Enter, so empty reads in a row are counted; at 100 it returns errorlevel 1.
if defined %~1 (set "_NOIN=0" & exit /b 0)
set /a _NOIN+=1
if !_NOIN! LSS 100 exit /b 0
exit /b 1

:dcx_noinput
echo.
echo [%r%ERROR%w%] No input after !_NOIN! empty reads - the keyboard input looks closed.
echo         DCX is an interactive menu: run it in its own console window ^(double-click
echo         it^). It cannot be driven from a pipe or a redirected file.
call :_tmp_cleanup
call :_halt 2>nul
:: Not reached - :_halt does not return.
exit /b 1

:_halt
:: Stops DCX from any call depth: the syntax error below ends every batch level at once and
:: keeps the console open - exit would close it, exit /b would leave only one call.
()

:reboot
echo.
echo  %y%This reboots the connected phone now.%w% Anything unsaved on it is lost,
echo  and any debug property DCX set this session is cleared by the reboot.
echo.
echo    [Y] Reboot the phone    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto menu
if not errorlevel 1 goto menu
adb reboot <nul
timeout /t 1 /nobreak > nul
:: Disconnect only this phone, and only on Wi-Fi: a bare adb disconnect drops every Wi-Fi device.
:: Test defined first: on an undefined variable the colon substitution yields literal text.
if not defined ANDROID_SERIAL goto menu
if "!ANDROID_SERIAL!"=="!ANDROID_SERIAL::=!" goto menu
adb disconnect !ANDROID_SERIAL!
goto menu
:: ===================================================================
:: Wireless ADB - pair, connect and manage Wi-Fi debugging
:: Android 11+: pair once per PC, then connect on the main screen's port, which changes on reboot.
:: Android 10 and older: option [3] over USB switches adbd to TCP port 5555.
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
echo                 %g%[%w%7%g%]%w% Select target device  (when more than one is attached)
echo                 %g%[%w%8%g%]%w% Back
set "wa=" & set /p wa="Choose An Option >> "
call :_noin wa || goto dcx_noinput
if "!wa!"=="1" goto wadb_pair
if "!wa!"=="2" goto wadb_connect
if "!wa!"=="3" goto wadb_tcpip
if "!wa!"=="4" goto wadb_disconnect
if "!wa!"=="5" goto wadb_usb
if "!wa!"=="6" goto wadb_help
if "!wa!"=="7" (
    call :pick_device
    goto wirelessadb
)
if "!wa!"=="8" goto wadb_back
goto wirelessadb

:wadb_back
rem  The attached-device list may have changed in this menu, so re-resolve the target.
call :pick_device
:: Always re-probe: the target may be a different phone now, and SDK must be that phone's.
goto detect_device

:wadb_pair
cls
title Wireless ADB : pair
call :logo
echo  On the phone: Developer options -^> Wireless debugging -^>
echo  %g%Pair device with pairing code%w%. Keep that dialog OPEN - the
echo  code and port stop working the moment it closes.
echo.
echo  Looking for the pairing dialog on this network...
call :_wa_scan _adb-tls-pairing._tcp 8
call :_wa_rows
if "!_wan!"=="0" echo  None found. Type the ip:port the dialog shows - see Help for why it may not show up.

:wadb_pair_ask
echo.
set "WIP=" & set /p WIP="Number, or the dialog's ip:port (R = look again, blank = cancel) >> "
call :_noin WIP || goto dcx_noinput
if "!WIP!"=="" goto wirelessadb
if /i "!WIP!"=="R" goto wadb_pair
set "_wainst="
call :_wa_pick
call :_tw_safechk WIP || goto wadb_pair_bad
echo !WIP!| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*:[0-9][0-9]*$" >nul || goto wadb_pair_bad
set "WCODE=" & set /p WCODE="6-digit pairing code (blank = cancel) >> "
call :_noin WCODE || goto dcx_noinput
if "!WCODE!"=="" goto wirelessadb
call :_tw_safechk WCODE || goto wadb_pair_bad
echo !WCODE!| findstr /r "^[0-9][0-9][0-9][0-9][0-9][0-9]$" >nul || goto wadb_pair_bad
echo.
:: adb exits 1 on any pairing failure since 34.0.5, but its message is a generic protocol fault.
adb pair !WIP! !WCODE! <nul >"!DCX_TMP!\pair.txt" 2>&1
set "_warc=!errorlevel!"
type "!DCX_TMP!\pair.txt"
echo.
if not "!_warc!"=="0" goto wadb_pair_fail
findstr /b /c:"Successfully paired" "!DCX_TMP!\pair.txt" >nul 2>&1 || goto wadb_pair_fail
:: The answer names the phone: Successfully paired to <ip:port> [guid=adb-<serial>-<id>].
set "_waguid="
for /f "usebackq tokens=2 delims=[]" %%g in ("!DCX_TMP!\pair.txt") do (
    set "_wax=%%g"
    call :_wa_guid
)
echo  [%g%+%w%] Paired: this PC is trusted now.
if not defined _waguid goto wadb_pair_noguid
:: adb connects a paired phone by itself once it sees the phone's connect entry.
echo  Waiting a moment for adb to connect to it...
set "_waw=0"

:wadb_pair_wait
call :_wa_isconn _waguid
if defined _waconn goto wadb_pair_conn
set /a _waw+=1
if !_waw! GEQ 6 goto wadb_pair_noconn
timeout /t 1 /nobreak >nul
goto wadb_pair_wait

:wadb_pair_conn
echo  [%g%OK%w%] Connected as !_waconn!
call :_wa_save _waguid _waconn
goto wadb_pair_end

:wadb_pair_noconn
echo  Not connected yet. Use option [2]: the phone shows up there by name once
echo  Wireless debugging's main screen is on.
call :_wa_save _waguid
goto wadb_pair_end

:wadb_pair_noguid
echo  Now use option [2] to connect. The connect port is the DIFFERENT one on
echo  the main Wireless-debugging screen.
goto wadb_pair_end

:wadb_pair_fail
echo  [%r%^^!%w%] Pairing failed. adb does not say why: usually the code was mistyped, the
echo      dialog closed or timed out, or the ip:port was not the pairing dialog's one.

:wadb_pair_end
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_pair_bad
echo [%r%^^!%w%] Expected a number from the list, an ip:port like 192.168.1.23:37123, and a 6-digit code.
timeout /t 2 /nobreak >nul
goto wadb_pair_ask

:wadb_connect
cls
title Wireless ADB : connect
call :logo
echo  Phones on this network with Wireless debugging on ^(Android 11+^):
call :_wa_scan _adb-tls-connect._tcp 6
call :_wa_rows
if "!_wan!"=="0" echo     none found - see Help for why one may not show up.
echo.
echo  Or type the ip:port from the MAIN Wireless-debugging screen, or just the IP
echo  if you used option [3] ^(port 5555 is assumed then^).

:wadb_connect_ask
echo.
set "WIP=" & set /p WIP="Number, or ip[:port] (R = look again, blank = cancel) >> "
call :_noin WIP || goto dcx_noinput
if "!WIP!"=="" goto wirelessadb
if /i "!WIP!"=="R" goto wadb_connect
set "_wainst="
call :_wa_pick
if "!WIP!"=="!WIP::=!" set "WIP=!WIP!:5555"
call :_tw_safechk WIP || goto wadb_connect_bad
echo !WIP!| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*:[0-9][0-9]*$" >nul || goto wadb_connect_bad
echo.
:: adb connect exits 0 for every outcome; only its own words say whether it connected.
adb connect !WIP! <nul >"!DCX_TMP!\connect.txt" 2>&1
type "!DCX_TMP!\connect.txt"
set "_waok="
findstr /b /c:"connected to " /c:"already connected to " "!DCX_TMP!\connect.txt" >nul 2>&1 && set "_waok=1"
echo.
echo  Now attached:
for /f "skip=1 delims=" %%i in ('adb devices ^<nul 2^>nul') do echo     %%i
echo.
if not defined _waok goto wadb_connect_fail
echo  [%g%OK%w%] Connected to !WIP!
if defined _wainst call :_wa_save _wainst WIP
goto wadb_connect_end

:wadb_connect_fail
echo  [%r%^^!%w%] Not connected. "failed to connect" usually means this PC is not paired with
echo      the phone yet -^> option [1]; a "(10061)" or "(10060)" at the end means nothing
echo      answered on that port - it changes after a reboot or re-toggle.

:wadb_connect_end
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:wadb_connect_bad
echo [%r%^^!%w%] Expected a number from the list, or an IPv4 address like 192.168.1.23[:41235].
timeout /t 2 /nobreak >nul
goto wadb_connect_ask

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
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto wirelessadb
if not errorlevel 1 goto wirelessadb
adb tcpip 5555
timeout /t 2 /nobreak >nul
:: Find the phone's Wi-Fi IP in ip route, preferring a wlan line.
set "WDEVIP="
for /f "delims=" %%l in ('adb shell ip route ^<nul 2^>nul ^| findstr /C:"wlan"') do if not defined WDEVIP set "_wr=%%l" & call :_wadb_src
if not defined WDEVIP for /f "delims=" %%l in ('adb shell ip route ^<nul 2^>nul ^| findstr /C:" src "') do if not defined WDEVIP set "_wr=%%l" & call :_wadb_src
echo.
if defined WDEVIP (
    echo  Phone Wi-Fi IP detected: %g%!WDEVIP!%w%
    echo.
    echo    [Y] Connect to !WDEVIP!:5555 now    [N] Not yet
    rem Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
    choice /c:YN /n >nul
    if errorlevel 2 goto wirelessadb
    if not errorlevel 1 goto wirelessadb
    adb connect !WDEVIP!:5555 <nul >"!DCX_TMP!\connect.txt" 2>&1
    type "!DCX_TMP!\connect.txt"
    echo.
    rem adb connect exits 0 for every outcome; only its own words say whether it connected.
    findstr /b /c:"connected to " /c:"already connected to " "!DCX_TMP!\connect.txt" >nul 2>&1 || goto wadb_tcpip_fail
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
:wadb_tcpip_fail
echo  [%r%^^!%w%] Not connected over Wi-Fi - keep the cable in. Check that the phone and the PC are
echo      on the same network, then try option [2] with !WDEVIP!.
echo.
echo Press Any Button To Go Back
pause > nul
goto wirelessadb

:_wa_scan
:: Arg 1 = the mDNS service type (_adb-tls-pairing._tcp or _adb-tls-connect._tcp), arg 2 = tries.
:: Fills _wai[n] instance (adb-<serial>-<id>, the same name in both lists), _wap[n] ip:port and
:: _wal[n] the name DCX saved for it, n = 1.._wan. adb answers from its server's cache, which fills
:: a few seconds after the server starts, so an empty list is read again once a second. Any device
:: on the network can announce a name, so every line is checked before use, with delayed
:: expansion off while it is read.
for /f "delims==" %%v in ('set _wai[ 2^>nul') do set "%%v="
for /f "delims==" %%v in ('set _wap[ 2^>nul') do set "%%v="
for /f "delims==" %%v in ('set _wal[ 2^>nul') do set "%%v="
for /f "delims==" %%v in ('set _waS_ 2^>nul') do set "%%v="
set "_wan=0" & set "_wat=0"

:_wa_scan_again
set /a _wat+=1
adb mdns services <nul >"!DCX_TMP!\mdns.txt" 2>nul
type nul >"!DCX_TMP!\mdns_ok.txt"
for /f "usebackq skip=1 tokens=1-3" %%a in ("!DCX_TMP!\mdns.txt") do (
    setlocal DisableDelayedExpansion
    set "_wx1=%%a"
    set "_wx2=%%b"
    set "_wx3=%%c"
    call :_wa_take %1
    endlocal
)
for /f "usebackq tokens=1,2" %%a in ("!DCX_TMP!\mdns_ok.txt") do call :_wa_put %%a %%b
if !_wan! GEQ 1 exit /b
if !_wat! GEQ %~2 exit /b
timeout /t 1 /nobreak >nul
goto _wa_scan_again

:_wa_take
:: _wx1.._wx3 = one answer line (instance, type, ip:port), delayed expansion off. Arg 1 = wanted type.
:: Keeps lines of that type with a plain name and a real IPv4 ip:port.
setlocal EnableDelayedExpansion
if not "!_wx2!"=="%~1" (endlocal & exit /b)
if not defined _wx1 (endlocal & exit /b)
if not defined _wx3 (endlocal & exit /b)
if not "!_wx1:~64!"=="" (endlocal & exit /b)
:: eol is one of the allowed characters, or text after a ; would never be checked.
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_wx1!") do (endlocal & exit /b)
for /f "eol=0 delims=0123456789.:" %%c in ("!_wx3!") do (endlocal & exit /b)
if "!_wx3:~0,8!"=="0.0.0.0:" (endlocal & exit /b)
if "!_wx3::=!"=="!_wx3!" (endlocal & exit /b)
>>"!DCX_TMP!\mdns_ok.txt" echo !_wx1! !_wx3!
endlocal
exit /b

:_wa_put
:: %1 = a checked instance, %2 = its ip:port. adb lists a phone once per network adapter: keep one.
if defined _waS_%~1 exit /b
set "_waS_%~1=1"
set /a _wan+=1
set "_wai[!_wan!]=%~1"
set "_wap[!_wan!]=%~2"
set "_wal[!_wan!]="
if exist "!PROFDIR!\wifi_phones.txt" for /f "usebackq tokens=1,* delims=~" %%a in ("!PROFDIR!\wifi_phones.txt") do if "%%a"=="%~1" set "_wal[!_wan!]=%%b"
exit /b

:_wa_rows
:: Prints the list _wa_scan filled: number, the saved name if any, ip:port, instance.
for /l %%i in (1,1,!_wan!) do (
    if defined _wal[%%i] echo     %g%[%w%%%i%g%]%w% !_wal[%%i]!   !_wap[%%i]!   ^(!_wai[%%i]!^)
    if not defined _wal[%%i] echo     %g%[%w%%%i%g%]%w% !_wap[%%i]!   !_wai[%%i]!
)
exit /b

:_wa_pick
:: WIP = what was typed. A list number becomes that entry's ip:port, and _wainst its instance.
set "_wan2=!WIP!"
for /f "eol=0 delims=0123456789" %%c in ("!_wan2!") do exit /b
if "!_wan2:~0,1!"=="0" exit /b
if not defined _wap[!_wan2!] exit /b
for /f "delims=" %%k in ("!_wan2!") do (
    set "WIP=!_wap[%%k]!"
    set "_wainst=!_wai[%%k]!"
)
exit /b

:_wa_guid
:: _wax = the text between [ and ] of adb pair's answer, guid=adb-<serial>-<id>. Sets _waguid.
if not defined _wax exit /b
if not "!_wax:~0,5!"=="guid=" exit /b
set "_wax=!_wax:~5!"
if not defined _wax exit /b
if not "!_wax:~64!"=="" exit /b
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_wax!") do exit /b
set "_waguid=!_wax!"
exit /b

:_wa_isconn
:: Arg 1 = NAME of a variable holding an instance. _waconn = the serial adb lists it under in
:: state device (the name form adb uses when it connects by itself), empty when not connected.
set "_waconn="
for /f "skip=1 tokens=1,2" %%a in ('adb devices ^<nul 2^>nul') do if "%%b"=="device" if /i "%%a"=="!%~1!._adb-tls-connect._tcp" set "_waconn=%%a"
exit /b

:_wa_save
:: Arg 1 = NAME of a variable holding an instance, arg 2 = NAME of one holding a serial to read the
:: model from (optional). Keeps instance~model in wifi_phones.txt, one line per phone, so the lists
:: can name a phone that was here before. The model is kept only if it is plain text.
set "_wsi=!%~1!"
if not defined _wsi exit /b
set "_wsm="
if not "%~2"=="" for /f "delims=" %%m in ('adb -s !%~2! shell getprop ro.product.model 2^>nul ^<nul') do set "_wsm=%%m"
if defined _wsm for /f "delims=" %%m in ("!_wsm!") do set "_wsm=%%m"
:: The space goes last in delims: in the middle it ends the option, and for /f fails without a check.
if defined _wsm for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+- " %%c in ("!_wsm!") do set "_wsm="
if defined _wsm if not "!_wsm:~40!"=="" set "_wsm=!_wsm:~0,40!"
if not defined _wsm exit /b
if not exist "!PROFDIR!\" md "!PROFDIR!" >nul 2>&1
set "_wsf=!PROFDIR!\wifi_phones.txt"
if exist "!_wsf!" findstr /v /b /c:"!_wsi!~" "!_wsf!" >"!_wsf!.tmp" 2>nul
if exist "!_wsf!" move /y "!_wsf!.tmp" "!_wsf!" >nul 2>&1
>>"!_wsf!" echo !_wsi!~!_wsm!
exit /b

:_wa_wifin
:: _wawn = how many Wi-Fi connections adb lists in state device.
set "_wawn=0"
for /f "skip=1 tokens=1,2" %%a in ('adb devices ^<nul 2^>nul') do if "%%b"=="device" (
    set "_wawx=%%a"
    call :_wifi_ser _wawx && set /a _wawn+=1
)
exit /b

:_wifi_ser
:: Arg 1 = NAME of a variable holding an adb serial. errorlevel 0 when it is a Wi-Fi connection:
:: ip:port, or the name adb gives a phone it connected by itself, adb-<serial>-<id>._adb-tls-connect._tcp.
if not defined %~1 exit /b 1
set "_wfs=!%~1!"
if not "!_wfs!"=="!_wfs::=!" exit /b 0
if not "!_wfs!"=="!_wfs:._adb=!" exit /b 0
exit /b 1

:: _wadb_src - takes one ip route line from _wr and sets WDEVIP to the token after src.
:: Phone text: read late from a variable, never as call arguments; only digits and dots pass.
:_wadb_src
if not defined _wr exit /b
set "_wt=!_wr:* src =!"
if "!_wt!"=="!_wr!" exit /b
if not defined _wt exit /b
for /f "tokens=1" %%a in ("!_wt!") do set "WDEVIP=%%a"
if not defined WDEVIP exit /b
set "_wipbad="
for /f "eol=0 delims=0123456789." %%c in ("!WDEVIP!") do set "_wipbad=1"
if defined _wipbad set "WDEVIP="
exit /b

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
:: Works only for devices switched with option [3], not Android 11+ wireless debugging. adb usb
:: exits 0 whenever adbd answered, so the verdict is read from adb devices a few seconds later.
adb usb <nul >"!DCX_TMP!\usb.txt" 2>&1
set "_usbrc=!errorlevel!"
type "!DCX_TMP!\usb.txt" 2>nul
if not "!_usbrc!"=="0" goto wadb_usb_fail
echo Waiting for the connections to settle...
timeout /t 6 /nobreak >nul
call :_wa_wifin
if not "!_wawn!"=="0" goto wadb_usb_still
echo Done - adbd is back on USB and no Wi-Fi connection is left.
goto wadb_usb_end

:wadb_usb_still
echo [%y%WARN%w%] adb still lists !_wawn! Wi-Fi connection^(s^). adb usb does not switch off
echo        Android 11+ Wireless debugging: turn the toggle off on the phone.
goto wadb_usb_end

:wadb_usb_fail
echo [%y%WARN%w%] adb usb returned !_usbrc! - nothing was switched ^(adb's answer is above^).
echo        This works only for devices put on Wi-Fi with option [3] (adb tcpip).
echo        For Android 11+ Wireless debugging, turn the toggle off on the phone.

:wadb_usb_end
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
echo    - Options [1] and [2] list what they find on the network, so you
echo      can pick a number instead. A phone paired before is named, and
echo      adb reconnects it by itself when it sees it on the network.
echo    - Nothing listed? The phone must be awake on the same network, not
echo      a guest Wi-Fi; a firewall may block the search ^(UDP 5353^); and
echo      adb only searches adapters that were up when its server started.
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
echo  Generating full device report - about 50 device queries, ~10 seconds.
echo  %y%The window cannot accept input until this finishes.%w%
echo.
:: Progress lines go to CON so they reach the screen while the block below goes to the report.
:: The previous report path is kept per phone by :_rpt_ptr, so Diff compares one device.
call :_rpt_ptr
set "PREV_REPORT="
if exist "!RPTPTR!" (
    set /p PREV_REPORT=<"!RPTPTR!"
)
if not defined PREV_REPORT set "PREV_REPORT=" 
:: Locale-safe, filename-safe timestamp from %date%/%time%.
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "REPORT=!TEMP!\dcx_report_%TS%.txt"
(
    echo ===========================================================
    echo  DCX Device Diagnostic Report - %date% %time%
    echo ===========================================================
    echo.
    echo    [1/6] hardware and software... 1>CON
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
    echo    [2/6] memory and storage... 1>CON
    echo [Memory]
    call :_ck_mem
    if defined _ckMT echo   Total RAM           : !_ckMT! MB
    if defined _ckMA echo   Available RAM       : !_ckMA! MB
    if defined _ckMF echo   Free RAM            : !_ckMF! MB
    if defined _ckMB echo   Buffers             : !_ckMB! MB
    if defined _ckMC echo   Cached              : !_ckMC! MB
    if defined _ckST echo   Swap total          : !_ckST! MB
    if defined _ckSF echo   Swap free           : !_ckSF! MB
    echo.
    echo [Storage]
    adb shell "df -h /data 2>/dev/null" <nul
    echo.
    echo [State]
    call :_uptime
    if defined _upt echo   Uptime              : !_upt!
    for /f "delims=" %%i in ('adb shell "dumpsys cpuinfo 2>/dev/null | grep 'Load:'"')      do echo   %%i
    call :_ck_bat
    if defined _ckBL echo   Battery level       : !_ckBL! %%
    if defined _ckBT echo   Battery temperature : !_ckBT! C
    if defined _ckBV echo   Battery voltage     : !_ckBV! mV
    if defined _ckBS echo   Battery status      : !_ckBS!
    if defined _ckBH echo   Battery health      : !_ckBH!
    echo.
    echo    [3/6] display and graphics... 1>CON
    echo [Display]
    for /f "tokens=2 delims=:=" %%i in ('adb shell "dumpsys SurfaceFlinger 2>/dev/null | grep refresh-rate"') do echo   Display refresh    : %%i Hz
    for /f "delims=" %%i in ('adb shell wm size 2^>nul ^<nul')                                              do echo   %%i
    for /f "delims=" %%i in ('adb shell wm density 2^>nul ^<nul')                                           do echo   %%i
    echo.
    echo [Graphics renderer - current values]
    for /f "delims=" %%i in ('adb shell getprop debug.hwui.renderer 2^>nul ^<nul')   do echo   debug.hwui.renderer        : "%%i" ^(skiagl=default, skiavk=Skia Vulkan, empty=auto^)
    for /f "delims=" %%i in ('adb shell getprop ro.hwui.renderer 2^>nul ^<nul')      do echo   ro.hwui.renderer           : "%%i"
    for /f "delims=" %%i in ('adb shell settings get global angle_gl_driver_all_angle 2^>nul ^<nul') do echo   angle_gl_driver_all_angle  : %%i ^(1=force ANGLE for all GLES apps, 0/null=off^)
    for /f "delims=" %%i in ('adb shell getprop persist.log.tag 2^>nul ^<nul')       do echo   persist.log.tag            : "%%i" ^(a bare S silences all logs - and crash logs^)
    echo.
    echo    [4/6] animation, refresh and saver keys... 1>CON
    echo [Animation / Refresh - current values]
    for /f "delims=" %%i in ('adb shell settings get global window_animation_scale 2^>nul ^<nul')     do echo   window_animation_scale     : %%i
    for /f "delims=" %%i in ('adb shell settings get global transition_animation_scale 2^>nul ^<nul') do echo   transition_animation_scale : %%i
    for /f "delims=" %%i in ('adb shell settings get global animator_duration_scale 2^>nul ^<nul')    do echo   animator_duration_scale    : %%i
    for /f "delims=" %%i in ('adb shell settings get system min_refresh_rate 2^>nul ^<nul')           do echo   min_refresh_rate ^(Hz^)      : %%i
    for /f "delims=" %%i in ('adb shell settings get system peak_refresh_rate 2^>nul ^<nul')          do echo   peak_refresh_rate ^(Hz^)     : %%i
    echo.
    echo [Battery savers / Sync - current values]
    for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul ^<nul')          do echo   master_sync_status         : %%i  ^(placebo on modern Android; Backup round-trip only^)
    for /f "delims=" %%i in ('adb shell device_config get_sync_disabled_for_tests 2^>nul ^<nul') do echo   sync_disabled_for_tests   : %%i  ^(none/persistent/until_reboot - DeviceConfig server sync^)
    for /f "delims=" %%i in ('adb shell settings get global hotword_detection_enabled 2^>nul ^<nul')   do echo   hotword_detection_enabled  : %%i  ^(1=on, 0=off^)
    for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul ^<nul') do echo   app_hibernation_enabled    : %%i
    echo.
    echo    [5/6] network and power state... 1>CON
    echo [Network]
    for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul ^<nul') do echo   Preferred network mode      : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_mode 2^>nul ^<nul')       do echo   Private DNS mode           : %%i
    for /f "delims=" %%i in ('adb shell settings get global private_dns_specifier 2^>nul ^<nul')  do echo   Private DNS host           : %%i
    echo.
    echo [Power state]
    for /f "delims=" %%i in ('adb shell settings get global low_power 2^>nul ^<nul') do echo   Battery saver         : %%i
    for /f "delims=" %%i in ('adb shell settings get global low_power_sticky 2^>nul ^<nul') do echo   Battery saver sticky  : %%i
    rem REMOVED: cmd power get-mode - no such subcommand; the two keys above are the state.
    echo.
    echo    [6/6] doze whitelist, RAM and focused app... 1>CON
    echo [Doze whitelist - first 20 entries]
    adb shell "dumpsys deviceidle whitelist 2>/dev/null | head -20" <nul
    echo.
    echo [RAM by OOM group - first 40 lines]
    adb shell "dumpsys meminfo --oom 2>/dev/null | head -40" <nul
    echo.
    echo [Currently focused app]
    adb shell "dumpsys activity activities 2>/dev/null | grep ResumedActivity" <nul
    echo.
    echo ===========================================================
    echo  End of report
    echo ===========================================================
) > "!REPORT!" < nul
:: Read late, like every path: the user name may hold an ampersand.
>"!RPTPTR!" echo !REPORT!
:: The report is generated once; redraws come back to :check_menu, never to :check.
:check_menu
cls
call :logo
echo  %g%Report saved to:%w%
echo    !REPORT!
if defined PREV_REPORT if exist "!PREV_REPORT!" (
    echo  %g%Previous report:%w%
    echo    !PREV_REPORT!
)
echo.
echo  %b%[%w%1%b%]%w% Open report in Notepad (scrollable, searchable)
echo  %b%[%w%2%b%]%w% Show report in this window (paginated with MORE)
echo  %b%[%w%3%b%]%w% Show short summary here ^& go back
echo  %b%[%w%4%b%]%w% Diff vs previous report
echo  %b%[%w%5%b%]%w% Back to main menu        %d%(0 or Q also work)%w%
echo.
echo  %d%Feeling stuck? %g%0%d% or %g%Q%d% leaves this screen. Inside the paginated view
echo  it is %g%Q%d% ^(that is Windows' MORE pager, it only takes its own keys^).%w%
echo.

:check_menu_ask
:: Re-ask in place without redrawing: the console hands set /p a phantom empty line after the
:: probes, and redraws would stack copies of the menu. 0 and Q also mean Back.
set "ck=" & set /p ck="Choose An Option >> "
call :_noin ck || goto dcx_noinput
if not defined ck goto check_menu_ask
if "!ck!"=="1" goto check_open
if "!ck!"=="2" goto check_paginate
if "!ck!"=="3" goto check_summary
if "!ck!"=="4" goto check_diff
if "!ck!"=="5" goto menu
if "!ck!"=="0" goto menu
if /i "!ck!"=="q" goto menu
goto check_menu_ask

:check_diff
if not defined PREV_REPORT goto check_diff_none
if not exist "!PREV_REPORT!" goto check_diff_none
if /i "!PREV_REPORT!"=="!REPORT!" goto check_diff_none
:: Named after the new report, so two DCX windows never share one diff file.
set "DIFFOUT=!REPORT:~0,-4!_diff.txt"
echo Comparing:
echo   OLD: !PREV_REPORT!
echo   NEW: !REPORT!
echo.
set "_UDA=!PREV_REPORT!" & set "_UDB=!REPORT!" & set "_UDO=!DIFFOUT!" & set "_UDM=new"
call :_udiff
echo  %g%Diff saved to:%w%
echo    !DIFFOUT!
echo.
echo  %b%[%w%1%b%]%w% Open diff in Notepad
echo  %b%[%w%2%b%]%w% Show diff here (MORE)
echo  %b%[%w%3%b%]%w% Back
:: ckd, not cd: a variable named cd shadows cmd's dynamic CD for this process and its children.
set "ckd=" & set /p ckd="Choose An Option >> "
call :_noin ckd || goto dcx_noinput
if "!ckd!"=="1" (start "" notepad "!DIFFOUT!" & goto check_menu)
if "!ckd!"=="2" (cls & title Report diff  -  SPACE=next page   Q=quit back to menu & more "!DIFFOUT!" & pause >nul & goto check_menu)
goto check_menu

:check_diff_none
echo  %y%No previous report to diff against.%w%
echo  Run CheckSetting once, change something, run it again - then use Diff.
timeout /t 3 /nobreak >nul
goto check_menu

:_rpt_ptr
:: Sets RPTPTR, the file holding this phone's last report path, named after its adb serial.
:: The serial is phone text: used only if made of letters, digits and . - _ : [ ], each : as _.
:: Otherwise the pointer lives in this window's folder and Diff works within this session only.
set "RPTPTR=!DCX_TMP!\last_report_path.txt"
if not defined ANDROID_SERIAL exit /b
set "_rpk=!ANDROID_SERIAL!"
set "_rpbad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:-_[]" %%c in ("!_rpk!") do set "_rpbad=1"
if defined _rpbad exit /b
set "_rpk=!_rpk::=_!"
set "RPTPTR=!TEMP!\dcx_last_report_path_!_rpk!.txt"
exit /b

:check_open
start "" notepad "!REPORT!"
goto check_menu

:check_paginate
cls
:: Keys go in the title, which stays visible on every page; MORE takes only its own keys.
title Device Diagnostics  -  SPACE=next page   ENTER=one line   Q=quit back to menu
echo  %d%[i]%w% Paging with MORE:  %g%SPACE%w% next page   %g%ENTER%w% one line   %g%Q%w% quit back to the menu.
echo.
more "!REPORT!"
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
call :_ck_mem
call :_ck_bat
if defined _ckMA if defined _ckMT (
    set /a "_g1=(_ckMA*10+512)/1024, _g2=(_ckMT*10+512)/1024"
    set /a "_g1a=_g1/10, _g1b=_g1%%10, _g2a=_g2/10, _g2b=_g2%%10"
    echo   Available RAM: !_g1a!.!_g1b! GB of !_g2a!.!_g2b! GB
)
if defined _ckBL echo   Battery: !_ckBL! %%
if defined _ckBT echo   Battery temperature: !_ckBT! C
call :_uptime
if defined _upt echo   Uptime: !_upt!
echo.
echo   Full report still saved at: !REPORT!
echo.
echo Press Any Button To Go Back
pause > nul
goto menu

:_ck_mem
:: /proc/meminfo in MB, one adb call: _ckMT _ckMA _ckMF _ckMB _ckMC _ckST _ckSF (empty if missing).
setlocal DisableDelayedExpansion
for %%k in (MT MA MF MB MC ST SF) do set "_%%k="
for /f "tokens=1,2 delims=: " %%a in ('adb shell cat /proc/meminfo ^<nul 2^>nul') do (
    for %%m in (MemTotal.MT MemAvailable.MA MemFree.MF Buffers.MB Cached.MC SwapTotal.ST SwapFree.SF) do for /f "tokens=1,2 delims=." %%p in ("%%m") do if "%%a"=="%%p" (
        set "_bad="
        for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_bad=1"
        if not defined _bad set /a "_%%q=%%b/1024" 2>nul
    )
)
endlocal & set "_ckMT=%_MT%" & set "_ckMA=%_MA%" & set "_ckMF=%_MF%" & set "_ckMB=%_MB%" & set "_ckMC=%_MC%" & set "_ckST=%_ST%" & set "_ckSF=%_SF%"
exit /b

:_ck_bat
:: dumpsys battery, one adb call: _ckBL level, _ckBT temperature in C ("34.0", from tenths),
:: _ckBV voltage (mV), _ckBS/_ckBH status and health by name (the number if unknown).
setlocal DisableDelayedExpansion
set "_lv=" & set "_tp=" & set "_vo=" & set "_st=" & set "_he="
for /f "tokens=1,2 delims=: " %%a in ('adb shell dumpsys battery ^<nul 2^>nul') do (
    if "%%a"=="level" (set "_lv=%%b" & for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_lv=")
    if "%%a"=="voltage" (set "_vo=%%b" & for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_vo=")
    if "%%a"=="status" (set "_st=%%b" & for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_st=")
    if "%%a"=="health" (set "_he=%%b" & for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_he=")
    if "%%a"=="temperature" for /f "tokens=* delims=-" %%y in ("%%b") do (
        set "_tp=%%b"
        for /f "eol=0 delims=0123456789" %%x in ("%%y") do set "_tp="
        if not "%%b"=="%%y" if not "%%b"=="-%%y" set "_tp="
    )
)
endlocal & set "_ckBL=%_lv%" & set "_ckBT=%_tp%" & set "_ckBV=%_vo%" & set "_ckBS=%_st%" & set "_ckBH=%_he%"
for %%v in (_ckBL _ckBV _ckBS _ckBH) do if defined %%v if not "!%%v:~6!"=="" set "%%v="
if defined _ckBT if not "!_ckBT:~7!"=="" set "_ckBT="
if defined _ckBT set /a "_n=_ckBT>>31, _m=_ckBT*(1+2*_n), _a=_m/10, _b=_m%%10"
if defined _ckBT (if !_n! LSS 0 (set "_ckBT=-!_a!.!_b!") else (set "_ckBT=!_a!.!_b!"))
for %%s in ("1 Unknown" "2 Charging" "3 Discharging" "4 Not charging" "5 Full") do for /f "tokens=1*" %%p in (%%s) do if "!_ckBS!"=="%%p" set "_ckBS=%%q"
for %%s in ("1 Unknown" "2 Good" "3 Overheat" "4 Dead" "5 Over voltage" "6 Failure" "7 Cold") do for /f "tokens=1*" %%p in (%%s) do if "!_ckBH!"=="%%p" set "_ckBH=%%q"
exit /b

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
call :_noin kb || goto dcx_noinput
if "!kb!"=="1" goto setupautorun
if "!kb!"=="2" goto menu
:: Anything else re-asks; falling through would run Auto Setup unprompted.
goto Auto

:setupautorun
cls
title Auto Setup
:: RETIRED: SurfaceFlinger phase offsets. SurfaceFlinger reads debug.sf.* only when it starts,
:: and without root that is the next boot, which clears them first.
call :logo
echo.
echo [%y%i%w%] Auto Setup no longer writes SurfaceFlinger phase offsets: SurfaceFlinger reads
echo     them only when it starts, and without root that means the next boot - which clears
echo     them first. Starting the steps that do take effect.
timeout /t 3 /nobreak > nul
title Auto Setup
cls
call :logo
:: Each step is counted from its exit code, and nothing clears the screen until the summary.
call :_act_reset
echo  Step 1/5: background dexopt
call :run_bgdexopt
call :_act_rc !errorlevel! "1/5 background dexopt"
echo  Step 2/5: battery state overrides cleared
adb shell dumpsys battery reset <nul
call :_act_rc !errorlevel! "2/5 battery state overrides cleared"
echo  Step 3/5: storage trim
adb shell sm fstrim <nul
call :_act_rc !errorlevel! "3/5 storage trim requested"
echo  Step 4/5: background and logging tweaks
adb shell am kill-all <nul
adb shell am kill --user 0 all <nul
adb shell am kill --user 0 current <nul
adb shell cmd looper_stats disable <nul
call :dropbox_lowprio
adb shell cmd dropbox set-rate-limit 20000000000000 <nul
adb shell cmd autofill set log_level off <nul
:: REMOVED: cmd thermalservice override-status - it masks real heat, a safety signal.
:: ----- Safe optimizations -----
:: REMOVED: persist.log.tag and log.tag '*:S' - liblog reads only the first letter, so no effect;
:: a bare S would silence crash logs too. The per-tag log.tag.TAG S lines below are unaffected.
:: ANGLE for all apps is not applied here: it crashes many apps on some GPUs. Gaming offers it.
adb shell setprop log.tag.stats_log S <nul
adb shell setprop log.tag.APM_AudioPolicyManager S <nul
adb shell setprop log.tag.ALL S <nul
adb shell settings put global settings_enable_monitor_phantom_procs false <nul
adb shell simpleperf --log fatal --log-to-android-buffer 0 <nul > nul 2>&1
adb shell cmd autofill set max_visible_datasets 0 <nul
adb shell cmd voiceinteraction set-debug-hotword-logging false <nul
call :wm_silence_logs
adb shell dumpsys binder_calls_stats --disable <nul > nul 2>&1
adb shell dumpsys binder_calls_stats --disable-detailed-tracking <nul > nul 2>&1
adb shell settings put global binder_calls_stats sampling_interval=500000000,detailed_tracking=disable,enabled=false,upload_data=false <nul
adb shell dumpsys batterystats disable full-history <nul > nul 2>&1
adb shell ime tracing stop <nul
:: About twenty calls with no single result: the step counts if the phone still answers after them.
call :_phone_live
call :_act_rc !errorlevel! "4/5 background and logging tweaks sent, phone still answering"
echo  Step 5/5: logs cleared
adb shell logcat -c <nul
call :_act_rc !errorlevel! "5/5 logs cleared"
call :_act_summary
if "%DCX_VFAIL%"=="0" adb shell cmd notification post -S bigtext -t 'Auto Setup Is Complete⚙️' 'Tag' 'Auto Setup Is A Bunch Of Tweaks That Can Be Use For Daily Or Dont Know Anything About This Script' <nul > nul 2>&1
echo.
echo Auto Setup steps finished. Press any key to go back.
pause > Nul
goto menu

:Optimize
cls
title Optimize Android
mode 100,37
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
call :_uptime
if defined _upt echo           [%g%+%w%]Uptime: !_upt!
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
for /f "delims=" %%a in ("!cpucheck!") do set "cpucheck=%%a"
echo           [%g%+%w%]!cpucheck! LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %g%[%w%1%g%]%w% Run bg-dexopt-job
echo                                     %g%[%w%2%g%]%w% Run Fstrim
echo                                     %g%[%w%3%g%]%w% Run Kill-all
echo                                     %g%[%w%4%g%]%w% Run Compile App
echo                                     %g%[%w%5%g%]%w% Run Clear Cache
echo                                     %g%[%w%6%g%]%w% SurfaceFlinger offsets ^(retired - clear old values^)
echo                                     %g%[%w%7%g%]%w% Run Clear Last Used
echo                                     %g%[%w%8%g%]%w% Compile All Apps
echo                                     %g%[%w%9%g%]%w% Animation Speed
echo                                     %g%[%w%0%g%]%w% Back
echo.

:Optimize_ask
:: Re-ask without redrawing, so a phantom empty line after the probes does not re-run them.
set "kb=" & set /p kb="Choose An Option >> "
call :_noin kb || goto dcx_noinput
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
:: Compile All Apps - recompiles every app with the chosen ART mode, then runs bg-dexopt.
:: Takes 5-30+ minutes; keep the phone plugged in.
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
call :_noin ca || goto dcx_noinput
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
echo Finished the compile/dexopt pass. See the status lines above.
echo Press any key to go back.
pause > nul
goto Optimize
:: ===================================================================
:: Heaviest optimization - everything mode ignoring profiles, layout compile, then bg-dexopt.
:: Uses the most storage and takes the longest.
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
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n > nul
if errorlevel 2 goto compileall
if not errorlevel 1 goto compileall
cls
title Compile All Apps : Heaviest (running)
echo [1/3] Full compilation of all apps...
echo This may take a long time. Do not unplug the device.
:: The helper adds --check-prof false up to Android 13; 14+ removed the flag.
call :dexopt_all_mode everything 1
echo.
echo [2/3] Compiling layout resources (if supported)...
:: --compile-layouts must run alone - it rejects -f, -m and --check-prof - and exists only on
:: Android 10-11, so non-support is detected. Its log goes to this window's own folder.
set "_hclog=!DCX_TMP!\layouts.txt"
adb shell pm compile -a --compile-layouts <nul > "!_hclog!" 2>&1
:: Unsupported, failed and done are told apart; a failure keeps the log. pm's text is never
:: echoed: it is untrusted, and an ampersand in it would run on this PC.
findstr /I /C:"Unknown option" /C:"Usage:" "!_hclog!" > nul
if not errorlevel 1 goto _hc_unsupported
findstr /I /C:"Error:" /C:"Failure" /C:"Exception" "!_hclog!" > nul
if not errorlevel 1 goto _hc_failed
echo   Layout resources compiled.
goto _hc_done

:_hc_unsupported
echo   [skipped] --compile-layouts is not supported on this device.
echo   That's expected on Android 12+ - the view compiler was removed
echo   and ART Service handles layout optimization during normal dexopt.
goto _hc_done

:_hc_failed
echo   [%y%WARN%w%] pm reported a failure while compiling layouts - nothing was
echo             compiled. The full output is kept at:
echo             !_hclog!
goto _hc_kept

:_hc_done
del "!_hclog!" > nul 2>&1

:_hc_kept
echo.
echo [3/3] Running background dexopt job...
call :run_bgdexopt
echo.
echo Finished the heaviest compile/dexopt pass. See the status lines above.
echo Press any key to go back.
pause > nul
goto Optimize
:: ===================================================================
:: Animation Speed - sets the window, transition and animator scales together.
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
call :_noin as || goto dcx_noinput
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
call :_noin asv || goto dcx_noinput
if "!asv!"=="" goto animspeed
:: Checked before settings put: a comma becomes a dot, then only 0 to 2 passes.
set "asv=!asv:,=.!"
call :_tw_safechk asv || goto animspeed_custom_bad
echo !asv!| findstr /r /x /c:"[0-2]" /c:"[01]\.[0-9][0-9]*" /c:"2\.0*" /c:"\.[0-9][0-9]*" >nul || goto animspeed_custom_bad
goto animspeed_apply

:animspeed_custom_bad
echo [%r%^^!%w%] Invalid value. Use a number between 0 and 2, e.g. 0.5, 0.75, 1.
timeout /t 2 /nobreak >nul
goto animspeed_custom

:animspeed_apply
adb shell settings put global window_animation_scale %asv% <nul
adb shell settings put global transition_animation_scale %asv% <nul
adb shell settings put global animator_duration_scale %asv% <nul
call :_act_reset
call :_settings_verify global window_animation_scale %asv%
call :_settings_verify global transition_animation_scale %asv%
call :_settings_verify global animator_duration_scale %asv%
call :_act_summary
pause > nul
goto animspeed

:lstused
cls
call :logo
title Clear Last Used Is Running^^!
:: The loop runs in the device shell: one adb call, not one per package, and not one long ';'
:: string built here, which would overrun cmd's 8191-char line. Stderr goes to /dev/null rather
:: than into stdout - that needs an ampersand, which breaks inside this quoted for /f command.
:: Lists what was attempted, not what worked; the per-app clear needs API 33 or newer.
set "_cl_hi="
for /f "eol=0 delims=0123456789" %%n in ("%SDK%") do set "_cl_hi=1"
if defined _cl_hi goto _clearlast_run
if %SDK% GEQ 33 goto _clearlast_run
echo  [%y%NOTE%w%] This device reports Android SDK %SDK%. The per-app command needs SDK 33
echo         ^(Android 13^) or newer, so the list below will scroll past without
echo         clearing anything. The cleanup commands after it still run.
echo.

:_clearlast_run
for /f "delims=" %%a in ('adb shell "pm list packages | while read p; do p=${p#package:}; cmd usagestats clear-last-used-timestamps $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo %%a ━ attempted
)
echo.
echo.
echo Per-package clear finished. Running cleanup commands...
adb shell cmd activity clear-debug-app <nul
adb shell cmd activity clear-exit-info <nul
adb shell cmd activity clear-watch-heap all <nul
adb shell cmd blob_store clear-all-sessions <nul
:: Not clear-all-blobs: it deletes every app's committed shared blobs for good. Sessions only.
echo.
echo Done. Press any key to return to Optimize.
pause > nul
goto Optimize

:sftmenu
title SurfaceFlinger offsets
cls
echo.
echo.
call :logo
:: RETIRED: the SF Hz profiles. SurfaceFlinger reads debug.sf.* only at start, the shell cannot
:: restart it, and a reboot clears debug.* first. Remove stays for values an older DCX set.
echo  %y%The SurfaceFlinger Hz profiles are retired - they could not take effect.%w%
echo.
echo  SurfaceFlinger reads its debug.sf.* phase offsets only when it starts. Without root
echo  the only restart is a reboot, and a reboot clears debug.* values first - so the
echo  profiles changed nothing. To pin the refresh rate, use Battery - Refresh Rate Lock.
echo.
echo                                      [%g%1%w%] Remove values an older DCX set
echo                                      [%g%2%w%] Back
set "opt=" & set /p opt="Choose An Option >> "
call :_noin opt || goto dcx_noinput
if "!opt!"=="1" goto removesf
if "!opt!"=="2" goto Optimize
goto sftmenu

:removesf
cls
title Remove SF offsets
call :logo
echo.
echo  Clears the debug.sf.* phase-offset / duration props that older DCX versions
echo  wrote ^(Auto Setup and the SurfaceFlinger Hz profiles^). Empty setprop resets
echo  them for this boot; a reboot also clears any leftovers.
echo.
echo  [%g%Y%w%] Clear now    [%g%N%w%] Cancel
:: Ctrl+C makes choice return 0 - treated as cancel.
choice /c:YN /n >nul
if errorlevel 2 goto sftmenu
if not errorlevel 1 goto sftmenu
echo.
call :_sf_clear_props
echo.
echo  Done - see the lines above. A reboot also clears any that are left.
echo  [%g%R%w%] Reboot now    [%g%B%w%] Back without reboot
:: Ctrl+C makes choice return 0 - treated as cancel.
choice /c:RB /n >nul
if errorlevel 2 goto sftmenu
if not errorlevel 1 goto sftmenu
adb reboot <nul
goto sftmenu

:_sf_clear_props
:: Props older DCX versions wrote from Auto Setup and the SF Hz profile menus (both retired).
for %%P in (
    debug.sf.region_sampling_duration_ns
    debug.sf.cached_set_render_duration_ns
    debug.sf.early.app.duration
    debug.sf.early.sf.duration
    debug.sf.earlyGl.app.duration
    debug.sf.earlyGl.sf.duration
    debug.sf.early_app_phase_offset_ns
    debug.sf.early_gl_app_phase_offset_ns
    debug.sf.early_gl_phase_offset_ns
    debug.sf.early_phase_offset_ns
    debug.sf.high_fps_early_app_phase_offset_ns
    debug.sf.high_fps_early_gl_app_phase_offset_ns
    debug.sf.high_fps_early_gl_phase_offset_ns
    debug.sf.high_fps_early_phase_offset_ns
    debug.sf.region_sampling_timer_timeout_ns
    debug.sf.region_sampling_period_ns
    debug.sf.phase_offset_threshold_for_next_vsync_ns
    debug.sf.high_fps_late_app_phase_offset_ns
    debug.sf.high_fps_late_sf_phase_offset_ns
    debug.sf.late.app.duration
    debug.sf.late.sf.duration
) do (
    rem Check each: setprop fails on read-only or OEM-protected props.
    adb shell setprop %%P '' <nul >nul 2>&1
    if errorlevel 1 (echo  [%y%WARN%w%] %%P - the device refused this one) else (echo  cleared %%P)
)
exit /b
:: Clear a prop with '' and never a double-quote pair: cmd strips those quotes, so the phone gets
:: setprop KEY alone, prints usage and changes nothing. '' arrives as a real empty argument.
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
:: stdin from nul as on every adb call: else a stray newline lets the next pause return at once.
call :_act_reset
adb shell sm fstrim <nul
call :_act_rc !errorlevel! "fstrim requested"
call :_act_summary
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
title Kill all background apps
:: Foreground package, so it is spared. Match the substring ResumedActivity - the name varies by
:: Android version - then after the '{' token 3 is pkg/activity; keep the part before '/'.
set "FG_PKG="
for /f "tokens=2 delims={" %%a in ('adb shell dumpsys activity activities 2^>nul ^<nul ^| findstr /C:"ResumedActivity"') do (
    if not defined FG_PKG (
        for /f "tokens=3 delims= " %%b in ("%%a") do (
            for /f "tokens=1 delims=/" %%c in ("%%b") do set "FG_PKG=%%c"
        )
    )
)
:: Delayed expansion, not percent expansion, for FG_PKG: it is text from the phone.
if defined FG_PKG echo [%b%i%w%] Foreground app detected, will be skipped: !FG_PKG!
echo.
:: Spares what must keep running - foreground app, keyboard, launcher, accessibility, dialer, SMS
:: and the four packages below - then lists the rest and asks first. Answers are read with delayed
:: expansion off, so phone text cannot expand PC variables; the inner for /f drops a trailing CR.
set "_kaf=!DCX_TMP!\killall"
if exist "!_kaf!\" rd /s /q "!_kaf!" >nul 2>&1
md "!_kaf!" >nul 2>&1
if not exist "!_kaf!\" goto killall_notmp
echo  Reading the app list and what has to keep running...
adb shell settings get secure default_input_method <nul >"!_kaf!\keyboard.txt" 2>nul
adb shell settings get secure enabled_accessibility_services <nul >"!_kaf!\accessibility.txt" 2>nul
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME <nul >"!_kaf!\launcher.txt" 2>nul
adb shell cmd role get-role-holders android.app.role.DIALER <nul >"!_kaf!\dialer.txt" 2>nul
adb shell telecom get-default-dialer <nul >>"!_kaf!\dialer.txt" 2>nul
adb shell cmd role get-role-holders android.app.role.SMS <nul >"!_kaf!\sms.txt" 2>nul
adb shell settings get secure sms_default_application <nul >>"!_kaf!\sms.txt" 2>nul
adb shell pm list packages -3 <nul >"!_kaf!\apps.txt" 2>nul
type nul >"!_kaf!\prot.txt"
if defined FG_PKG (set "_kat=!FG_PKG!" & call :_ka_tok P foreground)
for %%p in (com.android.systemui com.google.android.inputmethod.latin com.android.inputmethod.latin com.android.vending) do (
    set "_kat=%%p"
    call :_ka_tok P system
)
for %%q in (keyboard.C launcher.C accessibility.C dialer.P sms.P) do (
    for /f "usebackq delims=" %%a in ("!_kaf!\%%~nq.txt") do (
        setlocal DisableDelayedExpansion
        set "_kaln="
        for /f "delims=" %%v in ("%%a") do set "_kaln=%%v"
        call :_ka_line %%~xq %%~nq
        endlocal
    )
)
:: The first reason recorded for a package wins; clear what an earlier run left.
for /f "delims==" %%v in ('set _KAP_ 2^>nul') do set "%%v="
for /f "usebackq tokens=1,2" %%a in ("!_kaf!\prot.txt") do if not defined _KAP_%%a set "_KAP_%%a=%%b"
echo.
type nul >"!_kaf!\kill.txt"
for /f "usebackq tokens=1,* delims=:" %%a in ("!_kaf!\apps.txt") do (
    setlocal DisableDelayedExpansion
    set "_kah=%%a"
    set "_kat="
    for /f "delims=" %%v in ("%%b") do set "_kat=%%v"
    call :_ka_pick
    endlocal
)
set "_kan=0"
for /f "usebackq delims=" %%p in ("!_kaf!\kill.txt") do set /a _kan+=1
if "!_kan!"=="0" goto killall_none
echo.
echo  %y%!_kan! app^(s^) listed as Stop will be force-stopped.%w% A force-stopped app gets no
echo  notifications, alarms, reminders or background sync until you open it again - a
echo  messenger stays silent and an alarm app does not ring. Apps marked Skip keep running.
echo.
echo    [Y] Stop them    [N] Cancel
:: Ctrl+C makes choice return 0 - treated as cancel.
choice /c:YN /n >nul
if errorlevel 2 goto killall_end
if not errorlevel 1 goto killall_end
echo.
call :_act_reset
for /f "usebackq delims=" %%p in ("!_kaf!\kill.txt") do (
    adb shell am force-stop %%p <nul >nul 2>&1
    call :_act_rc !errorlevel! "stopped %%p"
)
:: kill-all only ends background processes the system can safely kill; it force-stops nothing.
adb shell am kill-all <nul >nul 2>&1
call :_act_rc !errorlevel! "background processes of all apps ended"
call :_act_summary
goto killall_end

:killall_none
echo [%y%WARN%w%] Nothing to stop: the phone listed no third-party app that is not protected.
echo        If it dropped, reconnect it and try again.
goto killall_end

:killall_notmp
echo [%r%^^!%w%] Could not create the scratch folder !_kaf!
echo        Nothing was stopped.

:killall_end
if exist "!_kaf!\" rd /s /q "!_kaf!" >nul 2>&1
echo.
echo Press Any Button To Go Back
pause > nul
goto Optimize

:_ka_line
:: _kaln = one answer line, delayed expansion off. Arg 1 = .C pkg/cls list or .P names, arg 2 = why.
:: A line with any other character is dropped whole, which keeps * and ? out of the plain for.
setlocal EnableDelayedExpansion
if not defined _kaln (endlocal & exit /b)
set "_kbad="
for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/$=:;,- " %%c in ("!_kaln!") do set "_kbad=1"
if defined _kbad (endlocal & exit /b)
set "_kaln=!_kaln::= !"
set "_kaln=!_kaln:;= !"
for %%t in (!_kaln!) do (
    set "_kat=%%t"
    call :_ka_tok %~1 %2
)
endlocal
exit /b

:_ka_tok
:: _kat = one piece; arg 1 = C or .C for pkg/cls, P or .P for a package; arg 2 = the reason.
:: Valid: a letter, then letters, digits, dots, underscores, with a dot - so null or true fail.
setlocal EnableDelayedExpansion
set "_kp=!_kat!"
if not defined _kp (endlocal & exit /b)
set "_km=%~1"
set "_km=!_km:.=!"
if /i "!_km!"=="C" if "!_kp:/=!"=="!_kp!" (endlocal & exit /b)
for /f "delims=/" %%x in ("!_kp!") do set "_kp=%%x"
set "_kbad="
for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%c in ("!_kp!") do set "_kbad=1"
if "!_kp:.=!"=="!_kp!" set "_kbad=1"
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%c in ("!_kp:~0,1!") do set "_kbad=1"
if defined _kbad (endlocal & exit /b)
>>"!_kaf!\prot.txt" echo !_kp! %~2
endlocal
exit /b

:_ka_pick
:: _kah/_kat = one pm list packages -3 line split at the first colon, delayed expansion off.
:: A plain package name goes on the kill list unless _KAP_name protects it.
setlocal EnableDelayedExpansion
if not "!_kah!"=="package" (endlocal & exit /b)
if not defined _kat (endlocal & exit /b)
set "_kbad="
for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%c in ("!_kat!") do set "_kbad=1"
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%c in ("!_kat:~0,1!") do set "_kbad=1"
if defined _kbad (endlocal & exit /b)
set "_kr="
for %%n in (!_kat!) do set "_kr=!_KAP_%%n!"
if defined _kr goto _ka_pick_skip
>>"!_kaf!\kill.txt" echo !_kat!
echo    Stop  !_kat!
endlocal
exit /b

:_ka_pick_skip
echo    Skip  !_kat!  ^(!_kr!^)
endlocal
exit /b

:compile
@echo off
cls
title Compile App
:: cmd package compile needs Android 7; older phones would also report success for anything.
if !SDK! GTR 0 if !SDK! LSS 24 goto compile_old
echo.
echo.
echo Enter The Mode You Want ^^!
echo Valid modes: speed, speed-profile, verify, quicken, everything, everything-profile
echo Recommended: speed (best performance, slower install)
echo.
set "mode=" & set /p mode="Choose A Mode >> "
call :_noin mode || goto dcx_noinput
:: Validate mode against the list ART accepts.
set "modeok=0"
for %%m in (speed speed-profile verify quicken everything everything-profile) do (
    if /i "!mode!"=="%%m" set "modeok=1"
)
:: The modes live in three places - the Valid modes line, this loop and the error; keep them equal.
:: Keep :: comments out of the if block below: inside it they print a drive error.
if "%modeok%"=="0" (
    echo [%r%^^!%w%] Invalid mode. Use one of: speed, speed-profile, verify, quicken,
    echo     everything, everything-profile.
    pause > nul
    goto Optimize
)
set "package=" & set /p package="Package name, or part of one >> "
call :_noin package || goto dcx_noinput
if "!package!"=="" (
    echo [%r%^^!%w%] Package name cannot be empty.
    pause > nul
    goto Optimize
)
call :_pkg_pick package inst || goto Optimize
set "_PKGCHK=!package!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto Optimize
)
call :_pkg_installed !package!
if errorlevel 2 (
    echo [%r%^^!%w%] The phone did not answer the package list - check the connection.
    pause > nul
    goto Optimize
)
if errorlevel 1 (
    echo [%r%^^!%w%] Package "!package!" is not installed on the device.
    pause > nul
    goto Optimize
)
echo.
echo Compiling !package! with mode %mode%...
adb shell cmd package compile -m %mode% -f !package! <nul
if errorlevel 1 (
    echo [%r%^^!%w%] Compile reported a failure for !package!.
) else (
    echo [%g%+%w%] Compile finished for !package! ^(mode %mode%^).
)
echo Press Any Button To Go Back
pause > nul
goto Optimize

:compile_old
echo.
echo [%r%^^!%w%] Compiling one app needs Android 7 or newer ^(API 24+^); the phone reports API !SDK!.
echo Press Any Button To Go Back
pause > nul
goto Optimize

:cache
mode 100,37
cls
title Clear Cache
echo [1] %c%Clear Cache%w%
echo [2] %c%Back%w%
set "k=" & set /p k="Choose An Option >> "
call :_noin k || goto dcx_noinput
if "!k!"=="1" goto sdgb
if "!k!"=="2" goto Optimize
:: guard against invalid input
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
call :_noin k || goto dcx_noinput
:: Each sub-screen returns to the screen it came from.
if "!k!"=="1" goto cache_trim
if "!k!"=="2" goto cache_wipe
if "!k!"=="3" goto cache
goto sdgb

:cache_trim
cls
echo Trimming system cache (may take a moment)...
adb shell pm trim-caches 1200G <nul
if errorlevel 1 (
    echo [%r%^^!%w%] trim-caches reported a failure. Nothing else was changed.
) else (
    echo [%g%+%w%] Trim requested. Press any key.
)
pause > nul
goto sdgb

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
goto sdgb

:cache_wipe_go
echo.
adb shell "su -c 'echo _DCXROOT'" <nul 2>nul | findstr /C:"_DCXROOT" >nul
if not errorlevel 1 goto cache_wipe_root_ok
echo [%r%^^!%w%] Root is not available on this device - nothing was wiped.
echo      This wipe needs a rooted device such as Magisk.
echo.
echo Press Any Button To Go Back
pause > nul
goto sdgb

:cache_wipe_root_ok
echo Wiping all app cache folders...
:: Plain $p, not backslash-escaped: the escaped form reaches su literally and wipes nothing.
adb shell "su -c 'for p in /data/data/*/cache; do rm -rf $p/*; done'" <nul
echo Cache wipe complete. A reboot is recommended.
pause > nul
goto sdgb
:: battery
:Battery
@echo off
cls
title Battery Mode
cls
echo                                                                                            Page%g%[%w%1/2%g%]
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
call :_uptime
if defined _upt echo           [%g%+%w%]Uptime: !_upt!
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
for /f "delims=" %%a in ("!cpucheck!") do set "cpucheck=%%a"
echo           [%g%+%w%]!cpucheck! LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %gold%[%w%1%gold%]%w% Toggle Power Saver
echo                                     %gold%[%w%2%gold%]%w% Toggle Animation
echo                                     %gold%[%w%3%gold%]%w% Wi-Fi/BT scan and related
echo                                     %gold%[%w%4%gold%]%w% Toggle Sync ^(placebo key^)
echo                                     %gold%[%w%5%gold%]%w% Samsung motion ^(OEM^)
echo                                     %gold%[%w%6%gold%]%w% ZRAM preference ^(reboot^)
echo                                     %gold%[%w%7%gold%]%w% Aggressive saver constants
echo                                     %gold%[%w%8%gold%]%w% Toggle Send Error
echo                                     %gold%[%w%9%gold%]%w% ART lock profiling ^(dev^)
echo                                     %gold%[%w%10%gold%]%w% Toggle Logs/etc
echo                                     %gold%[%w%11%gold%]%w% Next Page
echo                                     %gold%[%w%12%gold%]%w% Back

:Battery_ask
:: Re-ask without redrawing on empty input, so a phantom empty line does not re-run the probes.
set "opt=" & set /p opt="Choose An Option >> "
call :_noin opt || goto dcx_noinput
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
:: guard against invalid input
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
echo                                     %gold%[%w%A%gold%]%w% Drain leaderboard + Wake-Lock Audit
echo                                     %gold%[%w%B%gold%]%w% Toggle Finish Activities
echo                                     %gold%[%w%C%gold%]%w% Per-app battery restrict
echo                                     %gold%[%w%D%gold%]%w% App check  (late notifications, battery mode)
echo                                     %gold%[%w%0%gold%]%w% Back
echo.
echo.
set "ksd=" & set /p ksd="Choose An Option >> "
call :_noin ksd || goto dcx_noinput
if "!ksd!"=="1" goto logappsuser
if "!ksd!"=="2" goto universallogs
if "!ksd!"=="3" goto Deviceidle
if "!ksd!"=="4" goto hibernateapp
if "!ksd!"=="5" goto refreshlock
if "!ksd!"=="6" goto forcedoze
if "!ksd!"=="7" goto apphibernation
if "!ksd!"=="8" goto syncmaster
if "!ksd!"=="9" goto hotwordtoggle
if /i "!ksd!"=="A" goto drainboard_scan
if /i "!ksd!"=="B" goto finishact
if /i "!ksd!"=="C" goto appbattery
if /i "!ksd!"=="D" goto appcheck_bat
if "!ksd!"=="0" goto Battery
:: guard against invalid input
goto nextpage
:: ===================================================================
:: Per-app battery restrict: inactive, standby bucket and hibernation for one package. Reversible.
:appbattery
cls
title Per-app battery restrict
call :logo
echo.
echo  Restrict one package without the full Hibernate App hammer.
echo  Levels use real ADB commands: set-inactive, standby-bucket,
echo  bg-restriction-level, and ^(API 34+^) app_hibernation set-state.
echo.
set "BPKG=" & set /p BPKG="Package name, or part of one >> "
call :_noin BPKG || goto dcx_noinput
if not defined BPKG goto nextpage
set "BPKG=!BPKG:"=!"
call :_pkg_pick BPKG inst || goto appbattery
:: Check with :_pkg_ok, not an inline pipe to findstr: a pipe re-parses the name and runs its tail.
set "_PKGCHK=!BPKG!"
call :_pkg_ok || (
    echo  %r%Invalid package name.%w%
    timeout /t 2 /nobreak >nul
    goto appbattery
)
call :_pkg_installed !BPKG!
if errorlevel 2 (
    echo  %r%The phone did not answer the package list%w% - check the connection.
    timeout /t 2 /nobreak >nul
    goto appbattery
)
if errorlevel 1 (
    echo  %r%Package not installed:%w% !BPKG!
    timeout /t 2 /nobreak >nul
    goto appbattery
)

:appbattery_menu
cls
title Per-app battery - !BPKG!
call :logo
echo.
echo  Package: %g%!BPKG!%w%
echo  Current:
set "_inact=" & set "_bucket=" & set "_hib="
for /f "delims=" %%i in ('adb shell am get-inactive !BPKG! 2^>nul ^<nul') do set "_inact=%%i"
for /f "delims=" %%i in ('adb shell am get-standby-bucket !BPKG! 2^>nul ^<nul') do set "_bucket=%%i"
if %SDK% GEQ 34 for /f "delims=" %%i in ('adb shell cmd app_hibernation get-state !BPKG! 2^>nul ^<nul') do set "_hib=%%i"
echo    inactive        : !_inact!
echo    standby-bucket  : !_bucket!
if %SDK% GEQ 34 (echo    hibernation     : !_hib!) else (echo    hibernation     : ^(needs API 34+^))
echo.
echo    %g%[%w%1%g%]%w% Light   - inactive on, standby rare
echo    %g%[%w%2%g%]%w% Medium  - restricted bucket + bg-restriction
echo    %g%[%w%3%g%]%w% Heavy   - hibernation state ^(API 34+^) + medium + battery exemption off
echo    %g%[%w%4%g%]%w% Unrestrict - active / unrestricted / hibernation off
echo    %g%[%w%5%g%]%w% Back
set "ab=" & set /p ab="Choose An Option >> "
call :_noin ab || goto dcx_noinput
if not defined ab goto appbattery_menu
if "!ab!"=="1" goto appbattery_light
if "!ab!"=="2" goto appbattery_med
if "!ab!"=="3" goto appbattery_heavy
if "!ab!"=="4" goto appbattery_clear
if "!ab!"=="5" goto nextpage
goto appbattery_menu

:appbattery_light
echo.
call :_act_reset
adb shell am set-inactive !BPKG! true <nul
call :_act_rc !errorlevel! "inactive flag set"
adb shell am set-standby-bucket !BPKG! rare <nul
call :_act_rc !errorlevel! "standby bucket = rare"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Applied Light restrict.
goto appbattery_done

:appbattery_med
echo.
call :_act_reset
adb shell am set-inactive !BPKG! true <nul
call :_act_rc !errorlevel! "inactive flag set"
adb shell am set-standby-bucket !BPKG! restricted <nul
call :_act_rc !errorlevel! "standby bucket = restricted"
:: restricted_bucket is the level; restricted is only a bucket name. The level exists from Android 14.
if %SDK% GEQ 34 adb shell cmd activity set-bg-restriction-level --user 0 !BPKG! restricted_bucket <nul
if %SDK% GEQ 34 call :_act_rc !errorlevel! "background restriction level = restricted_bucket"
if %SDK% LSS 34 echo [%b%i%w%] background restriction level: needs Android 14 - skipped.
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Applied Medium restrict.
goto appbattery_done

:appbattery_heavy
if %SDK% LSS 34 (
    echo  %y%API %SDK% - heavy hibernation needs 34+. Applying Medium instead.%w%
    goto appbattery_med
)
:: The battery-optimisation exemption goes too: capture it before any change, as App check does.
call :_tw_undo_bgm !BPKG!
if errorlevel 2 goto appbattery_noundo
if errorlevel 1 (set "_bpu=") else set "_bpu=1"
adb shell am set-inactive !BPKG! true <nul
adb shell am set-standby-bucket !BPKG! restricted <nul
adb shell cmd activity set-bg-restriction-level --user 0 !BPKG! hibernation <nul
adb shell cmd app_hibernation set-state !BPKG! true <nul
adb shell cmd deviceidle whitelist -!BPKG! <nul >nul 2>&1
echo.
if defined _bpu echo [%b%i%w%] Battery-optimisation exemption removed - Tweaks ^> Undo can put it back.
if not defined _bpu echo [%y%WARN%w%] Battery-optimisation exemption removed - not recorded for Undo.
set "_hib="
for /f "delims=" %%i in ('adb shell cmd app_hibernation get-state !BPKG! 2^>nul ^<nul') do set "_hib=%%i"
if /i "!_hib!"=="true" (echo [%g%+%w%] hibernation state = true) else (echo [%y%WARN%w%] hibernation readout = "!_hib!")
goto appbattery_done

:appbattery_clear
:: Each clear is counted by its exit code, which adb passes back.
echo.
call :_act_reset
adb shell am set-inactive !BPKG! false <nul
call :_act_rc !errorlevel! "inactive flag cleared"
adb shell am set-standby-bucket !BPKG! active <nul
call :_act_rc !errorlevel! "standby bucket = active"
if %SDK% GEQ 34 adb shell cmd activity set-bg-restriction-level --user 0 !BPKG! unrestricted <nul
if %SDK% GEQ 34 call :_act_rc !errorlevel! "background restriction level = unrestricted"
if %SDK% LSS 34 echo [%b%i%w%] background restriction level: needs Android 14 - skipped.
if %SDK% GEQ 34 adb shell cmd app_hibernation set-state !BPKG! false <nul
if %SDK% GEQ 34 call :_act_rc !errorlevel! "hibernation state = false"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Restrictions cleared ^(reboot recommended if the app still misbehaves^).
goto appbattery_done

:appbattery_noundo
echo.
echo [%r%^^!%w%] DCX could not record !BPKG!'s current state for Undo, so nothing was changed.
echo        Check the phone is connected and answering, then try again.

:appbattery_done
echo.
echo  Press any key . . .
pause >nul
goto appbattery_menu
:: ===================================================================
:: App check: what holds one app's notifications back, and Settings' own battery modes.
:: Entry: set ACK_PKG and ACK_RET (label for Back), then goto appcheck.
:: ===================================================================
:appcheck_bat
set "ACK_RET=nextpage"
goto appcheck_pkg

:appcheck_pkg
if not defined ACK_RET set "ACK_RET=menu"
cls
title App check
call :logo
echo.
echo  Why are one app's notifications late? This screen shows what Android is doing to it,
echo  then sets the battery mode Settings offers: Restricted, Optimized or Unrestricted.
echo  Tip: type part of a name, such as chrome, to pick the app from a list.
echo.
set "ackp=" & set /p ackp="Package name or part of one (blank = back) >> "
call :_noin ackp || goto dcx_noinput
if not defined ackp goto appcheck_back
call :_pkg_pick ackp inst || goto appcheck_pkg
set "ACK_PKG=!ackp!"
goto appcheck

:appcheck_badpkg
echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
timeout /t 2 /nobreak >nul
goto appcheck_pkg

:appcheck
if not defined ACK_RET set "ACK_RET=menu"
set "_PKGCHK=!ACK_PKG!"
call :_pkg_ok || goto appcheck_badpkg
set "ACK_PKG=!_PKGCHK!"
if %SDK% LSS 28 goto appcheck_old
cls
title App check - !ACK_PKG!
call :logo
echo.
echo  Reading !ACK_PKG! ...
call :_ac_read
if errorlevel 2 goto appcheck_notmp
if errorlevel 1 goto appcheck_noanswer
if not defined _ac_inst goto appcheck_notinst
call :_ac_mode

:appcheck_draw
cls
title App check - !ACK_PKG!
call :logo
echo  Package: %g%!ACK_PKG!%w%
echo.
call :_ac_show
echo.
echo  Battery mode now: %gold%!_ac_mt!%w%
echo.
echo    %g%[%w%1%g%]%w% Restricted     %g%[%w%2%g%]%w% Optimized     %g%[%w%3%g%]%w% Unrestricted
echo    %g%[%w%4%g%]%w% Back to Android's default: background allowed, not idle, not hibernated
echo    %g%[%w%5%g%]%w% Check again
if "!_ac_stp!"=="1" (set "_ac_bk=7") else (set "_ac_bk=6")
if "!_ac_stp!"=="1" echo    %g%[%w%6%g%]%w% Clear the force-stop
echo    %g%[%w%!_ac_bk!%g%]%w% Back

:appcheck_ask
set "ack=" & set /p ack="Choose An Option >> "
call :_noin ack || goto dcx_noinput
if not defined ack goto appcheck_ask
if "!ack!"=="1" (set "_ac_want=R" & goto appcheck_set)
if "!ack!"=="2" (set "_ac_want=O" & goto appcheck_set)
if "!ack!"=="3" (set "_ac_want=U" & goto appcheck_set)
if "!ack!"=="4" goto appcheck_clear
if "!ack!"=="5" goto appcheck
if "!ack!"=="6" if "!_ac_stp!"=="1" goto appcheck_unstop
if "!ack!"=="!_ac_bk!" goto appcheck_back
goto appcheck_ask

:appcheck_direct
:: App Manager [1] / [2]: read the state quietly, then straight to the writer.
set "_PKGCHK=!ACK_PKG!"
call :_pkg_ok || goto appcheck_badpkg
set "ACK_PKG=!_PKGCHK!"
if %SDK% LSS 28 goto appcheck_old
echo.
echo  Reading !ACK_PKG! ...
call :_ac_read
if errorlevel 2 goto appcheck_notmp
if errorlevel 1 goto appcheck_noanswer
if not defined _ac_inst goto appcheck_notinst
call :_ac_mode
goto appcheck_set

:appcheck_old
echo.
if "%SDK%"=="0" echo [%r%^^!%w%] The Android version could not be read, so App check cannot run.
if not "%SDK%"=="0" echo [%r%^^!%w%] App check needs Android 9 ^(API 28^) or newer; this phone reports API %SDK%.
goto appcheck_hold

:appcheck_noanswer
echo.
echo [%r%^^!%w%] The phone did not answer. Check the cable or Wi-Fi ADB and try again.
goto appcheck_hold

:appcheck_notinst
echo.
echo [%r%^^!%w%] !ACK_PKG! is not installed for this user.
echo        If Debloat removed it, App Manager - Restore a removed app brings it back.
goto appcheck_hold

:appcheck_notmp
echo.
echo [%r%^^!%w%] Could not create the scratch folder !DCX_TMP!\appcheck - nothing was read.

:appcheck_hold
echo.
echo  Press any key . . .
pause >nul

:appcheck_back
if exist "!DCX_TMP!\appcheck\" rd /s /q "!DCX_TMP!\appcheck" >nul 2>&1
set "_ac_ret=!ACK_RET!" & set "ACK_RET="
goto !_ac_ret!

:appcheck_set
:: _ac_want: R Restricted, O Optimized, U Unrestricted, A allow only (App Manager [2]).
if not defined _ac_op goto appcheck_set_unread
if "!_ac_want!"=="A" goto appcheck_set_go
if not defined _ac_wlu goto appcheck_set_unread
if "!_ac_wls!"=="1" goto appcheck_set_builtin
if "!_ac_want!"=="U" goto appcheck_set_uask
if "!_ac_wlu!"=="1" goto appcheck_set_rmask
goto appcheck_set_go

:appcheck_set_unread
echo.
echo [%r%^^!%w%] The current mode could not be read, so nothing was changed.
goto appcheck_done

:appcheck_set_noundo
echo [%r%^^!%w%] DCX could not record the current mode for Undo, so nothing was changed.
goto appcheck_done

:appcheck_set_builtin
echo.
echo [%b%i%w%] !ACK_PKG! is on the phone's built-in allowlist. Android exempts it from these
echo        modes and Settings greys them out, so nothing was changed. Battery page 2 -
echo        Toggle Deviceidle Whitelist can take built-in entries off until Revert.
goto appcheck_done

:appcheck_set_uask
echo.
echo  %y%Unrestricted%w% puts !ACK_PKG! on the Doze allowlist: it may run in the background at
echo  any time and can drain the battery. Worth it for an app that fetches its own messages
echo  ^(Signal without Play services, ntfy, email^), an alarm or reminder app, a VPN, a
echo  fitness tracker or an automation app.
echo.
echo    [Y] Set Unrestricted    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appcheck_draw
if not errorlevel 1 goto appcheck_draw
goto appcheck_set_go

:appcheck_set_rmask
echo.
echo  !ACK_PKG! is on the Doze allowlist now ^(Unrestricted^). Taking it off can delay
echo  messages from an app that fetches its own: Signal without Play services, ntfy, email.
echo  The session undo file can put it back ^(Tweaks - 14 Undo / backups^).
echo.
echo    [Y] Continue    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appcheck_draw
if not errorlevel 1 goto appcheck_draw

:appcheck_set_go
set "_ac_m=allow"
if "!_ac_want!"=="R" set "_ac_m=ignore"
echo.
call :_act_reset
call :_tw_undo_bgm !ACK_PKG!
if errorlevel 2 goto appcheck_set_noundo
adb shell cmd appops set !ACK_PKG! RUN_ANY_IN_BACKGROUND !_ac_m! <nul >nul 2>&1
adb shell cmd appops set !ACK_PKG! RUN_IN_BACKGROUND !_ac_m! <nul >nul 2>&1
call :_act_rc !errorlevel! "legacy RUN_IN_BACKGROUND = !_ac_m!"
if "!_ac_want!"=="U" adb shell cmd deviceidle whitelist +!ACK_PKG! <nul >nul 2>&1
if "!_ac_want!"=="R" adb shell cmd deviceidle whitelist -!ACK_PKG! <nul >nul 2>&1
if "!_ac_want!"=="O" adb shell cmd deviceidle whitelist -!ACK_PKG! <nul >nul 2>&1
call :_ac_vop !_ac_m!
if "!_ac_want!"=="U" call :_ac_vwl on
if "!_ac_want!"=="R" call :_ac_vwl off
if "!_ac_want!"=="O" call :_ac_vwl off
call :_act_summary

:appcheck_done
echo.
echo  Press any key . . .
pause >nul
goto appcheck

:appcheck_clear
:: Only what differs from the default is touched; the Doze allowlist is the mode choice and stays.
set "_ac_c="
if defined _ac_op if not "!_ac_op!"=="allow" set "_ac_c=1"
if "!_ac_hib!"=="1" set "_ac_c=1"
if "!_ac_idle!"=="1" set "_ac_c=1"
if defined _ac_sbhi set "_ac_c=1"
for %%l in (unrestricted restricted_bucket background_restricted hibernation) do if "!_ac_lv!"=="%%l" set "_ac_c=1"
if not defined _ac_c goto appcheck_clear_none
echo.
echo  Where it differs from Android's own default: background app-op back to allow, not
echo  hibernated, and on Android 14+ the restriction level Android picks itself. A low standby
echo  bucket is lifted to active, but only until Android re-rates the app from its real use,
echo  within a few hours. The Doze allowlist stays: [2] takes it off, [3] keeps the bucket exempt.
echo.
echo    [Y] Continue    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appcheck_draw
if not errorlevel 1 goto appcheck_draw
echo.
call :_act_reset
if not defined _ac_op goto appcheck_clear_hib
if "!_ac_op!"=="allow" goto appcheck_clear_hib
call :_tw_undo_bgm !ACK_PKG!
if errorlevel 2 goto appcheck_set_noundo
adb shell cmd appops set !ACK_PKG! RUN_ANY_IN_BACKGROUND allow <nul >nul 2>&1
adb shell cmd appops set !ACK_PKG! RUN_IN_BACKGROUND allow <nul >nul 2>&1
call :_act_rc !errorlevel! "legacy RUN_IN_BACKGROUND = allow"
call :_ac_vop allow

:appcheck_clear_hib
if not "!_ac_hib!"=="1" goto appcheck_clear_idle
adb shell cmd app_hibernation set-state !ACK_PKG! false <nul >nul 2>&1
adb shell cmd app_hibernation get-state !ACK_PKG! <nul >"!_acd!\hb.txt" 2>nul
set "_ac_vg="
findstr /b /c:"false" "!_acd!\hb.txt" >nul 2>&1 && set "_ac_vg=1"
call :_ac_vres "not hibernated"

:appcheck_clear_idle
if "!_ac_idle!"=="1" goto appcheck_clear_idle2
if not defined _ac_sbhi goto appcheck_clear_lv

:appcheck_clear_idle2
:: set-inactive false sets active with a usage reason; the next idle check re-rates it.
adb shell am set-inactive !ACK_PKG! false <nul >nul 2>&1
adb shell am get-inactive !ACK_PKG! <nul >"!_acd!\in.txt" 2>nul
set "_ac_vg="
findstr /b /c:"Idle=false" "!_acd!\in.txt" >nul 2>&1 && set "_ac_vg=1"
call :_ac_vres "not idle for now - Android re-rates it from real use within hours"

:appcheck_clear_lv
if %SDK% LSS 34 goto appcheck_clear_end
call :_ac_lvread
set "_ac_c="
for %%l in (unrestricted restricted_bucket background_restricted hibernation) do if "!_ac_lv!"=="%%l" set "_ac_c=1"
if not defined _ac_c goto appcheck_clear_end
adb shell cmd activity set-bg-restriction-level --user 0 !ACK_PKG! adaptive_bucket <nul >nul 2>&1
call :_ac_lvread
set "_ac_vg="
if "!_ac_lv!"=="adaptive_bucket" set "_ac_vg=1"
if "!_ac_lv!"=="exempted" set "_ac_vg=1"
call :_ac_vres "restriction level back to Android's own choice"

:appcheck_clear_end
call :_act_summary
echo [%b%i%w%] Hibernation, idle and the restriction level are not recorded in the undo file.
goto appcheck_done

:appcheck_clear_none
echo.
echo [%g%OK%w%] Nothing to clear: what was read already matches Android's default.
if "!_ac_stp!"=="1" echo      It is still force-stopped - [5] clears that.
goto appcheck_done

:appcheck_unstop
echo.
call :_act_reset
if %SDK% GEQ 35 goto appcheck_unstop_pm
echo  Android 14 and older have no pm unstop. Opening the app once clears a force-stop,
echo  so DCX can open it on the phone now - its first screen appears there.
echo.
echo    [Y] Open it on the phone    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto appcheck_draw
if not errorlevel 1 goto appcheck_draw
:: --pct-syskeys 0: without it monkey refuses to start on a phone lacking hardware system keys.
adb shell monkey -p !ACK_PKG! -c android.intent.category.LAUNCHER --pct-syskeys 0 1 <nul >nul 2>&1
call :_act_rc !errorlevel! "opened through its launcher entry"
timeout /t 2 /nobreak >nul
goto appcheck_unstop_chk

:appcheck_unstop_pm
adb shell pm unstop !ACK_PKG! <nul >nul 2>&1
call :_act_rc !errorlevel! "pm unstop"

:appcheck_unstop_chk
adb shell "dumpsys package !ACK_PKG! | grep -m1 'User 0: ceDataInode='" <nul >"!_acd!\pk.txt" 2>nul
set "_ac_vg="
findstr /c:" stopped=false" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_vg=1"
call :_ac_vres "not force-stopped"
call :_act_summary
goto appcheck_done

:_ac_read
:: Fills the _ac_* flags; phone text only reaches findstr, as a file. 1 = no answer, 2 = no folder.
for %%v in (inst stp nl sus dis pn op opu wlu wls wlx sb sbhi idle lv hib) do set "_ac_%%v="
set "_acd=!DCX_TMP!\appcheck"
if not exist "!_acd!\" md "!_acd!" >nul 2>&1
if not exist "!_acd!\" exit /b 2
del /q "!_acd!\*.txt" >nul 2>&1
adb shell "dumpsys package !ACK_PKG! | grep -m1 'User 0: ceDataInode='; echo _DCXEND" <nul >"!_acd!\pk.txt" 2>nul
findstr /c:"_DCXEND" "!_acd!\pk.txt" >nul 2>&1 || exit /b 1
findstr /c:" installed=true" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_inst=1"
if not defined _ac_inst (adb shell pm path !ACK_PKG! <nul >nul 2>&1 && set "_ac_inst=2")
if not defined _ac_inst exit /b 0
findstr /c:" stopped=true" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_stp=1"
findstr /c:" stopped=false" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_stp=0"
set "_ac_nl=0"
findstr /c:" notLaunched=true" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_nl=1"
findstr /c:" suspended=true" "!_acd!\pk.txt" >nul 2>&1 && set "_ac_sus=1"
for %%e in (2 3 4) do findstr /c:" enabled=%%e " "!_acd!\pk.txt" >nul 2>&1 && set "_ac_dis=1"
if %SDK% GEQ 33 adb shell "dumpsys package !ACK_PKG! | grep -m1 'POST_NOTIFICATIONS: granted='" <nul >"!_acd!\pn.txt" 2>nul
if %SDK% GEQ 33 findstr /c:"POST_NOTIFICATIONS: granted=true" "!_acd!\pn.txt" >nul 2>&1 && set "_ac_pn=1"
if %SDK% GEQ 33 findstr /c:"POST_NOTIFICATIONS: granted=false" "!_acd!\pn.txt" >nul 2>&1 && set "_ac_pn=0"
adb shell cmd appops get !ACK_PKG! RUN_ANY_IN_BACKGROUND <nul >"!_acd!\op.txt" 2>nul
call :_ac_opmode op RUN_ANY_IN_BACKGROUND _ac_op _ac_opu
:: The marker follows only a clean exit, so a refused list never reads as not listed.
adb shell "cmd deviceidle whitelist && echo _DCXEND" <nul >"!_acd!\wl.txt" 2>nul
findstr /c:"_DCXEND" "!_acd!\wl.txt" >nul 2>&1 && set "_ac_wlu=0"
if defined _ac_wlu set "_ac_wls=0"
if defined _ac_wlu findstr /b /c:"user,!ACK_PKG!," "!_acd!\wl.txt" >nul 2>&1 && set "_ac_wlu=1"
if defined _ac_wlu findstr /b /c:"system,!ACK_PKG!," "!_acd!\wl.txt" >nul 2>&1 && set "_ac_wls=1"
if defined _ac_wlu findstr /b /c:"system-excidle,!ACK_PKG!," "!_acd!\wl.txt" >nul 2>&1 && set "_ac_wlx=1"
adb shell am get-standby-bucket !ACK_PKG! <nul >"!_acd!\sb.txt" 2>nul
:: Ascending, so 50 overrides the 5 that /b also finds in it.
for %%n in (5 10 20 30 40 45 50) do findstr /b /c:"%%n" "!_acd!\sb.txt" >nul 2>&1 && set "_ac_sb=%%n"
for %%n in (40 45 50) do if "!_ac_sb!"=="%%n" set "_ac_sbhi=1"
adb shell am get-inactive !ACK_PKG! <nul >"!_acd!\in.txt" 2>nul
findstr /b /c:"Idle=true" "!_acd!\in.txt" >nul 2>&1 && set "_ac_idle=1"
findstr /b /c:"Idle=false" "!_acd!\in.txt" >nul 2>&1 && set "_ac_idle=0"
if %SDK% GEQ 34 call :_ac_lvread
if %SDK% GEQ 31 adb shell cmd app_hibernation get-state !ACK_PKG! <nul >"!_acd!\hb.txt" 2>nul
if %SDK% GEQ 31 findstr /b /c:"true" "!_acd!\hb.txt" >nul 2>&1 && set "_ac_hib=1"
if %SDK% GEQ 31 findstr /b /c:"false" "!_acd!\hb.txt" >nul 2>&1 && set "_ac_hib=0"
exit /b 0

:_ac_lvread
set "_ac_lv="
adb shell cmd activity get-bg-restriction-level --user 0 !ACK_PKG! <nul >"!_acd!\lv.txt" 2>nul
for %%l in (unknown unrestricted exempted adaptive_bucket restricted_bucket background_restricted hibernation stopped user_only custom) do findstr /b /c:"%%l" "!_acd!\lv.txt" >nul 2>&1 && set "_ac_lv=%%l"
exit /b 0

:_ac_opmode
:: %1 answer file, %2 op, %3 / %4 package and uid mode. No line = allow, empty = no answer.
set "%~3=" & set "%~4="
findstr /b /c:"No operations." "!_acd!\%~1.txt" >nul 2>&1 && set "%~3=allow"
for %%m in (allow ignore deny foreground default) do findstr /b /c:"Uid mode: %~2: %%m" "!_acd!\%~1.txt" >nul 2>&1 && set "%~4=%%m"
for %%m in (allow ignore deny foreground default) do findstr /b /c:"%~2: %%m" "!_acd!\%~1.txt" >nul 2>&1 && set "%~3=%%m"
if defined %~4 if not defined %~3 set "%~3=allow"
exit /b 0

:_ac_mode
:: Settings' BatteryOptimizeUtils: ignore+off Restricted, allow+on Unrestricted, allow+off Optimized.
set "_ac_eff=!_ac_op!"
if defined _ac_opu if not "!_ac_opu!"=="allow" if not "!_ac_opu!"=="default" set "_ac_eff=!_ac_opu!"
set "_ac_wlt=off"
if "!_ac_wlu!"=="1" set "_ac_wlt=on"
set "_ac_mode=?"
set "_ac_mt=could not be read"
if not defined _ac_eff exit /b
if not defined _ac_wlu exit /b
set "_ac_mode=X"
set "_ac_mt=none that Settings can show"
if "!_ac_eff!!_ac_wlu!"=="ignore0" (set "_ac_mode=R" & set "_ac_mt=Restricted")
if "!_ac_eff!!_ac_wlu!"=="deny0" (set "_ac_mode=D" & set "_ac_mt=Restricted, written as deny")
if "!_ac_eff!!_ac_wlu!"=="allow0" (set "_ac_mode=O" & set "_ac_mt=Optimized")
if "!_ac_eff!!_ac_wlu!"=="allow1" (set "_ac_mode=U" & set "_ac_mt=Unrestricted")
if "!_ac_wls!"=="1" (set "_ac_mode=B" & set "_ac_mt=Unrestricted, built in")
exit /b

:_ac_show
:: BLOCKS = nothing arrives until it is fixed, DELAYS = arrives late.
set "_ac_nb=0" & set "_ac_nd=0" & set "_ac_nu=0"
if "!_ac_stp!!_ac_nl!"=="11" call :_ac_ln B "Never opened since it was installed: no push, alarms or jobs"
if "!_ac_stp!!_ac_nl!"=="11" call :_ac_ln C "until it is opened once. [5] clears it."
if "!_ac_stp!!_ac_nl!"=="10" call :_ac_ln B "Force-stopped by Force stop, Kill all or hibernation: no push,"
if "!_ac_stp!!_ac_nl!"=="10" call :_ac_ln C "alarms or jobs until it is opened once. [5] clears it."
if "!_ac_stp!"=="0" call :_ac_ln K "Not force-stopped."
if not defined _ac_stp call :_ac_ln U "Force-stop state could not be read."
if "!_ac_sus!"=="1" call :_ac_ln B "Paused by Digital Wellbeing, Focus mode or an app timer."
if "!_ac_dis!"=="1" call :_ac_ln B "Disabled for this user."
if %SDK% LSS 33 call :_ac_ln I "Notification on or off is not readable before Android 13."
if %SDK% GEQ 33 if "!_ac_pn!"=="0" call :_ac_ln B "Notification permission not granted: Settings, Notifications."
if %SDK% GEQ 33 if "!_ac_pn!"=="1" call :_ac_ln K "Notifications allowed."
if %SDK% GEQ 33 if not defined _ac_pn call :_ac_ln I "Notification permission not found - the app may not ask for it."
if %SDK% GEQ 31 if "!_ac_hib!"=="1" call :_ac_ln B "Hibernated by the unused-app pause or Hibernate App. [4] wakes it."
if %SDK% GEQ 31 if "!_ac_hib!"=="0" call :_ac_ln K "Not hibernated."
if %SDK% GEQ 31 if not defined _ac_hib call :_ac_ln U "Hibernation state could not be read."
if "!_ac_mode!"=="R" call :_ac_ln D "Restricted: no background work, alarms held back - messages can come late."
if "!_ac_mode!"=="D" call :_ac_ln D "Restricted, written as deny by an older DCX. Settings greys it out or"
if "!_ac_mode!"=="D" call :_ac_ln C "shows it wrongly; [1] rewrites it the way Settings does."
if "!_ac_mode!"=="O" call :_ac_ln K "Optimized, Android's default. High-priority push still gets through Doze."
if "!_ac_mode!"=="U" call :_ac_ln K "Unrestricted: on the Doze allowlist, may run in the background any time."
if "!_ac_mode!"=="B" call :_ac_ln K "On the phone's built-in allowlist: exempt. Settings greys the choice out."
if "!_ac_mode!"=="X" call :_ac_ln I "Background op !_ac_eff!, Doze allowlist !_ac_wlt!: no mode Settings can show."
if "!_ac_mode!"=="?" call :_ac_ln U "Battery mode could not be read."
if defined _ac_opu if not "!_ac_opu!"=="allow" if not "!_ac_opu!"=="default" call :_ac_ln I "A uid-level app-op, !_ac_opu!, overrides this for every app on its uid."
if defined _ac_wlx if not "!_ac_wls!"=="1" call :_ac_ln I "On the built-in except-idle list: no background limits outside Doze."
if "!_ac_sb!"=="5" call :_ac_ln K "Standby bucket: exempted."
if "!_ac_sb!"=="10" call :_ac_ln K "Standby bucket: active."
if "!_ac_sb!"=="20" call :_ac_ln K "Standby bucket: working set."
if "!_ac_sb!"=="30" call :_ac_ln K "Standby bucket: frequent."
if "!_ac_sb!"=="40" call :_ac_ln D "Standby bucket: rare - jobs 10 min a day, alarms once an hour, no background net."
if "!_ac_sb!"=="45" call :_ac_ln D "Standby bucket: restricted - jobs and alarms about once a day."
if "!_ac_sb!"=="50" call :_ac_ln D "Standby bucket: never - Android treats it as never used."
if defined _ac_sbhi call :_ac_ln C "[4] lifts it for a few hours; [3] Unrestricted keeps it exempt."
if not defined _ac_sb call :_ac_ln U "Standby bucket could not be read."
if not defined _ac_idle call :_ac_ln U "Inactive flag could not be read."
if "!_ac_idle!"=="1" if not defined _ac_sbhi call :_ac_ln D "Marked inactive, so treated as unused. [4] clears it for a while."
if defined _ac_lv call :_ac_ln I "Android's own restriction level: !_ac_lv!."
if "!_ac_lv!"=="unrestricted" call :_ac_ln C "Set by a tool; Android picks adaptive_bucket itself. [4] resets it."
if %SDK% LSS 31 call :_ac_ln I "Android 9 to 11 Settings: App info, Battery - Background restriction."
call :_ac_ln I "Android's own settings only: a phone maker's battery manager can still hold it back."
set "_ac_res=%g%nothing in Android's own settings holds it back%w%"
if not "!_ac_nu!"=="0" set "_ac_res=nothing that could be read holds it back"
if not "!_ac_nd!"=="0" set "_ac_res=%y%delayed%w% by !_ac_nd!"
if not "!_ac_nb!"=="0" set "_ac_res=%r%blocked%w% by !_ac_nb!, delayed by !_ac_nd!"
if not "!_ac_nu!"=="0" set "_ac_res=!_ac_res!; !_ac_nu! line(s) could not be read"
echo.
echo  Result: !_ac_res!.
exit /b

:_ac_ln
:: %1 = B blocks, D delays, K ok, I info, U unread, C continued; %2 = plain text, no cmd specials.
if "%~1"=="B" set /a _ac_nb+=1
if "%~1"=="D" set /a _ac_nd+=1
if "%~1"=="U" set /a _ac_nu+=1
if "%~1"=="B" echo  [%r%BLOCKS%w%] %~2
if "%~1"=="D" echo  [%y%DELAYS%w%] %~2
if "%~1"=="K" echo  [%g%OK%w%]     %~2
if "%~1"=="I" echo  [%b%i%w%]      %~2
if "%~1"=="U" echo  [%b%i%w%]      %~2
if "%~1"=="C" echo           %~2
exit /b

:_ac_vop
:: %1 = the RUN_ANY_IN_BACKGROUND mode just written; a uid mode other than allow/default fails it.
adb shell cmd appops get !ACK_PKG! RUN_ANY_IN_BACKGROUND <nul >"!_acd!\vo.txt" 2>nul
call :_ac_opmode vo RUN_ANY_IN_BACKGROUND _ac_vg _ac_vgu
set "_ac_vuo="
if defined _ac_vgu if not "!_ac_vgu!"=="allow" if not "!_ac_vgu!"=="default" if not "!_ac_vgu!"=="%~1" set "_ac_vuo=1"
if "!_ac_vg!!_ac_vuo!"=="%~1" (echo [%g%+%w%] RUN_ANY_IN_BACKGROUND = %~1 & set /a DCX_VOK+=1 & exit /b 0)
if defined _ac_vuo goto _ac_vop_uid
if not defined _ac_vg set "_ac_vg=no answer"
echo [%r%^^!%w%] wanted RUN_ANY_IN_BACKGROUND=%~1, the phone reports !_ac_vg!.
set /a DCX_VFAIL+=1
exit /b 1

:_ac_vop_uid
echo [%r%^^!%w%] RUN_ANY_IN_BACKGROUND=%~1 landed, but a uid-level !_ac_vgu! still overrides it.
set /a DCX_VFAIL+=1
exit /b 1

:_ac_vwl
:: %1 = on or off: where the app should now be on the user Doze allowlist; read back with =pkg.
adb shell cmd deviceidle whitelist =!ACK_PKG! <nul >"!_acd!\vw.txt" 2>nul
set "_ac_vg=no answer"
findstr /b /c:"true" "!_acd!\vw.txt" >nul 2>&1 && set "_ac_vg=on"
findstr /b /c:"false" "!_acd!\vw.txt" >nul 2>&1 && set "_ac_vg=off"
if "!_ac_vg!"=="%~1" (echo [%g%+%w%] Doze allowlist: %~1 & set /a DCX_VOK+=1 & exit /b 0)
echo [%r%^^!%w%] wanted Doze allowlist %~1, the phone reports !_ac_vg!.
set /a DCX_VFAIL+=1
exit /b 1

:_ac_vres
:: _ac_vg = 1 when the read-back matched; %1 = what was checked, no parentheses.
if defined _ac_vg (echo [%g%+%w%] %~1 & set /a DCX_VOK+=1 & exit /b 0)
echo [%r%^^!%w%] %~1 - the phone does not report it.
set /a DCX_VFAIL+=1
exit /b 1

:_ac_undo_op
:: %1 package, %2 app-op: one restore line for its package-level mode.
:: errorlevel 1 when the phone did not answer: only a DCX_SKIP comment was written.
adb shell cmd appops get %~1 %~2 <nul >"!_acd!\ua.txt" 2>nul
call :_ac_opmode ua %~2 _ac_ub _ac_ubu
if defined _ac_ub goto _ac_undo_op_emit
>>"!EXP_UNDO!" echo :: DCX_SKIP appops %~1 %~2 - the device did not answer
exit /b 1

:_ac_undo_op_emit
set "_BKCMD=cmd appops set %~1 %~2 !_ac_ub!"
call :_bk_emit EXP_UNDO || exit /b 1
exit /b 0

:_ac_undo_wl
:: %1 package: its user Doze allowlist entry, as whitelist + or -. errorlevel 1 as above.
adb shell cmd deviceidle whitelist =%~1 <nul >"!_acd!\uw.txt" 2>nul
set "_ac_ub="
findstr /b /c:"true" "!_acd!\uw.txt" >nul 2>&1 && set "_ac_ub=+"
findstr /b /c:"false" "!_acd!\uw.txt" >nul 2>&1 && set "_ac_ub=-"
if defined _ac_ub goto _ac_undo_wl_emit
>>"!EXP_UNDO!" echo :: DCX_SKIP deviceidle whitelist %~1 - the device did not answer
exit /b 1

:_ac_undo_wl_emit
set "_BKCMD=cmd deviceidle whitelist !_ac_ub!%~1"
call :_bk_emit EXP_UNDO || exit /b 1
exit /b 0
:: ===================================================================
:: Finish Activities, always_finish_activities: over adb it reads back set but on many builds may
:: not fully take effect, so the screen says so. Reversible; 0 = off, the default.
:finishact
cls
title Finish Activities
call :logo
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell settings get global always_finish_activities 2^>nul ^<nul') do echo    always_finish_activities = %%i
echo.
echo  Destroys each activity as soon as you leave it. Can trim background
echo  memory, at the cost of slower app resume.
echo.
echo                                     %gold%[%w%1%gold%]%w% Turn ON  (1)
echo                                     %gold%[%w%2%gold%]%w% Turn OFF (0, default)
echo                                     %gold%[%w%0%gold%]%w% Back
echo.
set "fa=" & set /p fa="Choose An Option >> "
call :_noin fa || goto dcx_noinput
if "!fa!"=="1" goto finishact_on
if "!fa!"=="2" goto finishact_off
if "!fa!"=="0" goto nextpage
goto finishact

:finishact_on
adb shell settings put global always_finish_activities 1 <nul
call :_finishact_readback
goto finishact_done

:finishact_off
adb shell settings put global always_finish_activities 0 <nul
call :_finishact_readback
goto finishact_done

:_finishact_readback
set "_fav="
for /f "delims=" %%i in ('adb shell settings get global always_finish_activities 2^>nul ^<nul') do set "_fav=%%i"
echo.
echo   Device now reports: always_finish_activities = !_fav!
echo   %gold%Note:%w% over ADB this flag reliably reports on/off, but on many builds it
echo   may not fully engage the way toggling it in Developer Options does. If you
echo   need it to truly take effect, set it there. Setting it back to 0 here always
echo   restores the default.
goto :eof

:finishact_done
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage
:: ===================================================================
:: Wake-Lock Audit: wake locks, battery stats, doze, alarms and CPU dumps in one report.
:wakelockaudit
cls
title Wake-Lock Audit
call :logo
echo.
echo  Generating wake-lock + battery-stats report - 5 dumps, ~5-10 seconds.
echo  %y%The window cannot accept input until this finishes.%w%
echo.
:: Progress goes to CON so it shows despite the block redirect. Timestamp is filename-safe.
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "WLREPORT=!TEMP!\dcx_wakelocks_%TS%.txt"
(
    echo ===========================================================
    echo  DCX Wake-Lock Audit - %date% %time%
    echo ===========================================================
    echo.
    echo    [1/5] held wake locks ^(this one is the slowest^)... 1>CON
    echo [Section 1] Currently held wake locks
    echo  ^(Each entry = something keeping CPU awake right now.
    echo   PARTIAL_WAKE_LOCK is the most common battery drain.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys power 2>/dev/null | grep -E 'Wake Locks:|PARTIAL_WAKE_LOCK|SCREEN_BRIGHT|FULL_WAKE_LOCK'" <nul
    echo.
    echo.
    echo    [2/5] battery stats since last charge... 1>CON
    echo [Section 2] Top wake-lock holders since last full charge
    echo  ^(Look at "Wake lock" totals - highest = biggest drainers.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys batterystats --charged 2>/dev/null | head -200" <nul
    echo.
    echo.
    echo    [3/5] doze state... 1>CON
    echo [Section 3] Doze ^(deep sleep^) state
    echo  ^(mState=IDLE means doze is active. ACTIVE = apps can run.^)
    echo -----------------------------------------------------------
    adb shell "dumpsys deviceidle 2>/dev/null | grep -E 'mState=|mLightState=|mActiveIdleOpCount|mScreenOn|mCharging'" <nul
    echo.
    echo.
    echo    [4/5] alarms and wakeups... 1>CON
    echo [Section 4] Top alarms ^(background wakeups^)
    echo -----------------------------------------------------------
    adb shell "dumpsys alarm 2>/dev/null | grep -E 'Top Alarms|wakeups in last|act=' | head -50" <nul
    echo.
    echo.
    echo    [5/5] CPU consumers... 1>CON
    echo [Section 5] Process CPU consumers ^(last sample^)
    echo -----------------------------------------------------------
    adb shell "dumpsys cpuinfo 2>/dev/null | head -25" <nul
    echo.
    echo ===========================================================
    echo  Quick interpretation:
    echo    - PARTIAL_WAKE_LOCK in Section 1 = active drainers
    echo    - In Section 2, an app with ^>1h "Wake lock" since charge
    echo      is the prime suspect
    echo    - High wakeup count in Section 4 = app pinging too often
    echo    - If mState ^^!= IDLE while screen is off, doze is blocked
    echo ===========================================================
) > "!WLREPORT!" < nul
:: Generated once; the menu re-shows without re-running the report or writing another file.
:wakelockaudit_menu
cls
call :logo
echo  %g%Report saved to:%w%
echo    !WLREPORT!
echo.
echo  %b%[%w%1%b%]%w% Open in Notepad (searchable)
echo  %b%[%w%2%b%]%w% Show paginated (MORE)
echo  %b%[%w%3%b%]%w% Show summary only
echo  %b%[%w%4%b%]%w% Back                     %d%(0 or Q also work)%w%
echo.
echo  %d%Feeling stuck? %g%0%d% or %g%Q%d% leaves this screen. Inside the paginated view
echo  it is %g%Q%d% ^(that is Windows' MORE pager, it only takes its own keys^).%w%

:wakelockaudit_menu_ask
:: Re-ask in place so a phantom empty line after the dumps does not look like an ignored key.
set "wl=" & set /p wl="Choose An Option >> "
call :_noin wl || goto dcx_noinput
if not defined wl goto wakelockaudit_menu_ask
if "!wl!"=="0" goto drainboard
if /i "!wl!"=="q" goto drainboard
if "!wl!"=="1" (
    start "" notepad "!WLREPORT!"
    goto wakelockaudit_menu
)
if "!wl!"=="2" (
    cls
    title Wake-Lock Audit  -  SPACE=next page   ENTER=one line   Q=quit back to menu
    echo  %d%[i]%w% Paging with MORE:  %g%SPACE%w% next page   %g%ENTER%w% one line   %g%Q%w% quit back to the menu.
    echo.
    more "!WLREPORT!"
    echo.
    echo Press Any Button To Go Back
    pause > nul
    goto wakelockaudit_menu
)
if not "!wl!"=="3" goto _skwl3
    cls
    echo Currently held wake locks:
    echo.
    :: Filter with grep on the device. Caret-escaped operators belong only inside a for /f clause.
    adb shell "dumpsys power 2>/dev/null | grep -E 'PARTIAL_WAKE_LOCK'" <nul
    echo.
    echo Doze state:
    adb shell "dumpsys deviceidle 2>/dev/null | grep -E 'mState=|mScreenOn'" <nul
    echo.
    echo Full report at: !WLREPORT!
    echo.
    pause > nul
    goto wakelockaudit_menu

:_skwl3
if "!wl!"=="4" goto drainboard
:: Nothing was printed, so the menu is still on screen - re-ask in place.
goto wakelockaudit_menu_ask
:: ===================================================================
:: Drain leaderboard: apps ranked by battery use since the stats reset. Read-only.
:drainboard
if not defined _dl_state goto drainboard_scan
goto drainboard_show

:drainboard_scan
cls
title Drain leaderboard
call :logo
for /f "delims==" %%v in ('set _dl 2^>nul') do set "%%v="
if defined DCX_TMP set "_dlf=!DCX_TMP!\drain"
set "_dl_bad=0" & set "_dl_n=0" & set "_DL_TOP=0"
if %SDK% LSS 31 goto drainboard_tooold
if not defined _dlf goto drainboard_notmp
if exist "!_dlf!\" rd /s /q "!_dlf!" >nul 2>&1
call :_dl_mkdir || goto drainboard_notmp
echo  Reading the phone: 6 queries, about 5-15 seconds. The window takes no input until then.
echo.
echo    [1/6] battery use since the stats reset...
if %SDK% LSS 34 goto drainboard_charged
set "_dl_src=batterystats --usage"
adb shell "dumpsys batterystats --usage 2>/dev/null | grep -E '^ *(UID u0a[0-9]+|Capacity): ' | sed -e 's/ ( .*//' -e 's/ ([^()]*)//g' | head -n 60; settings get global battery_stats_constants 2>/dev/null | grep -q 'track_cpu_active_cluster_time=false' && echo CPUTRACKOFF; echo _DCXOK" <nul >"!_dlf!\usage.txt" 2>nul
set "_dl_rc=!errorlevel!"
call :_dl_clean usage.txt
call :_dl_parse
if !_dl_n! GTR 0 goto drainboard_rank

:drainboard_charged
:: Android 12-13 have no --usage; the same UID lines are in the --charged dump.
set "_dl_src=batterystats --charged" & set "_dl_bad=0"
adb shell "dumpsys batterystats --charged 2>/dev/null | grep -E '^ *(UID u0a[0-9]+|Capacity): ' | sed -e 's/ ( .*//' -e 's/ ([^()]*)//g' | head -n 60; settings get global battery_stats_constants 2>/dev/null | grep -q 'track_cpu_active_cluster_time=false' && echo CPUTRACKOFF; echo _DCXOK" <nul >"!_dlf!\usage.txt" 2>nul
set "_dl_rc=!errorlevel!"
call :_dl_clean usage.txt
call :_dl_parse

:drainboard_rank
if defined _dl_live goto drainboard_rank2
set "_dl_why=adb exit !_dl_rc!. Is the phone still connected?"
set "_dl_state=fail"
goto drainboard_scanned

:drainboard_rank2
type nul >"!_dlf!\keys.txt"
for /l %%i in (1,1,!_dl_n!) do call :_dl_key %%i
"%SystemRoot%\System32\sort.exe" /r "!_dlf!\keys.txt" /o "!_dlf!\rank.txt"
for /f "usebackq tokens=2" %%i in ("!_dlf!\rank.txt") do if !_DL_TOP! LSS 15 call :_dl_top %%i
set "_dl_state=empty"
if "!_DL_TOP!"=="0" goto drainboard_scanned
echo    [2/6] app names...
adb shell "pm list packages -U --user 0 2>/dev/null | grep -E ' uid:(!_dl_ure!)$'; echo _DCXOK" <nul >"!_dlf!\pkgs.txt" 2>nul
call :_dl_clean pkgs.txt
for /f "usebackq tokens=1-4 delims=: " %%a in ("!_dlf!\pkgs.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_okP=1"
    if "%%a"=="package" if "%%c"=="uid" (set "_dl_pa=%%b" & set "_dl_pu=%%d" & call :_dl_pkg)
)
:: A cut-off list could make a shared UID look like one app, so nothing is offered without it.
set "_dl_pre="
if defined _dl_okP for /l %%p in (1,1,!_DL_TOP!) do if "!_dl_pc%%p!"=="1" call :_dl_pick %%p
echo    [3/6] standby buckets...
if not defined _dl_pre goto drainboard_nopre
adb shell "am get-standby-bucket --user 0 2>/dev/null | grep -E '(!_dl_pre!): [0-9]+$'; echo _DCXOK" <nul >"!_dlf!\bucket.txt" 2>nul
call :_dl_clean bucket.txt
for /f "usebackq tokens=1,2 delims=: " %%a in ("!_dlf!\bucket.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_okB=1"
    set "_dl_pa=%%a" & set "_dl_pu=%%b" & call :_dl_bucket
)
echo    [4/6] Doze exemptions...
adb shell "cmd deviceidle whitelist 2>/dev/null | grep -E '(system|user),(!_dl_pre!),'; echo _DCXOK" <nul >"!_dlf!\doze.txt" 2>nul
call :_dl_clean doze.txt
for /f "usebackq tokens=1,2 delims=," %%a in ("!_dlf!\doze.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_okD=1"
    set "_dl_pu=%%a" & set "_dl_pa=%%b" & call :_dl_doze
)
goto drainboard_alarm

:drainboard_nopre
:: No place maps to exactly one app, so there is no bucket or exemption to look up.
set "_dl_okB=1" & set "_dl_okD=1"
echo    [4/6] Doze exemptions...

:drainboard_alarm
echo    [5/6] alarm wake-ups since boot...
:: A caret typed on a line that also expands a !variable! is eaten, so the sed script sits in one.
set "_dl_sx=s/^ *\(\*ACTIVE\* \)*u0a\([0-9][0-9]*\):.* running, \([0-9][0-9]*\) wakeups:$/a\2 \3/p"
adb shell "dumpsys alarm 2>/dev/null | sed -n '!_dl_sx!' | grep -E 'a(!_dl_are!) '; echo _DCXOK" <nul >"!_dlf!\alarm.txt" 2>nul
call :_dl_clean alarm.txt
for /f "usebackq tokens=1,2" %%a in ("!_dlf!\alarm.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_okA=1"
    set "_dl_pa=%%a" & set "_dl_pu=%%b" & call :_dl_alarm
)
echo    [6/6] wake locks held now...
adb shell "dumpsys power 2>/dev/null | grep -E '^ *PARTIAL_WAKE_LOCK ' | grep -v ' DISABLED ' | sed -n 's/.* (uid=\([0-9][0-9]*\)[ )].*/\1/p'; echo _DCXOK" <nul >"!_dlf!\wl.txt" 2>nul
call :_dl_clean wl.txt
for /f "usebackq delims=" %%a in ("!_dlf!\wl.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_okL=1"
    set "_dl_pu=%%a" & call :_dl_wl
)
set "_dl_state=board"

:drainboard_scanned
for %%f in (usage pkgs bucket doze alarm wl keys rank) do del "!_dlf!\%%f.txt" "!_dlf!\%%f.txt.ok" >nul 2>&1
goto drainboard_show

:drainboard_tooold
set "_dl_state=old"
if "%SDK%"=="0" (set "_dl_why=Android version not read. Is the phone still connected?" & set "_dl_state=fail")
goto drainboard_show

:drainboard_notmp
set "_dl_why=could not create the scratch folder !_dlf!"
if not defined _dlf set "_dl_why=no scratch folder, DCX_TMP is not set"
set "_dl_state=fail"

:drainboard_show
cls
title Drain leaderboard
echo.
if "!_dl_state!"=="old" goto drainboard_oldmsg
if "!_dl_state!"=="fail" goto drainboard_failmsg
echo  %gold%Drain leaderboard%w% - battery use since the stats reset ^(normally the last full charge^)
echo  %d%dumpsys !_dl_src!: estimates from the phone's power model, in mAh.%w%
set "_dl_capm=!_dl_caplo!"
if defined _dl_caphi set "_dl_capm=!_dl_caplo!-!_dl_caphi!"
if defined _dl_caplo if defined _dl_capc echo  The battery gauge measured about !_dl_capm! mAh used since then ^(battery !_dl_capc! mAh^).
if defined _dl_caplo if not defined _dl_capc echo  The battery gauge measured about !_dl_capm! mAh used since then.
if not defined _dl_caplo if defined _dl_capn if defined _dl_capc echo  The phone counts about !_dl_capn! mAh used since then ^(battery !_dl_capc! mAh^).
if not defined _dl_caplo if defined _dl_capn if not defined _dl_capc echo  The phone counts about !_dl_capn! mAh used since then.
if "!_dl_state!"=="empty" goto drainboard_emptymsg
set "_dl_h1=     Bg"
if not defined _dl_split set "_dl_h1=  Total"
if not defined _dl_split if !SDK! LSS 34 echo  %y%Android before 14 does not split battery use into foreground and background%w% - ranked by total use.
if not defined _dl_split if !SDK! GEQ 34 echo  %y%This phone does not split use into foreground and background%w% - ranked by total use.
echo.
echo  %d%  # !_dl_h1!      Fg  Wake Now Bucket   Doze    App%w%
for /l %%p in (1,1,!_DL_TOP!) do call :_dl_line %%p
echo.
if defined _dl_split echo  %d%Bg = background incl. foreground services and cached.  Wake = alarm wake-ups since boot.%w%
if not defined _dl_split echo  %d%Total = all use since the reset.  Wake = alarm wake-ups since boot.%w%
echo  %d%Now = holds a partial wake lock now.  Doze = exempt from Doze ^(user / system^).  ? = not read.%w%
if !_DL_TOP! LSS 3 echo  [%b%i%w%] Only !_DL_TOP! app^(s^) so far: the stats reset at a full charge, so the list starts short.
if defined _dl_over echo  [%b%i%w%] The apps' estimates add up to about !_dl_over! mAh, more than the gauge measured: this
if defined _dl_over echo      phone's power model over-counts. Compare the apps with each other, not with the battery.
call :_dl_warns
echo.
if defined _dl_gold echo  %gold%[%w%1-!_DL_TOP!%gold%]%w% Open that app ^(gold numbers^)    %gold%[%w%D1-D!_DL_TOP!%gold%]%w% Its battery details in Notepad
if not defined _dl_gold echo  %gold%[%w%D1-D!_DL_TOP!%gold%]%w% Battery details of that place in Notepad
echo  %gold%[%w%R%gold%]%w% Read again    %gold%[%w%W%gold%]%w% Raw Wake-Lock Audit report    %gold%[%w%0%gold%]%w% Back
echo.
goto drainboard_ask

:drainboard_emptymsg
echo.
if defined _dl_split echo  [%b%i%w%] No app shows battery use in the background since the stats reset.
if not defined _dl_split echo  [%b%i%w%] No app shows battery use since the stats reset.
echo      That is normal right after a full charge. Try again after some hours off the charger.
call :_dl_warns
goto drainboard_short

:drainboard_failmsg
echo  [%r%^^!%w%] Could not read the battery stats: !_dl_why!
goto drainboard_short

:drainboard_oldmsg
echo  [%b%i%w%] The leaderboard needs Android 12 ^(API 31^) or newer; this phone reports API %SDK%.
echo.
echo  %gold%[%w%W%gold%]%w% Raw Wake-Lock Audit report    %gold%[%w%0%gold%]%w% Back
echo.
goto drainboard_ask

:drainboard_short
echo.
echo  %gold%[%w%R%gold%]%w% Read again    %gold%[%w%W%gold%]%w% Raw Wake-Lock Audit report    %gold%[%w%0%gold%]%w% Back
echo.

:drainboard_ask
set "dlb=" & set /p dlb="Choose An Option >> "
call :_noin dlb || goto dcx_noinput
if not defined dlb goto drainboard_ask
set "dlb=!dlb:"=!"
if not defined dlb goto drainboard_ask
if "!dlb!"=="0" goto drainboard_back
if /i "!dlb!"=="R" goto drainboard_scan
if /i "!dlb!"=="W" goto wakelockaudit
set "_dl_d="
if /i "!dlb:~0,1!"=="D" set "_dl_d=1"
if defined _dl_d set "dlb=!dlb:~1!"
call :_dl_digits dlb || goto drainboard_ask
if "!dlb!"=="0" goto drainboard_ask
if !dlb! GTR !_DL_TOP! goto drainboard_ask
if defined _dl_d goto drainboard_detail
set "ACK_PKG="
for %%n in (!dlb!) do set "ACK_PKG=!_dl_ok%%n!"
if not defined ACK_PKG goto drainboard_notsel
set "_PKGCHK=!ACK_PKG!"
call :_pkg_ok || goto drainboard_ask
set "ACK_RET=drainboard"
goto appcheck

:drainboard_back
if defined _dlf if exist "!_dlf!\" rd /s /q "!_dlf!" >nul 2>&1
set "_dl_state="
goto nextpage

:drainboard_notsel
if not defined _dl_okP goto drainboard_nonames
for %%n in (!dlb!) do if not defined _dl_pk%%n goto drainboard_noapp
echo  %y%Place !dlb! is a shared UID or Play services - not opened from here. D!dlb! shows its details.%w%
goto drainboard_ask

:drainboard_nonames
echo  %y%The app names were not read, so there is nothing to open. R reads the phone again.%w%
goto drainboard_ask

:drainboard_detail
set "_dl_dp="
for %%n in (!dlb!) do set "_dl_dp=!_dl_pk%%n!"
if not defined _dl_okP goto drainboard_nonames
if not defined _dl_dp goto drainboard_noapp
set "_PKGCHK=!_dl_dp!"
call :_pkg_ok || goto drainboard_ask
set "_dl_df=!_dlf!\app_!dlb!.txt"
call :_dl_mkdir || (echo  [%r%^^!%w%] Could not create the scratch folder !_dlf! & goto drainboard_ask)
echo  Reading the battery details of !_dl_dp! - a few seconds...
adb shell dumpsys batterystats --charged !_dl_dp! <nul >"!_dl_df!" 2>nul
set "_dl_rc=!errorlevel!"
set "_dl_sz="
for %%s in ("!_dl_df!") do set "_dl_sz=%%~zs"
if not defined _dl_sz goto drainboard_detail_fail
if "!_dl_sz!"=="0" goto drainboard_detail_fail
start "" notepad "!_dl_df!"
echo  [%g%+%w%] Opened in Notepad: !_dl_df!
if not "!_dl_rc!"=="0" echo  [%y%WARN%w%] adb exit !_dl_rc! - the file may hold an error message instead of the stats.
goto drainboard_ask

:drainboard_detail_fail
echo  [%r%^^!%w%] The phone sent nothing back ^(adb exit !_dl_rc!^).
goto drainboard_ask

:drainboard_noapp
echo  %y%Place !dlb! has no installed app of user 0 to show.%w%
goto drainboard_ask

:_dl_mkdir
:: Makes _dlf when missing; errorlevel 1 unless it is a folder now. if exist "x\" is true for a file too.
if not exist "!_dlf!\" md "!_dlf!" >nul 2>&1
set "_dl_x=-"
for %%a in ("!_dlf!") do set "_dl_x=-%%~aa"
if "!_dl_x:~1,1!"=="d" exit /b 0
exit /b 1

:_dl_clean
:: %1 = raw phone file in _dlf; lines of [A-Za-z0-9 ._:,-] go to %1.ok (read with delayed expansion off).
type nul >"!_dlf!\%~1.ok"
set "_dl_raw=0" & set "_dl_kept=0"
for /f "usebackq delims=" %%a in ("!_dlf!\%~1") do set /a _dl_raw+=1
for /f "usebackq delims=" %%a in ("!_dlf!\%~1") do (
    setlocal DisableDelayedExpansion
    set "_dlln="
    for /f "delims=" %%v in ("%%a") do set "_dlln=%%v"
    call :_dl_chk "%~1"
    endlocal
)
for /f "usebackq delims=" %%a in ("!_dlf!\%~1.ok") do set /a _dl_kept+=1
set /a _dl_bad+=_dl_raw-_dl_kept
exit /b

:_dl_chk
setlocal EnableDelayedExpansion
if not defined _dlln (endlocal & exit /b)
set "_dlb="
for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:,- " %%c in ("!_dlln!") do set "_dlb=1"
if defined _dlb (endlocal & exit /b)
>>"!_dlf!\%~1.ok" echo(!_dlln!
endlocal
exit /b

:_dl_parse
:: usage.txt.ok -> rows 1.._dl_n, the Capacity line, the CPU-tracking flag and the end marker.
set "_dl_n=0" & set "_dl_live=" & set "_dl_split=" & set "_dl_cap=" & set "_dl_capc=" & set "_dl_capn=" & set "_dl_cpuoff="
set "_dl_capa=" & set "_dl_caplo=" & set "_dl_caphi=" & set "_dl_over="
for /f "usebackq tokens=1,*" %%a in ("!_dlf!\usage.txt.ok") do (
    if "%%a"=="_DCXOK" set "_dl_live=1"
    if "%%a"=="CPUTRACKOFF" set "_dl_cpuoff=1"
    if "%%a"=="Capacity:" if not defined _dl_cap set "_dl_cap=%%b"
    if "%%a"=="UID" (set "_dl_ln=%%b" & call :_dl_row)
)
if not defined _dl_cap exit /b
:: "4042, Computed drain: 3.00, actual drain: 3193-3234": the actual drain is the battery gauge's.
for /f "tokens=1-7 delims=, " %%m in ("!_dl_cap!") do (
    set "_dl_capc=%%m"
    if "%%n %%o"=="Computed drain:" set "_dl_capn=%%p"
    if "%%q %%r"=="actual drain:" set "_dl_capa=%%s"
)
if defined _dl_capa for /f "tokens=1,2 delims=-" %%x in ("!_dl_capa!") do (set "_dl_caplo=%%x" & set "_dl_caphi=%%y")
for %%v in (_dl_capc _dl_capn _dl_caplo _dl_caphi) do call :_dl_mah %%v
if "!_dl_capc!"=="0" set "_dl_capc="
if "!_dl_caplo!"=="0" (set "_dl_caplo=" & set "_dl_caphi=")
if not defined _dl_caplo exit /b
:: Apps alone above the gauge's total by a quarter: the power model over-counts on this phone.
set "_dl_capm=!_dl_caplo!"
if defined _dl_caphi set "_dl_capm=!_dl_caphi!"
for /f "delims=." %%x in ("!_dl_capm!") do set "_dl_capm=%%x"
call :_dl_digits _dl_capm || exit /b
set "_dl_sum=0"
for /l %%i in (1,1,!_dl_n!) do set /a "_dl_sum+=_dl_t%%i/100"
set /a "_dl_capm=_dl_capm*5/4"
if !_dl_capm! GTR 0 if !_dl_sum! GTR !_dl_capm! set "_dl_over=!_dl_sum!"
exit /b

:_dl_row
:: _dl_ln = "u0a123: 41.2 fg: 20.1 bg: 10.0 fgs: 5.0 cached: 6.1"; a zero or unsplit state is absent.
if !_dl_n! GEQ 60 exit /b
set "_dlr_id=" & set "_dlr_t=" & set "_dlr_k=" & set "_dlr_fg=0" & set "_dlr_bg=0" & set "_dlr_fs=0" & set "_dlr_ca=0"
for %%t in (!_dl_ln!) do (
    if defined _dlr_k (
        set "_dlr_!_dlr_k!=%%t"
        set "_dlr_k="
    ) else if not defined _dlr_id (
        set "_dlr_id=%%t"
    ) else if not defined _dlr_t (
        set "_dlr_t=%%t"
    ) else (
        if "%%t"=="fg:" set "_dlr_k=fg"
        if "%%t"=="bg:" set "_dlr_k=bg"
        if "%%t"=="fgs:" set "_dlr_k=fs"
        if "%%t"=="cached:" set "_dlr_k=ca"
        if defined _dlr_k set "_dl_split=1"
    )
)
if not defined _dlr_id exit /b
if not "!_dlr_id:~0,3!"=="u0a" exit /b
if not "!_dlr_id:~-1!"==":" exit /b
set "_dlr_a=!_dlr_id:~3,-1!"
call :_dl_digits _dlr_a || exit /b
if not "!_dlr_a:~4!"=="" exit /b
call :_dl_c100 _dlr_t || (set /a _dl_bad+=1 & exit /b)
call :_dl_c100 _dlr_fg || set "_dlr_fg=0"
call :_dl_c100 _dlr_bg || set "_dlr_bg=0"
call :_dl_c100 _dlr_fs || set "_dlr_fs=0"
call :_dl_c100 _dlr_ca || set "_dlr_ca=0"
set /a _dl_n+=1
set "_dlr_p=0000!_dlr_a!"
set "_dl_uid!_dl_n!=1!_dlr_p:~-4!"
set "_dl_a!_dl_n!=!_dlr_a!"
set "_dl_t!_dl_n!=!_dlr_t!"
set "_dl_fg!_dl_n!=!_dlr_fg!"
set /a "_dl_bg!_dl_n!=_dlr_bg+_dlr_fs+_dlr_ca"
exit /b

:_dl_c100
:: %1 = variable holding mAh as dumpsys prints it (41.2, 0.123, 150); becomes hundredths.
:: At most 6 integer digits, so three states still add up inside set /a's 32 bits.
set "_dl_ci=" & set "_dl_cf="
for /f "tokens=1,2 delims=." %%x in ("!%~1!.") do (set "_dl_ci=%%x" & set "_dl_cf=%%y")
call :_dl_digits _dl_ci || exit /b 1
if not "!_dl_ci:~6!"=="" exit /b 1
set "_dl_x="
if defined _dl_cf for /f "eol=0 delims=0123456789" %%c in ("!_dl_cf!") do set "_dl_x=1"
if defined _dl_x exit /b 1
set "_dl_cf=!_dl_cf!00"
set /a "%~1=_dl_ci*100+1!_dl_cf:~0,2!-100"
exit /b 0

:_dl_digits
:: %1 = variable name; errorlevel 1 unless it is 0, or 1-9 digits with no leading zero.
if not defined %~1 exit /b 1
set "_dl_x="
for /f "eol=0 delims=0123456789" %%c in ("!%~1!") do set "_dl_x=1"
if defined _dl_x exit /b 1
if not "!%~1:~9!"=="" exit /b 1
if "!%~1!"=="0" exit /b 0
if "!%~1:~0,1!"=="0" exit /b 1
exit /b 0

:_dl_mah
if not defined %~1 exit /b
set "_dl_x="
for /f "eol=0 delims=0123456789." %%c in ("!%~1!") do set "_dl_x=1"
if defined _dl_x set "%~1="
exit /b

:_dl_key
:: %1 = row. By background use when the phone splits it, else by total.
set "_dl_x=!_dl_t%~1!"
if defined _dl_split set "_dl_x=!_dl_bg%~1!"
if "!_dl_x!"=="0" exit /b
set "_dl_x=000000000!_dl_x!"
>>"!_dlf!\keys.txt" echo !_dl_x:~-9! %~1
exit /b

:_dl_top
:: %1 = row for the next board place; copies it and adds its UID to the phone-side filters.
set /a _DL_TOP+=1
set "_dl_q=!_DL_TOP!"
set "_dlp_u!_dl_q!=!_dl_uid%~1!"
set "_dlp_a!_dl_q!=!_dl_a%~1!"
set "_dlp_t!_dl_q!=!_dl_t%~1!"
set "_dlp_b!_dl_q!=!_dl_bg%~1!"
set "_dlp_f!_dl_q!=!_dl_fg%~1!"
set "_dl_pc!_dl_q!=0"
set "_dl_pos_!_dl_uid%~1!=!_dl_q!"
if defined _dl_ure (set "_dl_ure=!_dl_ure!|!_dl_uid%~1!") else set "_dl_ure=!_dl_uid%~1!"
if defined _dl_are (set "_dl_are=!_dl_are!|!_dl_a%~1!") else set "_dl_are=!_dl_a%~1!"
exit /b

:_dl_pkg
:: _dl_pa / _dl_pu = one "package:NAME uid:N" line; counts the apps behind each board UID.
set "_PKGCHK=!_dl_pa!"
call :_pkg_ok || exit /b
call :_dl_digits _dl_pu || exit /b
set "_dl_q="
for %%u in (!_dl_pu!) do set "_dl_q=!_dl_pos_%%u!"
if not defined _dl_q exit /b
for %%q in (!_dl_q!) do (
    set /a _dl_pc%%q+=1
    if not defined _dl_pk%%q set "_dl_pk%%q=!_dl_pa!"
)
exit /b

:_dl_pick
:: %1 = a place whose UID is one app. Play services is never offered for restricting here.
set "_dl_x=!_dl_pk%~1!"
if defined _dl_pre (set "_dl_pre=!_dl_pre!|!_dl_x!") else set "_dl_pre=!_dl_x!"
if /i "!_dl_x!"=="com.google.android.gms" exit /b
if /i "!_dl_x!"=="com.google.android.gsf" exit /b
set "_dl_ok%~1=!_dl_x!"
set "_dl_gold=1"
exit /b

:_dl_bucket
set "_PKGCHK=!_dl_pa!"
call :_pkg_ok || exit /b
call :_dl_digits _dl_pu || exit /b
set "_dlB_!_dl_pa!=!_dl_pu!"
exit /b

:_dl_doze
if not "!_dl_pu!"=="system" if not "!_dl_pu!"=="user" exit /b
set "_PKGCHK=!_dl_pa!"
call :_pkg_ok || exit /b
for %%n in (!_dl_pa!) do if not "!_dlD_%%n!"=="system" set "_dlD_%%n=!_dl_pu!"
exit /b

:_dl_alarm
if not "!_dl_pa:~0,1!"=="a" exit /b
set "_dl_pa=!_dl_pa:~1!"
call :_dl_digits _dl_pa || exit /b
call :_dl_digits _dl_pu || exit /b
set /a "_dlW_!_dl_pa!+=_dl_pu"
exit /b

:_dl_wl
call :_dl_digits _dl_pu || exit /b
set "_dlL_!_dl_pu!=1"
exit /b

:_dl_line
:: %1 = board place; prints its row.
set "_dl_c0=   %~1"
set "_dl_c0=!_dl_c0:~-3!"
set "_dl_cc=%w%"
if defined _dl_ok%~1 set "_dl_cc=%gold%"
if defined _dl_split (set "_dl_v1=!_dlp_b%~1!" & set "_dl_v2=!_dlp_f%~1!") else (set "_dl_v1=!_dlp_t%~1!" & set "_dl_v2=")
call :_dl_fmt _dl_v1
if defined _dl_v2 (call :_dl_fmt _dl_v2) else set "_dl_v2=      -"
set "_dl_v3=?"
if defined _dl_okA set "_dl_v3=0"
if defined _dl_okA for %%a in (!_dlp_a%~1!) do if defined _dlW_%%a set "_dl_v3=!_dlW_%%a!"
if defined _dl_okA if !_dl_v3! GTR 99999 set "_dl_v3=100k+"
set "_dl_v3=     !_dl_v3!"
set "_dl_v3=!_dl_v3:~-5!"
set "_dl_v4=?  "
if defined _dl_okL set "_dl_v4=-  "
if defined _dl_okL for %%u in (!_dlp_u%~1!) do if defined _dlL_%%u set "_dl_v4=%y%now%w%"
set "_dl_v5=-" & set "_dl_v6=-"
if not defined _dl_okP (set "_dl_v5=?" & set "_dl_v6=?")
set "_dl_v7=!_dl_pk%~1!"
if defined _dl_okP if "!_dl_pc%~1!"=="1" call :_dl_one %~1
if "!_dl_pc%~1!"=="0" set "_dl_v7=uid !_dlp_u%~1!"
if "!_dl_pc%~1!"=="0" if defined _dl_okP set "_dl_v7=uid !_dlp_u%~1!, no app now"
set /a "_dl_x=_dl_pc%~1-1"
if !_dl_x! GTR 0 set "_dl_v7=!_dl_v7! +!_dl_x! shared"
if not "!_dl_v7:~51!"=="" set "_dl_v7=!_dl_v7:~0,50!~"
set "_dl_v5=!_dl_v5!        "
set "_dl_v6=!_dl_v6!      "
echo  !_dl_cc!!_dl_c0!%w% !_dl_v1! !_dl_v2! !_dl_v3! !_dl_v4! !_dl_v5:~0,8! !_dl_v6:~0,6!  !_dl_v7!
exit /b

:_dl_one
:: %1 = a place with exactly one app: its standby bucket and Doze exemption.
set "_dl_x=!_dl_pk%~1!"
set "_dl_v5=?" & set "_dl_v6=?"
if defined _dl_okB set "_dl_v5=-"
if defined _dl_okD set "_dl_v6=-"
for %%n in (!_dl_x!) do (
    if defined _dl_okB if defined _dlB_%%n set "_dl_v5=!_dlB_%%n!"
    if defined _dl_okD if defined _dlD_%%n set "_dl_v6=!_dlD_%%n!"
)
if "!_dl_v5!"=="5" set "_dl_v5=exempt"
if "!_dl_v5!"=="10" set "_dl_v5=active"
if "!_dl_v5!"=="20" set "_dl_v5=working"
if "!_dl_v5!"=="30" set "_dl_v5=frequent"
if "!_dl_v5!"=="40" set "_dl_v5=rare"
if "!_dl_v5!"=="45" set "_dl_v5=restrict"
if "!_dl_v5!"=="50" set "_dl_v5=never"
exit /b

:_dl_fmt
:: %1 = variable holding hundredths of a mAh; becomes "12.3", right-aligned in 7, or 100k+.
set /a "_dl_fi=%~1/100, _dl_fd=%~1%%100/10"
set "_dl_fs=       !_dl_fi!.!_dl_fd!"
if !_dl_fi! GTR 99999 set "_dl_fs=  100k+"
set "%~1=!_dl_fs:~-7!"
exit /b

:_dl_warns
set "_dl_x="
if not defined _dl_okP set "_dl_x=!_dl_x! names"
if not defined _dl_okB set "_dl_x=!_dl_x! buckets"
if not defined _dl_okD set "_dl_x=!_dl_x! Doze"
if not defined _dl_okA set "_dl_x=!_dl_x! wake-ups"
if not defined _dl_okL set "_dl_x=!_dl_x! wake-locks"
if "!_dl_state!"=="empty" set "_dl_x="
if defined _dl_x echo  [%y%WARN%w%] Not read:!_dl_x! ^(shown as ?^). If the phone dropped, reconnect and press R.
if not "!_dl_bad!"=="0" echo  [%y%WARN%w%] Left out !_dl_bad! line^(s^) from the phone that were not in the expected shape.
if defined _dl_cpuoff echo  [%y%WARN%w%] Toggle Logs Off ^(Battery page 1^) stopped per-app CPU time reading, so CPU use
if defined _dl_cpuoff echo         is under-counted here. Toggle Logs On restores it from then on.
exit /b
:: ===================================================================
:: Refresh Rate Lock: min_refresh_rate and peak_refresh_rate; setting both equal forces that rate.
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
call :_noin rl || goto dcx_noinput
if "!rl!"=="1" (
    adb shell settings put system min_refresh_rate 60 <nul
    adb shell settings put system peak_refresh_rate 60 <nul
    call :_act_reset
    call :_settings_verify system min_refresh_rate 60
    call :_settings_verify system peak_refresh_rate 60
    call :_act_summary
    pause > nul
    goto refreshlock
)
if "!rl!"=="2" (
    adb shell settings put system min_refresh_rate 90 <nul
    adb shell settings put system peak_refresh_rate 90 <nul
    call :_act_reset
    call :_settings_verify system min_refresh_rate 90
    call :_settings_verify system peak_refresh_rate 90
    call :_act_summary
    echo ^(Falls back if your panel doesn't support 90.^)
    pause > nul
    goto refreshlock
)
if "!rl!"=="3" (
    adb shell settings put system min_refresh_rate 120 <nul
    adb shell settings put system peak_refresh_rate 120 <nul
    call :_act_reset
    call :_settings_verify system min_refresh_rate 120
    call :_settings_verify system peak_refresh_rate 120
    call :_act_summary
    echo ^(Falls back if your panel doesn't support 120.^)
    pause > nul
    goto refreshlock
)
if "!rl!"=="4" (
    adb shell settings put system min_refresh_rate 1 <nul
    adb shell settings put system peak_refresh_rate 120 <nul
    call :_act_reset
    call :_settings_verify system min_refresh_rate 1
    call :_settings_verify system peak_refresh_rate 120
    call :_act_summary
    pause > nul
    goto refreshlock
)
if not "!rl!"=="5" goto _skrl5
    adb shell settings delete system min_refresh_rate <nul
    adb shell settings delete system peak_refresh_rate <nul
    call :_act_reset
    call :_settings_verify system min_refresh_rate DELETE
    call :_settings_verify system peak_refresh_rate DELETE
    call :_act_summary
    pause > nul
    goto refreshlock

:_skrl5
if "!rl!"=="6" goto nextpage
goto refreshlock
:: ===================================================================
:: Force Doze Now: deviceidle force-idle puts the device into deep idle until it is woken.
:forcedoze
cls
title Force Doze Now
call :logo
echo.
echo  Immediately forces the device into deep idle (doze) mode.
echo  Forcing also marks the battery "unplugged" - doze cannot hold while charging,
echo  and the adb cable counts as charging. Option 2 undoes both.
echo  Wakes up normally when you unlock or receive a high-priority push.
echo.
echo                                     %g%[%w%1%g%]%w% Force doze now
echo                                     %g%[%w%2%g%]%w% Unforce (restore scheduling + real battery state)
echo                                     %g%[%w%3%g%]%w% Show current state
echo                                     %g%[%w%4%g%]%w% Back
set "fd=" & set /p fd="Choose An Option >> "
call :_noin fd || goto dcx_noinput
if not "!fd!"=="1" goto _skfd1
    :: battery unplug, then force-idle: doze will not hold while charging, and the adb cable counts.
    :: Option 2 undoes both with unforce and battery reset. Do not split either pair.
    set "_dvst="
    for /f "delims=" %%d in ('adb get-state 2^>nul') do set "_dvst=%%d"
    if /i not "%_dvst%"=="device" (
        echo  %r%No device connected - nothing was sent.%w%  Check: adb devices
        pause > nul
        goto forcedoze
    )
    adb shell dumpsys battery unplug <nul
    adb shell dumpsys deviceidle force-idle <nul
    echo Doze forced. The device now reports "unplugged" so idle can hold with the
    echo cable in. Use option 2 when done - until then the battery UI shows the
    echo spoofed state.
    pause > nul
    goto forcedoze

:_skfd1
if not "!fd!"=="2" goto _skfd2
    :: undo BOTH halves: leave forced idle, then restore the real battery/charging state.
    set "_dvst="
    for /f "delims=" %%d in ('adb get-state 2^>nul') do set "_dvst=%%d"
    if /i not "%_dvst%"=="device" (
        echo  %r%No device connected - nothing was sent.%w%  Check: adb devices
        pause > nul
        goto forcedoze
    )
    adb shell dumpsys deviceidle unforce <nul
    adb shell dumpsys battery reset <nul
    echo Returned to normal scheduling and restored the real battery state.
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
:: App Hibernation, Android 12+: unused apps lose permissions and optimised code until reopened.
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
call :_dcfg_warn
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell device_config get app_hibernation app_hibernation_enabled 2^>nul ^<nul') do echo    app_hibernation_enabled = %%i
echo.
echo                                     %g%[%w%1%g%]%w% Enable
echo                                     %g%[%w%2%g%]%w% Disable
echo                                     %g%[%w%3%g%]%w% Back
set "ah=" & set /p ah="Choose An Option >> "
call :_noin ah || goto dcx_noinput
if "!ah!"=="1" (
    adb shell device_config put app_hibernation app_hibernation_enabled true <nul
    call :_act_reset
    call :_dcfg_verify app_hibernation app_hibernation_enabled true
    call :_act_summary
    pause > nul
    goto apphibernation
)
if "!ah!"=="2" (
    adb shell device_config put app_hibernation app_hibernation_enabled false <nul
    call :_act_reset
    call :_dcfg_verify app_hibernation app_hibernation_enabled false
    call :_act_summary
    pause > nul
    goto apphibernation
)
if "!ah!"=="3" goto nextpage
goto apphibernation
:: ===================================================================
:: Account Sync: master_sync_status only - a placebo on modern Android, kept for Backup/Restore.
:syncmaster
cls
title Account Sync Toggle
call :logo
echo.
echo  Writes global master_sync_status only.
echo  %y%Placebo on modern Android:%w% nothing reads this key. Real Auto sync
echo  lives in the sync framework ^(dumpsys content^) and needs root to change.
echo  Kept so Backup/Restore can round-trip the stored value.
echo.
echo  Current:
for /f "delims=" %%i in ('adb shell settings get global master_sync_status 2^>nul ^<nul') do echo    master_sync_status = %%i  (1=on, 0=off)
echo.
echo                                     %g%[%w%1%g%]%w% Set master_sync_status = 1
echo                                     %g%[%w%2%g%]%w% Set master_sync_status = 0
echo                                     %g%[%w%3%g%]%w% Back
set "sm=" & set /p sm="Choose An Option >> "
call :_noin sm || goto dcx_noinput
if "!sm!"=="1" (set "_msv=1" & goto syncmaster_set)
if "!sm!"=="2" (set "_msv=0" & goto syncmaster_set)
if "!sm!"=="3" goto nextpage
goto syncmaster

:syncmaster_set
:: The value is read back before it is reported.
call :_act_reset
call :_put_chk global master_sync_status !_msv!
call :_act_summary
echo Real Auto sync is unchanged on modern Android.
pause > nul
goto syncmaster
:: ===================================================================
:: Voice Hotword: hotword_detection_enabled parks the always-on mic; manual assistant still works.
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
call :_noin hw || goto dcx_noinput
if "!hw!"=="1" (
    adb shell settings put global hotword_detection_enabled 1 <nul
    call :_act_reset
    call :_settings_verify global hotword_detection_enabled 1
    call :_act_summary
    pause > nul
    goto hotwordtoggle
)
if "!hw!"=="2" (
    adb shell settings put global hotword_detection_enabled 0 <nul
    call :_act_reset
    call :_settings_verify global hotword_detection_enabled 0
    call :_act_summary
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
call :_noin ksd || goto dcx_noinput
if "!ksd!"=="1" goto sethibdernatephs
if "!ksd!"=="2" goto stockpackage
if "!ksd!"=="3" goto nextpage
:: guard against invalid input
goto nexthibernateappphase

:stockpackage
cls
title Revert Your Package To Stock
call :logo
set "pkgv2=" & set /p pkgv2="Package name, or part of one >> "
call :_noin pkgv2 || goto dcx_noinput
if "!pkgv2!"=="" goto nexthibernateappphase
call :_pkg_pick pkgv2 inst || goto nexthibernateappphase
set "_PKGCHK=!pkgv2!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto nexthibernateappphase
)
echo.
echo [#] Set !pkgv2! To Stock . . . .
echo.
:: Only the app-ops Hibernate sets go back to default: appops reset would also drop the
:: special access the user granted in Settings.
for %%b in (FOREGROUND_SERVICE_SPECIAL_USE INSTANT_APP_START_FOREGROUND RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND START_FOREGROUND WAKE_LOCK) do adb shell cmd appops set !pkgv2! %%b default <nul > nul 2>&1
:: adaptive_bucket is Android's own default level; Hibernate's restart-backoff change goes back too.
adb shell cmd activity set-bg-restriction-level --user 0 !pkgv2! adaptive_bucket <nul
adb shell cmd activity service-restart-backoff enable !pkgv2! <nul
adb shell cmd activity set-inactive !pkgv2! false <nul
adb shell cmd activity set-standby-bucket !pkgv2! active <nul
adb shell cmd app_hibernation set-state !pkgv2! false <nul
adb shell cmd dropbox remove-low-priority !pkgv2! <nul
adb shell cmd tare set-vip 0 !pkgv2! default <nul
echo.
set "_hib="
for /f "delims=" %%i in ('adb shell cmd app_hibernation get-state !pkgv2! 2^>nul ^<nul') do set "_hib=%%i"
if /i "!_hib!"=="false" (
    echo [%g%+%w%] !pkgv2! hibernation state = false
) else if /i "!_hib!"=="true" (
    echo [%y%WARN%w%] !pkgv2! still reports hibernated - reboot may be required.
) else (
    echo [%y%WARN%w%] Could not read hibernation state ^(got "!_hib!"^) - the reverts were sent, nothing is confirmed.
)
echo [#] Reboot recommended to finish the process.
echo [#] A battery-optimisation exemption Hibernate removed comes back with Tweaks ^> Undo.
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:sethibdernatephs
cls
title Set Your Package Here
call :logo
set "pkgv2=" & set /p pkgv2="Package name, or part of one >> "
call :_noin pkgv2 || goto dcx_noinput
if "!pkgv2!"=="" (
    echo invalid package. . . .
    timeout /t 2 /nobreak > nul
    goto nexthibernateappphase
)
call :_pkg_pick pkgv2 inst || goto nexthibernateappphase
set "_PKGCHK=!pkgv2!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto nexthibernateappphase
)
echo.
echo  Clear the app's shortcuts too? This removes the ones pinned to the home screen,
echo  and they cannot be put back.
echo    [Y] Clear them    [N] Keep them
:: Ctrl+C makes choice return 0: keep them, as N does.
set "_hibsc="
choice /c:YN /n >nul
if errorlevel 2 goto _hib_go
if errorlevel 1 set "_hibsc=1"

:_hib_go
echo.
echo [#] Set !pkgv2! To Hibernate . . . .
echo.
:: The background app-ops and the battery-optimisation exemption go to the undo file first;
:: when they could not be recorded, nothing is changed.
call :_tw_undo_bgm !pkgv2!
if errorlevel 2 goto _hib_noundo
for %%b in (
    FOREGROUND_SERVICE_SPECIAL_USE
    INSTANT_APP_START_FOREGROUND
    RUN_ANY_IN_BACKGROUND
    RUN_IN_BACKGROUND
    START_FOREGROUND
    WAKE_LOCK
) do (
    rem Delayed expansion for pkgv2: it is user input, and a closing paren in it ends the block.
    rem Use rem inside blocks: a :: line inside one prints a drive error on every pass.
    adb shell cmd appops set !pkgv2! %%b ignore <nul > nul 2>&1
)
adb shell cmd activity service-restart-backoff disable !pkgv2! <nul
adb shell cmd activity set-bg-restriction-level --user 0 !pkgv2! hibernation <nul
adb shell cmd activity set-foreground-service-delegate --user 0 !pkgv2! stop <nul
adb shell cmd activity set-inactive !pkgv2! true <nul
adb shell cmd activity set-standby-bucket !pkgv2! restricted <nul
adb shell cmd app_hibernation set-state !pkgv2! true <nul
adb shell cmd deviceidle sys-whitelist -!pkgv2! <nul
adb shell cmd deviceidle whitelist -!pkgv2! <nul
adb shell cmd dropbox add-low-priority !pkgv2! <nul
adb shell cmd package art clear-app-profiles !pkgv2! <nul
adb shell cmd package log-visibility --disable !pkgv2! <nul
if defined _hibsc adb shell cmd shortcut clear-shortcuts !pkgv2! <nul
adb shell cmd tare set-vip 0 !pkgv2! false <nul
adb shell cmd usagestats clear-last-used-timestamps !pkgv2! <nul
adb shell am force-stop !pkgv2! <nul
adb shell am kill !pkgv2! <nul
adb shell am stop-app !pkgv2! <nul
adb shell cmd activity force-stop !pkgv2! <nul
adb shell cmd activity kill !pkgv2! <nul
echo.
set "_hib="
for /f "delims=" %%i in ('adb shell cmd app_hibernation get-state !pkgv2! 2^>nul ^<nul') do set "_hib=%%i"
if /i "!_hib!"=="true" (
    echo [%g%+%w%] !pkgv2! hibernation state = true
) else if /i "!_hib!"=="false" (
    echo [%y%WARN%w%] !pkgv2! hibernation state still false - commands may be ignored on this OEM.
) else (
    echo [%y%WARN%w%] Could not read hibernation state ^(got "!_hib!"^) - applied best-effort.
)
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:_hib_noundo
echo [%r%^^!%w%] DCX could not record !pkgv2!'s current state for Undo, so nothing was changed.
echo        Check the phone is connected and answering, then try again.
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
call :_noin ksd || goto dcx_noinput
if "!ksd!"=="1" goto devicesysdel
if "!ksd!"=="2" goto devicesysrev
if "!ksd!"=="3" goto nextpage
:: guard against invalid input
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
:: Ctrl+C makes choice return 0 - treated as cancel.
choice /c:YN /n > nul
if errorlevel 2 goto Deviceidle
if not errorlevel 1 goto Deviceidle
cls
call :logo
title Removing system apps from Doze whitelist...
:: The list is filtered on the phone with grep and sed, where line endings are predictable; a
:: missing tool leaves the file empty and removes nothing. The file sits in this window's own temp
:: folder so two DCX windows cannot collide; usebackq because the path is quoted.
set "_wlfile=!DCX_TMP!\idle_whitelist.txt"
adb shell "dumpsys deviceidle sys-whitelist | grep -E '^[[:blank:]]*[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+(,[0-9]+)?[[:blank:]]*$' | sed 's/[[:blank:]]//g; s/,.*//'" > "!_wlfile!" <nul
set "_rm=0" & set "_prot=0" & set "_wlskip=0" & set "_wlfail=0"
:: Each line passes :_dz_name with delayed expansion off and is used only if it is a plain package
:: name. The protected-word test runs in this shell: never pipe phone text to findstr, the pipe
:: re-parses it. Read the file directly, not via type in a child cmd that re-expands the path.
for /f "usebackq delims=" %%A in ("!_wlfile!") do (
    setlocal DisableDelayedExpansion
    set "_wlraw=%%A"
    call :_dz_name
    if errorlevel 1 (endlocal & set "_wlp=") else (endlocal & for /f "delims=" %%B in ("%%A") do set "_wlp=%%B")
    set "_wlprot="
    if defined _wlp for %%k in (gms gsf shell ims downloads providers settings systemui inputmethod telecom telephony bluetooth dialer mms phone alarm calendar fused) do if not "!_wlp:%%k=!"=="!_wlp!" set "_wlprot=1"
    if not defined _wlp (
        set /a _wlskip+=1
    ) else if not defined _wlprot (
        adb shell cmd deviceidle sys-whitelist -!_wlp! <nul
        if errorlevel 1 (
            echo [%r%x%w%] Not removed: !_wlp!
            set /a _wlfail+=1
        ) else (
            echo Removed: !_wlp!
            set /a _rm+=1
        )
    ) else (
        echo [%r%#%w%] !_wlp! Is Protected
        set /a _prot+=1
    )
)
del "!_wlfile!" > nul 2>&1
echo.
if not "!_wlskip!"=="0" echo [%y%WARN%w%] Left alone !_wlskip! line^(s^) that were not plain package names.
if not "!_wlfail!"=="0" echo [%y%WARN%w%] The phone refused !_wlfail! removal^(s^), or stopped answering.
if !SDK! GTR 0 if !SDK! LSS 24 echo [%b%i%w%] Android 6 and older report no result, so Removed means sent.
if "!_rm!"=="0" (
    echo [%y%WARN%w%] Removed 0 packages ^(list empty, all protected, or filter matched nothing^).
) else (
    echo [%g%+%w%] Removed !_rm! package^(s^), protected !_prot!.
)
echo Done, Press Any Button To Go Back
pause > nul
goto nextpage

:_dz_name
:: Called with delayed expansion off; _wlraw = the line as the phone wrote it. Errorlevel 1 unless,
:: with a trailing CR dropped, it holds only letters, digits, dots and underscores.
call :_tw_pctbang _wlraw || exit /b 1
setlocal EnableDelayedExpansion
set "_dzn="
for /f "delims=" %%b in ("!_wlraw!") do set "_dzn=%%b"
if not defined _dzn exit /b 1
set "_dzb="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%c in ("!_dzn!") do set "_dzb=1"
if defined _dzb exit /b 1
exit /b 0

:devicesysrev
title Toggle Deviceidle Whitelist : Revert
cls
call :logo
echo.
echo.
adb shell cmd deviceidle sys-whitelist reset <nul
if errorlevel 1 (echo [%y%WARN%w%] The phone refused the reset or did not answer.) else (echo                           [%y%=%w%]All System Apps Is Revert Back To Deviceidle)
echo Press Any Button To Go Back
pause > nul
goto nextpage

:_lvis_note
:: errorlevel 1 below Android 11, where cmd package log-visibility does not exist.
if !SDK! GTR 0 if !SDK! LSS 30 exit /b 1
echo  This switches app-visibility debug logging for each of your apps. Android leaves it off,
echo  so Off is the stock state and On turns the extra logging on.
echo.
exit /b 0

:_lvis_old
echo  [%r%^^!%w%] This needs Android 11 or newer ^(API 30+^); the phone reports API !SDK!.
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
call :_noin ksd || goto dcx_noinput
if "!ksd!"=="1" goto offlogsuni
if "!ksd!"=="2" goto onlogsuni
if "!ksd!"=="3" goto nextpage
:: guard against invalid input
goto universallogs

:offlogsuni
cls
title Universal Toggle Logs\etc : Off
call :logo
:: Each log.tag name is read with delayed expansion off and must be a plain property name before
:: it goes back to the phone. Each setprop is counted by its exit code.
set "_lgok=0" & set "_lgfail=0" & set "_lgskip=0"
setlocal DisableDelayedExpansion
for /f "tokens=1 delims=:" %%a in ('adb shell getprop ^<nul ^| findstr "log.tag"') do (
    set "_lgraw=%%a"
    call :_lg_one S
)
endlocal & set "_lgok=%_lgok%" & set "_lgfail=%_lgfail%" & set "_lgskip=%_lgskip%"
call :_lg_report Off
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:onlogsuni
cls
title Universal toggle Logs\etc : On
call :logo
echo  Clearing log.tag* props set by Off ^(empty = platform default^)...
:: Same capture and check as :offlogsuni.
set "_lgok=0" & set "_lgfail=0" & set "_lgskip=0"
setlocal DisableDelayedExpansion
for /f "tokens=1 delims=:" %%a in ('adb shell getprop ^<nul ^| findstr "log.tag"') do (
    set "_lgraw=%%a"
    call :_lg_one CLEAR
)
endlocal & set "_lgok=%_lgok%" & set "_lgfail=%_lgfail%" & set "_lgskip=%_lgskip%"
call :_lg_report On
if not "%_lgok%"=="0" echo  A reboot finishes restoring default log levels.
echo.
echo Press Any Button To Go Back
pause > nul
goto nextpage

:_lg_one
:: Arg 1 = S for Off or CLEAR for On. _lgraw = the key of one getprop line, as the phone printed
:: it, delayed expansion off. Counts into _lgok, _lgfail and _lgskip in the caller's scope.
setlocal EnableDelayedExpansion
if not defined _lgraw (endlocal & set /a _lgskip+=1 & exit /b)
:: No space-stripping: a name with a space is not a property, and squeezing it sets another one.
set "_lgp=!_lgraw!"
if defined _lgp set "_lgp=!_lgp:[=!"
if defined _lgp set "_lgp=!_lgp:]=!"
set "_lgbad="
if not defined _lgp set "_lgbad=1"
if defined _lgp for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-:@" %%c in ("!_lgp!") do set "_lgbad=1"
if defined _lgbad (endlocal & set /a _lgskip+=1 & exit /b)
if /i "%~1"=="S" (adb shell setprop !_lgp! S <nul >nul 2>&1) else (adb shell setprop !_lgp! '' <nul >nul 2>&1)
if errorlevel 1 (endlocal & set /a _lgfail+=1 & exit /b)
endlocal & set /a _lgok+=1
exit /b

:_lg_report
:: Arg 1 = Off or On. Reports what the loop did - nothing found is not done.
if "%_lgok%%_lgfail%%_lgskip%"=="000" (
    echo  [%y%WARN%w%] No log.tag properties were found - nothing was changed. If the phone
    echo         dropped, reconnect it and try again.
    exit /b
)
if "%_lgfail%"=="0" (echo  [%g%OK%w%] Logs %1: %_lgok% log.tag properties changed.) else (echo  [%y%WARN%w%] Logs %1: %_lgok% changed, %_lgfail% refused by the phone.)
if not "%_lgskip%"=="0" echo         %_lgskip% skipped: not a plain property name, so not sent back to the phone.
exit /b

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
call :_noin ksd || goto dcx_noinput
if "!ksd!"=="1" goto offlogsuserapp
if "!ksd!"=="2" goto onlogsuserapp
if "!ksd!"=="3" goto nextpage
:: guard against invalid input
goto logappsuser

:offlogsuserapp
cls
title Log For User Apps : Off
call :logo
call :_lvis_note || goto _lvis_old
:: In-device loop as in :lstused: one adb call, stderr to /dev/null without an ampersand.
for /f "delims=" %%a in ('adb shell "pm list packages -3 | while read p; do p=${p#package:}; cmd package log-visibility --disable $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo Debug logging off ^(sent^) : %%a
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
call :_lvis_note || goto _lvis_old
:: In-device loop as in :lstused: one adb call, stderr to /dev/null without an ampersand.
for /f "delims=" %%a in ('adb shell "pm list packages -3 | while read p; do p=${p#package:}; cmd package log-visibility --enable $p >/dev/null 2>/dev/null; echo $p; done" ^<nul') do (
echo Debug logging on ^(sent^) : %%a
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
call :_noin toggle || goto dcx_noinput
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
call :_noin conx || goto dcx_noinput
if "!conx!"=="1" goto skiplogv
if "!conx!"=="2" goto mainlogv
if "!conx!"=="3" goto Battery
:: guard against invalid input
goto offlogss

:mainlogv
cls
::debugprop from tecno pova 6 neo
adb shell setprop debug.ae.dump.enable false <nul
adb shell setprop debug.ae.dump.stat 0 <nul
adb shell setprop debug.ae.dump_level 0 <nul
adb shell setprop debug.ae.log.enable false <nul
adb shell setprop debug.ae.log.level 0 <nul
adb shell setprop debug.ae.logi.enable false <nul
adb shell setprop debug.af.log.enable false <nul
adb shell setprop debug.bq.dump false <nul
adb shell setprop debug.camera.dump false <nul
adb shell setprop debug.stagefright.mediacodec.trace 0 <nul
adb shell setprop debug.sf.log_transaction false <nul
adb shell setprop debug.sf.stats false <nul
adb shell setprop debug.mtkcam.systrace.level 0 <nul
adb shell setprop debug.dump.enable false <nul
adb shell setprop debug.dump 0 <nul
adb shell setprop debug.camera.log 0 <nul
adb shell setprop debug.ae.stat.log.level 0 <nul
adb shell setprop debug.ae.stat.perf.enable false <nul
adb shell setprop debug.af.systrace 0 <nul
adb shell setprop debug.awb.systrace.db.enable false <nul
adb shell setprop debug.flicker.systrace false <nul
adb shell setprop debug.flicker.log 0 <nul
adb shell setprop debug.pdsystrace 0 <nul
adb shell setprop debug.syncawbsystrace.enable false <nul
adb shell setprop debug.trace.print.video false <nul
adb shell setprop debug.trace.print.audio false <nul
adb shell setprop debug.trace.info false <nul
adb shell setprop debug.gpu.dump.texture false <nul
adb shell setprop debug.sf.cpupolicy.log false <nul
adb shell setprop debug.hwc.wdt_trace false <nul
adb shell setprop debug.apusys.loglevel 0 <nul
adb shell setprop debug.awb.latency.log.level 0 <nul
adb shell setprop debug.awb_alg.log.level 0 <nul
adb shell setprop debug.edma.loglevel 0 <nul
adb shell setprop debug.ae.pline.table.log 0 <nul
adb shell setprop debug.ae_alg.log.level 0 <nul
adb shell setprop debug.atms.dump false <nul
adb shell setprop debug.eis.dumpdisplay false <nul
adb shell setprop debug.featureProfile.dump false <nul
adb shell setprop debug.flk_dump 0 <nul
adb shell setprop debug.fpipe.force.dump 0 <nul
adb shell setprop debug.hwc.dump_buf_log_enable false <nul
adb shell setprop debug.ai3a_log.enable false <nul
adb shell setprop debug.aiawb.ga.log.enable false <nul
adb shell setprop debug.alsflk.log 0 <nul
adb shell setprop debug.awb.p1ggm.log.enable false <nul
adb shell setprop debug.awb.sa.log.enable false <nul
adb shell setprop debug.mediatek.vklayer.dump_analysis_enabled false <nul
adb shell setprop debug.mediatek.vklayer.dump_blas_info_enabled false <nul
adb shell setprop debug.mediatek.vklayer.dump_debug_enabled false <nul
adb shell setprop debug.mediatek.vklayer.dump_debug_mem_at_QSubmit false <nul
adb shell setprop debug.mediatek.vklayer.dump_debug_mem_enabled false <nul
adb shell setprop debug.loglevel 0 <nul
adb shell setprop debug.log.enable false <nul
adb shell setprop debug.thread_raw.log false <nul
adb shell setprop debug.apusyslog false <nul
adb shell setprop debug.neuropilot.gpu.systrace false <nul
adb shell setprop debug.neuron.runtime.ProfilingLevel 0 <nul
adb shell setprop debug.neuron.runtime.EnableDebugger false <nul
adb shell setprop debug.hwc.aibld_dump_enable false <nul
adb shell setprop debug.tkflow.bokeh.log 0 <nul
adb shell setprop debug.tone.log.enable false <nul
adb shell setprop debug.vpustream.loglevel 0 <nul
adb shell setprop debug.smvrb.loglevel 0 <nul
adb shell setprop debug.pipeline.trace 0 <nul
adb shell setprop debug.mtk_tflite.vlog 0 <nul
adb shell setprop debug.sensors.color.log 0 <nul
adb shell setprop debug.P1STT.log 0 <nul
adb shell setprop debug.af_alg.log.level 0 <nul
adb shell setprop debug.awb.sa.log.level 0 <nul
adb shell setprop debug.gpud.gl.state.error.dump 0 <nul
adb shell setprop debug.gpud.log 0 <nul
adb shell setprop debug.3alog.enable false <nul
adb shell setprop debug.STEREO.Log 0 <nul
adb shell setprop debug.STEREO.dump 0 <nul
adb shell setprop debug.ThreadPool.log 0 <nul
adb shell setprop debug.edma.loglevel 0 <nul
adb shell setprop debug.sync3A.log 0 <nul
adb shell setprop debug.camera.3dnr.log.level 0 <nul
adb shell setprop debug.sync3AWrapper.log 0 <nul
adb shell setprop debug.sf.wdlog 0 <nul
adb shell setprop debug.sf.display_dejitter_log 0 <nul
adb shell setprop debug.sensors.flicker.log 0 <nul
adb shell setprop debug.tpi.s.log 0 <nul
adb shell setprop debug.pip.logLevel 0 <nul
adb shell setprop debug.EntryPool.log 0 <nul
adb shell setprop debug.log.rpt 0 <nul
adb shell setprop debug.ltm.smth.log.enable false <nul
adb shell setprop debug.fsc.log_level 0 <nul
adb shell setprop debug.gpunn.enable_profiler false <nul
adb shell setprop debug.hal3av3.log 0 <nul
adb shell setprop debug.pq.enable.trace false <nul
adb shell setprop debug.pd.dump.enable false <nul
adb shell setprop debug.p2f.dump.enable false <nul
adb shell setprop debug.neuron.runtime.DumpVerbose 0 <nul
adb shell setprop debug.vendor.sys.camfilelock.log 0 <nul
adb shell setprop debug.smvr.log.level 0 <nul
adb shell setprop debug.statistic_buf.enable false <nul
adb shell setprop debug.sync3AMgr.log false <nul
adb shell setprop debug.tpi.s.async.log false <nul
adb shell setprop debug.tpi.s.dump false <nul
adb shell setprop debug.tsfcore.filedump.enable false <nul
adb shell setprop debug.gpud.wsframebuffer.log 0 <nul
adb shell setprop debug.hmplog 0 <nul
adb shell setprop debug.hwui.memory_dump_disable 1 <nul
adb shell setprop debug.trace.p2.Cropper 0 <nul
adb shell setprop debug.trace.p2.CaptureNode 0 <nul
adb shell setprop debug.trace.p2.LMVInfo 0 <nul
adb shell setprop debug.trace.p2.Streaming_VSDOF 0 <nul
adb shell setprop debug.systrace.p2 0 <nul
adb shell setprop debug.sf.show_msync2_trace false <nul
::debugprop from tecno pova 6 neo
:skiplogv
cls
call :_dcfg_warn
::if something is wrong , revert this prop by reboot
:: No log.tag '*:S': liblog reads only the first character as a level, so it does nothing. A bare
:: S works but also hides crash logs, so it is not applied.
adb shell setprop debug.vendor.gpu.record_sbwc false <nul
adb shell setprop debug.egl.blobcache.multifile false <nul
adb shell setprop debug.tracefpunwindoff 1 <nul
adb shell setprop log.tag.LAUNCHER_TRACE S <nul > nul 2>&1
adb shell device_config put systemui com.android.systemui.coroutine_tracing false <nul
adb shell setprop persist.log.tag.DisplayPowerController S <nul > nul 2>&1
adb shell setprop debug.met_log_d.user null <nul
adb shell cmd wifi set-verbose-logging disabled <nul > nul 2>&1
adb shell device_config put profcollect_native_boot enabled false <nul
adb shell setprop debug.sf.boot_animation false <nul
adb shell setprop debug.sf.edge_extension_shader false <nul
adb shell setprop debug.perf_event_max_sample_rate 1 <nul
adb shell setprop debug.perf_event_mlock_kb 2 <nul
adb shell setprop debug.perf_cpu_time_max_percent 1 <nul
adb shell setprop security.perf_harden 0 <nul
adb shell setprop debug.lldb-rpc-server 0 <nul
adb shell setprop debug.MB.running 0 <nul
adb shell setprop debug.hwc.otf 0 <nul
adb shell setprop debug.art.monitor.app false <nul
::if something is wrong , revert this propt by reboot
adb shell setprop sys.wifitracing.started 0 <nul > nul 2>&1
adb shell setprop debug.rs.script 0 <nul
adb shell setprop debug.rs.shader 0 <nul
adb shell setprop debug.sensors 0 <nul
adb shell setprop debug.hwui.profile false <nul
adb shell setprop debug.layout false <nul
adb shell setprop debug.generate-debug-info false <nul
adb shell setprop debug.egl.traceGpuCompletion false <nul
adb shell setprop debug.rs.shader.attributes 0 <nul
adb shell setprop debug.rs.shader.uniforms 0 <nul
adb shell setprop debug.rs.visual 0 <nul
adb shell setprop debug.egl.callstack false <nul
adb shell setprop debug.orientation.log false <nul
adb shell setprop debug.ld.all 0 <nul
adb shell setprop debug.hwui.level 0 <nul
adb shell setprop debug.contacts.ksad 0 <nul
adb shell setprop debug.sf.layerdump 0 <nul
adb shell setprop debug.ldbase 0 <nul
adb shell setprop debug.perfmond.atrace 0 <nul
adb shell setprop debug.sf.enable_transaction_tracing false <nul
adb shell setprop debug.gles.layers 0 <nul
adb shell setprop debug.angle.validation false <nul
adb shell setprop debug.sf.layer_history_trace false <nul
adb shell setprop debug.sf.layer_caching_highlight false <nul
adb shell setprop debug.jni.logging 0 <nul
adb shell setprop debug.orientation.log false <nul
adb shell setprop debug.track-associations 0 <nul
adb shell setprop debug.tracing.screen_state 0 <nul
adb shell setprop debug.synclog 0 <nul
adb shell setprop debug.sys.looper_stats_enabled 0 <nul
adb shell setprop debug.velocitytracker.alt 0 <nul
adb shell setprop debug.tflite.trace 0 <nul
adb shell setprop debug.adbd.logging 0 <nul
adb shell setprop debug.sf.enable_egl_image_tracker false <nul
adb shell setprop debug.stagefright.omx-debug 0 <nul
adb shell setprop debug.stagefright.profilecodec 0 <nul
adb shell setprop debug.debuggerd.wait_for_gdb false <nul
adb shell setprop debug.cp2.scan_all_packages 0 <nul
adb shell setprop debug.tracing.screen_brightness 0 <nul
adb shell setprop debug.servicemanager.log_calls 0 <nul
adb shell setprop debug.hwui.print_config 0 <nul
adb shell setprop debug.choreographer.frametime false <nul
adb shell setprop debug.sf.vsp_trace false <nul
adb shell setprop debug.egl.trace 0 <nul
adb shell setprop debug.egl.finish false <nul
adb shell setprop debug.sf.trace_hint_sessions false <nul
adb shell setprop debug.sf.vsync_trace_detailed_info false <nul
adb shell setprop debug.atrace.tags.enableflags 0 <nul
adb shell setprop debug.debuggerd.wait_for_debugger false <nul
adb shell setprop debug.hwui.capture_skp_enabled false <nul
adb shell setprop debug.renderengine.skia_atrace_enabled 0 <nul
adb shell setprop debug.mdpcomp.logs 0 <nul
adb shell setprop debug.graphics.gpu.profiler.perfetto 0 <nul
adb shell setprop debug.NewDatabasePerformanceTests.enable_wal false <nul
adb shell setprop debug.hwui.skia_atrace_enabled 0 <nul
adb shell setprop debug.rs.profile 0 <nul
adb shell setprop debug.sf.dump 0 <nul
adb shell setprop debug.debuggerd.disable 1 <nul
adb shell setprop debug.hwc_dump_en 0 <nul
adb shell setprop persist.traced.enable 0 <nul > nul 2>&1
adb shell setprop debug.hwc.logvsync 0 <nul
adb shell setprop debug.malloc 0 <nul
adb shell setprop debug.enable.wl_log 0 <nul
adb shell setprop debug.sensors.logging.slpi false <nul
adb shell setprop debug.tracing.battery_status 0 <nul
adb shell setprop debug.hwui.trace_gpu_resources false <nul
adb shell setprop debug.hwui.skia_use_perfetto_track_events false <nul
adb shell setprop debug.hwui.skia_tracing_enabled false <nul
adb shell setprop debug.hwui.skip_eglmanager_telemetry true <nul
adb shell setprop persist.traced_perf.enable false <nul > nul 2>&1
adb shell setprop debug.renderengine.skia_use_perfetto_track_events false <nul
adb shell setprop debug.tracing.ctl.renderengine.skia_tracing_enabled false <nul
adb shell setprop debug.hwui.skp_filename false <nul
:: Never set debug.sqlite journalmode, syncmode or wal.syncmode OFF: that drops SQLite durability
:: for every database, so a crash corrupts or loses data. journalsizelimit only caps the file.
adb shell setprop debug.sqlite.journalsizelimit 1mb <nul
adb shell setprop debug.sf.dump.external false <nul
adb shell setprop debug.sf.dump.primary false <nul
adb shell setprop debug.sf.dump.png 0 <nul
adb shell setprop debug.checkjni 0 <nul
adb shell setprop debug.apidump.detailed false <nul
adb shell setprop debug.renderengine.skia_tracing_enabled false <nul
adb shell setprop debug.adpf_cts_verbose_logging false <nul
adb shell setprop debug.tracing.plug_type 0 <nul
adb shell setprop debug.tracing.profile_boot_classpath 0 <nul
adb shell setprop debug.tracing.profile_system_server 0 <nul
adb shell setprop debug.tracing.mnc 0 <nul
adb shell setprop debug.tracing.mcc 0 <nul
adb shell setprop debug.tracing.device_state 0 <nul
adb shell setprop debug.logging.enabled false <nul
adb shell setprop debug.nn.fuzzer.dumpspec 0 <nul
adb shell setprop debug.nn.fuzzer.log 0 <nul
adb shell setprop debug.nn.fuzzer.detectleak 0 <nul
adb shell setprop debug.perfetto.sdk_sysprop_guard_generation 0 <nul
adb shell setprop debug.libbase.property_test false <nul
adb shell setprop debug.tracing.ctl.perfetto.sdk_sysprop_guard_generation false <nul
adb shell setprop debug.tracing.ctl.hwui.skia_use_perfetto_track_events false <nul
adb shell setprop debug.tracing.ctl.hwui.skia_tracing_enabled false <nul
adb shell setprop debug.sf.dump.enable false <nul
adb shell setprop debug.hwc.enable_vds_dump 0 <nul
adb shell setprop debug.power.loghint 0 <nul
adb shell setprop debug.surface_trace 0 <nul
adb shell setprop debug.sf.ddms 0 <nul
adb shell setprop debug.sensors.diag_buffer_log false <nul
adb shell setprop debug.systemui.latency_tracking 0 <nul
adb shell setprop debug.hwc.trace_hint_sessions false <nul
adb shell setprop debug.vulkan.enable_callback false <nul
adb shell setprop debug.angle.enable_vulkan_api_dump_layer 0 <nul
adb shell setprop debug.angle.capture.enabled 0 <nul
adb shell setprop debug.force_remoteinput_history false <nul
adb shell setprop persist.debug.trace_layouts false <nul > nul 2>&1
adb shell setprop debug.atrace.prefer_sdk false <nul
adb shell setprop debug.tracing.desktop_mode_visible_tasks 0 <nul
adb shell setprop debug.msg_enable 0 <nul
adb shell setprop debug.hwc.normalize_hint_session_durations false <nul
adb shell setprop db.log.detailed 0 <nul > nul 2>&1
adb shell setprop debug.mdlogger.Running 0 <nul
adb shell setprop debug.sf.sa_log 0 <nul
adb shell setprop debug.hwc.fakevsync 0 <nul
adb shell setprop debug.rs.reduce-split-accum 1 <nul
adb shell setprop debug.hwui.nv_profiling false <nul
adb shell setprop debug.hwui.filter_test_overhead false <nul
adb shell setprop debug.trace.enable 0 <nul
adb shell setprop debug.sf.treble_testing_override false <nul
adb shell setprop debug.sf.kernel_idle_timer_update_overlay false <nul
adb shell setprop debug.choreographer.janklog false <nul
adb shell setprop debug.sf.hwc_hotplug_error_via_neg_vsync 0 <nul
adb shell setprop debug.firebase.analytics.app none <nul
adb shell setprop debug.atrace.user_initiated 0 <nul
adb shell setprop debug.stagefright.rtp false <nul
adb shell setprop debug.incremental.enforce_readlogs_max_interval_for_system_dataloaders false <nul
adb shell setprop debug.Stats false <nul
adb shell setprop debug.AnalysisOrder false <nul
adb shell setprop debug.DumpLiveExprs false <nul
adb shell setprop debug.DumpLiveVars false <nul
adb shell setprop debug.DumpCFG false <nul
adb shell setprop debug.ViewCFG false <nul
adb shell setprop debug.DumpCalls false <nul
adb shell setprop debug.ReportStmts false <nul
adb shell setprop debug.DumpDominators false <nul
adb shell setprop debug.DumpCallGraph false <nul
adb shell setprop debug.ConfigDumper false <nul
adb shell setprop debug.DumpControlDependencies false <nul
adb shell setprop debug.ExprInspection false <nul
adb shell setprop debug.adservices.consent_manager_debug_mode null <nul
adb shell setprop debug.vulkan.layers '' <nul
:: Not debug.force_low_ram here: low-RAM mode slows the device; only Extreme Power Saver sets it.
adb shell device_config put device_personalization_services SpeechRecognitionService__clear_logging_events_if_too_much_memory true <nul
::changed
adb shell setprop debug.sf.prime_shader_cache.transparent_image_dimmed_layers false <nul
adb shell setprop debug.sf.prime_shader_cache.solid_dimmed_layers false <nul
adb shell setprop debug.sf.prime_shader_cache.shadow_layers false <nul
adb shell setprop debug.egl.force_msaa false <nul
adb shell setprop debug.sf.showupdates 0 <nul
adb shell setprop debug.sf.showcpu 0 <nul
adb shell setprop debug.sf.showbackground 0 <nul
adb shell setprop debug.sf.showfps 0 <nul
adb shell setprop debug.rs.debug 0 <nul
adb shell setprop debug.sf.show_refresh_rate_overlay_spinner 0 <nul
adb shell setprop debug.sf.show_refresh_rate_overlay_render_rate 0 <nul
adb shell setprop debug.sf.show_refresh_rate_overlay_in_middle 0 <nul
adb shell setprop debug.hwc.showfps 0 <nul
adb shell setprop debug.hwui.overdraw false <nul
adb shell setprop debug.hwui.webview_overlays_enabled false <nul
adb shell setprop debug.sf.enable_hwc_vds false <nul
adb shell setprop debug.hwui.profile.maxframes 0 <nul
adb shell setprop debug.hwui.show_non_rect_clip hide <nul
adb shell setprop debug.hwui.show_layers_updates false <nul
adb shell setprop debug.assert 0 <nul
adb shell setprop debug.hwui.show_dirty_regions false <nul
adb shell setprop debug.angle.capture.frame_start 0 <nul
adb shell setprop debug.rs.reduce 1 <nul
adb shell setprop debug.sf.gpuoverlay 0 <nul
adb shell setprop debug.stagefright.fps false <nul
adb shell setprop debug.sf.disable_hwc_vds 1 <nul
adb shell setprop debug.hwc.simulate 0 <nul
adb shell setprop debug.enable_remote_input false <nul
adb shell setprop debug.angle.markers 0 <nul
adb shell setprop debug.stagefright.experiments false <nul
adb shell setprop debug.stagefright.enableshaping 0 <nul
adb shell setprop debug.sf.show_predicted_vsync false <nul
::changed
call :dropbox_lowprio
adb shell cmd dropbox set-rate-limit 20000000000000 <nul
adb shell device_config put runtime_native metrics.reporting-mods 0 <nul
adb shell device_config put runtime_native metrics.reporting-mods-server 0 <nul
adb shell device_config put runtime_native metrics.write-to-statsd false <nul
adb shell device_config put runtime_native metrics.reporting-num-mods 0 <nul
adb shell device_config put runtime_native metrics.reporting-num-mods-server 0 <nul
adb shell device_config put runtime_native metrics.reporting-spec S <nul
adb shell device_config put runtime_native metrics.reporting-spec-server S <nul
adb shell device_config put odad enable_fa_stats_log_logging false <nul
adb shell device_config put device_personalization_services StatsLog__active_users_logger_enabled false <nul
adb shell device_config put device_personalization_services StatsLog__active_users_logger_non_persistent false <nul
adb shell device_config put device_personalization_services StatsLog__enable_new_logger_api false <nul
adb shell device_config put adservices cobalt_logging_enabled false <nul
adb shell device_config put adservices enable_logged_topic false <nul
adb shell device_config put adservices adservice_error_logging_enabled false <nul
adb shell device_config put adservices measurement_enable_app_package_name_logging false <nul
adb shell device_config put adservices measurement_enable_source_debug_report false <nul
adb shell device_config put adservices fledge_app_package_name_logging_enabled false <nul
adb shell device_config put adservices fledge_auction_server_enable_debug_reporting false <nul
adb shell device_config put adservices fledge_auction_server_api_usage_metrics_enabled false <nul
adb shell device_config put adservices enable_ad_services_system_api false <nul
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_filtering false <nul
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_socket false <nul
adb shell device_config put odad westworld_logging false <nul
adb shell device_config put odad log_error_model_id_westworld_enabled false <nul
adb shell device_config put odad log_model_id_westworld false <nul
adb shell device_config put odad log_model_version_westworld false <nul
adb shell device_config put odad log_classification_latency_westworld false <nul
adb shell device_config put odad moirai_additional_metrics_enabled false <nul
adb shell device_config put odad mismatch_metrics_v2_enabled false <nul
adb shell device_config put on_device_personalization odp_enable_client_error_logging false <nul
adb shell device_config put on_device_personalization fcp_enable_client_error_logging false <nul
adb shell device_config put on_device_personalization odp_background_jobs_logging_enabled false <nul
adb shell device_config put on_device_personalization fcp_enable_background_jobs_logging false <nul
adb shell device_config put device_personalization_services AutofillVC__enable_clearcut_log false <nul
adb shell device_config put device_personalization_services Captions__enable_clearcut_logging false <nul
adb shell device_config put device_personalization_services PlatformLogging__enable_metric_wise_populations false <nul
adb shell device_config put device_personalization_services Superpacks__use_logging_listener false <nul
adb shell device_config put device_personalization_services Overview__enable_pir_clearcut_logging false <nul
adb shell device_config put device_personalization_services Overview__enable_pir_westworld_logging false <nul
adb shell cmd display ab-logging-disable <nul > nul 2>&1
adb shell cmd display dwb-logging-disable <nul > nul 2>&1
adb shell cmd display dmd-logging-disable <nul > nul 2>&1
adb shell settings put global netstats_sample_enabled 0 <nul
adb shell settings put global sqlite_compatibility_wal_flags legacy_compatibility_wal_enabled=false,wal_syncmode=OFF <nul
adb shell settings put global foreground_service_starts_logging_enabled_uri false <nul
adb shell settings put global activity_starts_logging_enabled_uri false <nul
adb shell settings put global nene_log 0 <nul
adb shell settings put global wifi_link_speed_metrics_enabled 0 <nul
adb shell settings put global wifi_is_unusable_event_metrics_enabled 0 <nul
adb shell settings put global wait_for_debugger 0 <nul
adb shell settings put global contacts_database_wal_enabled 0 <nul
adb shell settings put global logcat_for_system_server_anr 0 <nul
adb shell settings put global enable_gnss_raw_meas_full_tracking 0 <nul
adb shell settings put global force_enable_pss_profiling 0 <nul
adb shell settings put global verbose_logging_level_disabled 1 <nul
adb shell settings put global enable_gpu_debug_layers 0 <nul
:: Do not delete gpu_debug_layers: Logs On cannot restore that list, and the switch above covers it.
adb shell settings put global sys_traced 0 <nul
adb shell settings put global autofill_logging_level 0 <nul
adb shell settings put global dropbox_max_files 1 <nul
adb shell settings put global activity_starts_logging_enabled 0 <nul
adb shell settings put global enable_diskstats_logging 0 <nul
adb shell settings put global foreground_service_starts_logging_enabled 0 <nul
adb shell settings put global wifi_verbose_logging_enabled 0 <nul
adb shell settings put global enable_automatic_system_server_heap_dumps 0 <nul
adb shell settings put global settings_enable_monitor_phantom_procs false <nul
adb shell settings put global enable_opengl_traces false <nul
adb shell settings put global dropbox:dumpsys:procstats disabled <nul
adb shell settings put global dropbox:dumpsys:usagestats disabled <nul
adb shell settings put global battery_stats_constants track_cpu_times_by_proc_state=false,track_cpu_active_cluster_time=false,read_binary_cpu_time=false,max_history_files=0,max_history_buffer_kb=0 <nul
adb shell settings put global chained_battery_attribution_enabled 0 <nul
adb shell settings put global kernel_cpu_thread_reader num_buckets=0,collected_uids=,minimum_total_cpu_usage_millis=999999999 <nul
adb shell settings put global sys_uidcpupower 0 <nul
adb shell settings put global netstats_augment_enabled 0 <nul
adb shell settings put global netstats_combine_subtype_enabled 0 <nul
adb shell settings put global settings_enable_spa_metrics false <nul
adb shell settings put global settings_adb_metrics_writer false <nul
adb shell device_config put systemui enable_notification_memory_monitoring false <nul
adb shell device_config put interaction_jank_monitor enabled false <nul
adb shell settings put system anr_debugging_mechanism 0 <nul
adb shell settings put system remote_control 0 <nul
adb shell cmd looper_stats disable <nul > nul 2>&1
adb shell settings put global looper_stats enabled=false,sampling_interval=999999999 <nul
adb shell simpleperf --log fatal --log-to-android-buffer 0 <nul > nul 2>&1
adb shell cmd autofill set log_level off <nul
adb shell cmd autofill set max_visible_datasets 0 <nul
adb shell cmd activity clear-debug-app <nul
adb shell cmd activity clear-exit-info <nul
adb shell cmd device_policy clear-freeze-period-record <nul > nul 2>&1
adb shell cmd otadexopt cleanup <nul
adb shell cmd voiceinteraction set-debug-hotword-logging false <nul
call :wm_silence_logs
adb shell dumpsys binder_calls_stats --disable <nul > nul 2>&1
adb shell dumpsys binder_calls_stats --disable-detailed-tracking <nul > nul 2>&1
adb shell dumpsys procstats --stop-testing <nul > nul 2>&1
adb shell settings put global binder_calls_stats sampling_interval=500000000,detailed_tracking=disable,enabled=false,upload_data=false <nul
adb shell dumpsys batterystats disable full-history <nul > nul 2>&1
adb shell ime tracing stop <nul
adb shell logcat -c <nul
adb shell logcat -G 64kb <nul
adb shell wm tracing level critical <nul > nul 2>&1
adb shell wm tracing size 1 <nul > nul 2>&1
echo Done , Press Any Button To Go Back
pause > nul
goto Battery

:onlogss
cls
title Logs/etc : On
call :_dcfg_warn
:: Revert the universal log silencer. Clear with '', never a double-quote pair: cmd strips those.
adb shell setprop persist.log.tag '' <nul > nul 2>&1
adb shell setprop log.tag '' <nul > nul 2>&1
:: persist.* survives reboot, so every persist prop Logs Off sets must be cleared here.
adb shell setprop persist.debug.trace_layouts '' <nul > nul 2>&1
:: Clears the SQLite durability props an older DCX Logs Off set, for anyone not rebooted since.
adb shell setprop debug.sqlite.journalmode '' <nul > nul 2>&1
adb shell setprop debug.sqlite.syncmode '' <nul > nul 2>&1
adb shell setprop debug.sqlite.wal.syncmode '' <nul > nul 2>&1
adb shell logcat -G 256kb <nul
adb shell device_config put adservices enable_ad_services_system_api true <nul
adb shell device_config put odad mismatch_metrics_v2_enabled true <nul
adb shell device_config put adservices fledge_auction_server_api_usage_metrics_enabled true <nul
adb shell device_config put adservices enable_logged_topic true <nul
adb shell settings delete global settings_adb_metrics_writer <nul > nul 2>&1
adb shell settings delete global settings_enable_spa_metrics <nul > nul 2>&1
adb shell device_config put device_personalization_services SpeechRecognitionService__clear_logging_events_if_too_much_memory false <nul
adb shell settings delete global netstats_augment_enabled <nul > nul 2>&1
adb shell settings delete global netstats_combine_subtype_enabled <nul > nul 2>&1
:: Restore by deleting: that hands the flag back to the platform default instead of guessing true.
adb shell device_config delete interaction_jank_monitor enabled <nul > nul 2>&1
adb shell device_config delete systemui enable_notification_memory_monitoring <nul > nul 2>&1
adb shell settings delete global sys_uidcpupower <nul > nul 2>&1
adb shell settings delete global contacts_database_wal_enabled <nul > nul 2>&1
adb shell settings delete global kernel_cpu_thread_reader <nul > nul 2>&1
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_filtering true <nul
adb shell device_config put bluetooth INIT_gd_hal_snoop_logger_socket true <nul
adb shell device_config put device_personalization_services AutofillVC__enable_clearcut_log true <nul
adb shell settings delete global chained_battery_attribution_enabled <nul > nul 2>&1
adb shell device_config put odad moirai_additional_metrics_enabled true <nul
adb shell device_config put odad log_classification_latency_westworld true <nul
:: Delete, not put: battery_stats_constants returns to the platform default.
adb shell settings delete global battery_stats_constants <nul > nul 2>&1
adb shell device_config put adservices fledge_auction_server_enable_debug_reporting true <nul
adb shell device_config put adservices fledge_app_package_name_logging_enabled true <nul
adb shell device_config put adservices mdd_network_stats_logging_sample_interval 100 <nul
adb shell device_config put adservices mdd_api_logging_sample_interval 100 <nul
adb shell device_config put device_personalization_services Overview__enable_pir_westworld_logging true <nul
adb shell device_config put device_personalization_services Overview__enable_pir_clearcut_logging true <nul
adb shell settings delete global dropbox:dumpsys:procstats <nul > nul 2>&1
adb shell settings delete global dropbox:dumpsys:usagestats <nul > nul 2>&1
adb shell setprop security.perf_harden 1 <nul
adb shell settings delete global enable_opengl_traces <nul > nul 2>&1
adb shell device_config put odad log_model_version_westworld true <nul
adb shell device_config put odad log_model_id_westworld true <nul
adb shell device_config put odad log_error_model_id_westworld_enabled true <nul
adb shell device_config put device_personalization_services Superpacks__use_logging_listener true <nul
adb shell device_config put on_device_personalization fcp_enable_background_jobs_logging true <nul
adb shell device_config put device_personalization_services Captions__enable_clearcut_logging true <nul
adb shell device_config put device_personalization_services PlatformLogging__enable_metric_wise_populations true <nul
adb shell device_config put runtime_native metrics.reporting-spec 1,5,30,60,600 <nul
adb shell device_config put runtime_native metrics.reporting-spec-server 1,10,60,3600,* <nul
adb shell device_config put runtime_native metrics.write-to-statsd true <nul
adb shell device_config put runtime_native metrics.reporting-num-mods 100 <nul
adb shell device_config put runtime_native metrics.reporting-num-mods-server 100 <nul
adb shell device_config put runtime_native metrics.reporting-mods 2 <nul
adb shell device_config put runtime_native metrics.reporting-mods-server 2 <nul
adb shell settings delete global netstats_sample_enabled <nul > nul 2>&1
adb shell settings delete global bluetooth_disabled_profiles <nul > nul 2>&1
adb shell wm tracing level trim <nul > nul 2>&1
adb shell settings delete global binder_calls_stats <nul > nul 2>&1
adb shell settings delete global foreground_service_starts_logging_enabled_uri <nul > nul 2>&1
adb shell settings delete global activity_starts_logging_enabled_uri <nul > nul 2>&1
adb shell device_config delete profcollect_native_boot enabled <nul > nul 2>&1
adb shell setprop persist.log.tag.DisplayPowerController '' <nul
adb shell device_config delete systemui com.android.systemui.coroutine_tracing <nul > nul 2>&1
adb shell settings delete global nene_log <nul > nul 2>&1
adb shell settings delete global wifi_link_speed_metrics_enabled <nul > nul 2>&1
adb shell settings delete global wifi_is_unusable_event_metrics_enabled <nul > nul 2>&1
adb shell settings delete global wait_for_debugger <nul > nul 2>&1
adb shell settings delete global contacts_database_wal_enabled <nul > nul 2>&1
adb shell settings delete global logcat_for_system_server_anr <nul > nul 2>&1
adb shell settings delete global enable_gnss_raw_meas_full_tracking <nul > nul 2>&1
adb shell settings delete global force_enable_pss_profiling <nul > nul 2>&1
adb shell settings delete global verbose_logging_level_disabled <nul > nul 2>&1
adb shell settings delete global enable_gpu_debug_layers <nul > nul 2>&1
:: 0 means the framework default, the value Off also sets - there is nothing else to restore.
adb shell cmd autofill set max_visible_datasets 0 <nul
adb shell settings delete global sys_traced <nul > nul 2>&1
adb shell settings delete system user_log_enabled <nul > nul 2>&1
adb shell settings delete system window_orientation_listener_log <nul > nul 2>&1
adb shell settings delete global enable_automatic_system_server_heap_dumps <nul > nul 2>&1
adb shell settings delete global sys.wifitracing.started <nul > nul 2>&1
adb shell settings delete global opengl_trace <nul > nul 2>&1
adb shell settings delete global settings_enable_monitor_phantom_procs <nul > nul 2>&1
adb shell settings delete global dropbox_max_files <nul > nul 2>&1
adb shell settings delete global dropbox:dumpsys:usagestats <nul > nul 2>&1
adb shell settings delete global dropbox:dumpsys:procstats <nul > nul 2>&1
adb shell settings delete global activity_starts_logging_enabled <nul > nul 2>&1
adb shell settings delete global enable_diskstats_logging <nul > nul 2>&1
adb shell settings delete global sys.lmk.reportkills <nul > nul 2>&1
adb shell settings delete global foreground_service_starts_logging_enabled <nul > nul 2>&1
adb shell settings delete global wifi_verbose_logging_enabled <nul > nul 2>&1
adb shell settings delete global enable_automatic_system_server_heap_dumps <nul > nul 2>&1
adb shell cmd looper_stats enable <nul
adb shell settings delete system anr_debugging_mechanism <nul > nul 2>&1
adb shell setprop persist.traced.enable 1 <nul > nul 2>&1
adb shell settings delete global idle_loglevel <nul > nul 2>&1
adb shell settings delete global persist.sampling_profiler <nul > nul 2>&1
adb shell settings delete system Logcat.live <nul > nul 2>&1
adb shell settings delete system remote_control <nul > nul 2>&1
adb shell settings delete system log.closeguard.Animation <nul > nul 2>&1
:: Undo with restore-defaults: calling :dropbox_lowprio or set-rate-limit again re-applies Off.
adb shell cmd dropbox restore-defaults <nul > nul 2>&1
adb shell setprop persist.traced_perf.enable 1 <nul > nul 2>&1
adb shell device_config put odad enable_fa_stats_log_logging true <nul
adb shell device_config put device_personalization_services StatsLog__active_users_logger_enabled true <nul
adb shell device_config put device_personalization_services StatsLog__active_users_logger_non_persistent true <nul
adb shell device_config put device_personalization_services StatsLog__enable_new_logger_api true <nul
adb shell device_config put adservices cobalt_logging_enabled true <nul
adb shell device_config put adservices adservice_error_logging_enabled true <nul
adb shell device_config put odad westworld_logging true <nul
adb shell device_config put adservices measurement_enable_source_debug_report true <nul
:: Not the *-logging-enable display commands: those loggers are off on a stock phone, so Off's
:: disable already matches stock and enabling them here would add logging, not revert it.
adb shell device_config put on_device_personalization odp_enable_client_error_logging true <nul
adb shell device_config put adservices measurement_enable_app_package_name_logging true <nul
adb shell device_config put on_device_personalization fcp_enable_client_error_logging true <nul
:: Off pins these persistent settings and they survive reboot, so they are deleted here.
:: Do not touch DeviceConfig server sync here: it belongs to Tweaks.
adb shell settings delete global looper_stats <nul > nul 2>&1
adb shell settings delete global sqlite_compatibility_wal_flags <nul > nul 2>&1
adb shell settings delete global autofill_logging_level <nul > nul 2>&1
adb shell device_config put on_device_personalization odp_background_jobs_logging_enabled true <nul > nul 2>&1
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
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offsv
if "!toggle!"=="2" goto onsv
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto saverpower

:offsv
@echo off
cls
title Power Saver : Off
adb shell settings delete global low_power <nul
adb shell settings delete global low_power_sticky <nul
call :_act_reset
call :_settings_verify global low_power DELETE
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsv
@echo off
cls
title Power Saver : On
adb shell settings put global low_power 1 <nul
adb shell settings put global low_power_sticky 0 <nul
call :_act_reset
call :_settings_verify global low_power 1
call :_act_summary
:: Android will not run battery saver while powered - USB always is - though low_power reads 1.
:: ip:port or an mDNS name is a Wi-Fi connection; anything else is the USB cable.
echo.
if not defined ANDROID_SERIAL goto _onsv_wifi
call :_wifi_ser ANDROID_SERIAL && goto _onsv_wifi
echo  %y%Note:%w% the phone is on USB, so it is charging - Android will not actually
echo  turn battery saver on until you unplug it. The setting is stored and takes
echo  effect then.
goto _onsv_done

:_onsv_wifi
echo  %y%Note:%w% if the phone is charging, Android will not turn battery saver on
echo  until it is unplugged. The setting is stored either way.

:_onsv_done
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
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offani
if "!toggle!"=="2" goto onani
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto animation

:offani
@echo off
cls
title Animation : Off
adb shell settings put global enable_back_animation 0 <nul
adb shell settings put global fancy_ime_animations 0 <nul
adb shell settings put secure accessibility_disable_animations 1 <nul
adb shell settings put global fade_duration 0 <nul
adb shell settings put global reduce_motion 1 <nul
adb shell settings put secure reduce_motion 1 <nul
adb shell settings put secure long_press_timeout 250 <nul
adb shell settings put secure multi_press_timeout 250 <nul
adb shell settings put global enable_back_animation 0 <nul
adb shell settings put global window_animation_scale 0.0 <nul
adb shell settings put global transition_animation_scale 0.0 <nul
adb shell settings put global animator_duration_scale 0.0 <nul
adb shell settings put secure accessibility_disable_animations 1 <nul
adb shell settings put global disable_window_blurs 1 <nul
call :_act_reset
call :_settings_verify global window_animation_scale 0.0
call :_settings_verify global transition_animation_scale 0.0
call :_settings_verify global animator_duration_scale 0.0
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:onani
@echo off
cls
title Animation : On
adb shell settings delete global reduce_motion <nul > nul 2>&1
adb shell settings delete global enable_back_animation <nul > nul 2>&1
adb shell settings delete global fancy_ime_animations <nul > nul 2>&1
adb shell settings delete secure accessibility_disable_animations <nul > nul 2>&1
adb shell settings delete global recent_app_transition_duration_scale <nul > nul 2>&1
adb shell settings delete global recent_app_transition_scale <nul > nul 2>&1
adb shell settings delete global app_transition_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global app_transition_animation_scale <nul > nul 2>&1
adb shell settings delete global reduce_transitions <nul > nul 2>&1
adb shell settings delete global shadow_animation_scale <nul > nul 2>&1
adb shell settings delete global remove_animations <nul > nul 2>&1
adb shell settings delete global fade_duration <nul > nul 2>&1
adb shell settings delete secure reduce_motion <nul > nul 2>&1
:: Delete the timeouts Off pins to 250 so tap and long-press timing return to the platform default.
adb shell settings delete secure long_press_timeout <nul > nul 2>&1
adb shell settings delete secure multi_press_timeout <nul > nul 2>&1
adb shell settings delete global animator_slow_preview <nul > nul 2>&1
adb shell settings delete global animation_scale_animator_duration <nul > nul 2>&1
adb shell settings delete global animation_scale_window_transition <nul > nul 2>&1
adb shell settings delete global activity_open_enter_animation <nul > nul 2>&1
adb shell settings delete global activity_open_exit_animation <nul > nul 2>&1
adb shell settings delete global activity_close_enter_animation <nul > nul 2>&1
adb shell settings delete global activity_close_exit_animation <nul > nul 2>&1
adb shell settings delete global app_transition_scale <nul > nul 2>&1
adb shell settings delete global app_transition_duration_scale <nul > nul 2>&1
adb shell settings delete global app_close_animate_level <nul > nul 2>&1
adb shell settings delete global windows_anim_duration_scale <nul > nul 2>&1
adb shell settings delete global windows_anim_scale <nul > nul 2>&1
adb shell settings delete global windows_transition_anim_scale <nul > nul 2>&1
adb shell settings delete global windows_transition_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global window_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global transition_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global display_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global display_animation_scale <nul > nul 2>&1
adb shell settings delete global window_move_animation_duration_scale <nul > nul 2>&1
adb shell settings delete global window_move_animation_scale <nul > nul 2>&1
adb shell settings put global window_animation_scale 1.0 <nul > nul 2>&1
adb shell settings put global transition_animation_scale 1.0 <nul > nul 2>&1
adb shell settings put global animator_duration_scale 1.0 <nul > nul 2>&1
adb shell settings put global disable_window_blurs 0 <nul > nul 2>&1
adb shell settings delete global accessibility_reduce_transparency <nul > nul 2>&1
adb shell device_config delete systemui window_cornerRadius <nul > nul 2>&1
adb shell device_config delete systemui window_blur <nul > nul 2>&1
adb shell device_config delete systemui window_shadow <nul > nul 2>&1
adb shell device_config delete systemui reduce_animations <nul > nul 2>&1
adb shell device_config delete battery_saver reduce_animations <nul > nul 2>&1
call :_act_reset
call :_settings_verify global window_animation_scale 1.0
call :_settings_verify global transition_animation_scale 1.0
call :_settings_verify global animator_duration_scale 1.0
call :_act_summary
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
title Wi-Fi/BT scan and related
echo.
echo.
echo  Toggles wifi/bt scan-always and related scoring/netstats keys.
echo  Not an OEM "auto Wi-Fi" switch. Some watchdog keys are ignored on modern stacks.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offaut
if "!toggle!"=="2" goto onaut
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto autowifi

:offaut
@echo off
cls
title Auto Wifi : Off
adb shell settings put global wifi_supplicant_scan_interval_ms 240000 <nul
adb shell settings put global wifi_networks_available_notification_on 0 <nul
adb shell settings put global wifi_watchdog_on 0 <nul
adb shell settings put global wifi_watchdog_poor_network_test_enabled 0 <nul
adb shell settings put global wifi_scan_always_enabled 0 <nul > nul 2>&1
:: The BLE scan key is ble_scan_always_enabled; bluetooth_scan_always_enabled does not exist.
adb shell settings put global ble_scan_always_enabled 0 <nul > nul 2>&1
adb shell settings put global network_recommendations_enabled 0 <nul > nul 2>&1
adb shell settings put global netstats_enabled 0 <nul > nul 2>&1
adb shell settings put global network_scoring_ui_enabled 0 <nul > nul 2>&1
adb shell settings put global wifi_watchdog_poor_network_test_enabled 0 <nul > nul 2>&1
call :_act_reset
call :_settings_verify global wifi_scan_always_enabled 0
call :_settings_verify global ble_scan_always_enabled 0
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:onaut
@echo off
cls
title Auto Wifi : On
adb shell settings delete global wifi_supplicant_scan_interval_ms <nul > nul 2>&1
adb shell settings delete global wifi_networks_available_notification_on <nul > nul 2>&1
adb shell settings delete global wifi_watchdog_on <nul > nul 2>&1
adb shell settings delete global wifi_watchdog_poor_network_test_enabled <nul > nul 2>&1
adb shell settings put global wifi_scan_always_enabled 1 <nul > nul 2>&1
adb shell settings put global ble_scan_always_enabled 1 <nul > nul 2>&1
adb shell settings delete global network_recommendations_enabled <nul > nul 2>&1
adb shell settings put global netstats_enabled 1 <nul > nul 2>&1
adb shell settings put global network_scoring_ui_enabled 1 <nul > nul 2>&1
adb shell settings delete global wifi_watchdog_poor_network_test_enabled <nul > nul 2>&1
call :_act_reset
call :_settings_verify global wifi_scan_always_enabled 1
call :_settings_verify global ble_scan_always_enabled 1
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery
::sync
:sync
cls
title Toggle Sync
echo.
echo.
echo Toggle master_sync_status ^(placebo on modern Android^)
echo Real Auto sync is not rootless-writable - see Account Sync on page 2.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offsync
if "!toggle!"=="2" goto onsync
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto sync

:offsync
@echo off
cls
title Sync : Off
:: master_sync_status is the key the backup and CheckSetting use; placebo on modern Android.
call :_act_reset
call :_put_chk global master_sync_status 0
call :_act_summary
echo Real Auto sync is unchanged on modern Android.
echo Press Any Button To Go Back
pause > nul
goto Battery

:onsync
@echo off
cls
title Sync : On
call :_act_reset
call :_put_chk global master_sync_status 1
call :_act_summary
echo Real Auto sync is unchanged on modern Android.
echo Press Any Button To Go Back
pause > nul
goto Battery
::motion
:motion
@echo off
cls
title Samsung motion (OEM)
echo.
echo.
echo  Samsung OneUI motion-gesture keys ^(master_motion / air_motion_*^).
echo  Placebo on non-Samsung devices - AOSP does not read them.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offmotion
if "!toggle!"=="2" goto onmotion
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto motion

:offmotion
@echo off
cls
title Motion : Off
adb shell settings put system master_motion 0 <nul > nul 2>&1
adb shell settings put system motion_engine 0 <nul > nul 2>&1
adb shell settings put system air_motion_engine 0 <nul > nul 2>&1
adb shell settings put system air_motion_wake_up 0 <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery

:onmotion
@echo off
cls
title Motion : On
:: settings has no remove verb; delete restores the OEM default.
adb shell settings delete system master_motion <nul > nul 2>&1
adb shell settings delete system motion_engine <nul > nul 2>&1
adb shell settings delete system air_motion_engine <nul > nul 2>&1
adb shell settings delete system air_motion_wake_up <nul > nul 2>&1
echo Press Any Button To Go Back
pause > nul
goto Battery
::zram
:zram
@echo off
cls
title ZRAM preference
echo.
echo.
echo  Sets global zram_enabled ^(StorageManager preference^). Needs reboot;
echo  no-op if the OEM has no zram toggle ^(e.g. Samsung RAM Plus uses other keys^).
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offzram
if "!toggle!"=="2" goto onzram
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto zram

:offzram
@echo off
cls
title ZRAM : Off
adb shell settings put global zram_enabled 0 <nul
call :_act_reset
call :_settings_verify global zram_enabled 0
call :_act_summary
echo Reboot may be required for this to apply.
echo Press Any Button To Go Back
pause > nul
goto Battery

:onzram
@echo off
cls
title ZRAM : On
adb shell settings put global zram_enabled 1 <nul
call :_act_reset
call :_settings_verify global zram_enabled 1
call :_act_summary
echo Reboot may be required for this to apply.
echo Press Any Button To Go Back
pause > nul
goto Battery
::extreme
:extremepower
@echo off
cls
title Aggressive saver constants
echo.
echo.
echo  Not OEM "Extreme power saving". Tweaks battery_saver_constants,
echo  power mode, and related debug/AM flags. device_config bits need root on 14+.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offsvpp
if "!toggle!"=="2" goto onsvpp
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto extremepower

:offsvpp
@echo off
cls
title Extreme Power Saver : Off
:: Each key is captured for the session undo before it is changed or deleted: the three lists are
:: whole values a user or ROM may have set, and the flags may be server-pushed.
call :_tw_undo_dcfg activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled
call :_tw_undo_dcfg activity_manager bg_auto_restrict_abusive_apps
call :_tw_undo_add global battery_tip_constants
call :_tw_undo_add global battery_saver_constants
call :_tw_undo_add global activity_manager_constants
adb shell device_config delete activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled <nul
adb shell device_config delete activity_manager bg_auto_restrict_abusive_apps <nul
adb shell cmd power set-adaptive-power-saver-enabled false <nul
adb shell cmd power set-mode 0 <nul
adb shell settings put global battery_tip_constants app_restriction_enabled=true <nul
adb shell settings delete global battery_saver_constants <nul > nul 2>&1
:: Do not delete protect_battery: DCX never sets it, and on Samsung it is the user's charge limit.
adb shell settings delete global activity_manager_constants <nul > nul 2>&1
:: Clear the low-RAM mode :onsvpp forces; the debug.rs.* props are left to the reboot.
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
call :_dcfg_warn
:: Clears fake-battery state. dumpsys rather than cmd: older builds may lack cmd battery.
adb shell dumpsys battery reset <nul
:: Captured before any write, as Off does.
call :_tw_undo_dcfg activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled
call :_tw_undo_dcfg activity_manager bg_auto_restrict_abusive_apps
call :_tw_undo_add global activity_manager_constants
call :_tw_undo_add global battery_saver_constants
call :_tw_undo_add global battery_tip_constants
adb shell device_config put activity_manager bg_current_drain_auto_restrict_abusive_apps_enabled true <nul
adb shell device_config put activity_manager bg_auto_restrict_abusive_apps 1 <nul
adb shell settings put global activity_manager_constants power_check_interval=990000,power_check_max_cpu_1=2,power_check_max_cpu_2=2,power_check_max_cpu_3=2,power_check_max_cpu_4=2 <nul
adb shell settings put global battery_saver_constants advertise_is_enabled=false,enable_datasaver=false,enable_night_mode=true,disable_launch_boost=true,disable_vibration=true,disable_animation=true,disable_soundtrigger=true,defer_full_backup=true,defer_keyvalue_backup=true,enable_firewall=false,location_mode=2,enable_brightness_adjustment=false,adjust_brightness_factor=0.5,force_all_apps_standby=true,force_background_check=true,disable_optional_sensors=true,disable_aod=true,enable_quick_doze=true <nul
adb shell settings put global battery_tip_constants reduced_battery_enabled=true,battery_saver_tip_enabled=true,high_usage_period_ms=120000,app_restriction_enabled=true,battery_tip_enabled=false,summary_enabled=false,high_usage_enabled=true,high_usage_app_count=1,high_usage_battery_draining=15,reduced_battery_percent=5,low_battery_enabled=true,low_battery_hour=1 <nul
adb shell cmd power set-mode 1 <nul
adb shell cmd power set-adaptive-power-saver-enabled true <nul
adb shell setprop debug.rs.max-threads 2 <nul
adb shell setprop debug.rs.precision rs_fp_relaxed <nul
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
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offerr
if "!toggle!"=="2" goto onerr
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto senderror

:offerr
cls
title Send Error : Off
call :_act_reset
call :_put_chk secure send_action_app_error 0
call :_put_chk global send_action_app_error 0
call :_put_chk global enable_diagnostic_data 0
call :_put_chk system send_security_reports 0
call :_put_chk secure upload_debug_log_pref 0
call :_put_chk secure upload_log_pref 0
call :_put_chk system profiler.force_disable_ulog 1
call :_put_chk system profiler.force_disable_err_rpt 1
call :_put_chk secure usage_metrics_marketing_enabled 0
call :_put_chk secure USAGE_METRICS_UPLOAD_ENABLED 0
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:onerr
cls
title Send Error : On
call :_act_reset
call :_put_chk secure send_action_app_error 1
call :_put_chk global send_action_app_error 1
call :_put_chk global enable_diagnostic_data 1
call :_put_chk system send_security_reports 1
call :_put_chk secure upload_debug_log_pref DELETE
call :_put_chk secure upload_log_pref DELETE
call :_put_chk system profiler.force_disable_ulog DELETE
call :_put_chk system profiler.force_disable_err_rpt DELETE
call :_put_chk secure usage_metrics_marketing_enabled DELETE
call :_put_chk secure USAGE_METRICS_UPLOAD_ENABLED DELETE
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:toggleprofilling
cls
title ART lock profiling (developer)
echo.
echo.
echo  ART runtime_native_boot disable_lock_profiling - developer/debug only.
echo  Not a battery or FPS toggle. device_config writes need root on Android 14+.
echo.
echo [%r%1%w%] Off
echo [%r%2%w%] On
echo [%r%3%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offprof
if "!toggle!"=="2" goto onprof
if "!toggle!"=="3" goto Battery
:: guard against invalid input
goto toggleprofilling

:offprof
cls
title Lock Profiling : Off
call :_dcfg_warn
call :_act_reset
adb shell device_config put runtime_native_boot disable_lock_profiling true <nul
call :_dcfg_verify runtime_native_boot disable_lock_profiling true
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery

:onprof
cls
title Lock Profiling : ON
call :_dcfg_warn
call :_act_reset
adb shell device_config put runtime_native_boot disable_lock_profiling false <nul
call :_dcfg_verify runtime_native_boot disable_lock_profiling false
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Battery
:: gaming
:Gaming
@echo off
title Gaming Mode
cls
call :logo
echo          ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
call :_uptime
if defined _upt echo           [%g%+%w%]Uptime: !_upt!
set "cpucheck=N/A"
for /f "tokens=2 delims=:" %%i in ('adb shell dumpsys cpuinfo ^<nul 2^>nul ^| findstr /C:"Load:"') do set "cpucheck=%%i"
for /f "delims=" %%a in ("!cpucheck!") do set "cpucheck=%%a"
echo           [%g%+%w%]!cpucheck! LOAD
echo          ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
echo.
echo.
echo                                     %r%[%w%1%r%]%w% Toggle GMS
echo                                     %r%[%w%2%r%]%w% Thermal override ^(temporary^)
echo                                     %r%[%w%3%r%]%w% Toggle Package Verifier
echo                                     %r%[%w%4%r%]%w% Game Mode ^(FPS cap / render scale^)
echo                                     %r%[%w%5%r%]%w% Performance props ^(debug/OEM dump^)
echo                                     %r%[%w%6%r%]%w% TCP / DNS / network mode
echo                                     %r%[%w%7%r%]%w% GPU Renderer (Skia GL/Vulkan)
echo                                     %r%[%w%8%r%]%w% Force ANGLE for All Apps
echo                                     %r%[%w%9%r%]%w% Display Scaler (Resolution / DPI)
echo                                     %r%[%w%10%r%]%w% Game performance monitor
echo                                     %r%[%w%11%r%]%w% Back

:Gaming_ask
:: Re-ask without redrawing, so a phantom empty read does not re-run the probes.
set "game=" & set /p game="Choose An Option >> "
call :_noin game || goto dcx_noinput
if not defined game goto Gaming_ask
if "!game!"=="1" goto gms
if "!game!"=="2" goto thermal
if "!game!"=="3" goto package
if "!game!"=="4" goto gamemode
if "!game!"=="5" goto performance
if "!game!"=="6" goto netboost
if "!game!"=="7" goto gpurenderer
if "!game!"=="8" goto angleall
if "!game!"=="9" goto dispscaler
if "!game!"=="10" goto perfmon
if "!game!"=="11" goto menu
goto Gaming_ask
:: ===================================================================
:: Display Scaler - wm size / wm density: no root, persists across reboot, reversible.
:: Density scales with resolution so UI size stays the same; presets use the physical panel.
:: ===================================================================
:dispscaler
cls
title Display Scaler (Resolution / DPI)
call :logo
:: Read the panel's TRUE native resolution + density as the baseline.
set "PW=" & set "PH=" & set "PD=" & set "PDR=" & set "SZ=" & set "OVR=" & set "OVRD="
for /f "tokens=2 delims=:" %%a in ('adb shell wm size ^<nul 2^>nul ^| findstr /C:"Physical size"') do set "SZ=%%a"
for /f "tokens=1,2 delims=x " %%a in ("!SZ!") do ( set "PW=%%a" & set "PH=%%b" )
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Physical density"') do set "PDR=%%a"
for /f "tokens=* delims= " %%a in ("!PDR!") do set "PD=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm size ^<nul 2^>nul ^| findstr /C:"Override size"') do set "OVR=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Override density"') do set "OVRD=%%a"
:: Strip the trailing CR older adb builds add.
if defined OVR for /f "delims=" %%a in ("!OVR!") do set "OVR=%%a"
if defined OVRD for /f "delims=" %%a in ("!OVRD!") do set "OVRD=%%a"
:: Phone text is read with delayed expansion and checked pipe-free: a pipe re-parses it.
:: Once this passes, PW/PH/PD hold digits only, so non-delayed reads of them are safe.
if not defined PW goto dispscaler_err
if not defined PH goto dispscaler_err
if not defined PD goto dispscaler_err
set "_dsbad="
for /f "eol=0 delims=0123456789" %%c in ("!PW!!PH!!PD!") do set "_dsbad=1"
if defined _dsbad goto dispscaler_err
set /a W85=PW*85/100, H85=PH*85/100, D85=PD*85/100
set /a W75=PW*75/100, H75=PH*75/100, D75=PD*75/100
set /a W67=PW*67/100, H67=PH*67/100, D67=PD*67/100
set /a W50=PW*50/100, H50=PH*50/100, D50=PD*50/100
echo.
echo  Native : %g%%PW%x%PH%%w% @ %g%%PD% dpi%w%   (the panel's real resolution)
if defined OVR echo  Active override :%gold%!OVR!%w% /%gold%!OVRD!%w% dpi
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
:: Re-ask without redrawing: a phantom empty read after the slow wm probes must not re-run them.
set "ds="
set /p ds="Choose An Option >> "
call :_noin ds || goto dcx_noinput
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
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 goto dispscaler
if not errorlevel 1 goto dispscaler
echo.
call :_act_reset
adb shell wm size %NW%x%NH% <nul
call :_act_rc !errorlevel! "wm size %NW%x%NH%"
adb shell wm density %ND% <nul
call :_act_rc !errorlevel! "wm density %ND%"
call :_act_summary
echo  If anything looks off, come back and choose Reset.
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
:: CDPI, not CD: a variable named CD shadows cmd's dynamic current-directory value.
set "CW=" & set "CH=" & set "CDPI="
set /p "CW=Width  (blank = cancel) >> "
call :_noin CW || goto dcx_noinput
if "!CW!"=="" goto dispscaler
set /p "CH=Height (blank = cancel) >> "
call :_noin CH || goto dcx_noinput
if "!CH!"=="" goto dispscaler
set "CDPI=" & set /p "CDPI=Density dpi (blank = cancel) >> "
call :_noin CDPI || goto dcx_noinput
if "!CDPI!"=="" goto dispscaler
:: Whole numbers, checked without a pipe: the pipe's child cmd drops a caret, and 1080^ then
:: passed and broke the bound checks below.
call :_tw_safechk CW || goto dispscaler_custom_bad
call :_lib_num CW || goto dispscaler_custom_bad
call :_tw_safechk CH || goto dispscaler_custom_bad
call :_lib_num CH || goto dispscaler_custom_bad
call :_tw_safechk CDPI || goto dispscaler_custom_bad
call :_lib_num CDPI || goto dispscaler_custom_bad
:: sane bounds so a typo can't leave the UI unusable
if %CW% LSS 320 goto dispscaler_custom_bad
if %CH% LSS 320 goto dispscaler_custom_bad
if %CW% GTR 8000 goto dispscaler_custom_bad
if %CH% GTR 8000 goto dispscaler_custom_bad
if %CDPI% LSS 80 goto dispscaler_custom_bad
if %CDPI% GTR 900 goto dispscaler_custom_bad
:: A value under half or over double the panel's own needs a second yes, e.g. 4800 for 480.
set "_dsodd="
call :_ds_ratio CW PW
call :_ds_ratio CH PH
call :_ds_ratio CDPI PD
set "NW=%CW%" & set "NH=%CH%" & set "ND=%CDPI%"
if not defined _dsodd goto dispscaler_set
call :_ds_confirm || goto dispscaler_custom
goto dispscaler_set

:dispscaler_custom_bad
echo [%r%^^!%w%] Invalid values. Width/height 320-8000, density 80-900, digits only.
timeout /t 2 /nobreak >nul
goto dispscaler_custom

:_ds_ratio
:: %1 = name of the value entered, %2 = name of the panel's own value (digits, or undefined).
:: Outside 50-200%% of it, prints the percentage and sets _dsodd for :_ds_confirm.
setlocal
set "_v=!%~1!"
set "_p=!%~2!"
if "!_p!"=="0" set "_p="
if not defined _p (echo  [%y%?%w%] !_v! - the panel's own value is unknown, so it cannot be compared. & endlocal & set "_dsodd=1" & exit /b)
set /a "_pct=_v*100/_p"
if !_pct! LSS 50 goto _ds_ratio_odd
if !_pct! GTR 200 goto _ds_ratio_odd
endlocal
exit /b

:_ds_ratio_odd
echo  [%y%?%w%] !_v! is !_pct!%% of the panel's !_p!.
endlocal & set "_dsodd=1"
exit /b

:_ds_confirm
:: Second confirmation for :_ds_ratio. exit 0 = the user meant it.
echo.
echo  %y%Check the value^(s^) marked [?] above.%w% Far from the panel's own - or not comparable
echo  with it - is usually a typo ^(4800 for 480^), and a wrong size can leave the screen hard to use.
echo    [Y] Yes, these are the values I meant    [N] No, enter them again
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 exit /b 1
if not errorlevel 1 exit /b 1
exit /b 0
:: -------------------------------------------------------------------
:: UI size, DPI only - stand-in for Smallest width, which some OEMs such as Huawei leave broken.
:: -------------------------------------------------------------------
:dispscaler_dpi
cls
title Display Scaler : UI size (DPI)
call :logo
:: Re-read the panel's native (physical) density as the 100%% baseline.
set "PDR=" & set "PD=" & set "OVRD="
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Physical density"') do set "PDR=%%a"
for /f "tokens=* delims= " %%a in ("!PDR!") do set "PD=%%a"
for /f "tokens=2 delims=:" %%a in ('adb shell wm density ^<nul 2^>nul ^| findstr /C:"Override density"') do set "OVRD=%%a"
:: The baseline must match the resolution in use, so read the size override too.
if defined OVRD for /f "delims=" %%a in ("!OVRD!") do set "OVRD=%%a"
if defined OVRD set "OVRD=!OVRD: =!"
set "PSZ=" & set "OSZ=" & set "PWID=" & set "OWID="
for /f "tokens=1,* delims=:" %%a in ('adb shell wm size ^<nul 2^>nul') do (
    if /i "%%a"=="Physical size" set "PSZ=%%b"
    if /i "%%a"=="Override size" set "OSZ=%%b"
)
if defined PSZ set "PSZ=!PSZ: =!"
if defined OSZ set "OSZ=!OSZ: =!"
for /f "tokens=1 delims=x" %%a in ("!PSZ!") do set "PWID=%%a"
for /f "tokens=1 delims=x" %%a in ("!OSZ!") do set "OWID=%%a"
:: Digits-only check without a pipe: a pipe re-parses phone text.
set "_wbad="
if defined PWID for /f "eol=0 delims=0123456789" %%c in ("!PWID!") do set "_wbad=1"
if defined _wbad set "PWID="
set "_wbad="
if defined OWID for /f "eol=0 delims=0123456789" %%c in ("!OWID!") do set "_wbad=1"
if defined _wbad set "OWID="
if defined PWID if "!PWID!"=="0" set "PWID="
if not defined PD goto dispscaler_err
call :_tw_safechk PD || goto dispscaler_err
:: Pipe-free digits check.
set "_dsbad="
for /f "eol=0 delims=0123456789" %%c in ("!PD!") do set "_dsbad=1"
if defined _dsbad goto dispscaler_err
:: PDB is the baseline: physical density, rescaled by the override width when one is in force.
set "PDB=!PD!"
set "SCALED="
if not defined PWID goto _dsdpi_base
if not defined OWID goto _dsdpi_base
if "!PWID!"=="!OWID!" goto _dsdpi_base
set /a PDB=PD*OWID/PWID
set "SCALED=1"

:_dsdpi_base
set /a U110=PDB*110/100, U90=PDB*90/100, U85=PDB*85/100, U80=PDB*80/100
echo.
echo  Changes ONLY the DPI (UI element size); the resolution is left as it is.
echo  This is the reliable replacement for the developer-options
echo  "Smallest width" entry that some OEMs (e.g. Huawei) disable.
echo.
echo  Physical density          : %g%%PD% dpi%w%
if defined OVRD echo  Active density override   : %gold%!OVRD! dpi%w%
if defined SCALED echo  Resolution override       : %gold%!OSZ! ^(physical !PSZ!^)%w%
if defined SCALED echo  100%% UI on THAT resolution: %g%!PDB! dpi%w% - the percentages below use this
if not defined SCALED echo  100%% UI                   : %g%!PDB! dpi%w%
echo.
echo  Lower %% = smaller UI, more content fits.
echo.
echo                    %g%[%w%1%g%]%w% 110%% UI -^> %U110% dpi   (bigger)
echo                    %g%[%w%2%g%]%w% 100%% UI -^> %PDB% dpi   (matches the current resolution)
echo                    %g%[%w%3%g%]%w% 90%%  UI -^> %U90% dpi
echo                    %g%[%w%4%g%]%w% 85%%  UI -^> %U85% dpi   (fix for over-large stock UI)
echo                    %g%[%w%5%g%]%w% 80%%  UI -^> %U80% dpi   (smallest)
echo                    %g%[%w%6%g%]%w% Custom dpi
echo                    %g%[%w%7%g%]%w% Reset density to the device default (wm density reset)
echo                    %g%[%w%8%g%]%w% Back

:dispscaler_dpi_ask
:: Re-ask without redrawing so a phantom empty read does not re-run the density probe.
set "du="
set /p du="Choose An Option >> "
call :_noin du || goto dcx_noinput
if not defined du goto dispscaler_dpi_ask
:: [2] applies PDB, the figure it is labelled with, not the physical PD.
if "!du!"=="1" ( set "ND=%U110%" & goto dispscaler_dpi_set )
if "!du!"=="2" ( set "ND=!PDB!" & goto dispscaler_dpi_set )
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
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 goto dispscaler_dpi
if not errorlevel 1 goto dispscaler_dpi
echo.
call :_act_reset
adb shell wm density %ND% <nul
call :_act_rc !errorlevel! "wm density %ND%"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Density is now %ND% dpi. This persists across reboot.
pause >nul
goto dispscaler_dpi

:dispscaler_dpi_custom
cls
title Display Scaler : custom dpi
call :logo
echo  Native density: %g%%PD% dpi%w%   (lower = smaller UI, higher = bigger)
echo.
:: CDPI, not CD: CD is cmd's current-directory value.
set "CDPI="
set /p "CDPI=Density dpi (blank = cancel) >> "
call :_noin CDPI || goto dcx_noinput
if "!CDPI!"=="" goto dispscaler_dpi
call :_tw_safechk CDPI || goto dispscaler_dpi_custom_bad
call :_lib_num CDPI || goto dispscaler_dpi_custom_bad
if %CDPI% LSS 80 goto dispscaler_dpi_custom_bad
if %CDPI% GTR 900 goto dispscaler_dpi_custom_bad
set "ND=%CDPI%"
:: Typo guard against PDB, the baseline for the resolution in use, not the physical PD.
set "_dsodd="
call :_ds_ratio CDPI PDB
if not defined _dsodd goto dispscaler_dpi_set
call :_ds_confirm || goto dispscaler_dpi_custom
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
adb shell wm density reset <nul
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
call :_act_reset
adb shell wm size reset <nul
call :_act_rc !errorlevel! "wm size reset"
adb shell wm density reset <nul
call :_act_rc !errorlevel! "wm density reset"
:: Some OEMs, e.g. Huawei, keep the forced value after reset; delete the backing keys too.
call :_put_chk global display_size_forced DELETE
call :_put_chk secure display_density_forced DELETE
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Back to native (%PW%x%PH% @ %PD% dpi).
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
:: GPU Renderer - debug.hwui.renderer: skiagl, skiavk, or empty for the framework default.
:: setprop applies live but a reboot clears it; persisting needs root.
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
call :_noin gpur || goto dcx_noinput
if "!gpur!"=="1" goto gpurenderer_vk
if "!gpur!"=="2" goto gpurenderer_gl
if "!gpur!"=="3" goto gpurenderer_clear
if "!gpur!"=="4" goto Gaming
goto gpurenderer

:gpurenderer_vk
cls
title GPU Renderer : Skia Vulkan
:: RETIRED: debug.renderengine.backend - read only at SurfaceFlinger start, and a reboot clears it.
:: Clear still empties it for values an older DCX set.
call :_act_reset
adb shell setprop debug.hwui.renderer skiavk <nul
call :_prop_verify debug.hwui.renderer skiavk
call :_act_summary
echo.
echo To verify after relaunching an app:
echo   adb shell dumpsys gfxinfo ^<package^> ^| findstr Pipeline
echo Expected: "Skia (Vulkan)"
echo.
echo %y%Do not reboot to apply this.%w% These are debug.* properties: a reboot CLEARS
echo them and puts the renderer back to the default. Restart the APPS you want
echo to test - each one picks up the renderer when its process starts. The system UI's
echo own compositor ^(SurfaceFlinger^) is not changed by this.
pause > nul
goto gpurenderer

:gpurenderer_gl
cls
title GPU Renderer : Skia GL
call :_act_reset
adb shell setprop debug.hwui.renderer skiagl <nul
call :_prop_verify debug.hwui.renderer skiagl
call :_act_summary
pause > nul
goto gpurenderer

:gpurenderer_clear
cls
title GPU Renderer : Clear
:: An empty value makes Android fall back to the framework default.
:: '' not a double-quote pair: those quotes never reach the device, and setprop just prints usage.
call :_act_reset
adb shell setprop debug.hwui.renderer '' <nul
adb shell setprop debug.renderengine.backend '' <nul
call :_prop_verify debug.hwui.renderer EMPTY
call :_prop_verify debug.renderengine.backend EMPTY
call :_act_summary
if "%DCX_VFAIL%"=="0" echo Framework default in effect after reboot.
pause > nul
goto gpurenderer
:: ===================================================================
:: Force ANGLE - global angle_gl_driver_all_angle 1 or 0; persists across reboots.
:: Needs the ANGLE APK; on non-root only debuggable apps load it; some games break.
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
call :_noin ang || goto dcx_noinput
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
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n > nul
if errorlevel 2 goto angleall
if not errorlevel 1 goto angleall
adb shell settings put global angle_gl_driver_all_angle 1 <nul
echo.
call :_act_reset
call :_settings_verify global angle_gl_driver_all_angle 1
call :_act_summary
echo If apps start crashing, return here and Disable/Delete.
pause > nul
goto angleall

:angleall_off
cls
title ANGLE for All Apps : OFF
adb shell settings put global angle_gl_driver_all_angle 0 <nul
call :_act_reset
call :_settings_verify global angle_gl_driver_all_angle 0
call :_act_summary
pause > nul
goto angleall

:angleall_del
cls
title ANGLE for All Apps : Delete (default)
adb shell settings delete global angle_gl_driver_all_angle <nul
call :_act_reset
call :_settings_verify global angle_gl_driver_all_angle DELETE
call :_act_summary
pause > nul
goto angleall
:: ===================================================================
:: Network Boost - TCP hint, private DNS, network mode; Revert deletes the keys.
:: ===================================================================
:netboost
cls
title Network Boost
call :logo
echo.
echo  TCP init-window hint + private DNS + preferred network mode.
echo  Modest effect - not a magic latency boost. DNS often helps more than TCP.
echo  %y%Note:%w% old Wi-Fi power tweaks were removed (could break Wi-Fi on
echo  Android 15). Revert still clears any leftovers from an old run.
echo.
echo                                     %g%[%w%1%g%]%w% Apply TCP hint (safe)
echo                                     %g%[%w%2%g%]%w% Private DNS (pick a provider, or your own)
echo                                     %g%[%w%3%g%]%w% Preferred network mode
echo                                     %g%[%w%4%g%]%w% Revert (remove all)
echo                                     %g%[%w%5%g%]%w% Back
set "nb=" & set /p nb="Choose An Option >> "
call :_noin nb || goto dcx_noinput
if "!nb!"=="1" goto netboost_apply
if "!nb!"=="2" goto netboost_dns
if "!nb!"=="3" goto netboost_prefmode
if "!nb!"=="4" goto netboost_revert
if "!nb!"=="5" goto Gaming
goto netboost
:: -----------------------------------------------------------------
:: Preferred network mode - preferred_network_mode, RILConstants: 9 LTE/GSM/WCDMA, 11 LTE only,
:: 26 NR/LTE/GSM/WCDMA (5G preferred).
:: mode1 is on purpose: the key for subId 1, usually the first SIM. Restore deletes both.
:: -----------------------------------------------------------------
:netboost_prefmode
cls
title Network Boost : Preferred mode
call :logo
echo  Current preferred_network_mode:
for /f "delims=" %%i in ('adb shell settings get global preferred_network_mode 2^>nul ^<nul') do echo    %%i
echo.
echo                                     %g%[%w%1%g%]%w% LTE preferred (9)  -^> fall back 3G/2G
echo                                     %g%[%w%2%g%]%w% LTE only (11)
echo                                     %g%[%w%3%g%]%w% 5G preferred (26)  -^> fall back LTE/3G
echo                                     %g%[%w%4%g%]%w% Restore default (delete)
echo                                     %g%[%w%5%g%]%w% Back
set "pm=" & set /p pm="Choose An Option >> "
call :_noin pm || goto dcx_noinput
if "!pm!"=="1" (
    call :_tw_undo_add global preferred_network_mode
    call :_tw_undo_add global preferred_network_mode1
    adb shell settings put global preferred_network_mode 9 <nul
    adb shell settings put global preferred_network_mode1 9 <nul
    call :_act_reset
    call :_settings_verify global preferred_network_mode 9
    call :_act_summary
    pause > nul
    goto netboost_prefmode
)
if "!pm!"=="2" (
    call :_tw_undo_add global preferred_network_mode
    call :_tw_undo_add global preferred_network_mode1
    adb shell settings put global preferred_network_mode 11 <nul
    adb shell settings put global preferred_network_mode1 11 <nul
    call :_act_reset
    call :_settings_verify global preferred_network_mode 11
    call :_act_summary
    echo WARNING: voice calls only work if VoLTE is active.
    pause > nul
    goto netboost_prefmode
)
if "!pm!"=="3" (
    call :_tw_undo_add global preferred_network_mode
    call :_tw_undo_add global preferred_network_mode1
    adb shell settings put global preferred_network_mode 26 <nul
    adb shell settings put global preferred_network_mode1 26 <nul
    call :_act_reset
    call :_settings_verify global preferred_network_mode 26
    call :_act_summary
    pause > nul
    goto netboost_prefmode
)
if not "!pm!"=="4" goto _skpm4
    call :_tw_undo_add global preferred_network_mode
    call :_tw_undo_add global preferred_network_mode1
    adb shell settings delete global preferred_network_mode <nul
    adb shell settings delete global preferred_network_mode1 <nul
    call :_act_reset
    call :_settings_verify global preferred_network_mode DELETE
    call :_act_summary
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
:: Only the TCP receive window is set; it does not touch the Wi-Fi stack.
:: Do not re-add the old Wi-Fi power keys: they broke Wi-Fi on Android 15. Revert clears them.
adb shell "settings put global tcp_default_init_rwnd 60" <nul > nul 2>&1
call :_act_reset
call :_settings_verify global tcp_default_init_rwnd 60
call :_act_summary
echo.
echo This change is safe and does not alter Wi-Fi behaviour.
echo If you want lower latency, the DNS option (Cloudflare) often helps
echo more than buffer tuning on modern networks.
pause > nul
goto netboost

:ShowPrivateDns
:: Prints the current Private DNS setting; the string null means unset, not off.
set "_pdmode=" & set "_pdspec="
for /f "delims=" %%i in ('adb shell settings get global private_dns_mode 2^>nul ^<nul')      do set "_pdmode=%%i"
for /f "delims=" %%i in ('adb shell settings get global private_dns_specifier 2^>nul ^<nul') do set "_pdspec=%%i"
if not defined _pdmode set "_pdmode=null"
if /i "!_pdmode!"=="null" (
    echo   Currently: not set - the device is using its default
) else if /i "!_pdmode!"=="hostname" (
    if /i "!_pdspec!"=="null" set "_pdspec=none stored"
    echo   Currently: hostname mode -^> !_pdspec!
) else (
    echo   Currently: !_pdmode!
)
goto :eof

:_host_ok
:: Validates !_HCHK! as a DNS-over-TLS hostname; errorlevel 1 if it is not one.
:: Free user text bound for adb: charset check first, then only delayed expansion.
:: Pipe-free on purpose: a pipe re-parses the text and would run what follows a metacharacter.
if not defined _HCHK exit /b 1
:: A quote is refused, not stripped: the caller goes on to use its own copy of the name.
set "_hq=!_HCHK:"=!"
if not "!_hq!"=="!_HCHK!" exit /b 1
set "_h_bad="
:: eol=a: with the default eol, a token starting with ; is skipped and name;x would pass.
:: A leading a is stripped as a delimiter before the eol test sees it.
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-" %%c in ("!_HCHK!") do set "_h_bad=1"
if defined _h_bad exit /b 1
:: a DoT server is a domain name - require at least one dot
if "!_HCHK!"=="!_HCHK:.=!" exit /b 1
:: must start with a letter or digit, not a dot or a hyphen
set "_h_bad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" %%c in ("!_HCHK:~0,1!") do set "_h_bad=1"
if defined _h_bad exit /b 1
exit /b 0

:netboost_dns
cls
title Network Boost : Private DNS
call :logo
echo.
echo   Private DNS (DNS-over-TLS). Encrypts lookups and applies system-wide, on
echo   Wi-Fi and mobile data alike. It is a device setting, not a per-app one.
echo.
call :ShowPrivateDns
echo.
echo                                     %g%[%w%1%g%]%w% Cloudflare   one.one.one.one
echo                                     %g%[%w%2%g%]%w% Google       dns.google
echo                                     %g%[%w%3%g%]%w% AdGuard      dns.adguard.com   (blocks ads/trackers)
echo                                     %g%[%w%4%g%]%w% Quad9        dns.quad9.net     (blocks known-malicious)
echo                                     %g%[%w%5%g%]%w% Custom hostname
echo                                     %g%[%w%6%g%]%w% Automatic (device default)
echo                                     %g%[%w%0%g%]%w% Back
echo.
echo   %y%If your network blocks external DNS, lookups can fail entirely.%w%
echo   Option 6 puts it straight back - you do not need Revert, which also
echo   removes the TCP and network-mode changes.
echo.
set "PDLIST=" & set /p PDLIST="Choose >> "
call :_noin PDLIST || goto dcx_noinput
if "!PDLIST!"=="1" ( set "_pdhost=one.one.one.one"  & goto _pdns_apply )
if "!PDLIST!"=="2" ( set "_pdhost=dns.google"       & goto _pdns_apply )
if "!PDLIST!"=="3" ( set "_pdhost=dns.adguard.com"  & goto _pdns_apply )
if "!PDLIST!"=="4" ( set "_pdhost=dns.quad9.net"    & goto _pdns_apply )
if "!PDLIST!"=="5" goto _pdns_custom
if "!PDLIST!"=="6" goto _pdns_auto
if "!PDLIST!"=="0" goto netboost
goto netboost_dns

:_pdns_custom
echo.
echo   Enter the DoT hostname your provider gave you - for example dns.nextdns.io
echo   or a personal resolver. Letters, digits, dots and hyphens only.
echo.
set "_pdhost=" & set /p _pdhost="Hostname (blank = cancel) >> "
call :_noin _pdhost || goto dcx_noinput
if not defined _pdhost goto netboost_dns
set "_HCHK=!_pdhost!"
call :_host_ok || (
    echo.
    echo  [%r%x%w%] That is not a hostname. Letters, digits, dots and hyphens, and it
    echo      needs at least one dot - dns.google, not just "google".
    pause > nul
    goto netboost_dns
)

:_pdns_apply
echo.
echo Setting Private DNS to !_pdhost! . . .
:: The specifier may be the user's own server, so both keys go to the undo file first.
call :_tw_undo_add global private_dns_mode
call :_tw_undo_add global private_dns_specifier
adb shell settings put global private_dns_mode hostname <nul
adb shell settings put global private_dns_specifier !_pdhost! <nul
call :_act_reset
call :_settings_verify global private_dns_mode hostname
call :_settings_verify global private_dns_specifier !_pdhost!
call :_act_summary
echo.
call :ShowPrivateDns
echo.
pause > nul
goto netboost_dns

:_pdns_auto
:: The DNS half of Revert on its own; TCP, network mode and Wi-Fi keys are left alone.
echo.
echo Restoring automatic DNS . . .
:: The specifier may be the user's own server, so both keys go to the undo file first.
call :_tw_undo_add global private_dns_mode
call :_tw_undo_add global private_dns_specifier
adb shell settings put global private_dns_mode opportunistic <nul
adb shell settings delete global private_dns_specifier <nul
call :_act_reset
call :_settings_verify global private_dns_mode opportunistic
call :_act_summary
echo.
call :ShowPrivateDns
echo.
pause > nul
goto netboost_dns

:netboost_revert
cls
title Network Boost : Revert
:: Some keys here may be the user's own settings; capture all of them for undo before deleting.
call :_tw_undo_add global tcp_default_init_rwnd
call :_tw_undo_add global tether_offload_disabled
call :_tw_undo_add global mobile_data_always_on
call :_tw_undo_add global wifi_idle_ms
call :_tw_undo_add global wifi_suspend_optimizations_enabled
call :_tw_undo_add global wifi_sleep_policy
call :_tw_undo_add global private_dns_mode
call :_tw_undo_add global private_dns_specifier
call :_tw_undo_add global preferred_network_mode
call :_tw_undo_add global preferred_network_mode1
adb shell settings delete global tcp_default_init_rwnd <nul > nul 2>&1
adb shell settings delete global tether_offload_disabled <nul > nul 2>&1
adb shell settings delete global mobile_data_always_on <nul > nul 2>&1
adb shell settings delete global wifi_idle_ms <nul > nul 2>&1
adb shell settings delete global wifi_suspend_optimizations_enabled <nul > nul 2>&1
adb shell settings delete global wifi_sleep_policy <nul > nul 2>&1
adb shell settings put global private_dns_mode opportunistic <nul > nul 2>&1
adb shell settings delete global private_dns_specifier <nul > nul 2>&1
adb shell settings delete global preferred_network_mode <nul > nul 2>&1
adb shell settings delete global preferred_network_mode1 <nul > nul 2>&1
call :_act_reset
call :_settings_verify global tcp_default_init_rwnd DELETE
call :_settings_verify global private_dns_mode opportunistic
call :_act_summary
pause > nul
goto netboost
:: gms
:gms
@echo off
cls
title Toggle GMS
call :logo
echo.
echo  Full Off disables Play Services itself and breaks most Google-dependent apps.
echo  Safe subset only disables ads/telemetry-adjacent packages and keeps GMS running.
echo.
echo [%r%1%w%] Disable GMS entirely ^(dangerous^)
echo [%r%2%w%] Enable GMS ^(undo full Off^)
echo [%g%3%w%] Safe subset Off - ads/telemetry packages only
echo [%g%4%w%] Safe subset On  - re-enable those packages
echo [%r%5%w%] Back
set "toggle=" & set /p toggle="Choose An Option >> "
call :_noin toggle || goto dcx_noinput
if "!toggle!"=="1" goto offgms
if "!toggle!"=="2" goto ongms
if "!toggle!"=="3" goto gms_safe_off
if "!toggle!"=="4" goto gms_safe_on
if "!toggle!"=="5" goto Gaming
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
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n > nul
if errorlevel 2 goto Gaming
if not errorlevel 1 goto Gaming
cls
title GMS : Off
adb shell am force-stop com.google.android.gms <nul
adb shell pm disable-user --user 0 com.google.android.gms <nul
:: Do not touch zen_mode: it is the user's Do Not Disturb state.
adb shell cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND ignore <nul
adb shell cmd appops set com.google.android.gms RUN_IN_BACKGROUND ignore <nul
adb shell cmd appops set com.google.android.gms WAKE_LOCK ignore <nul
adb shell cmd appops set com.google.android.gms START_FOREGROUND ignore <nul
adb shell cmd appops set com.google.android.gms INSTANT_APP_START_FOREGROUND ignore <nul
adb shell am set-inactive --user 0 com.google.android.gms true <nul
adb shell am set-standby-bucket --user 0 com.google.android.gms never <nul
echo.
call :_pkg_installed com.google.android.gms -d
if errorlevel 2 (
    echo [%y%WARN%w%] The phone did not answer, so the GMS state could not be checked.
) else if errorlevel 1 (
    echo [%y%WARN%w%] GMS not listed as disabled - OEM may have blocked the disable.
) else (
    echo [%g%+%w%] com.google.android.gms is disabled-user.
)
echo Press Any Button To Go Back
pause > nul
goto Gaming

:ongms
@echo off
cls
adb shell pm enable com.google.android.gms <nul
adb shell cmd appops set com.google.android.gms RUN_ANY_IN_BACKGROUND allow <nul
adb shell cmd appops set com.google.android.gms RUN_IN_BACKGROUND allow <nul
adb shell cmd appops set com.google.android.gms WAKE_LOCK allow <nul
adb shell cmd appops set com.google.android.gms START_FOREGROUND allow <nul
adb shell cmd appops set com.google.android.gms INSTANT_APP_START_FOREGROUND allow <nul
adb shell am set-inactive --user 0 com.google.android.gms false <nul
adb shell am set-standby-bucket --user 0 com.google.android.gms active <nul
title GMS : On
echo.
:: A positive match: an empty list from a phone that stopped answering must not read as enabled.
call :_pkg_installed com.google.android.gms -e
if errorlevel 2 (
    echo [%y%WARN%w%] The phone did not answer, so the GMS state could not be checked.
) else if errorlevel 1 (
    echo [%y%WARN%w%] GMS is not listed as enabled - the enable may not have landed.
) else (
    echo [%g%+%w%] com.google.android.gms is enabled.
)
echo Press Any Button To Go Back
pause > nul
goto Gaming
:: ===================================================================
:: GMS safe subset - ads/telemetry packages only, if installed; gms itself stays enabled.
:: ===================================================================
:gms_safe_off
cls
title GMS safe subset : Off
call :logo
echo.
echo  Will disable-user these packages if installed ^(Play Services stays up^):
echo    adservices.api, as.oss, mainline.telemetry, mainline.adservices,
echo    federatedcompute, partnersetup, feedback, apps.turbo
echo.
echo  [%g%Y%w%] Disable them now    [%g%N%w%] Cancel
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 goto gms
if not errorlevel 1 goto gms
call :_act_reset
call :_gms_safe_one disable-user com.google.android.adservices.api
call :_gms_safe_one disable-user com.google.android.as.oss
call :_gms_safe_one disable-user com.google.mainline.telemetry
call :_gms_safe_one disable-user com.google.mainline.adservices
call :_gms_safe_one disable-user com.google.android.federatedcompute
call :_gms_safe_one disable-user com.google.android.partnersetup
call :_gms_safe_one disable-user com.google.android.feedback
call :_gms_safe_one disable-user com.google.android.apps.turbo
call :_act_summary
echo.
echo  Play Services ^(com.google.android.gms^) was not touched.
pause >nul
goto gms

:gms_safe_on
cls
title GMS safe subset : On
call :logo
echo.
echo  Re-enabling the safe-subset packages if present...
echo.
call :_act_reset
call :_gms_safe_one enable com.google.android.adservices.api
call :_gms_safe_one enable com.google.android.as.oss
call :_gms_safe_one enable com.google.mainline.telemetry
call :_gms_safe_one enable com.google.mainline.adservices
call :_gms_safe_one enable com.google.android.federatedcompute
call :_gms_safe_one enable com.google.android.partnersetup
call :_gms_safe_one enable com.google.android.feedback
call :_gms_safe_one enable com.google.android.apps.turbo
call :_act_summary
pause >nul
goto gms

:_gms_safe_one
:: %1 = disable-user ^| enable    %2 = package
:: A phone that did not answer the list is a failure, not "not installed".
call :_pkg_installed %~2
if errorlevel 2 goto _gms_safe_noans
if errorlevel 1 (
    echo  skip  %~2 ^(not installed^)
    exit /b 0
)
if /i "%~1"=="enable" (
    adb shell pm enable --user 0 %~2 <nul >nul 2>&1
) else (
    adb shell pm disable-user --user 0 %~2 <nul >nul 2>&1
)
if errorlevel 1 (
    echo  [%r%FAIL%w%] %~1 %~2
    set /a DCX_VFAIL+=1
    exit /b 1
)
echo  [%g%OK%w%] %~1 %~2
set /a DCX_VOK+=1
exit /b 0

:_pkg_installed
:: %1 package, %2 optional pm list filter (-d, -e). errorlevel 0 listed, 1 not listed, 2 the phone
:: did not answer. The list ends with a marker: a pipe hides adb's failure, and an empty list is
:: not "not installed". find /v turns LF-only output into CRLF lines, which findstr /x needs.
adb shell "pm list packages %~2 && echo _DCXEND" <nul 2>nul | find /v "" >"!DCX_TMP!\pkchk.txt"
findstr /c:"_DCXEND" "!DCX_TMP!\pkchk.txt" >nul 2>&1 || exit /b 2
findstr /x /c:"package:%~1" "!DCX_TMP!\pkchk.txt" >nul 2>&1 || exit /b 1
exit /b 0

:_gms_safe_noans
echo  [%r%FAIL%w%] %~1 %~2 - the phone did not answer the package list
set /a DCX_VFAIL+=1
exit /b 1
:: thermal
:thermal
@echo off
cls
title Thermal override (temporary)
if !SDK! GEQ 1 if !SDK! LSS 29 goto thermal_old
echo.
echo.
echo  Temporary thermalservice override-status ^(usually clears on reboot^).
echo  Not a permanent cooling profile - and not cooling at all: an override makes
echo  the framework REPORT that status and stop reporting the real one, so even
echo  "0 = NONE" is a lock rather than "throttling off". Option 7 clears it.
echo.
echo [%r%1%w%] Process To Setting Thermal
echo [%r%2%w%] Go Back
set "kb=" & set /p kb="Choose An Option >> "
call :_noin kb || goto dcx_noinput
if "!kb!"=="1" goto settingthermal
if "!kb!"=="2" goto Gaming
:: guard against invalid input
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
echo  7 = Clear the override - the device reports its own thermal status again
echo.
set "kb=" & set /p kb=">> "
call :_noin kb || goto dcx_noinput
set "valid=0"
for %%v in (0 1 2 3 4 5 6 7) do if "!kb!"=="%%v" set "valid=1"
if "%valid%"=="0" (
    echo [%r%^^!%w%] Invalid value. Must be a number between 0 and 6.
    timeout /t 2 /nobreak > nul
    goto thermal
)
cls
if "!kb!"=="7" goto thermal_clear
call :_act_reset
adb shell cmd thermalservice override-status !kb! <nul
call :_act_rc !errorlevel! "thermal status override = !kb!"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Status is now pinned at !kb! until you clear it ^(option 7^) or reboot.
echo Press Any Button To Go Back.
pause > nul
goto Gaming

:thermal_old
echo.
echo  [%r%^^!%w%] The thermal override needs Android 10 or newer ^(API 29+^); the phone reports API !SDK!.
echo Press Any Button To Go Back
pause >nul
goto Gaming

:thermal_clear
call :_act_reset
adb shell cmd thermalservice reset <nul
call :_act_rc !errorlevel! "thermal status override cleared"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  The device reports its own thermal status again.
echo Press Any Button To Go Back.
pause > nul
goto Gaming
:: ===================================================================
:: Game performance monitor: fps and frame pacing from SurfaceFlinger TimeStats, a thermal row
:: every 5 s. The only phone state it changes is the TimeStats collector, which it leaves as found.
:: ===================================================================
:perfmon
cls
title Game performance monitor
call :logo
echo                          %m%Game performance monitor%w%
echo.
if "!SDK!"=="0" echo  [%y%WARN%w%] Android version unknown - this needs Android 10 or newer.
if !SDK! GEQ 1 if !SDK! LSS 29 goto perfmon_old
set "_pmd=!DCX_TMP!\perf"
if not exist "!_pmd!\" md "!_pmd!" >nul 2>&1
if not exist "!_pmd!\" goto perfmon_notmp
set "_pmSN0=NONE" & set "_pmSN1=LIGHT" & set "_pmSN2=MODERATE" & set "_pmSN3=SEVERE"
set "_pmSN4=CRITICAL" & set "_pmSN5=EMERGENCY" & set "_pmSN6=SHUTDOWN"
set "_pmhrok="
call :_pm_stale
call :_pm_read
echo  A game's real frame rate and frame pacing, from SurfaceFlinger's own frame
echo  statistics - also for games drawn on a SurfaceView, where gfxinfo shows nothing.
echo  While it runs, a row about every 5 s shows thermal status, temperatures and cooling.
echo.
if not defined _pmovk echo  [%r%^^!%w%] The phone did not answer the thermal service query.
if defined _pmst echo  Thermal status now: !_pmSN%_pmst%!
if defined _pmov echo  [%r%^^!%w%] %r%The thermal status is pinned%w% ^(IsStatusOverride: true^): the phone reports
if defined _pmov echo      the pinned value, not its real throttling. Gaming 2 and Performance props On pin it.
echo.
echo    %g%[%w%1%g%]%w% Start a run ^(have the game open on the phone^)
echo    %g%[%w%2%g%]%w% Clear the thermal status override
echo    %g%[%w%3%g%]%w% Back

:perfmon_ask
set "pmx=" & set /p pmx="Choose An Option >> "
call :_noin pmx || goto dcx_noinput
if not defined pmx goto perfmon_ask
if "!pmx!"=="1" goto perfmon_pick
if "!pmx!"=="2" goto perfmon_unpin
if "!pmx!"=="3" goto perfmon_back
goto perfmon_ask

:perfmon_back
if exist "!_pmd!\" rd /s /q "!_pmd!" >nul 2>&1
goto Gaming

:perfmon_old
echo  [%r%^^!%w%] This needs Android 10 or newer ^(API 29+^); the phone reports API !SDK!.
echo Press Any Button To Go Back
pause >nul
goto Gaming

:perfmon_notmp
echo  [%r%^^!%w%] Could not create the scratch folder !_pmd!
echo Press Any Button To Go Back
pause >nul
goto Gaming

:perfmon_unpin
echo.
call :_act_reset
adb shell cmd thermalservice reset <nul >nul 2>&1
call :_act_rc !errorlevel! "cmd thermalservice reset"
call :_pm_read
:: Only the IsStatusOverride line proves the reset; a battery answer alone also sets _pmok.
if not defined _pmovk goto perfmon_unpin_gone
if defined _pmov goto perfmon_unpin_still
echo [%g%+%w%] IsStatusOverride: false - the phone reports its own thermal status again.
set /a DCX_VOK+=1
goto perfmon_unpin_end

:perfmon_unpin_still
echo [%r%^^!%w%] The phone still reports IsStatusOverride: true.
set /a DCX_VFAIL+=1
goto perfmon_unpin_end

:perfmon_unpin_gone
echo [%r%^^!%w%] The thermal service did not answer, so the result could not be read back.
set /a DCX_VFAIL+=1

:perfmon_unpin_end
call :_act_summary
echo Press Any Button To Go Back
pause >nul
goto perfmon

:perfmon_pick
echo.
call :_pm_fg
echo  Keep the phone's screen on with the game open: DCX checks the frame statistics next.
if defined _pmfg echo  Foreground app: %g%!_pmfg!%w% - Enter measures it, or type a package ^(0 = back^).
if not defined _pmfg echo  No foreground app found. Type the game's package name ^(Enter = back^).
echo  Part of a name works too, such as pubg: DCX lists the apps that match.

:perfmon_pick_ask
set "pmp=" & set /p pmp="Package >> "
call :_noin pmp || goto dcx_noinput
if "!pmp!"=="0" goto perfmon
if not defined pmp if defined _pmfg set "pmp=!_pmfg!"
if not defined pmp goto perfmon
call :_pkg_pick pmp inst || goto perfmon_pick_ask
set "_PKGCHK=!pmp!"
call :_pkg_ok || goto perfmon_pick_bad
set "_pmpkg=!_PKGCHK!"
call :_pm_uid
if not defined _pminst goto perfmon_pick_none
call :_pm_serial
echo  Checking SurfaceFlinger's frame statistics...
call :_pm_tsstate
goto perfmon_confirm

:perfmon_pick_bad
echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
goto perfmon_pick_ask

:perfmon_pick_none
echo  [%r%x%w%] !_pmpkg! is not installed, or the phone did not answer.
goto perfmon_pick_ask

:perfmon_confirm
cls
call :logo
echo  Game : %g%!_pmpkg!%w%
echo.
if defined _pmtsw goto perfmon_confirm_on
if defined _pmtsq goto perfmon_confirm_q
echo  SurfaceFlinger's frame statistics are off on this phone. DCX turns them on for
echo  this run and off again when you stop. If DCX is closed mid-run, the next visit
echo  to this screen turns them off.
goto perfmon_confirm_ask

:perfmon_confirm_q
echo  SurfaceFlinger's frame statistics hold data but did not move during the check.
echo  With the phone's screen on, that means they are off: DCX turns them on for this
echo  run and off again when you stop. %y%If the screen was off%w%, press N, turn it on
echo  and start again - DCX must not turn off statistics the phone itself is collecting.
goto perfmon_confirm_ask

:perfmon_confirm_on
echo  SurfaceFlinger's frame statistics are already running ^(Android collects them for
echo  its usage statistics^). Starting %y%resets%w% them: the phone loses the frame counts it
echo  has not reported yet, nothing else. DCX leaves them running afterwards.

:perfmon_confirm_ask
echo.
if "!SDK!"=="29" if not "!_pmpkg:~0,3!"=="co." if not "!_pmpkg:~0,4!"=="com." echo  [%y%WARN%w%] Android 10 records only packages starting with com. or co. - expect no frames.
echo  Have the game in play on the phone. One to three minutes of normal play gives
echo  steady numbers; menus and loading screens count as slow frames.
echo.
echo    [Y] Start    [N] Cancel
:: Ctrl+C makes choice return 0 - treated as cancel.
choice /c:YN /n >nul
if errorlevel 2 goto perfmon
if not errorlevel 1 goto perfmon
call :_act_reset
if defined _pmtsw goto perfmon_go
:: No marker, no run: the marker lets the next visit turn the statistics off after a cut-off run.
adb shell setprop debug.dcx.perfmon 1 <nul >nul 2>&1
call :_prop_verify debug.dcx.perfmon 1 || goto perfmon_nomark

:perfmon_go
adb shell dumpsys SurfaceFlinger --timestats -clear -enable <nul >nul 2>&1
call :_act_rc !errorlevel! "SurfaceFlinger frame statistics reset and running" || goto perfmon_nots
set "_pmss0="
adb shell dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 <nul >"!_pmd!\ts0.txt" 2>nul
call :_pm_key ts0.txt statsStart _pmss0
if not defined _pmss0 goto perfmon_nots_read
:: A reset sets statsStart to now, so an unchanged one means the old counts are still there.
if defined _pmssb if "!_pmss0!"=="!_pmssb!" goto perfmon_nots_read
call :_pm_now
set "_pmstart=!_pmnow!"
set "_pmMaxSt=0" & set "_pmThrAt=" & set "_pmOvSeen=" & set "_pmStOk=" & set "_pmmiss=0" & set "_pmhaln="
set "_pmMx0=" & set "_pmMx1=" & set "_pmMx3=" & set "_pmMxb="
set "_pmhrok="
if !SDK! GEQ 35 set "_pmhrok=1"
echo.
echo  %m%Monitoring%w% !_pmpkg! - play now.   %g%Q%w% stop and report   %g%R%w% clear a thermal override
echo  Hottest sensor of each kind in C. cool = CPU level / GPU level / devices throttling.
echo  * = the status is pinned by an override, not the phone's real one.
echo.
echo   time   status     CPU    GPU    skin   batt   cool c/g/on         headroom
set "_pmlost=" & set "_pmhold="

:perfmon_tick
call :_pm_read
call :_pm_row
if !_pmmiss! GEQ 3 goto perfmon_lost
choice /c:QRN /n /t 5 /d N >nul
if errorlevel 3 goto perfmon_tick
if errorlevel 2 goto perfmon_tick_unpin
goto perfmon_stop

:perfmon_tick_unpin
adb shell cmd thermalservice reset <nul >nul 2>&1
call :_act_rc !errorlevel! "thermal status override cleared"
goto perfmon_tick

:perfmon_lost
echo.
echo  [%r%^^!%w%] The phone stopped answering - stopping the run.
set "_pmlost=1" & set "_pmhold=1"

:perfmon_stop
call :_pm_el
set "_pmdurt=!_pmelt!"
echo.
echo  Stopping - reading the frame statistics...
adb shell dumpsys SurfaceFlinger --timestats -dump <nul >"!_pmd!\ts.txt" 2>nul
call :_act_rc !errorlevel! "frame statistics read" || set "_pmhold=1"
if not defined _pmtsw call :_pm_off || set "_pmhold=1"
:: The report starts with cls: hold so a failure printed here is read first.
if defined _pmhold echo.
if defined _pmhold echo  Press any key for the report . . .
if defined _pmhold pause >nul
echo  Working out the numbers...
call :_pm_ts_parse
call :_pm_ts_best
goto perfmon_report

:perfmon_nomark
echo  The run did not start: without the marker a cut-off run could leave the statistics on.
goto perfmon_nots_end

:perfmon_nots_read
echo [%r%^^!%w%] SurfaceFlinger does not report statistics since the reset - this build may not keep them.
set /a DCX_VFAIL+=1

:perfmon_nots
if not defined _pmtsw call :_pm_off

:perfmon_nots_end
call :_act_summary
echo Press Any Button To Go Back
pause >nul
goto perfmon

:perfmon_report
cls
call :logo
echo  %m%Run report%w%   !_pmpkg!   ^(!_pmdurt! monitored^)
echo.
if !_rN! EQU 0 goto perfmon_noframes
if !_rS! EQU 0 goto perfmon_noframes
set /a "_pmfi=_rN*1000/_rS, _pmff=(_rN*1000%%_rS)*10/_rS"
set /a "_pmp18=_r18*1000/_rN, _pmp35=_r35*1000/_rN"
set /a "_pmp18i=_pmp18/10, _pmp18f=_pmp18%%10, _pmp35i=_pmp35/10, _pmp35f=_pmp35%%10"
set /a "_pmcov=_rS/1000, _pmcovm=_pmcov/60, _pmcovs=_pmcov%%60"
set "_pmcovs=0!_pmcovs!"
set "_pmrzs=" & set "_pmrztop=-" & set "_pmrzmax=0"
for /f "usebackq tokens=1,2" %%x in ("!_pmd!\hz.txt") do call :_pm_hzadd %%x %%y
if not defined _pmrzs set "_pmrzs= not reported"
set "_pmgms="
for /f "usebackq delims=" %%x in ("!_pmd!\gm.txt") do call :_pm_gmadd %%x
if not defined _pmgms set "_pmgms= not reported"
:: Too few frames, or frames over a small part of the run: an app that hardly drew says nothing.
set "_pmfew="
if !_rTF! LSS 60 set "_pmfew=1"
set /a "_pmcov5=_pmcov*5"
if defined _pmel if !_pmcov5! LSS !_pmel! set "_pmfew=1"
if defined _pmfew echo  [%y%WARN%w%] Only !_rTF! frames in the run: the app hardly drew anything, so these numbers
if defined _pmfew echo         say little. Measure while it moves on screen - a game in play, or scrolling.
if defined _pmfew echo.
if defined _pmfew (echo  Average frame rate        %y%!_pmfi!.!_pmff! fps%w%) else (echo  Average frame rate        %g%!_pmfi!.!_pmff! fps%w%)
echo                            ^(frame times are counted in whole ms: a steady 60 fps shows about 62^)
echo  Frames of 18 ms or more   !_pmp18i!.!_pmp18f! %%   ^(slower than a 60 fps frame^)
echo  Frames of 35 ms or more   !_pmp35i!.!_pmp35f! %%   ^(slower than a 30 fps frame^)
echo  Dropped frames            !_rDF! of !_rTF!
if !_rJT! GTR 0 call :_pm_jank
echo  Refresh rate, 30 Hz steps!_pmrzs!
echo  Game mode                !_pmgms!
echo  Frames cover              !_pmcovm!:!_pmcovs:~-2! of the !_pmdurt! run
set "_pmln="
<"!_pmd!\name.txt" set /p "_pmln="
if defined _pmln echo  Layer measured            !_pmln!
if !_rO! GTR 0 echo  ^(!_rO! smaller layer entr^(ies^) of the same app not counted^)
if defined _pmss0 if defined _pmss if not "!_pmss!"=="!_pmss0!" echo  [%y%WARN%w%] The phone reset its statistics during the run ^(its own upload^);
if defined _pmss0 if defined _pmss if not "!_pmss!"=="!_pmss0!" echo         the numbers cover only the part after that.
echo.
call :_pm_thsum
call :_pm_hist_add
goto perfmon_report_end

:perfmon_noframes
echo  [%y%WARN%w%] SurfaceFlinger recorded no frames for !_pmpkg! ^(!_pmlays! layers listed^).
if defined _pmlost echo    - The phone stopped answering, so the run's statistics could not be read.
echo    - Was the game on screen, and in play, during the run?
if "!SDK!"=="29" echo    - Android 10 records only packages starting with com. or co.
echo    - The phone's own statistics upload can reset the counters mid-run: try again.
echo    - Some builds do not record per-app frame statistics.
set "_pmln="
<"!_pmd!\top.txt" set /p "_pmln="
if defined _pmln echo    Busiest layer in the run:!_pmln!
echo.
call :_pm_thsum

:perfmon_report_end
call :_act_summary
echo.
echo Press Any Button To Go Back
pause >nul
goto perfmon

:_pm_stale
:: debug.dcx.perfmon=1: a run DCX started was cut off with the statistics on. A reboot clears both.
setlocal DisableDelayedExpansion
set "_mk="
for /f "delims=" %%v in ('adb shell getprop debug.dcx.perfmon 2^>nul ^<nul') do for /f "delims=" %%w in ("%%v") do if "%%w"=="1" set "_mk=1"
endlocal & set "_pmmk=%_mk%"
if not defined _pmmk exit /b
echo  [%b%i%w%] An earlier run was cut off and left SurfaceFlinger's frame statistics on.
call :_act_reset
call :_pm_off
call :_act_summary
echo.
exit /b

:_pm_off
:: Turns TimeStats off, reads it back (off = exit 0 and an empty dump) and clears the marker.
adb shell dumpsys SurfaceFlinger --timestats -disable -clear <nul >nul 2>&1
set "_pmrc=!errorlevel!"
if not "!_pmrc!"=="0" goto _pm_off_fail
set "_pmchk="
adb shell dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 <nul >"!_pmd!\ts0.txt" 2>nul
set "_pmrc=!errorlevel!"
if not "!_pmrc!"=="0" goto _pm_off_fail
call :_pm_key ts0.txt statsStart _pmchk
if defined _pmchk goto _pm_off_still
echo [%g%+%w%] SurfaceFlinger's frame statistics are off again, as they were before.
set /a DCX_VOK+=1
adb shell setprop debug.dcx.perfmon '' <nul >nul 2>&1
call :_prop_verify debug.dcx.perfmon EMPTY
exit /b 0

:_pm_off_still
echo [%r%^^!%w%] SurfaceFlinger still reports frame statistics - the next visit here tries again.
set /a DCX_VFAIL+=1
exit /b 1

:_pm_off_fail
echo [%r%^^!%w%] Could not turn SurfaceFlinger's frame statistics off ^(exit !_pmrc!^).
echo        The next visit to this screen tries again.
set /a DCX_VFAIL+=1
exit /b 1

:_pm_fg
:: _pmfg = the foreground package, parsed as Kill all does, with delayed expansion off.
set "_pmfg="
setlocal DisableDelayedExpansion
set "_f="
for /f "tokens=2 delims={" %%a in ('adb shell "dumpsys activity activities | grep ResumedActivity" ^<nul 2^>nul') do if not defined _f for /f "tokens=3" %%b in ("%%a") do for /f "delims=/" %%c in ("%%b") do (set "_f=%%c" & for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%x in ("%%c") do set "_f=")
endlocal & set "_pmfg=%_f%"
if not defined _pmfg exit /b
set "_PKGCHK=!_pmfg!"
call :_pkg_ok || set "_pmfg="
exit /b

:_pm_uid
:: _pminst=1 if pm lists _pmpkg exactly; _pmuid = its uid (TimeStats prints uids on Android 12+).
setlocal DisableDelayedExpansion
set "_u=" & set "_ok="
for /f "tokens=1-4 delims=: " %%a in ('adb shell pm list packages -U %_pmpkg% 2^>nul ^<nul') do if "%%a"=="package" if "%%b"=="%_pmpkg%" (set "_ok=1" & if "%%c"=="uid" for /f "delims=," %%u in ("%%d") do (set "_u=%%u" & for /f "eol=0 delims=0123456789" %%x in ("%%u") do set "_u="))
endlocal & set "_pmuid=%_u%" & set "_pminst=%_ok%"
call :_pm_num _pmuid
exit /b

:_pm_serial
:: _pmser = ro.serialno if it is file-name safe, else "phone". Names the history file.
setlocal DisableDelayedExpansion
set "_s="
for /f "delims=" %%v in ('adb shell getprop ro.serialno 2^>nul ^<nul') do for /f "delims=" %%w in ("%%v") do (set "_s=%%w" & for /f "eol=. delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%x in ("%%w") do set "_s=")
endlocal & set "_pmser=%_s%"
if not defined _pmser set "_pmser=phone"
set "_pmser=!_pmser:~0,40!"
exit /b

:_pm_tsstate
:: _pmtsw=1: TimeStats is collecting (displayOnTime grows, only while the screen is on).
:: _pmtsq=1: it holds data that did not move - off, or on with the screen off. _pmssb = statsStart.
set "_pmtsw=" & set "_pmtsq=" & set "_pmssb=" & set "_pmdot1=" & set "_pmdot2="
adb shell dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 <nul >"!_pmd!\ts0.txt" 2>nul
call :_pm_key ts0.txt statsStart _pmssb
call :_pm_key ts0.txt displayOnTime _pmdot1
if not defined _pmssb if not defined _pmdot1 exit /b
set "_pmtsq=1"
if not defined _pmdot1 exit /b
timeout /t 2 /nobreak >nul
adb shell dumpsys SurfaceFlinger --timestats -dump -maxlayers 0 <nul >"!_pmd!\ts0.txt" 2>nul
call :_pm_key ts0.txt displayOnTime _pmdot2
if not defined _pmdot2 exit /b
if "!_pmdot1!"=="!_pmdot2!" exit /b
set "_pmtsq="
set "_pmtsw=1"
exit /b

:_pm_key
:: Args: file in _pmd, key of a "key = N" line, out variable (digits only, else empty).
setlocal DisableDelayedExpansion
set "_kv="
for /f "usebackq tokens=1,* delims==" %%a in ("%_pmd%\%~1") do if "%%a"=="%~2 " for /f %%v in ("%%b") do (set "_kv=%%v" & for /f "eol=0 delims=0123456789" %%x in ("%%v") do set "_kv=")
endlocal & set "%~3=%_kv%"
exit /b

:_pm_num
:: Arg 1 = a variable name: kept if 1-9 digits (leading zeros dropped), else cleared + errorlevel 1.
setlocal EnableDelayedExpansion
set "_nv=!%~1!"
set "_nb="
if not defined _nv set "_nb=1"
if defined _nv for /f "eol=0 delims=0123456789" %%c in ("!_nv!") do set "_nb=1"
if defined _nb (endlocal & set "%~1=" & exit /b 1)
if not "!_nv:~9!"=="" (endlocal & set "%~1=" & exit /b 1)
set "_nz="
for /f "tokens=* delims=0" %%z in ("!_nv!") do set "_nz=%%z"
if not defined _nz set "_nz=0"
endlocal & set "%~1=%_nz%"
exit /b 0

:_pm_read
:: One sample: thermalservice, battery and (Android 15+) the headroom forecast.
set "_pmok="
adb shell dumpsys thermalservice <nul >"!_pmd!\th.txt" 2>nul
if not errorlevel 1 set "_pmok=1"
adb shell dumpsys battery <nul >"!_pmd!\bt.txt" 2>nul
if not errorlevel 1 set "_pmok=1"
type nul >"!_pmd!\hr.txt"
if defined _pmhrok adb shell cmd thermalservice headroom 10 <nul >"!_pmd!\hr.txt" 2>nul
call :_pm_th_parse
set "_pmtz="
if defined _pmok if not defined _pmT0 if not defined _pmT1 if not defined _pmT3 call :_pm_zones
if defined _pmhrok if defined _pmok if not defined _pmhrseen set "_pmhrok="
exit /b

:_pm_zones
:: No temperatures from the thermal HAL: read the kernel's thermal zones. The phone sorts zones by
:: name into C/G/S (CPU, GPU, skin); millidegrees or whole degrees become tenths, over 150 C is dropped.
adb shell "for z in /sys/class/thermal/thermal_zone*; do t=; c=; v=; read t < $z/type; case $t in *[Cc][Pp][Uu]*|BIG|MID|LITTLE) c=C;; *[Gg][Pp][Uu]*|*[Gg]3[Dd]*) c=G;; *skin*|*shell*|*xo-therm*|*quiet*) c=S;; esac; [ x$c = x ] || { read v < $z/temp; echo $c $v; }; done 2>/dev/null" <nul >"!_pmd!\tz.txt" 2>nul
setlocal DisableDelayedExpansion
set /a "_T0=-1, _T1=-1, _T3=-1"
for /f "usebackq tokens=1,2" %%a in ("%_pmd%\tz.txt") do (
    set "_bad="
    if "%%b"=="" set "_bad=1"
    for /f "eol=0 delims=0123456789" %%x in ("%%b") do set "_bad=1"
    if not defined _bad if "%%a"=="C" set /a "_z=%%b, _g=(999-_z)>>31, _t=((_z/100)&_g)|((_z*10)&~_g), _ok=(_t-1501)>>31, _d=_T0-_t, _T0-=_d&(_d>>31)&_ok" 2>nul
    if not defined _bad if "%%a"=="G" set /a "_z=%%b, _g=(999-_z)>>31, _t=((_z/100)&_g)|((_z*10)&~_g), _ok=(_t-1501)>>31, _d=_T1-_t, _T1-=_d&(_d>>31)&_ok" 2>nul
    if not defined _bad if "%%a"=="S" set /a "_z=%%b, _g=(999-_z)>>31, _t=((_z/100)&_g)|((_z*10)&~_g), _ok=(_t-1501)>>31, _d=_T3-_t, _T3-=_d&(_d>>31)&_ok" 2>nul
)
endlocal & set "_pmT0=%_T0%" & set "_pmT1=%_T1%" & set "_pmT3=%_T3%"
for %%v in (_pmT0 _pmT1 _pmT3) do if "!%%v!"=="-1" set "%%v="
if defined _pmT0 set "_pmtz=1"
if defined _pmT1 set "_pmtz=1"
if defined _pmT3 set "_pmtz=1"
exit /b

:_pm_th_parse
:: Phone text stays in FOR variables, and no call per sensor line: a phone lists ~100 of them.
:: max(a,b) = a-(d&(d>>31)) with d = a-b. Temperatures are kept in tenths of a degree.
setlocal DisableDelayedExpansion
set "_inT=" & set "_inC=" & set "_ov=" & set "_ovk=" & set "_st=" & set "_hal=" & set "_bt=" & set "_hr=" & set "_hrs="
set /a "_T0=-1, _T1=-1, _T3=-1, _C2=-1, _C3=-1, _Cn=0"
for /f "usebackq tokens=1-5 delims={=, " %%a in ("%_pmd%\th.txt") do (
    if "%%a"=="IsStatusOverride:" (set "_ovk=1" & for /f %%t in ("%%b") do if "%%t"=="true" set "_ov=1")
    if "%%a %%b"=="Thermal Status:" for /f %%t in ("%%c") do for %%k in (0 1 2 3 4 5 6) do if "%%t"=="%%k" set "_st=%%k"
    if "%%a %%b"=="HAL Ready:" for /f %%t in ("%%c") do if "%%t"=="true" set "_hal=1"
    if "%%a %%b %%c"=="Current temperatures from" (set "_inT=1" & set "_inC=")
    if "%%a %%b %%c"=="Current cooling devices" (set "_inT=" & set "_inC=1")
    if "%%a %%b"=="Temperature static" (set "_inT=" & set "_inC=")
    if "%%a %%b"=="Temperature headroom" (set "_inT=" & set "_inC=")
    if "%%b %%d"=="mValue mType" (
        set "_bad="
        for /f "eol=0 delims=0123456789." %%x in ("%%c") do set "_bad=1"
        if defined _inT if not defined _bad for %%k in (0 1 3) do if "%%e"=="%%k" for /f "tokens=1-3 delims=." %%p in ("%%c.") do if "%%r"=="" (
            set "_f=0"
            for %%z in (1 2 3 4 5 6 7 8 9) do if "x%%q" GEQ "x%%z" set "_f=%%z"
            set /a "_v=%%p, _ok=(_v-1000)>>31, _v=_v*10+_f, _d=_T%%k-_v, _T%%k-=_d&(_d>>31)&_ok" 2>nul
        )
        if defined _inC if not defined _bad for /f "eol=0 delims=0123456789" %%x in ("%%c") do set "_bad=1"
        if defined _inC if not defined _bad if not "%%c"=="0" set /a _Cn+=1
        if defined _inC if not defined _bad for %%k in (2 3) do if "%%e"=="%%k" set /a "_d=_C%%k-%%c, _C%%k-=_d&(_d>>31)" 2>nul
    )
)
for /f "usebackq tokens=1,2 delims=: " %%a in ("%_pmd%\bt.txt") do if "%%a"=="temperature" for /f %%y in ("%%b") do (set "_bt=%%y" & for /f "eol=0 delims=0123456789" %%x in ("%%y") do set "_bt=")
for /f "usebackq tokens=1-5 delims= " %%a in ("%_pmd%\hr.txt") do if "%%a %%b"=="Headroom in" (set "_hrs=1" & for /f %%y in ("%%e") do (set "_hr=%%y" & for /f "eol=0 delims=0123456789.E-" %%x in ("%%y") do set "_hr="))
endlocal & set "_pmov=%_ov%" & set "_pmovk=%_ovk%" & set "_pmst=%_st%" & set "_pmhal=%_hal%" & set "_pmbat=%_bt%" & set "_pmhr=%_hr%" & set "_pmhrseen=%_hrs%" & set "_pmT0=%_T0%" & set "_pmT1=%_T1%" & set "_pmT3=%_T3%" & set "_pmCc=%_C2%" & set "_pmCg=%_C3%" & set "_pmCn=%_Cn%"
for %%v in (_pmT0 _pmT1 _pmT3 _pmCc _pmCg) do if "!%%v!"=="-1" set "%%v="
call :_pm_num _pmbat
:: Java prints a headroom under 0.001 as 1.0E-4.
if defined _pmhr if not "!_pmhr:E-=!"=="!_pmhr!" set "_pmhr=0.0"
if defined _pmhr if not "!_pmhr:E=!"=="!_pmhr!" set "_pmhr="
if defined _pmhr if not "!_pmhr:-=!"=="!_pmhr!" set "_pmhr="
exit /b

:_pm_now
:: _pmnow = seconds since midnight from %time%, empty if it is not h:m:s.
set "_pmnow="
set "_pmtm=!time: =0!"
for /f "tokens=1-3 delims=:.," %%a in ("!_pmtm!") do set /a "_pmnow=(1%%a-100)*3600+(1%%b-100)*60+(1%%c-100)" 2>nul
exit /b

:_pm_el
:: _pmel = seconds since _pmstart, _pmelt = m:ss.
call :_pm_now
set "_pmel=0" & set "_pmelt=--:--"
if not defined _pmnow exit /b
if not defined _pmstart exit /b
set /a "_pmel=_pmnow-_pmstart"
if !_pmel! LSS 0 set /a "_pmel+=86400"
set /a "_pmem=_pmel/60, _pmes=_pmel%%60"
set "_pmes=0!_pmes!"
set "_pmelt=!_pmem!:!_pmes:~-2!"
exit /b

:_pm_fmt
:: Arg 1 = tenths of a degree or empty, arg 2 = out: "61.2" or "-", padded to 7.
setlocal EnableDelayedExpansion
set "_v=!%~1!"
set "_o=-"
if defined _v set /a "_a=_v/10, _b=_v%%10"
if defined _v set "_o=!_a!.!_b!"
set "_o=!_o!       "
endlocal & set "%~2=%_o:~0,7%"
exit /b

:_pm_max
:: Arg 1 = sample, arg 2 = running maximum.
if not defined %~1 exit /b
if not defined %~2 (set "%~2=!%~1!" & exit /b)
if !%~1! GTR !%~2! set "%~2=!%~1!"
exit /b

:_pm_row
call :_pm_el
set "_pme=!_pmelt!       "
set "_pme=!_pme:~0,7!"
if not defined _pmok goto _pm_row_gone
set "_pmmiss=0"
set "_pmsn=?"
if defined _pmst set "_pmsn=!_pmSN%_pmst%!"
if defined _pmov set "_pmsn=!_pmsn!*"
if defined _pmov set "_pmOvSeen=1"
set "_pmsn=!_pmsn!           "
set "_pmsn=!_pmsn:~0,11!"
set "_pmsc=%g%"
if defined _pmst if !_pmst! GEQ 1 set "_pmsc=%y%"
if defined _pmst if !_pmst! GEQ 3 set "_pmsc=%r%"
if defined _pmst if not defined _pmov set "_pmStOk=1"
if defined _pmst if not defined _pmov if !_pmst! GTR !_pmMaxSt! set "_pmMaxSt=!_pmst!"
if defined _pmst if not defined _pmov if !_pmst! GEQ 1 if not defined _pmThrAt set "_pmThrAt=!_pmelt!"
call :_pm_max _pmT0 _pmMx0
call :_pm_max _pmT1 _pmMx1
call :_pm_max _pmT3 _pmMx3
call :_pm_max _pmbat _pmMxb
call :_pm_fmt _pmT0 _pmc0
call :_pm_fmt _pmT1 _pmc1
call :_pm_fmt _pmT3 _pmc3
call :_pm_fmt _pmbat _pmcb
set "_pmcx=-" & set "_pmgx=-"
if defined _pmCc set "_pmcx=!_pmCc!"
if defined _pmCg set "_pmgx=!_pmCg!"
set "_pmcl=!_pmcx!/!_pmgx!/!_pmCn!"
if not defined _pmCc if not defined _pmCg if "!_pmCn!"=="0" set "_pmcl=-"
set "_pmcl=!_pmcl!                    "
set "_pmcl=!_pmcl:~0,20!"
set "_pmch=-"
if defined _pmhrseen set "_pmch=n/a"
if defined _pmhr call :_pm_hrpct
if not defined _pmhal if not defined _pmhaln if defined _pmtz (set "_pmhaln=1" & echo   [%b%i%w%] The phone's thermal HAL reports nothing: CPU, GPU and skin come from the kernel's thermal zones.)
if not defined _pmhal if not defined _pmhaln (set "_pmhaln=1" & echo   [%b%i%w%] The phone's thermal HAL reports nothing ^(not ready^): only the battery temperature can be shown.)
echo   !_pme!!_pmsc!!_pmsn!%w%!_pmc0!!_pmc1!!_pmc3!!_pmcb!!_pmcl!!_pmch!
exit /b

:_pm_row_gone
set /a _pmmiss+=1
echo   !_pme![%r%^^!%w%] no answer from the phone
exit /b

:_pm_hrpct
:: _pmhr as printed ("0.63"; 1.0 = SEVERE throttling) -> _pmch "63%".
set "_pmhri=" & set "_pmhrf="
for /f "tokens=1,2 delims=." %%p in ("!_pmhr!") do (set "_pmhri=%%p" & set "_pmhrf=%%q")
call :_pm_num _pmhri || exit /b
if !_pmhri! GTR 99 exit /b
set "_pmhrf=!_pmhrf!00"
set /a "_pmhrp=_pmhri*100+1!_pmhrf:~0,2!-100"
set "_pmch=!_pmhrp!%%"
exit /b

:_pm_ts_parse
:: Pass 1, rec.txt: tf p2pN p2pMs n18 n35 dropped janky timeline Hz mode name, one per game entry.
type nul >"!_pmd!\rec.txt"
type nul >"!_pmd!\top.txt"
set "_pmss=" & set "_pmlays=0"
setlocal DisableDelayedExpansion
set "_pmin=" & set "_pmPR=" & set "_pmPU=" & set "_pmhn=" & set "_ss=" & set "_top=" & set "_nl=0"
for /f "usebackq tokens=1,* delims==" %%a in ("%_pmd%\ts.txt") do (
    if defined _pmhn if not "%%a"=="0ms" set "_pmhn="
    if "%%a"=="statsStart " for /f %%v in ("%%b") do (set "_ss=%%v" & for /f "eol=0 delims=0123456789" %%x in ("%%v") do set "_ss=")
    if "%%a"=="displayRefreshRate " if defined _pmin call :_pm_rec
    if "%%a"=="displayRefreshRate " (set "_pmPR=" & for /f %%v in ("%%b") do set "_pmPR=%%v")
    if "%%a"=="uid " (set "_pmPU=" & for /f %%v in ("%%b") do set "_pmPU=%%v")
    if "%%a"=="layerName " if defined _pmin call :_pm_rec
    if "%%a"=="layerName " (set "_pmin=1" & set "_pmnm=" & set "_pmGM=" & set "_pmTF=" & set "_pmDF=" & set "_pmJF=" & set "_pmJT=" & set "_pmhl=" & set /a _nl+=1)
    if "%%a"=="layerName " for /f "delims=" %%v in ("%%b") do set "_pmnm=%%v"
    if "%%a"=="layerName " if not defined _top >"%_pmd%\top.txt" echo(%%b
    if "%%a"=="layerName " set "_top=1"
    if defined _pmin (
        if "%%a"=="gameMode " for /f %%v in ("%%b") do set "_pmGM=%%v"
        if "%%a"=="totalFrames " for /f %%v in ("%%b") do set "_pmTF=%%v"
        if "%%a"=="droppedFrames " for /f %%v in ("%%b") do set "_pmDF=%%v"
        if "%%a"=="totalTimelineFrames " for /f %%v in ("%%b") do set "_pmJT=%%v"
        if "%%a"=="jankyFrames " for /f %%v in ("%%b") do set "_pmJF=%%v"
        for /f "delims=" %%h in ("%%a") do if "%%h"=="present2present histogram is as below:" set "_pmhn=1"
        if "%%a"=="0ms" if defined _pmhn (set "_pmhn=" & for /f "delims=" %%v in ("%%b") do set "_pmhl=%%v")
    )
)
call :_pm_rec
endlocal & set "_pmss=%_ss%" & set "_pmlays=%_nl%"
exit /b

:_pm_rec
:: Closes the open entry. It is the game's if the uid matches (12+), else if " <pkg>/" is in the
:: name with [ read as a space: SurfaceView[pkg/..., SurfaceView - pkg/..., pkg/...
if not defined _pmin exit /b
set "_pmin="
setlocal EnableDelayedExpansion
set "_m=" & set "_nm="
if defined _pmnm set "_nm=!_pmnm:~1!"
if defined _pmuid if defined _pmPU if "!_pmPU!"=="!_pmuid!" set "_m=1"
if defined _pmuid if defined _pmPU goto _pm_rec_m
if not defined _nm goto _pm_rec_m
set "_nm2= !_nm:[= !"
if not "!_nm2: %_pmpkg%/=!"=="!_nm2!" set "_m=1"

:_pm_rec_m
if not defined _m (endlocal & exit /b)
for %%v in (_pmTF _pmDF _pmJF _pmJT _pmPR) do call :_pm_num %%v
for %%v in (_pmTF _pmDF _pmJF _pmJT _pmPR) do if not defined %%v set "%%v=0"
call :_pm_hist
set "_gm=-"
if defined _pmGM set "_gm=!_pmGM!"
if defined _pmGM for /f "eol=A delims=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" %%c in ("!_pmGM!") do set "_gm=-"
>>"!_pmd!\rec.txt" echo(!_pmTF! !_hn! !_hs! !_h18! !_h35! !_pmDF! !_pmJF! !_pmJT! !_pmPR! !_gm! !_nm!
endlocal
exit /b

:_pm_hist
:: _pmhl = present2present buckets after "0ms=". A bucket holds deltas up to its own value, so
:: 18+ is 18 ms or more and 36+ is 35 ms or more. Out: _hn frames, _hs ms, _h18, _h35.
set "_hn=0" & set "_hs=0" & set "_h18=0" & set "_h35=0"
if not defined _pmhl exit /b 1
setlocal EnableDelayedExpansion
set "_x=0ms=!_pmhl!"
set "_bad="
for /f "eol=0 delims=0123456789ms= " %%c in ("!_x!") do set "_bad=1"
if defined _bad (endlocal & exit /b 1)
set "_x=!_x:ms=!"
set "_k=" & set "_i=0" & set "_n=0" & set "_s=0" & set "_a=0" & set "_c=0"
for %%t in (!_x!) do (
    set /a _i+=1
    if defined _k (
        set /a "_n+=%%t, _s+=_k*%%t"
        if !_k! GEQ 18 set /a "_a+=%%t"
        if !_k! GEQ 36 set /a "_c+=%%t"
        set "_k="
    ) else (
        set "_k=%%t"
    )
)
set /a "_odd=_i%%2"
if not "!_odd!"=="0" (endlocal & exit /b 1)
endlocal & set "_hn=%_n%" & set "_hs=%_s%" & set "_h18=%_a%" & set "_h35=%_c%"
exit /b 0

:_pm_ts_best
:: Pass 2: TimeStats sorts entries busiest first; add up every entry of the first record's layer.
type nul >"!_pmd!\hz.txt"
type nul >"!_pmd!\gm.txt"
type nul >"!_pmd!\name.txt"
setlocal DisableDelayedExpansion
for /f "delims==" %%v in ('set _pmHz 2^>nul') do set "%%v="
for /f "delims==" %%v in ('set _pmGm_ 2^>nul') do set "%%v="
set "_pmbest=" & set "_pmB="
set /a "_rTF=0, _rN=0, _rS=0, _r18=0, _r35=0, _rDF=0, _rJF=0, _rJT=0, _rO=0"
for /f "usebackq tokens=1-10,*" %%a in ("%_pmd%\rec.txt") do (
    if not defined _pmbest >"%_pmd%\name.txt" echo(%%k
    if not defined _pmbest set "_pmbest=%%k"
    set "_pmB=%%k"
    set "_same="
    call :_pm_same && set "_same=1"
    if defined _same set /a "_rTF+=%%a, _rN+=%%b, _rS+=%%c, _r18+=%%d, _r35+=%%e, _rDF+=%%f, _rJF+=%%g, _rJT+=%%h, _pmHz%%i+=%%a"
    if defined _same set "_pmGm_%%j=1"
    if not defined _same set /a _rO+=1
)
for /f "tokens=1,2 delims==" %%x in ('set _pmHz 2^>nul') do >>"%_pmd%\hz.txt" echo %%x %%y
for /f "delims==" %%x in ('set _pmGm_ 2^>nul') do >>"%_pmd%\gm.txt" echo %%x
endlocal & set "_rTF=%_rTF%" & set "_rN=%_rN%" & set "_rS=%_rS%" & set "_r18=%_r18%" & set "_r35=%_r35%" & set "_rDF=%_rDF%" & set "_rJF=%_rJF%" & set "_rJT=%_rJT%" & set "_rO=%_rO%"
exit /b

:_pm_same
setlocal EnableDelayedExpansion
if "!_pmB!"=="!_pmbest!" (endlocal & exit /b 0)
endlocal & exit /b 1

:_pm_hzadd
:: Arg 1 = _pmHz<rate>, arg 2 = frames at that rate.
set "_pmh=%~1"
set "_pmh=!_pmh:_pmHz=!"
if "!_pmh!"=="0" exit /b
if !_rTF! EQU 0 exit /b
set /a "_pmhp=%~2*100/_rTF"
if !_pmhp! GTR !_pmrzmax! (set "_pmrzmax=!_pmhp!" & set "_pmrztop=!_pmh!")
if defined _pmrzs set "_pmrzs=!_pmrzs!,"
set "_pmrzs=!_pmrzs! !_pmh! Hz !_pmhp! %%"
exit /b

:_pm_gmadd
set "_pmh=%~1"
set "_pmh=!_pmh:_pmGm_=!"
if "!_pmh!"=="-" exit /b
if defined _pmgms set "_pmgms=!_pmgms!,"
set "_pmgms=!_pmgms! !_pmh!"
exit /b

:_pm_jank
set /a "_pmpj=_rJF*1000/_rJT, _pmpji=_pmpj/10, _pmpjf=_pmpj%%10"
echo  Janky frames              !_pmpji!.!_pmpjf! %%   ^(Android's own verdict, !_rJF! of !_rJT!^)
exit /b

:_pm_thsum
:: Thermal summary of the run, from the rows.
call :_pm_fmt _pmMx0 _pmc0
call :_pm_fmt _pmMx1 _pmc1
call :_pm_fmt _pmMx3 _pmc3
call :_pm_fmt _pmMxb _pmcb
echo  Peak temperatures         CPU !_pmc0! GPU !_pmc1! skin !_pmc3! battery !_pmcb!
set "_pmwst=!_pmSN%_pmMaxSt%!"
if defined _pmThrAt echo  Throttling                %y%!_pmwst!%w% at worst, first reported at !_pmThrAt!
if not defined _pmThrAt if defined _pmStOk echo  Throttling                none reported ^(status NONE throughout^)
if not defined _pmStOk echo  Throttling                not known - the phone reported no unpinned thermal status
if defined _pmOvSeen echo  [%y%WARN%w%] The status was pinned by an override for part of the run;
if defined _pmOvSeen echo         those rows do not show the real status.
exit /b

:_pm_hist_add
:: One line per run in PERFDIR\<serial>_<package>.txt, then the last five.
if not exist "!PERFDIR!\" md "!PERFDIR!" >nul 2>&1
set "_pmhf=!PERFDIR!\!_pmser!_!_pmpkg!.txt"
set "_pmwst=!_pmSN%_pmMaxSt%!"
if not defined _pmStOk set "_pmwst=-"
if defined _pmOvSeen set "_pmwst=!_pmwst!*"
call :_pm_fmt _pmMx0 _pmc0
call :_pm_fmt _pmMx3 _pmc3
set "_pmc0=!_pmc0: =!" & set "_pmc3=!_pmc3: =!"
:: A failed redirection skips the echo and its && but leaves errorlevel alone, so test a flag;
:: the block keeps cmd's own error line off the screen.
set "_pmhw="
(>>"!_pmhf!" echo !date! !time:~0,5!  !_pmfi!.!_pmff! fps  18ms+ !_pmp18i!.!_pmp18f!%%  35ms+ !_pmp35i!.!_pmp35f!%%  !_pmrztop! Hz  !_pmwst!  CPU/skin !_pmc0!/!_pmc3!  !_pmdurt!) 2>nul && set "_pmhw=1"
if not defined _pmhw echo  [%y%WARN%w%] Could not write the run history to !_pmhf!
if not defined _pmhw set /a DCX_VFAIL+=1
if not defined _pmhw exit /b
set "_pmhc=0"
for /f "usebackq delims=" %%a in ("!_pmhf!") do set /a _pmhc+=1
set /a "_pmhk=_pmhc-5"
echo  Last runs of this game on this phone ^(newest last; worst thermal status, peak CPU/skin C^):
if !_pmhk! LEQ 0 goto _pm_hist_all
setlocal DisableDelayedExpansion
for /f "usebackq skip=%_pmhk% delims=" %%a in ("%_pmhf%") do echo    %%a
endlocal
exit /b

:_pm_hist_all
setlocal DisableDelayedExpansion
for /f "usebackq delims=" %%a in ("%_pmhf%") do echo    %%a
endlocal
exit /b
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
call :_noin kb || goto dcx_noinput
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
call :_act_reset
call :_settings_verify global package_verifier_enable 0
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Gaming

:onpck
@echo off
cls
title Package Verifier : On
adb shell settings put global package_verifier_enable 1 <nul
call :_act_reset
call :_settings_verify global package_verifier_enable 1
call :_act_summary
echo Press Any Button To Go Back
pause > nul
goto Gaming
:: Game Mode: one game's FPS cap and render scale. 14+: cmd game set (custom mode, kept across reboots).
:: 13: game_overlay entry + cmd game mode 2 (13's cmd game set is memory-only). 12: cmd game downscale.
:gamemode
cls
title Game Mode (FPS cap / render scale)
call :logo
echo.
if %SDK% LSS 31 goto gm_old
set "_gm_l1=Set FPS cap and render scale for a game"
if %SDK% GEQ 34 echo  API %SDK%: custom Game Mode per game ^(cmd game set^), kept until you reset it.
if "%SDK%"=="33" echo  Android 13: Performance mode per game through device_config game_overlay.
if %SDK% LSS 33 set "_gm_l1=Set render scale for a game"
if %SDK% LSS 33 echo  Android 12: render scale only ^(cmd game downscale^) - the FPS cap needs 13+.
if %SDK% GEQ 33 echo  Only apps that declare themselves games ^(appCategory "game"^) are affected.
echo.
echo    %g%[%w%1%g%]%w% !_gm_l1!
echo    %g%[%w%2%g%]%w% Show a game's Game Mode
echo    %g%[%w%3%g%]%w% Reset a game to normal
echo    %g%[%w%4%g%]%w% Back

:gamemode_ask
set "gm=" & set /p gm="Choose An Option >> "
call :_noin gm || goto dcx_noinput
if not defined gm goto gamemode_ask
if "!gm!"=="1" goto gm_set
if "!gm!"=="2" goto gm_show
if "!gm!"=="3" goto gm_reset
if "!gm!"=="4" goto Gaming
goto gamemode_ask

:gm_old
echo  [%y%WARN%w%] Game Mode needs Android 12 or newer. This phone reports API level %SDK%
echo         ^(0 means it was not read - check the connection^).
echo.
echo Press Any Button To Go Back
pause > nul
goto Gaming

:gm_set
cls
title Game Mode : Set
call :logo
echo.
call :_gm_askpkg || goto gamemode
set "_gm_fps=0"
set "_gm_fpl=not available before Android 13"
if %SDK% LSS 33 goto gm_set_scale
call :_gm_isgame
if errorlevel 2 goto gm_set_noans
if errorlevel 1 goto gm_set_notgame
call :_gm_fpsmenu

:gm_set_fps_ask
set "gmx=" & set /p gmx="Choose An Option >> "
call :_noin gmx || goto dcx_noinput
if not defined gmx goto gm_set_fps_ask
set "_gm_fps="
for /l %%i in (1,1,!_gmn!) do if "!gmx!"=="%%i" set "_gm_fps=!_gmf_%%i!"
if not defined _gm_fps goto gm_set_fps_ask
set "_gm_fpl=!_gm_fps! fps"
if "!_gm_fps!"=="0" set "_gm_fpl=none"

:gm_set_scale
echo.
echo  Render scale - the game draws fewer pixels, the rest of the phone stays native:
echo    %g%[%w%1%g%]%w% 100%% ^(native^)
echo    %g%[%w%2%g%]%w% 90%%
echo    %g%[%w%3%g%]%w% 80%%
echo    %g%[%w%4%g%]%w% 70%%
echo    %g%[%w%5%g%]%w% 60%%  %y%text in the game may look soft%w%
echo    %g%[%w%6%g%]%w% 50%%  %y%text in the game may look soft%w%

:gm_set_scale_ask
set "gmsc=" & set /p gmsc="Choose An Option >> "
call :_noin gmsc || goto dcx_noinput
if not defined gmsc goto gm_set_scale_ask
set "_gm_scl="
if "!gmsc!"=="1" (set "_gm_scl=disable" & set "_gm_pct=100")
if "!gmsc!"=="2" (set "_gm_scl=0.9" & set "_gm_pct=90")
if "!gmsc!"=="3" (set "_gm_scl=0.8" & set "_gm_pct=80")
if "!gmsc!"=="4" (set "_gm_scl=0.7" & set "_gm_pct=70")
if "!gmsc!"=="5" (set "_gm_scl=0.6" & set "_gm_pct=60")
if "!gmsc!"=="6" (set "_gm_scl=0.5" & set "_gm_pct=50")
if not defined _gm_scl goto gm_set_scale_ask
echo.
echo  !_GM_PKG!: render scale !_gm_pct!%%, FPS cap !_gm_fpl!
echo.
call :_act_reset
set "_gm_ok="
if %SDK% GEQ 34 goto gm_set14
if "%SDK%"=="33" goto gm_set13
goto gm_set12

:gm_set_notgame
call :_gm_notgame
echo        Nothing was changed.
goto gm_set_quit

:gm_set_nochange
echo        Nothing was changed.
goto gm_set_quit

:gm_set_noans
echo  [%r%^^!%w%] The phone did not say whether !_GM_PKG! is a game - check the connection.

:gm_set_quit
call :_gm_tmpdel
echo.
echo Press Any Button To Go Back
pause > nul
goto gamemode

:gm_set14
:: No cap = no --fps: 14.0 rejects "disable" and "0", 14 QPR1+ rejects "disable".
set "_gm_fo="
if not "!_gm_fps!"=="0" set "_gm_fo=--fps !_gm_fps! "
adb shell cmd game set --downscale !_gm_scl! !_gm_fo!!_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "cmd game set: render scale !_gm_scl:disable=native!, FPS cap !_gm_fpl!"
if errorlevel 1 (call :_gm_msg) else set "_gm_ok=1"
call :_gm_rb14
goto gm_set_end

:gm_set13
:: ",dcx=1" marks the entry as DCX's (Android ignores unknown keys), so Reset deletes only its own.
set "_gm_dv=mode=2"
if not "!_gm_scl!"=="disable" set "_gm_dv=!_gm_dv!,downscaleFactor=!_gm_scl!"
if not "!_gm_fps!"=="0" set "_gm_dv=!_gm_dv!,fps=!_gm_fps!"
set "_gm_dv=!_gm_dv!,dcx=1"
adb shell device_config put game_overlay !_GM_PKG! !_gm_dv! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_dcfg_verify game_overlay !_GM_PKG! "!_gm_dv!"
if errorlevel 1 goto gm_set_fail
set "_gm_try=0"

:gm_set13_mode
set /a _gm_try+=1
adb shell cmd game mode 2 !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
set "_gm_rc=!errorlevel!"
if "!_gm_rc!"=="0" goto gm_set13_rc
if !_gm_try! GEQ 3 goto gm_set13_rc
:: Android reads the new entry asynchronously.
timeout /t 1 /nobreak > nul
goto gm_set13_mode

:gm_set13_rc
call :_act_rc !_gm_rc! "Performance mode selected for !_GM_PKG!"
if errorlevel 1 goto gm_set13_modefail
set "_gm_ok=1"
call :_gm_rbcfg
goto gm_set_end

:gm_set13_modefail
call :_gm_msg
echo [%b%i%w%] The game_overlay entry was written; Reset removes it.
goto gm_set_end

:gm_set12
call :_gm_ask12 || goto gm_set_nochange
adb shell cmd game downscale !_gm_scl! !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "cmd game downscale !_gm_scl! - Android 12 closes the app itself"
if errorlevel 1 goto gm_set_fail
call :_gm_rb12
goto gm_set_end

:gm_set_fail
call :_gm_msg

:gm_set_end
if defined _gm_ok if %SDK% GEQ 33 call :_gm_restart
call :_act_summary
call :_gm_tmpdel
echo Press Any Button To Go Back
pause > nul
goto gamemode

:gm_show
cls
title Game Mode : Show
call :logo
echo.
call :_gm_askpkg || goto gamemode
echo.
if %SDK% GEQ 34 goto gm_show14
if "%SDK%"=="33" goto gm_show13
adb shell dumpsys platform_compat <nul >"!DCX_TMP!\gm_cfg.txt" 2>&1
findstr /l /c:"ChangeId(" "!DCX_TMP!\gm_cfg.txt" >nul 2>&1 || goto gm_show12_none
set "_gm_now=100"
call :_gm_cc12 168419799 true || goto gm_show12_out
set "_gm_now="
for %%s in (90 80 70 60 50) do (
    call :_gm_cid %%s
    call :_gm_cc12 !_gm_cid! true && set "_gm_now=%%s"
)

:gm_show12_out
if defined _gm_now echo  Render scale of !_GM_PKG!: %g%!_gm_now!%%%w%
if not defined _gm_now echo  !_GM_PKG! has a render scale DCX does not offer; Reset turns it off.
goto gm_show_end

:gm_show12_none
echo  [%r%^^!%w%] The phone did not list its compat overrides:
call :_gm_msg gm_cfg.txt
goto gm_show_end

:gm_show14
call :_gm_readmode
if not defined _GM_MODE goto gm_show14_nomode
echo  Game Mode of !_GM_PKG!: %g%!_GM_MODE!%w%
if "!_GM_MODE!"=="unsupported" echo  Android does not list it as a game, so Game Mode does not apply.
goto gm_show14_cfg

:gm_show14_nomode
echo  [%r%^^!%w%] The phone did not report a mode:
call :_gm_msg gm_modes.txt

:gm_show14_cfg
adb shell cmd game list-configs !_GM_PKG! <nul >"!DCX_TMP!\gm_cfg.txt" 2>&1
echo.
echo  Interventions as Android reports them ^(mode 4 = custom^):
call :_gm_msg gm_cfg.txt
goto gm_show_end

:gm_show13
call :_gm_isgame
set "_gm_g=!errorlevel!"
if "!_gm_g!"=="0" echo  Android lists !_GM_PKG! as a game.
if "!_gm_g!"=="1" echo  Android does not list !_GM_PKG! as a game, so Game Mode does not apply.
if "!_gm_g!"=="2" echo  [%r%^^!%w%] The phone did not say whether !_GM_PKG! is a game.
adb shell cmd game list !_GM_PKG! <nul >"!DCX_TMP!\gm_cfg.txt" 2>&1
echo  Interventions as Android reports them ^(mode 2 = Performance^):
call :_gm_msg gm_cfg.txt
adb shell device_config get game_overlay !_GM_PKG! <nul >"!DCX_TMP!\gm_dc.txt" 2>&1
echo  game_overlay entry:
call :_gm_msg gm_dc.txt

:gm_show_end
call :_gm_tmpdel
echo.
echo Press Any Button To Go Back
pause > nul
goto gamemode

:gm_reset
cls
title Game Mode : Reset
call :logo
echo.
call :_gm_askpkg || goto gamemode
echo.
call :_act_reset
set "_gm_ok="
if %SDK% GEQ 34 goto gm_reset14
if "%SDK%"=="33" goto gm_reset13
goto gm_reset12

:gm_reset14
call :_gm_readmode
if "!_GM_MODE!"=="unsupported" goto gm_reset14_ng
adb shell cmd game reset !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "custom Game Mode config removed"
if errorlevel 1 call :_gm_msg
adb shell cmd game mode standard !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "Standard mode selected"
if errorlevel 1 (call :_gm_msg) else set "_gm_ok=1"
call :_gm_readmode
if "!_GM_MODE!"=="standard" goto gm_reset14_ok
echo [%r%^^!%w%] Android does not report Standard mode for !_GM_PKG!:
call :_gm_msg gm_modes.txt
set "_gm_ok="
set /a DCX_VFAIL+=1
goto gm_reset_end

:gm_reset14_ok
echo [%g%+%w%] Android reports Standard mode for !_GM_PKG!.
set /a DCX_VOK+=1
goto gm_reset_end

:gm_reset14_ng
echo [%g%+%w%] Android does not list !_GM_PKG! as a game, so no Game Mode applies to it.
set /a DCX_VOK+=1
:: 14 and early 15 builds keep a "set" for a non-game; later builds refuse this reset.
adb shell cmd game reset !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
set "_gm_rc=!errorlevel!"
findstr /l /c:" is not of game type" "!DCX_TMP!\gm_out.txt" >nul 2>&1 && goto gm_reset_end
call :_act_rc !_gm_rc! "stored custom config removed"
if errorlevel 1 call :_gm_msg
goto gm_reset_end

:gm_reset13
adb shell cmd game mode 1 !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "Standard mode selected"
if errorlevel 1 (call :_gm_msg) else set "_gm_ok=1"
adb shell cmd game reset !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "shell overrides removed"
if errorlevel 1 call :_gm_msg
call :_gm_dcclean
goto gm_reset_end

:gm_reset12
call :_gm_ask12 || goto gm_set_nochange
adb shell cmd game downscale disable !_GM_PKG! <nul >"!DCX_TMP!\gm_out.txt" 2>&1
call :_act_rc !errorlevel! "downscaling off - Android 12 closes the app itself"
if errorlevel 1 call :_gm_msg
set "_gm_scl=disable" & set "_gm_pct=100"
call :_gm_rb12
call :_gm_dcclean

:gm_reset_end
if defined _gm_ok call :_gm_restart
call :_act_summary
call :_gm_tmpdel
echo Press Any Button To Go Back
pause > nul
goto gamemode

:_gm_askpkg
:: _GM_PKG = a checked, installed package name; errorlevel 1 = none.
set "_GM_PKG="
set "gmp=" & set /p gmp="Game package name or part of one (blank = back) >> "
call :_noin gmp || goto dcx_noinput
if not defined gmp exit /b 1
call :_pkg_pick gmp inst || exit /b 1
set "_PKGCHK=!gmp!"
call :_pkg_ok
if errorlevel 1 goto _gm_askpkg_bad
adb shell pm path !_PKGCHK! <nul >nul 2>&1
if errorlevel 1 goto _gm_askpkg_none
set "_GM_PKG=!_PKGCHK!"
exit /b 0

:_gm_askpkg_bad
echo  [%r%^^!%w%] Invalid package name. Letters, digits, dots and underscores only.
timeout /t 2 /nobreak > nul
exit /b 1

:_gm_askpkg_none
:: pm path exits 1 for "not installed" and for a dropped phone alike.
set "_gm_live="
for /f "delims=" %%i in ('adb shell echo _DCXRD 2^>nul ^<nul') do if "%%i"=="_DCXRD" set "_gm_live=1"
if not defined _gm_live goto _gm_askpkg_gone
echo  [%r%^^!%w%] !_PKGCHK! is not installed on the phone.
goto _gm_askpkg_wait

:_gm_askpkg_gone
echo  [%r%^^!%w%] The phone did not answer - check the connection.

:_gm_askpkg_wait
timeout /t 3 /nobreak > nul
exit /b 1

:_gm_isgame
:: 13+: errorlevel 0 = Android lists _GM_PKG as a game, 1 = it does not, 2 = no answer.
if %SDK% LSS 34 goto _gm_isgame13
call :_gm_readmode
if not defined _GM_MODE exit /b 2
if "!_GM_MODE!"=="unsupported" exit /b 1
exit /b 0

:_gm_isgame13
:: dumpsys game prints a line for every installed game and for nothing else.
adb shell "dumpsys game | grep -qxF ' No intervention found for package !_GM_PKG!' && echo _DCXG; dumpsys game | grep -qF '[Name:!_GM_PKG! Modes:' && echo _DCXG; echo _DCXRD" <nul >"!DCX_TMP!\gm_game.txt" 2>nul
findstr /b /l /c:"_DCXRD" "!DCX_TMP!\gm_game.txt" >nul 2>&1 || exit /b 2
findstr /b /l /c:"_DCXG" "!DCX_TMP!\gm_game.txt" >nul 2>&1 || exit /b 1
exit /b 0

:_gm_readmode
:: 14+: _GM_MODE = standard/performance/battery/custom/unsupported, empty when unread.
set "_GM_MODE="
if %SDK% LSS 34 exit /b 1
adb shell cmd game list-modes !_GM_PKG! <nul >"!DCX_TMP!\gm_modes.txt" 2>&1
for %%m in (standard performance battery custom unsupported) do (
    findstr /l /c:" current mode: %%m," "!DCX_TMP!\gm_modes.txt" >nul 2>&1 && set "_GM_MODE=%%m"
)
findstr /l /c:" is not of game type" "!DCX_TMP!\gm_modes.txt" >nul 2>&1 && set "_GM_MODE=unsupported"
if not defined _GM_MODE exit /b 1
exit /b 0

:_gm_rb14
call :_gm_readmode
if "!_GM_MODE!"=="unsupported" goto _gm_rb14_ng
if not "!_GM_MODE!"=="custom" goto _gm_rb14_mode
echo [%g%+%w%] Android reports custom Game Mode for !_GM_PKG!.
set /a DCX_VOK+=1
goto _gm_rbcfg

:_gm_rb14_ng
call :_gm_notgame
set "_gm_ok="
set /a DCX_VFAIL+=1
exit /b

:_gm_rb14_mode
echo [%r%^^!%w%] Android does not report custom Game Mode for !_GM_PKG!:
call :_gm_msg gm_modes.txt
set "_gm_ok="
set /a DCX_VFAIL+=1
exit /b

:_gm_rbcfg
:: Scale and cap must sit in one entry: mode 4 (custom) on 14+, mode 2 on 13.
set "_gm_sre=!_gm_scl:.=\.!"
set "_gm_fre=,"
if not "!_gm_fps!"=="0" set "_gm_fre=!_gm_fps!,"
if %SDK% GEQ 34 (set "_gm_mn=4" & set "_gm_lc=list-configs") else (set "_gm_mn=2" & set "_gm_lc=list")
if "!_gm_scl!"=="disable" if %SDK% GEQ 34 set "_gm_sre=-1\.0"
if "!_gm_scl!"=="disable" if %SDK% LSS 34 set "_gm_sre=1\.0"
adb shell cmd game !_gm_lc! !_GM_PKG! <nul >"!DCX_TMP!\gm_cfg.txt" 2>&1
findstr /r /c:"\[Game Mode:!_gm_mn!,Scaling:!_gm_sre!,Use Angle:[a-z]*,Fps:!_gm_fre!" "!DCX_TMP!\gm_cfg.txt" >nul 2>&1
if errorlevel 1 goto _gm_rbcfg_bad
echo [%g%+%w%] Android reports scale !_gm_pct!%% and FPS cap !_gm_fpl! for !_GM_PKG!.
set /a DCX_VOK+=1
echo [%b%i%w%] Set and reported by Android, not proven on screen: OEM game tools can override
echo        it. Watch the frame rate to be sure.
exit /b

:_gm_rbcfg_bad
echo [%r%^^!%w%] Android does not report scale !_gm_pct!%% / FPS cap !_gm_fpl! for !_GM_PKG!:
call :_gm_msg gm_cfg.txt
if "%SDK%"=="33" echo        The game may opt out. The first Android 13 release also drops the FPS
if "%SDK%"=="33" echo        cap of apps that carry manifest meta-data; 13 QPR1 fixed that.
set "_gm_ok="
set /a DCX_VFAIL+=1
exit /b

:_gm_rb12
:: 12: dumpsys platform_compat lists each compat change with its per-app overrides.
adb shell dumpsys platform_compat <nul >"!DCX_TMP!\gm_cfg.txt" 2>&1
set "_gm_on=true"
if "!_gm_scl!"=="disable" set "_gm_on=false"
call :_gm_cc12 168419799 !_gm_on! || goto _gm_rb12_bad
if "!_gm_scl!"=="disable" goto _gm_rb12_ok
call :_gm_cid !_gm_pct!
call :_gm_cc12 !_gm_cid! true || goto _gm_rb12_bad

:_gm_rb12_ok
echo [%g%+%w%] Android reports the !_gm_pct!%% render scale for !_GM_PKG!.
set /a DCX_VOK+=1
exit /b

:_gm_rb12_bad
echo [%r%^^!%w%] Android does not report the !_gm_pct!%% render scale for !_GM_PKG!.
set /a DCX_VFAIL+=1
exit /b

:_gm_cid
:: %1 = render scale in percent; _gm_cid = its DOWNSCALE_<n> compat change id.
set "_gm_cid=0"
for %%p in (90:182811243 80:176926753 70:176926829 60:176926771 50:176926741) do (
    for /f "tokens=1,2 delims=:" %%a in ("%%p") do if "%%a"=="%~1" set "_gm_cid=%%b"
)
exit /b

:_gm_cc12
:: %1 = change id, %2 = true/false. errorlevel 0 if gm_cfg.txt shows that override for _GM_PKG.
findstr /r /c:"ChangeId(%~1;.*[{ ]!_GM_PKG:.=\.!=%~2[,}]" "!DCX_TMP!\gm_cfg.txt" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:_gm_notgame
echo [%r%^^!%w%] Android does not list !_GM_PKG! as a game ^(no appCategory "game"^),
echo        so Game Mode is ignored for it.
exit /b

:_gm_ask12
:: Android 12 applies a render scale by closing the app at once: ask first, as 13+ asks before it
:: closes the game. errorlevel 1 = no; Ctrl+C makes choice return 0, also no.
echo  Android 12 applies this by closing !_GM_PKG! at once if it is running.
echo    [Y] Apply and close it ^(unsaved game progress is lost^)    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 exit /b 1
if not errorlevel 1 exit /b 1
exit /b 0

:_gm_restart
echo.
echo  A render-scale change applies the next time !_GM_PKG! starts.
echo    [Y] Close it now ^(unsaved game progress is lost^)    [N] Leave it running
:: Ctrl+C makes choice return 0 - treated as N.
choice /c:YN /n >nul
if errorlevel 2 exit /b
if not errorlevel 1 exit /b
adb shell am force-stop !_GM_PKG! <nul >nul 2>&1
call :_act_rc !errorlevel! "!_GM_PKG! closed - open it again"
exit /b

:_gm_dcclean
:: 12-13: deletes the game_overlay entry only if DCX wrote it (",dcx=1", or the old "mode=1").
set "_gm_mine="
adb shell device_config get game_overlay !_GM_PKG! <nul >"!DCX_TMP!\gm_dc.txt" 2>nul
findstr /l /c:",dcx=1" "!DCX_TMP!\gm_dc.txt" >nul 2>&1 && set "_gm_mine=1"
for /f "usebackq delims=" %%v in ("!DCX_TMP!\gm_dc.txt") do (
    setlocal DisableDelayedExpansion
    set "_gmd="
    for /f "delims=" %%w in ("%%v") do if "%%w"=="mode=1" set "_gmd=1"
    if defined _gmd (endlocal & set "_gm_mine=1") else endlocal
)
if not defined _gm_mine goto _gm_dcclean_none
adb shell device_config delete game_overlay !_GM_PKG! <nul >nul 2>&1
call :_dcfg_verify game_overlay !_GM_PKG! null
exit /b

:_gm_dcclean_none
echo [%b%i%w%] No game_overlay entry from DCX for !_GM_PKG! ^(or no answer^) - left alone.
exit /b

:_gm_msg
:: Echoes up to 3 lines of !DCX_TMP!\%1 (default gm_out.txt) with delayed expansion off.
set "_gmmf=%~1"
if not defined _gmmf set "_gmmf=gm_out.txt"
set "_gmc=0"
set "_gmstop="
if not exist "!DCX_TMP!\!_gmmf!" goto _gm_msg_end
for /f "usebackq delims=" %%a in ("!DCX_TMP!\!_gmmf!") do (
    set /a _gmc+=1
    setlocal DisableDelayedExpansion
    if not defined _gmstop echo         phone: %%a
    endlocal
    if !_gmc! GEQ 3 set "_gmstop=1"
)

:_gm_msg_end
if "!_gmc!"=="0" echo         phone: ^(no output^)
exit /b

:_gm_tmpdel
del "!DCX_TMP!\gm_out.txt" "!DCX_TMP!\gm_modes.txt" "!DCX_TMP!\gm_cfg.txt" "!DCX_TMP!\gm_dc.txt" "!DCX_TMP!\gm_game.txt" "!DCX_TMP!\gm_hz.txt" >nul 2>&1
exit /b

:_gm_fpsmenu
:: Lists the caps that some panel refresh rate is 2x, 3x... of; fills _gmn and _gmf_<n>.
call :_gm_panel
echo.
if "!_GM_HZ!"==" " echo  FPS cap - the panel refresh rates were not read, so every cap is listed:
if not "!_GM_HZ!"==" " echo  FPS cap - panel refresh rates:!_GM_HZ!Hz
echo  A cap holds only while the screen runs at a multiple of it: 60 works at 120 Hz, 45 does not.
echo.
set "_gmn=0"
for %%f in (30 40 45 60 90 120) do call :_gm_fpsrow %%f
set /a _gmn+=1
set "_gmf_!_gmn!=0"
echo    %g%[%w%!_gmn!%g%]%w% No cap
exit /b

:_gm_fpsrow
set "_gmok="
if "!_GM_HZ!"==" " set "_gmok=1"
for %%h in (!_GM_HZ!) do call :_gm_divides %%h %1
if not defined _gmok exit /b
set /a _gmn+=1
set "_gmf_!_gmn!=%1"
echo    %g%[%w%!_gmn!%g%]%w% %1 fps
exit /b

:_gm_divides
:: A cap equal to the refresh rate throttles nothing (SurfaceFlinger divisor 1).
if %1 LEQ %2 exit /b
set /a "_gmr=%1 %% %2"
if "!_gmr!"=="0" set "_gmok=1"
exit /b

:_gm_panel
:: _GM_HZ = panel refresh rates as " 60 120 " (" " if unread). Delayed expansion off: a "!" must not vanish.
set "_GM_HZ= "
set "_gm_hzf=!DCX_TMP!\gm_hz.txt"
adb shell "dumpsys display | grep -o 'fps=[0-9]*'" <nul >"!_gm_hzf!" 2>nul
setlocal DisableDelayedExpansion
for /f "usebackq tokens=2 delims==" %%h in ("%_gm_hzf%") do for /f "delims=" %%x in ("%%h") do (
    set "_gmh="
    for /f "delims=0123456789" %%c in ("%%x#") do if "%%c"=="#" set "_gmh=1"
    if defined _gmh call :_gm_hzadd %%x
)
endlocal & set "_GM_HZ=%_GM_HZ%"
del "!_gm_hzf!" >nul 2>&1
exit /b

:_gm_hzadd
:: %1 = digits only; delayed expansion is off here. Keeps 2-3 digit rates without a leading 0, once each.
set "_gmh=%~1"
if "%_gmh:~1,1%"=="" exit /b
if not "%_gmh:~3%"=="" exit /b
if "%_gmh:~0,1%"=="0" exit /b
call set "_gmt=%%_GM_HZ: %_gmh% =%%"
if not "%_gmt%"=="%_GM_HZ%" exit /b
set "_GM_HZ=%_GM_HZ%%_gmh% "
exit /b
:: Performance
:performance
@echo off
cls
title Performance props (debug/OEM)
echo.
echo.
echo  Writes a large dump of debug/OEM props. Most are volatile and
echo  device-dependent - not a guaranteed FPS mode. What lasts: battery saver
echo  off, the thermal status pinned at NONE until Off, activity_manager_constants
echo  and storage/SurfaceFlinger flags; Samsung-only keys no-op elsewhere.
echo.
echo [%r%1%w%] Toggle
echo [%r%2%w%] Back
set "kb=" & set /p kb="Choose An Option >> "
call :_noin kb || goto dcx_noinput
if "!kb!"=="1" goto toggleperf
if "!kb!"=="2" goto Gaming
:: guard against invalid input
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
call :_noin kb || goto dcx_noinput
if "!kb!"=="1" goto offperf
if "!kb!"=="2" goto onperf
if "!kb!"=="3" goto Gaming
:: guard against invalid input
goto toggleperf

:offperf
@echo off
cls
title Performance Mode : Off
call :_dcfg_warn
:: Off deletes the overrides so the platform defaults return. Each key goes to the session undo
:: file first, as On does: a value set before DCX is not lost.
call :_tw_undo_dcfg storage_native_boot target_dirty_ratio
call :_tw_undo_dcfg storage_native_boot target_dirty_background_ratio
call :_tw_undo_dcfg runtime_native_boot iorap_readahead_enable
call :_tw_undo_dcfg surface_flinger_native_boot max_frame_buffer_acquired_buffers
call :_tw_undo_dcfg surface_flinger_native_boot adpf_cpu_hint
call :_tw_undo_add global activity_manager_constants
call :_tw_undo_add global low_power
call :_tw_undo_add system multicore_packet_scheduler
call :_tw_undo_add global sem_enhanced_cpu_responsiveness
if "%SDK%"=="" call :_tw_undo_add global device_idle_constants
if not "%SDK%"=="" if %SDK% GEQ 31 call :_tw_undo_dcfg device_idle inactive_to
if not "%SDK%"=="" if %SDK% LSS 31 call :_tw_undo_add global device_idle_constants
adb shell device_config delete storage_native_boot target_dirty_ratio <nul > nul 2>&1
adb shell device_config delete storage_native_boot target_dirty_background_ratio <nul > nul 2>&1
adb shell logcat -G 256kb <nul
adb shell settings delete global activity_manager_constants <nul > nul 2>&1
adb shell device_config delete runtime_native_boot iorap_readahead_enable <nul > nul 2>&1
adb shell device_config delete surface_flinger_native_boot max_frame_buffer_acquired_buffers <nul > nul 2>&1
adb shell device_config delete surface_flinger_native_boot adpf_cpu_hint <nul > nul 2>&1
:: Undo the persistent power state :onperf pins; the debug.* props clear on reboot.
:: Do not force set-mode here: 1 turns low-power mode on; unpinning low_power is enough.
adb shell cmd thermalservice reset <nul > nul 2>&1
adb shell cmd power set-adaptive-power-saver-enabled true <nul > nul 2>&1
adb shell settings delete global low_power <nul > nul 2>&1
adb shell settings delete system multicore_packet_scheduler <nul > nul 2>&1
adb shell settings delete global sem_enhanced_cpu_responsiveness <nul > nul 2>&1
:: Clears SQLite durability props an older DCX set, so fsync returns without a reboot.
adb shell setprop debug.sqlite.journalmode '' <nul > nul 2>&1
adb shell setprop debug.sqlite.syncmode '' <nul > nul 2>&1
adb shell setprop debug.sqlite.wal.syncmode '' <nul > nul 2>&1
if "%SDK%"=="" (
    adb shell settings delete global device_idle_constants <nul > nul 2>&1
) else if %SDK% GEQ 31 (
    adb shell device_config delete device_idle inactive_to <nul > nul 2>&1
) else (
    adb shell settings delete global device_idle_constants <nul > nul 2>&1
)
:: Read the device_config deletes back: Android 14+ without root can accept one and keep the value.
echo.
call :_act_reset
call :_dcfg_verify storage_native_boot target_dirty_ratio null
call :_dcfg_verify storage_native_boot target_dirty_background_ratio null
call :_dcfg_verify runtime_native_boot iorap_readahead_enable null
call :_dcfg_verify surface_flinger_native_boot max_frame_buffer_acquired_buffers null
call :_dcfg_verify surface_flinger_native_boot adpf_cpu_hint null
if not "%SDK%"=="" if %SDK% GEQ 31 call :_dcfg_verify device_idle inactive_to null
call :_act_summary
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
call :_dcfg_warn
:: Every persistent key On writes is captured first, so On then Off undoes to the values from before
:: On, not to On's own. The first capture of a key wins.
call :_tw_undo_dcfg storage_native_boot target_dirty_ratio
call :_tw_undo_dcfg storage_native_boot target_dirty_background_ratio
call :_tw_undo_dcfg runtime_native_boot iorap_readahead_enable
call :_tw_undo_dcfg surface_flinger_native_boot max_frame_buffer_acquired_buffers
call :_tw_undo_dcfg surface_flinger_native_boot adpf_cpu_hint
call :_tw_undo_add global activity_manager_constants
call :_tw_undo_add global low_power
call :_tw_undo_add system multicore_packet_scheduler
call :_tw_undo_add global sem_enhanced_cpu_responsiveness
echo.
echo.
echo [%r%^^!%w%] Turning power saving off: battery saver, the adaptive saver, and the thermal
echo     status pinned at NONE until Off. To use battery saver again, turn Performance Mode
echo     off first, then use Power Saver in Battery Mode.
::disable powersaver
adb shell cmd power set-mode 0 <nul > nul 2>&1
adb shell cmd thermalservice override-status 0 <nul
adb shell settings put global low_power 0 <nul
:: REMOVED: inactive_to=300000. It is the delay before Doze, 30 min by default, so 5 min made the
:: phone doze sooner - the opposite of this mode. Off still deletes it, for an older DCX's write.
adb shell cmd power set-adaptive-power-saver-enabled false <nul
adb shell setprop debug.power_management_mode pref_max <nul
adb shell cmd shortcut reset-all-throttling <nul > nul 2>&1
:: Keep the log buffer small: a huge one stalls the system on flush.
adb shell logcat -G 1mb <nul
adb shell setprop debug.rs.rsov 1 <nul
adb shell setprop debug.rs.default-CPU-driver 0 <nul
adb shell setprop debug.renderengine.graphite true <nul
adb shell setprop debug.hwc.hdr_nbm_enable 0 <nul
:: Do not disable vsync: it causes tearing and breaks frame pacing.
:: Do not turn off the sqlite journal or sync modes: it risks corrupting contacts and messages.
adb shell setprop debug.sqlite.journalsizelimit 1mb <nul
adb shell setprop debug.hwui.disable_draw_defer true <nul
adb shell setprop debug.hwui.disable_draw_reorder false <nul
adb shell setprop debug.sf.disable_client_composition_cache 1 <nul
adb shell setprop debug.hwui.initialize_gl_always true <nul
adb shell setprop debug.sf.drop_missed_frames 1 <nul
adb shell setprop debug.sf.allowed_actual_deviation 0 <nul
adb shell setprop debug.hwui.render_dirty_regions false <nul
adb shell setprop debug.hwc.flattenning_enabled false <nul
adb shell setprop debug.hwc.test_plan false <nul
adb shell setprop debug.incremental.always_enable_read_timeouts_for_system_dataloaders false <nul
adb shell setprop debug.incremental.enable_read_timeouts_after_install false <nul
adb shell setprop debug.sf.treat_170m_as_sRGB 0 <nul
adb shell setprop debug.sf.fp16_client_target 1 <nul
adb shell setprop debug.soundtrigger_middleware.use_mock_hal 0 <nul
adb shell setprop debug.extractor.ignore_version false <nul
adb shell setprop debug.art.monitor.app false <nul
adb shell setprop debug.sf.vrr_timeout_hint_enabled false <nul
adb shell setprop debug.sf.enable_hole_punch_pip false <nul
adb shell setprop debug.hwc.force_gpu 1 <nul
adb shell setprop debug.sf.framedrop 0 <nul
adb shell setprop debug.hwui.clip_surfaceviews true <nul
adb shell setprop debug.hwui.resample_gainmap_regions false <nul
adb shell setprop debug.egl.blobcache.multifile true <nul
adb shell setprop debug.egl.blobcache.multifile_limit 16777216 <nul
adb shell setprop debug.sf.enable_layer_command_batching 1 <nul
adb shell setprop debug.sf.use_content_detection_v2 false <nul
adb shell setprop debug.adpf.use_report_actual_duration false <nul
adb shell setprop debug.sf.hint_margin_us 550 <nul
adb shell setprop debug.sf.cached_set_max_defer_render_attmpts 2 <nul
adb shell setprop debug.sf.layer_caching_active_layer_timeout_ms 1200 <nul
adb shell setprop debug.sf.cache_source_crop_only_moved true <nul
adb shell setprop debug.sf.multithreaded_present 1 <nul
adb shell setprop debug.sf.hwc_hdcp_via_neg_vsync false <nul
adb shell setprop debug.sf.enable_layer_lifecycle_manager false <nul
adb shell setprop debug.sf.send_early_power_session_hint true <nul
adb shell setprop debug.sf.send_late_power_session_hint false <nul
adb shell setprop debug.sf.hwc.min.duration 0 <nul
adb shell setprop debug.sf.use_frame_rate_priority 1 <nul
adb shell setprop debug.sf.enable_cached_set_render_scheduling true <nul
adb shell setprop debug.sf.enable_layer_caching 0 <nul
adb shell setprop debug.sf.max_igbp_list_size 7 <nul
adb shell setprop debug.hwc.fakevsync 0 <nul
adb shell setprop debug.enable.sglscale 1 <nul
adb shell setprop debug.enable.gamed 1 <nul
adb shell setprop debug.enabletr true <nul
adb shell setprop debug.sf.enable_adpf_cpu_hint true <nul
adb shell setprop debug.rs.precision rs_fp_full <nul
adb shell setprop debug.hwui.high_performance_mode true <nul
adb shell settings put system multicore_packet_scheduler 1 <nul
adb shell settings put global sem_enhanced_cpu_responsiveness 1 <nul
adb shell settings put global activity_manager_constants max_cached_processes=12,power_check_interval=80000,power_check_max_cpu_1=85,power_check_max_cpu_2=85,power_check_max_cpu_3=60,power_check_max_cpu_4=15 <nul
:: REMOVED: debug.cpurend.vsync false and debug.egl.swapinterval 0 - vsync off means tearing.
adb shell setprop debug.sf.hw 1 <nul
adb shell setprop debug.rs.max-threads 8 <nul
adb shell setprop debug.sf.vsync_reactor_ignore_present_fences true <nul
adb shell setprop debug.sf.disable_hwc_vds 1 <nul
adb shell setprop debug.sf.enable_hwc_vds false <nul
adb shell setprop debug.hwui.target_cpu_time_percent 35 <nul
adb shell setprop debug.egl.hw 1 <nul
adb shell setprop debug.rs.reduce-split-accum 1 <nul
adb shell setprop debug.choreographer.skipwarning 16500000 <nul
adb shell setprop debug.sf.luma_sampling 0 <nul
adb shell setprop debug.gr.numframebuffers 3 <nul
adb shell setprop debug.hwui.skip_empty_damage true <nul
adb shell setprop debug.composition.type dyn <nul
adb shell setprop debug.hwui.use_buffer_age true <nul
adb shell setprop debug.hwui.use_partial_updates true <nul
adb shell setprop debug.gralloc.map_fb_memory 1 <nul
adb shell setprop debug.gralloc.enable_fb_ubwc 1 <nul
adb shell setprop debug.sf.swaprect 1 <nul
adb shell setprop debug.hwui.filter_test_overhead false <nul
adb shell setprop debug.hwui.fps_divisor 1 <nul
adb shell setprop debug.graphics.game_default_frame_rate.disabled true <nul
adb shell setprop debug.sf.latch_unsignaled 1 <nul
adb shell setprop debug.sf.auto_latch_unsignaled true <nul
adb shell setprop debug.sf.disable_backpressure 1 <nul
adb shell setprop debug.sf.enable_advanced_sf_phase_offset 1 <nul
adb shell setprop debug.gralloc.gfx_ubwc_disable 0 <nul
adb shell setprop debug.hwc.bq_count 3 <nul
adb shell setprop debug.hwc.compose_level 0 <nul
adb shell setprop debug.hwui.use_hint_manager true <nul
adb shell setprop debug.hwui.render_ahead 3 <nul
adb shell setprop debug.sf.enable_gl_backpressure 0 <nul
adb shell setprop debug.sf.vsync_reactor_ignore_present_fences true <nul
adb shell setprop debug.sf.set_idle_timer_ms 3500 <nul
adb shell setprop debug.sf.frame_rate_multiple_threshold 120 <nul
adb shell setprop debug.sf.use_phase_offsets_as_durations 0 <nul
adb shell setprop debug.c2.use_dmabufheaps 1 <nul
adb shell setprop debug.sf.prime_shader_cache.image_layers true <nul
adb shell setprop debug.sf.prime_shader_cache.solid_layers true <nul
adb shell setprop debug.mdpcomp.idletime 5000 <nul
adb shell setprop debug.mdpcomp.maxpermixer 3 <nul
adb shell device_config put runtime_native_boot iorap_readahead_enable true <nul
adb shell setprop debug.media.c2.large.audio.frame false <nul
adb shell device_config put surface_flinger_native_boot max_frame_buffer_acquired_buffers 3 <nul
adb shell device_config put surface_flinger_native_boot adpf_cpu_hint true <nul
:: Absolute ratios so repeating On is idempotent; Off deletes the keys.
echo storage_native_boot/target_dirty_ratio : 35
echo storage_native_boot/target_dirty_background_ratio : 5
adb shell device_config put storage_native_boot target_dirty_ratio 35 <nul
adb shell device_config put storage_native_boot target_dirty_background_ratio 5 <nul
:: About a hundred unchecked writes: at least say so when the phone is gone by the end.
call :_phone_live || echo [%y%WARN%w%] The phone did not answer at the end - some writes above may not have landed.
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
echo                 %g%[%w%1%g%]%w% Restrict app background (Android's Restricted mode)
echo                 %g%[%w%2%g%]%w% Allow app background (revert)
echo                 %g%[%w%3%g%]%w% Debloat - remove an app by package name
echo                 %g%[%w%4%g%]%w% Debloat - suggested bloatware (auto-detect brand)
echo                 %g%[%w%5%g%]%w% List installed packages (to Notepad)
echo                 %g%[%w%6%g%]%w% Restore a removed app
echo                 %g%[%w%7%g%]%w% Back
set "am=" & set /p am="Choose An Option >> "
call :_noin am || goto dcx_noinput
if "!am!"=="1" goto appmgr_restrict
if "!am!"=="2" goto appmgr_allow
if "!am!"=="3" goto appmgr_debloat_input
if "!am!"=="4" goto appmgr_suggest
if "!am!"=="5" goto appmgr_listpkgs
if "!am!"=="6" goto appmgr_restore_input
if "!am!"=="7" goto menu
goto appmgr
:: ===================================================================
:: Restrict / Allow background: ask for the package, then App check writes and reads back.
:: ===================================================================
:appmgr_restrict
cls
title Restrict Background
call :logo
echo  Sets Android's own Restricted mode, as Settings does: RUN_ANY_IN_BACKGROUND ignore and off
echo  the Doze allowlist. "Allow background" lifts it; the session undo file restores the old mode.
echo  Tip: type part of a name, such as chrome, to pick the app from a list.
echo.
set "pkg=" & set /p pkg="Package name or part of one (blank = cancel) >> "
call :_noin pkg || goto dcx_noinput
if "!pkg!"=="" goto appmgr
call :_pkg_pick pkg inst || goto appmgr_restrict
set "_PKGCHK=!pkg!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto appmgr
)
call :_pkg_installed !pkg!
if errorlevel 2 (
    echo [%r%^^!%w%] The phone did not answer the package list - check the connection.
    pause >nul
    goto appmgr_restrict
)
if errorlevel 1 (
    echo [%r%^^!%w%] "!pkg!" is not installed.
    pause >nul
    goto appmgr_restrict
)
:: ignore, not deny: Settings writes ignore, and no Settings version shows deny correctly.
set "ACK_PKG=!pkg!" & set "ACK_RET=appmgr" & set "_ac_want=R"
goto appcheck_direct

:appmgr_allow
cls
title Allow Background
call :logo
echo  Allows background again: both app-ops back to allow. The Doze allowlist stays as it is.
echo.
set "pkg=" & set /p pkg="Package name or part of one (blank = cancel) >> "
call :_noin pkg || goto dcx_noinput
if "!pkg!"=="" goto appmgr
call :_pkg_pick pkg inst || goto appmgr_allow
set "_PKGCHK=!pkg!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto appmgr
)
call :_pkg_installed !pkg!
if errorlevel 2 (
    echo [%r%^^!%w%] The phone did not answer the package list - check the connection.
    pause >nul
    goto appmgr_allow
)
if errorlevel 1 (
    echo [%r%^^!%w%] "!pkg!" is not installed.
    pause >nul
    goto appmgr_allow
)
set "ACK_PKG=!pkg!" & set "ACK_RET=appmgr" & set "_ac_want=A"
goto appcheck_direct
:: ===================================================================
:: Debloat - pm uninstall -k --user 0 keeps data; known bootloop packages are hard-blocked.
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
set "pkg=" & set /p pkg="Package name or part of one (blank = cancel) >> "
call :_noin pkg || goto dcx_noinput
if "!pkg!"=="" goto appmgr
call :_pkg_pick pkg inst || goto appmgr_debloat_input
set "_PKGCHK=!pkg!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto appmgr
)
set "BLOCKED=0"
for %%c in (com.android.systemui com.hoffnung com.android.phone com.android.settings com.miui.daemon com.android.systemui.plugins com.android.providers.telephony com.huawei.hwid com.huawei.android.pushagent com.huawei.hwasm com.huawei.android.hwouc com.huawei.systemserver) do if /i "!pkg!"=="%%c" set "BLOCKED=1"
if "%BLOCKED%"=="1" (
    echo [%r%BLOCKED%w%] "!pkg!" is a critical package and will not be removed.
    pause >nul
    goto appmgr_debloat_input
)
call :_pkg_installed !pkg!
if errorlevel 2 (
    echo [%r%^^!%w%] The phone did not answer the package list - check the connection.
    pause >nul
    goto appmgr_debloat_input
)
if errorlevel 1 (
    echo [%r%^^!%w%] "!pkg!" is not installed.
    pause >nul
    goto appmgr_debloat_input
)
echo.
echo  About to remove: !pkg!
echo    [Y] Remove    [N] Cancel
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 goto appmgr
if not errorlevel 1 goto appmgr
:: Only pm's own Success line counts as removed, via :_am_uninst.
call :_act_reset
call :_am_uninst !pkg!
call :_act_summary
if not "%DCX_VOK%"=="0" echo To bring it back: App Manager -^> Restore ^(or a factory reset^).
pause >nul
goto appmgr

:appmgr_restore_input
cls
title Restore Removed App
call :logo
echo  Reinstalls an app removed with Debloat (pm install-existing).
echo  Works as long as it was removed with -k and not fully wiped.
echo.
set "pkg=" & set /p pkg="Package name or part of one (blank = cancel) >> "
call :_noin pkg || goto dcx_noinput
if "!pkg!"=="" goto appmgr
call :_pkg_pick pkg removed || goto appmgr_restore_input
set "_PKGCHK=!pkg!"
call :_pkg_ok || (
    echo  [%r%x%w%] Invalid package name. Letters, digits, dots and underscores only.
    timeout /t 2 /nobreak > nul
    goto appmgr
)
:: --user 0 like Debloat: newer Android otherwise restores for the current user.
adb shell cmd package install-existing --user 0 !pkg! <nul
echo.
call :_pkg_installed !pkg!
if errorlevel 2 (
    echo [%y%WARN%w%] The phone did not answer, so the restore could not be checked.
) else if errorlevel 1 (
    echo [%r%^^!%w%] Restore did not land - "!pkg!" is not installed for this user.
    echo      It may never have been a system/preloaded package, or the APK is gone.
) else (
    echo [%g%+%w%] !pkg! is present for the current user.
)
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
call :_noin lp || goto dcx_noinput
if not defined lp goto appmgr_listpkgs
if "!lp!"=="3" goto appmgr
:: Re-ask on other keys; delete the old list first so a failed dump never shows stale data.
if not "!lp!"=="1" if not "!lp!"=="2" goto appmgr_listpkgs
:: Per-window folder: a shared file could be overwritten by another DCX window.
set "PKGLIST=!DCX_TMP!\installed_packages.txt"
del "!PKGLIST!" > nul 2>&1
:: find /v normalises adb's LF-only output so older Notepad builds do not show one long line.
if "!lp!"=="1" adb shell pm list packages < nul 2>nul | find /v "" > "!PKGLIST!"
if "!lp!"=="2" adb shell pm list packages -3 < nul 2>nul | find /v "" > "!PKGLIST!"
:: Require a real package line: an empty file still passes if exist; a missing one fails too.
findstr /b /c:"package:" "!PKGLIST!" >nul 2>&1 || goto appmgr_listpkgs_none
start "" notepad "!PKGLIST!"
echo Opened in Notepad. Use these names with Restrict / Debloat.
pause >nul
goto appmgr

:appmgr_listpkgs_none
echo.
echo  %r%No packages were listed.%w% Is the device still connected? ^(check: adb devices^)
pause >nul
goto appmgr
:: ===================================================================
:: Suggested bloatware - brand-detected; only vetted safe-to-remove packages that are installed.
:: ===================================================================
:appmgr_suggest
cls
title Suggested Bloatware
call :logo
set "BRAND="
for /f "delims=" %%i in ('adb shell getprop ro.product.brand 2^>nul ^<nul') do set "BRAND=%%i"
set "MANU="
for /f "delims=" %%i in ('adb shell getprop ro.product.manufacturer 2^>nul ^<nul') do set "MANU=%%i"
:: Strip the trailing CR older adb builds add.
if defined BRAND for /f "delims=" %%a in ("!BRAND!") do set "BRAND=%%a"
if defined MANU for /f "delims=" %%a in ("!MANU!") do set "MANU=%%a"
:: Per-window folder: a shared file let another DCX window swap in its phone's package list.
set "PKGDUMP=!DCX_TMP!\pkgs.txt"
echo  Detected brand: !BRAND!   manufacturer: !MANU!
echo.
echo  These groups only remove well-documented, safe-to-remove apps that
echo  are actually installed. Removal is for the current user (-k keeps
echo  data) and reversible via Restore or a factory reset. Critical
echo  packages (system UI, telephony, etc) are never listed.
echo.
echo                 %g%[%w%1%g%]%w% Facebook bloat (any brand)
echo                 %g%[%w%2%g%]%w% Optional Google apps (YouTube, Drive, Meet...)
set "BRANDCAT=0"
:: Phone text: no percent expansion and no pipe to findstr - either lets cmd parse it as code.
:: Substitution drops the word in any case, so a changed string is a match; later groups win.
set "_bm=!BRAND! !MANU!"
for %%k in (xiaomi redmi poco) do if not "!_bm:%%k=!"=="!_bm!" set "BRANDCAT=Xiaomi"
for %%k in (tecno infinix itel transsion) do if not "!_bm:%%k=!"=="!_bm!" set "BRANDCAT=Transsion"
for %%k in (samsung) do if not "!_bm:%%k=!"=="!_bm!" set "BRANDCAT=Samsung"
for %%k in (huawei honor) do if not "!_bm:%%k=!"=="!_bm!" set "BRANDCAT=Huawei"
if not "%BRANDCAT%"=="0" echo                 %g%[%w%3%g%]%w% %BRANDCAT% bloat
echo                 %g%[%w%4%g%]%w% Back
set "sg=" & set /p sg="Choose An Option >> "
call :_noin sg || goto dcx_noinput
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
:: Shared remover: shows which BLOATSET packages are in PKGDUMP, removes them after one yes.
:: -------------------------------------------------------------------
:_remove_noans
echo  [%r%^^!%w%] The phone did not answer the package list, so nothing was checked or removed.
pause >nul
goto appmgr_suggest

:_remove_present_set
cls
title Debloat : review
call :logo
echo  %BLOATDESC%
echo.
:: A fresh list, ended by a marker: without it the phone did not answer, which is not "none".
:: find /v turns LF-only output into CRLF so the whole-line /x match below works.
adb shell "pm list packages && echo _DCXEND" < nul 2>nul | find /v "" > "!PKGDUMP!"
findstr /c:"_DCXEND" "!PKGDUMP!" >nul 2>&1 || goto _remove_noans
echo  Installed packages from this group (these will be removed):
echo.
set "_found="
set "_n=0"
for %%p in (%BLOATSET%) do (
    findstr /x /c:"package:%%p" "!PKGDUMP!" >nul
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
:: Ctrl+C makes choice return 0; treat it as No.
choice /c:YN /n >nul
if errorlevel 2 goto appmgr_suggest
if not errorlevel 1 goto appmgr_suggest
echo.
:: Same check as the single-package path: only pm's own "Success" line counts.
call :_act_reset
for %%p in (%_found%) do call :_am_uninst %%p
call :_act_summary
pause >nul
goto appmgr_suggest
:: ===================================================================
:: Tweaks and Settings - main menu 14.
:: Every adb call reads stdin from nul so it cannot eat the next set /p.
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
echo    %g%[%w%13%g%]%w% DeviceConfig server sync (advanced)
echo.
echo   %d%Undo / backups%w%
if defined EXP_UNDO (
    echo    Session undo: !EXP_UNDO!
) else if exist "!BACKUPDIR!\dcx_last_undo.txt" (
    set "_lu="
    set /p _lu=<"!BACKUPDIR!\dcx_last_undo.txt"
    echo    Last undo: !_lu!
) else (
    echo    No undo script yet this session.
)
if exist "!BACKUPDIR!\dcx_last_backup.txt" (
    set "_lb="
    set /p _lb=<"!BACKUPDIR!\dcx_last_backup.txt"
    echo    Last backup: !_lb!
)
echo    %g%[%w%14%g%]%w% Undo / backups hub - open or run last undo
echo.
echo    %g%[%w%15%g%]%w% Back to main menu
set "tw=" & set /p tw="Choose An Option >> "
call :_noin tw || goto dcx_noinput
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
if "!tw!"=="13" goto tw_dcfgsync
if "!tw!"=="14" goto tw_undo_hub
if "!tw!"=="15" goto menu
goto tweaks

:tw_undo_hub
cls
title Undo / Backups
call :logo
if not exist "!BACKUPDIR!" mkdir "!BACKUPDIR!"
set "UNDOFILE="
if defined EXP_UNDO if exist "!EXP_UNDO!" set "UNDOFILE=!EXP_UNDO!"
if not defined UNDOFILE if exist "!BACKUPDIR!\dcx_last_undo.txt" (
    set /p UNDOFILE=<"!BACKUPDIR!\dcx_last_undo.txt"
)
set "BAKLAST="
if exist "!BACKUPDIR!\dcx_last_backup.txt" set /p BAKLAST=<"!BACKUPDIR!\dcx_last_backup.txt"
echo.
echo  Folder: !BACKUPDIR!
echo  Session/last undo:
if defined UNDOFILE (echo    !UNDOFILE!) else (echo    ^(none yet^))
echo  Last backup:
if defined BAKLAST (echo    !BAKLAST!) else (echo    ^(none yet^))
echo.
echo    %g%[%w%1%g%]%w% Open undo script in Notepad
echo    %g%[%w%2%g%]%w% Run undo script now ^(restores captured values^)
echo    %g%[%w%3%g%]%w% Open backups folder
echo    %g%[%w%4%g%]%w% Open last backup in Notepad
echo    %g%[%w%5%g%]%w% Back
set "uh=" & set /p uh="Choose An Option >> "
call :_noin uh || goto dcx_noinput
if not defined uh goto tw_undo_hub
if "!uh!"=="1" goto tw_undo_open
if "!uh!"=="2" goto tw_undo_run
if "!uh!"=="3" (start "" "!BACKUPDIR!" & goto tw_undo_hub)
if "!uh!"=="4" goto tw_bak_open
if "!uh!"=="5" goto tweaks
goto tw_undo_hub

:tw_undo_open
if not defined UNDOFILE goto tw_undo_missing
if not exist "!UNDOFILE!" goto tw_undo_missing
start "" notepad "!UNDOFILE!"
goto tw_undo_hub

:tw_undo_run
if not defined UNDOFILE goto tw_undo_missing
if not exist "!UNDOFILE!" goto tw_undo_missing
echo.
echo  About to run: !UNDOFILE!
set "ok=" & set /p ok="Run undo? (y = yes) >> "
call :_noin ok || goto dcx_noinput
if /i not "!ok!"=="y" goto tw_undo_hub
echo.
:: UNDOFILE is expanded by the child cmd, not pasted into this line.
call :_retarget UNDOFILE
cmd /c ""%%UNDOFILE%%" /nopause"
set "_urc=%errorlevel%"
set "DCX_RETARGET="
echo.
echo  ----------------------------------------
echo  Undo finished ^(exit code %_urc%^).
:: Android 14+ without root can accept a device_config write and keep nothing, as Restore notes.
set "_udcfg="
if "%_urc%"=="0" if !SDK! GEQ 34 findstr /c:"DCX_CMD=device_config " "!UNDOFILE!" >nul 2>&1 && set "_udcfg=1"
if defined _udcfg echo  %y%Note:%w% Android 14+ without root can accept a device_config value without keeping it -
if defined _udcfg echo  the count above is what the phone accepted, not what it kept.
echo  Press any key to continue . . .
pause >nul
goto tw_undo_hub

:tw_bak_open
if not defined BAKLAST goto tw_bak_missing
if not exist "!BAKLAST!" goto tw_bak_missing
start "" notepad "!BAKLAST!"
goto tw_undo_hub

:tw_undo_missing
echo  %y%No undo script found yet.%w% Change something in Tweaks / Explorer first.
timeout /t 2 /nobreak >nul
goto tw_undo_hub

:tw_bak_missing
echo  %y%No backup path recorded yet.%w% Use Main Menu - Backup first.
timeout /t 2 /nobreak >nul
goto tw_undo_hub

:tw_dcfgsync
cls
title DeviceConfig Server Sync
call :logo
call :_dcfg_warn
echo.
call :_dcfgsync_read
if errorlevel 1 (
    echo  device_config get_sync_disabled_for_tests = %r%not readable on this build%w%
    echo  This Android build does not implement the getter, so DCX cannot show the
    echo  current mode or confirm a change. The setter below may still work - it just
    echo  cannot be verified, and Backup will skip this key rather than guess.
) else (
    echo  device_config get_sync_disabled_for_tests = "!DCS_VAL!"
)
echo.
echo  This is NOT Google/account sync. It freezes remote DeviceConfig flag
echo  updates from the server ^(OEM/feature flags^). "persistent" survives
echo  reboot until you set it back to none. Was previously buried inside
echo  Battery - Logs Off, which froze sync as a silent side effect.
echo.
echo    %g%[%w%1%g%]%w% Allow sync (none) - default / undo
echo    %g%[%w%2%g%]%w% Disable until reboot (until_reboot)
echo    %g%[%w%3%g%]%w% Disable permanently (persistent)
echo    %g%[%w%4%g%]%w% Back
set "dc=" & set /p dc="Choose An Option >> "
call :_noin dc || goto dcx_noinput
if not defined dc goto tw_dcfgsync
if "!dc!"=="1" (call :_tw_undo_dcfgsync & adb shell device_config set_sync_disabled_for_tests none <nul >nul 2>&1 & call :_dcfgsync_verify none & echo  Press any key . . . & pause >nul & goto tw_dcfgsync)
if "!dc!"=="2" (call :_tw_undo_dcfgsync & adb shell device_config set_sync_disabled_for_tests until_reboot <nul >nul 2>&1 & call :_dcfgsync_verify until_reboot & echo  Press any key . . . & pause >nul & goto tw_dcfgsync)
if "!dc!"=="3" (
    echo.
    echo  %y%Warning:%w% persistent stays frozen across reboot until you pick [1].
    echo    [Y] Freeze DeviceConfig sync permanently    [N] Cancel
    rem Ctrl+C makes choice return 0; treat it as No.
    choice /c:YN /n >nul
    if errorlevel 2 goto tw_dcfgsync
    if not errorlevel 1 goto tw_dcfgsync
    call :_tw_undo_dcfgsync
    adb shell device_config set_sync_disabled_for_tests persistent <nul >nul 2>&1
    call :_dcfgsync_verify persistent
    echo  Press any key . . .
    pause >nul
    goto tw_dcfgsync
)
if "!dc!"=="4" goto tweaks
goto tw_dcfgsync

:tw_clock
cls
title Clock Seconds
call :logo
echo.
:: clock_seconds is a live SystemUI tunable, so changes apply at once.
:: Values come from the device: strip their quotes, then echo them inside quotes.
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
call :_noin tc || goto dcx_noinput
if not defined tc goto tw_clock
if "!tc!"=="1" (call :_tw_undo_add secure clock_seconds & adb shell settings put secure clock_seconds 1 <nul & goto tw_clock)
if "!tc!"=="2" (call :_tw_undo_add secure clock_seconds & adb shell settings put secure clock_seconds 0 <nul & goto tw_clock)
if "!tc!"=="3" (call :_tw_undo_add secure clock_seconds & adb shell settings delete secure clock_seconds >nul 2>&1 <nul & goto tw_clock)
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
call :_noin tb || goto dcx_noinput
if not defined tb goto tw_batpct
if "!tb!"=="1" (call :_tw_undo_add system status_bar_show_battery_percent & adb shell settings put system status_bar_show_battery_percent 1 <nul & goto tw_batpct)
if "!tb!"=="2" (call :_tw_undo_add system status_bar_show_battery_percent & adb shell settings put system status_bar_show_battery_percent 0 <nul & goto tw_batpct)
if "!tb!"=="3" (call :_tw_undo_add system status_bar_show_battery_percent & adb shell settings delete system status_bar_show_battery_percent >nul 2>&1 <nul & goto tw_batpct)
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
call :_noin sv || goto dcx_noinput
if not defined sv goto tw_safevol
if "!sv!"=="1" goto tw_safevol_off
if "!sv!"=="2" (call :_tw_undo_add global audio_safe_volume_state & adb shell settings put global audio_safe_volume_state 3 <nul & goto tw_safevol)
if "!sv!"=="3" (call :_tw_undo_add global audio_safe_volume_state & adb shell settings delete global audio_safe_volume_state >nul 2>&1 <nul & goto tw_safevol)
if "!sv!"=="4" goto tw_safevol_dose
if "!sv!"=="5" goto tw_safevol_csdoff
if "!sv!"=="6" goto tweaks
goto tw_safevol

:tw_safevol_off
call :_tw_undo_add global audio_safe_volume_state
echo.
call :_act_reset
call :_put_chk global audio_safe_volume_state 2
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  State set to 2 ^(inactive^). Takes effect at the NEXT boot.
echo  Re-run this after each reboot if you want the cap to stay off.
set "rb=" & set /p rb="Reboot device now? (y = yes, anything else = back) >> "
call :_noin rb || goto dcx_noinput
if /i "!rb!"=="y" adb reboot <nul
goto tw_safevol

:tw_safevol_dose
if %SDK% LSS 34 (
    echo [%r%^^!%w%] Needs Android 14 or newer - this device reports API %SDK%.
    timeout /t 2 /nobreak >nul
    goto tw_safevol
)
call :_act_reset
adb shell cmd audio set-sound-dose-value 0.0 <nul
call :_act_rc !errorlevel! "accumulated sound dose reset to 0"
call :_act_summary
if "%DCX_VFAIL%"=="0" echo  Applies live.
echo Press Any Button To Go Back
pause >nul
goto tw_safevol

:tw_safevol_csdoff
if %SDK% LSS 34 (
    echo [%r%^^!%w%] Needs Android 14 or newer - this device reports API %SDK%.
    timeout /t 2 /nobreak >nul
    goto tw_safevol
)
:: Only matters where CSD is available-but-not-enforced; harmless elsewhere.
call :_tw_undo_add secure audio_safe_csd_as_a_feature_enabled
call :_act_reset
call :_put_chk secure audio_safe_csd_as_a_feature_enabled 0
call :_act_summary
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
call :_noin tx || goto dcx_noinput
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
call :_noin EXP_FLT || goto dcx_noinput
if not defined EXP_FLT goto tw_exp_list_go
set "EXP_FLT=!EXP_FLT:"=!"
if not defined EXP_FLT goto tw_exp_list_go
call :_tw_safechk EXP_FLT || goto tw_exp_bad
echo(!EXP_FLT!| findstr /r /x /c:"[a-zA-Z0-9_.-][a-zA-Z0-9_.-]*" >nul || goto tw_exp_bad

:tw_exp_list_go
echo  ---- %EXP_NS% ----
:: To a file with an end marker first: piped straight to more, a phone that stopped answering
:: printed the same empty table as no match.
adb shell "settings list %EXP_NS% && echo _DCXEND" <nul >"!DCX_TMP!\exp_list.txt" 2>nul
findstr /b /c:"_DCXEND" "!DCX_TMP!\exp_list.txt" >nul 2>&1 || (echo  [%r%^^!%w%] The phone did not answer, so nothing could be listed. & goto tw_exp_list_end)
if defined EXP_FLT (
    findstr /v /b /c:"_DCXEND" "!DCX_TMP!\exp_list.txt" | findstr /i /c:"%EXP_FLT%" | more
) else (
    findstr /v /b /c:"_DCXEND" "!DCX_TMP!\exp_list.txt" | more
)

:tw_exp_list_end
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
:: No output means the phone did not answer: an unset key reads "null".
if not defined EXP_OLD goto tw_exp_noans
:: Device values may hold cmd metacharacters: strip quotes, then echo inside quotes.
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
if not defined EXP_OLD goto tw_exp_noans
set "EXP_OLD=!EXP_OLD:"=!"
echo  Current value: "!EXP_OLD!"
set "EXP_VAL=" & set /p EXP_VAL="New value (blank = cancel) >> "
call :_noin EXP_VAL || goto dcx_noinput
if not defined EXP_VAL goto tw_explorer
set "EXP_VAL=!EXP_VAL:"=!"
if not defined EXP_VAL goto tw_explorer
call :_tw_safechk EXP_VAL || goto tw_exp_bad
echo(!EXP_VAL!| findstr /r /x /c:"[a-zA-Z0-9_.,:/=+-][a-zA-Z0-9_.,:/=+-]*" >nul || goto tw_exp_bad
echo.
echo  Command: adb shell settings put %EXP_NS% %EXP_KEY% !EXP_VAL!
set "ok=" & set /p ok="Run it? (y = yes, anything else = cancel) >> "
call :_noin ok || goto dcx_noinput
if /i not "!ok!"=="y" goto tw_explorer
call :_tw_undo_add %EXP_NS% %EXP_KEY%
adb shell settings put %EXP_NS% %EXP_KEY% !EXP_VAL! <nul
set "EXP_NEW="
for /f "delims=" %%v in ('adb shell settings get %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do set "EXP_NEW=%%v"
if not defined EXP_NEW goto tw_exp_put_noback
set "EXP_NEW=!EXP_NEW:"=!"
echo  Read-back: %EXP_NS% %EXP_KEY% = "!EXP_NEW!"
goto tw_exp_put_end

:tw_exp_put_noback
echo  [%y%WARN%w%] Read-back: the phone did not answer, so the new value could not be checked.

:tw_exp_put_end
echo  Undo script: !EXP_UNDO!
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
if not defined EXP_OLD goto tw_exp_noans
set "EXP_OLD=!EXP_OLD:"=!"
echo  Current value: "!EXP_OLD!"
echo.
echo  Command: adb shell settings delete %EXP_NS% %EXP_KEY%
set "ok=" & set /p ok="Run it? (y = yes, anything else = cancel) >> "
call :_noin ok || goto dcx_noinput
if /i not "!ok!"=="y" goto tw_explorer
call :_tw_undo_add %EXP_NS% %EXP_KEY%
for /f "delims=" %%i in ('adb shell settings delete %EXP_NS% %EXP_KEY% 2^>nul ^<nul') do echo  %%i
echo  Undo script: !EXP_UNDO!
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_noans
echo.
echo [%r%^^!%w%] The phone did not answer, so %EXP_NS% %EXP_KEY% could not be read. Nothing was changed.
echo  Press any key . . .
pause >nul
goto tw_explorer

:tw_exp_bad
echo [%r%^^!%w%] Not allowed - stick to letters, digits and _ . , : / = + -
timeout /t 2 /nobreak >nul
goto tw_explorer
:: -------------------------------------------------------------------
:: Explorer helpers. _tw_askns / _tw_askkey set EXP_NS / EXP_KEY; empty = cancelled or invalid.
:: -------------------------------------------------------------------
:_tw_askns
set "EXP_NS="
set "tn=" & set /p tn="Namespace (1=system 2=secure 3=global, blank=cancel) >> "
call :_noin tn || goto dcx_noinput
if "!tn!"=="1" set "EXP_NS=system"
if "!tn!"=="2" set "EXP_NS=secure"
if "!tn!"=="3" set "EXP_NS=global"
exit /b

:_tw_askkey
set "EXP_KEY="
set "tk=" & set /p tk="Key name (blank = cancel) >> "
call :_noin tk || goto dcx_noinput
if not defined tk exit /b
set "tk=!tk:"=!"
if not defined tk exit /b
call :_tw_safechk tk || exit /b
echo(!tk!| findstr /r /x /c:"[a-zA-Z0-9_.-][a-zA-Z0-9_.-]*" >nul || exit /b
set "EXP_KEY=!tk!"
exit /b

:_tw_safechk
:: Arg 1 = NAME of a variable, callers strip double quotes first. errorlevel 1 if the value holds
:: an ampersand, pipe, angle bracket, caret or quote. Each test sits inside a quoted comparison so
:: the char never reaches command position. The caret is refused because a value read with percent
:: expansion that ends in one continues the line, and a pipe's child cmd drops it unseen.
if not defined %~1 exit /b 1
if not "!%~1:^=_!"=="!%~1!" exit /b 1
if not "!%~1:&=_!"=="!%~1!" exit /b 1
if not "!%~1:|=_!"=="!%~1!" exit /b 1
if not "!%~1:<=_!"=="!%~1!" exit /b 1
if not "!%~1:>=_!"=="!%~1!" exit /b 1
:: A quote would end the quoted comparison, so strip-and-compare through a temp instead.
:: Keep it: a findstr probe on a percent-expanded value would accept a value with a quote.
set "_twq=!%~1!"
set _twz=!_twq:"=!
if not "!_twz!"=="!_twq!" exit /b 1
exit /b 0

:_tw_pctbang
:: Arg 1 = NAME of a variable. errorlevel 1 if its value holds a percent sign or exclamation mark.
:: Only meaningful if it was filled with delayed expansion OFF. Pipe-free on purpose; eol=percent
:: keeps a leading char visible, and the # stops for /f dropping a trailing CR before the compare.
setlocal EnableDelayedExpansion
if not defined %~1 exit /b 0
set "_tpb="
for /f "eol=%% delims=%%!" %%x in ("!%~1!#") do set "_tpb=%%x"
if not "!_tpb!"=="!%~1!#" exit /b 1
exit /b 0

:_tw_wb_get
:: Args: ns, key, variable to fill, flag variable. For editors that write back the list they read.
:: Prints the value and fills arg 3 with it, null if unset. A quote or bang in it leaves arg 3
:: empty and sets arg 4; no answer from the phone leaves both empty, errorlevel 1.
:: Read with delayed expansion OFF and no eol, or bangs become PC vars.
setlocal DisableDelayedExpansion
set "_wbv="
for /f delims^=^ eol^= %%v in ('adb shell settings get %~1 %~2 2^>nul ^<nul') do for /f delims^=^ eol^= %%w in ("%%v") do set "_wbv=%%w"
if not defined _wbv goto _tw_wb_unread
setlocal EnableDelayedExpansion
echo  %~2 (%~1) = "!_wbv!"
set "_wbq=!_wbv:"=!"
if not "!_wbq!"=="!_wbv!" goto _tw_wb_odd
set "_wb1="
for /f "eol=! delims=!" %%x in ("!_wbv!") do set "_wb1=%%x"
if not "!_wb1!"=="!_wbv!" goto _tw_wb_odd
for /f "eol=! delims=" %%x in ("!_wbv!") do endlocal & endlocal & set "%~3=%%x" & set "%~4="
exit /b 0

:_tw_wb_odd
endlocal & endlocal & set "%~3=" & set "%~4=1"
exit /b 0

:_tw_wb_unread
echo  %~2 (%~1) - the phone did not answer, so the list was not read.
endlocal & set "%~3=" & set "%~4="
exit /b 1

:_tw_undo_ensure
:: Lazily creates the session undo .bat: :dcx_do and :dcx_report up top, then a growing :dcx_main.
:: Restore lines go in before the trailing goto :dcx_report, so the file always runs.
:: If the file was deleted, a new one is started with a warning.
set "_tw_ue_hold="
:: One file per phone: the file is tagged for the phone it started on, and only restores there.
if defined EXP_UNDO if exist "!EXP_UNDO!" call :_tw_undo_samephone && exit /b 0
if defined EXP_UNDO set "_tw_ue_hold=1"
if defined EXP_UNDO echo  [%y%WARN%w%] The session undo file is gone - starting a new one.
if defined EXP_UNDO echo         Changes made before now are no longer undoable from it.
:: A new file holds nothing yet: clear the _TWSEEN_ marks, or writes would skip as recorded.
for /f "delims==" %%v in ('set _TWSEEN_ 2^>nul') do set "%%v="
if not exist "!BACKUPDIR!" mkdir "!BACKUPDIR!"
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
set "EXP_UNDO=!BACKUPDIR!\dcx_explorer_undo_%TS%.bat"
call :_bk_write_adb_boot EXP_UNDO
set "_TW_UNDO_SER=!_bk_ser!"
if defined _bk_untagged set "_tw_ue_hold=1"
(
    echo :: DCX Settings-Explorer / Tweaks undo - restores values before writes.
    echo :: Safe to re-run. Uses %%ADB%% from the header ^(not bare adb^).
    echo :: Labels BEFORE :dcx_main so appended call :dcx_do lines stay in :dcx_main.
    echo goto :dcx_main
    echo.
    echo :dcx_do
    echo :: Runs one restore command and records whether it landed. Uses %%ADB%%
    echo :: from the header ^(not bare adb - this file is not next to adb\^).
    echo :: The command arrives in DCX_CMD rather than as an argument: CALL re-expands its
    echo :: arguments, and that second parse used to eat the phone's own values - a ringtone
    echo :: URI's %%%%20 became this file's empty second argument ^(Over%%%%20the%%%%20Horizon
    echo :: restored as Over0the0Horizon^) and a ^^ came back doubled.
    echo if defined DCX_CMD goto :dcx_do_run
    echo echo   [FAIL] a restore line is missing its command - this file may be truncated
    echo set /a DCX_FAIL+=1
    echo goto :eof
    echo :dcx_do_run
    echo "%%ADB%%" shell "%%DCX_CMD%%" ^>nul 2^>^&1
    echo set "DCX_RC=%%errorlevel%%"
    echo if not "%%DCX_RC%%"=="0" goto :dcx_do_fail
    echo set /a DCX_OK+=1
    echo set "DCX_CMD="
    echo goto :eof
    echo :dcx_do_fail
    echo set /a DCX_FAIL+=1
    echo echo   [FAIL] "%%DCX_CMD%%"
    echo set "DCX_CMD="
    echo goto :eof
    echo.
    echo :dcx_hold
    echo if defined DCX_CP0 chcp %%DCX_CP0%% ^>nul 2^>^&1
    echo if defined DCX_NOPAUSE exit /b 0
    echo echo.
    echo echo ----------------------------------------
    echo echo Press any key to close this window . . .
    echo pause
    echo exit /b 0
    echo.
    echo :dcx_report
    echo echo.
    echo if "%%DCX_FAIL%%"=="0" ^(
    echo     echo [OK] Restored %%DCX_OK%% settings, none failed.
    echo ^) else ^(
    echo     echo [WARN] %%DCX_OK%% restored, %%DCX_FAIL%% FAILED - listed above.
    echo ^)
    echo echo.
    echo call :dcx_hold
    echo exit /b %%DCX_FAIL%%
    echo.
    echo :dcx_main
    echo set "DCX_OK=0" ^& set "DCX_FAIL=0"
    echo goto :dcx_report
) >> "!EXP_UNDO!"
>"!BACKUPDIR!\dcx_last_undo.txt" echo !EXP_UNDO!
:: Hold once so these WARNs, and the one from :_bk_write_adb_boot, survive the caller's next cls.
if defined _tw_ue_hold echo         Press any key to continue . . .
if defined _tw_ue_hold pause >nul
exit /b 0

:_tw_undo_samephone
:: errorlevel 0 when the phone in use is the one the session undo file was started for, or that
:: cannot be told. Otherwise it says so and drops EXP_UNDO, so the caller starts a new file.
if not defined _TW_UNDO_SER exit /b 0
set "_tus="
for /f "delims=" %%s in ('adb get-serialno 2^>nul') do set "_tus=%%s"
if not defined _tus exit /b 0
if /i "!_tus!"=="unknown" exit /b 0
if /i "!_tus!"=="!_TW_UNDO_SER!" exit /b 0
echo  [%b%i%w%] Another phone or connection is in use now ^(!_tus!^): changes from here go into a
echo        new session undo file. The earlier one stays in dcx_backups for the other phone.
set "_tw_ue_hold=1"
set "EXP_UNDO="
exit /b 1

:_tw_undo_add
:: Capture settings namespace/key into the session undo script before a write.
:: Only the FIRST capture per key counts, so undo restores the original, not the previous value.
:: Tracked in _TWSEEN_ns_key variables, not read from the file; :_tw_undo_ensure clears them.
call :_tw_undo_ensure
if defined _TWSEEN_%~1_%~2 exit /b 0
call :_tw_undo_prep || goto _tw_undo_broken
set "_TWSEEN_%~1_%~2=1"
>>"!EXP_UNDO!" echo :: DCX_KEY settings %~1 %~2
:: An unanswered read leaves only a DCX_SKIP comment: unmark the key so the next write tries again.
call :_bk_settings %~1 %~2 EXP_UNDO || set "_TWSEEN_%~1_%~2="
call :_tw_undo_finish
exit /b

:_tw_undo_dcfg
:: device_config twin of :_tw_undo_add: namespace, key. First capture wins, as above.
call :_tw_undo_ensure
if defined _TWSEEN_dc_%~1_%~2 exit /b 0
call :_tw_undo_prep || goto _tw_undo_broken
set "_TWSEEN_dc_%~1_%~2=1"
>>"!EXP_UNDO!" echo :: DCX_KEY device_config %~1 %~2
call :_bk_devcfg %~1 %~2 EXP_UNDO || set "_TWSEEN_dc_%~1_%~2="
call :_tw_undo_finish
exit /b

:_tw_undo_dcfgsync
:: Capture DeviceConfig sync mode into the same undo script. First capture wins, as above.
call :_tw_undo_ensure
if defined _TWSEEN_dcfgsync exit /b 0
call :_tw_undo_prep || goto _tw_undo_broken
set "_TWSEEN_dcfgsync=1"
>>"!EXP_UNDO!" echo :: DCX_KEY dcfgsync
:: Unread: unmark, so the next change tries again.
call :_bk_dcfgsync EXP_UNDO || set "_TWSEEN_dcfgsync="
call :_tw_undo_finish
exit /b

:_tw_undo_bgm
:: %1 = package: both background app-ops and its user Doze allowlist entry. First capture wins,
:: per item: an item the phone did not answer stays unmarked, so the next change tries it again.
:: errorlevel 0 recorded (now or earlier), 1 the undo file could not be updated (warned),
:: 2 not recorded - the phone did not answer, or no scratch folder. Callers then change nothing.
call :_tw_undo_ensure
if defined _TWSEEN_bgm_%~1_any if defined _TWSEEN_bgm_%~1_run if defined _TWSEEN_bgm_%~1_wl exit /b 0
:: The answer files go where App check keeps its own; outside App check that folder is gone.
set "_acd=!DCX_TMP!\appcheck"
if not exist "!_acd!\" md "!_acd!" >nul 2>&1
if not exist "!_acd!\" (echo [%r%^^!%w%] Could not create the scratch folder !_acd!. & exit /b 2)
call :_tw_undo_prep || goto _tw_undo_broken
>>"!EXP_UNDO!" echo :: DCX_KEY appops+deviceidle %~1
if not defined _TWSEEN_bgm_%~1_any call :_ac_undo_op %~1 RUN_ANY_IN_BACKGROUND && set "_TWSEEN_bgm_%~1_any=1"
if not defined _TWSEEN_bgm_%~1_run call :_ac_undo_op %~1 RUN_IN_BACKGROUND && set "_TWSEEN_bgm_%~1_run=1"
if not defined _TWSEEN_bgm_%~1_wl call :_ac_undo_wl %~1 && set "_TWSEEN_bgm_%~1_wl=1"
call :_tw_undo_finish
if not defined _TWSEEN_bgm_%~1_any exit /b 2
if not defined _TWSEEN_bgm_%~1_run exit /b 2
if not defined _TWSEEN_bgm_%~1_wl exit /b 2
exit /b 0

:_tw_undo_broken
:: Reached when :_tw_undo_prep failed. An append now would land after goto :dcx_report and never
:: run, so skip it and warn that this change is not undoable.
echo  [%y%WARN%w%] Could not update the undo script - this change will NOT be recorded.
echo         Check !BACKUPDIR! is writable ^(antivirus / Controlled
echo         Folder Access are the usual cause^).
:: Hold: most callers redraw their screen with cls straight after the write.
echo         Press any key to continue . . .
pause >nul
exit /b 1

:_tw_undo_prep
:: Drop the trailing "goto :dcx_report" under :dcx_main so the next
:: call :dcx_do line is appended inside :dcx_main ^(not after :dcx_hold^).
if not defined EXP_UNDO exit /b 1
if not exist "!EXP_UNDO!" exit /b 1
:: The .tmp exists even when findstr fails: trust it only if it still holds :dcx_main.
del "!EXP_UNDO!.tmp" > nul 2>&1
findstr /v /b /c:"goto :dcx_report" "!EXP_UNDO!" > "!EXP_UNDO!.tmp" 2>nul
findstr /b /c:":dcx_main" "!EXP_UNDO!.tmp" >nul 2>&1 || goto _tw_undo_prep_fail
move /y "!EXP_UNDO!.tmp" "!EXP_UNDO!" >nul || goto _tw_undo_prep_fail
exit /b 0

:_tw_undo_prep_fail
del "!EXP_UNDO!.tmp" > nul 2>&1
exit /b 1

:_tw_undo_finish
>>"!EXP_UNDO!" echo goto :dcx_report
exit /b 0

:tw_snapshot
cls
title Settings Snapshot
call :logo
if not exist "!SNAPDIR!" mkdir "!SNAPDIR!"
echo.
echo  Dump all three settings tables, poke something in the device UI,
echo  dump again, diff - and you know exactly which key that toggle writes.
echo  Folder: !SNAPDIR!
echo.
echo    %g%[%w%1%g%]%w% Take a snapshot now (system + secure + global)
echo    %g%[%w%2%g%]%w% Diff the two most recent snapshots
echo    %g%[%w%3%g%]%w% Open snapshots folder
echo    %g%[%w%4%g%]%w% Back
set "sn=" & set /p sn="Choose An Option >> "
call :_noin sn || goto dcx_noinput
if not defined sn goto tw_snapshot
if "!sn!"=="1" goto tw_snap_take
if "!sn!"=="2" goto tw_snap_diff
if "!sn!"=="3" (start "" "!SNAPDIR!" & goto tw_snapshot)
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
:: find /v re-terminates adb's LF-only lines as CRLF so fc works; sort gives a stable key order.
for %%n in (system secure global) do (
    adb shell settings list %%n <nul 2>nul | find /v "" | sort > "!SNAPDIR!\%%n_%TS%.txt"
)
:: The pipe's status is sort's, so an empty file is how a dump from a phone that is gone shows.
:: Such a file is removed: Diff would read it as every key deleted.
set "_snbad=0"
for %%n in (system secure global) do for %%f in ("!SNAPDIR!\%%n_%TS%.txt") do (
    set "_snz="
    if exist "%%~f" set "_snz=%%~zf"
    if not defined _snz set /a _snbad+=1
    if "!_snz!"=="0" (set /a _snbad+=1 & del "%%~f" >nul 2>&1)
)
if not "!_snbad!"=="0" echo  [%y%WARN%w%] !_snbad! of 3 tables came back empty - the phone did not answer. Those files were removed.
if "!_snbad!"=="3" goto _tw_snap_none
echo  Done:
dir /b "!SNAPDIR!\*_%TS%.txt"
echo  Press any key . . .
pause >nul
goto tw_snapshot

:_tw_snap_none
echo  Nothing was saved. Check the connection and take the snapshot again.
echo  Press any key . . .
pause >nul
goto tw_snapshot

:tw_snap_diff
set "SNP1="
set "SNP2="
for /f "delims=" %%f in ('dir /b /o-d /a-d "%%SNAPDIR%%\global_*.txt" 2^>nul') do (
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
set "DIFFOUT=!SNAPDIR!\diff_%TS%.txt"
> "!DIFFOUT!" echo DCX settings diff:  %TSOLD%  -^>  %TSNEW%
for %%n in (system secure global) do (
    >>"!DIFFOUT!" echo.
    >>"!DIFFOUT!" echo ===== %%n =====
    set "_UDA=!SNAPDIR!\%%n_%TSOLD%.txt"
    set "_UDB=!SNAPDIR!\%%n_%TSNEW%.txt"
    set "_UDO=!DIFFOUT!" & set "_UDM=add"
    call :_udiff
)
cls
call :logo
echo  Comparing %TSOLD%  (older)
echo         to %TSNEW%  (newer)
echo.
more < "!DIFFOUT!"
echo.
echo  Saved to: !DIFFOUT!
echo    %g%[%w%1%g%]%w% Open in Notepad
echo    %g%[%w%2%g%]%w% Back
set "sd=" & set /p sd="Choose An Option >> "
call :_noin sd || goto dcx_noinput
if "!sd!"=="1" (start "" notepad "!DIFFOUT!" & goto tw_snapshot)
if "!sd!"=="2" goto tw_snapshot
goto tw_snapshot
:: ===================================================================
:: Tier 2: icon blacklist, demo mode, heads-up, font scale, long-press timeout, stay-awake,
:: night modes, profiles. Animation scales belong to Optimize - Animation Speed.
:: ===================================================================
:tw_icons
cls
title Icon Blacklist
call :logo
echo.
set "IBCUR="
call :_tw_wb_get secure icon_blacklist IBCUR IBODD
:: Flag as odd a list the plain for below would change: * and ? expand as wildcards, a caret is
:: lost, and ; = and space turn into commas. The caret is doubled because the line holds a bang.
set "_ibw="
if defined IBCUR for /f "eol=* delims=*?^^;= " %%x in ("!IBCUR!") do set "_ibw=%%x"
if defined IBCUR if not "!_ibw!"=="!IBCUR!" set "IBODD=1"
echo  A comma-separated list of status bar slots to hide. Applies live on
echo  AOSP-based status bars. Slot names are OEM-dependent - an unknown
echo  name is simply ignored by SystemUI, it does not break anything.
echo.
echo    %g%[%w%1%g%]%w% Hide an icon
echo    %g%[%w%2%g%]%w% Show an icon again
echo    %g%[%w%3%g%]%w% Clear the list (delete key - every icon returns)
echo    %g%[%w%4%g%]%w% Back
set "ic=" & set /p ic="Choose An Option >> "
call :_noin ic || goto dcx_noinput
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
:: Some icons answer to two names across versions, so those entries write both.
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
call :_noin IBSEL || goto dcx_noinput
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
call :_noin IBTOK || goto dcx_noinput
if not defined IBTOK goto tw_ib_add
set "IBTOK=!IBTOK:"=!"
if not defined IBTOK goto tw_ib_add
call :_tw_safechk IBTOK || goto tw_ib_bad
echo(!IBTOK!| findstr /r /x /c:"[a-z0-9_,][a-z0-9_,]*" >nul || goto tw_ib_bad
goto tw_ib_addgo

:tw_ib_addgo
if defined IBODD goto tw_ib_odd
if not defined IBCUR goto tw_ib_unread
call :_tw_undo_add secure icon_blacklist
:: Rebuild without the tokens being added, so re-hiding cannot duplicate; IBTOK may hold several.
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
if defined IBODD goto tw_ib_odd
if not defined IBCUR goto tw_ib_unread
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
call :_noin IBPICK || goto dcx_noinput
if not defined IBPICK goto tw_ib_del
if "!IBPICK!"=="0" goto tw_icons
call :_tw_safechk IBPICK || goto tw_ib_del
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

:tw_ib_unread
echo.
echo [%r%^^!%w%] The list was not read when this screen opened, so nothing was changed. The
echo        screen reads it again now.
timeout /t 4 /nobreak >nul
goto tw_icons

:tw_ib_odd
echo.
echo  %y%DCX will not rewrite this list%w% - it holds a ^^!, a * or ?, or a double quote.
echo  Edited here it would not be the list the phone has: cmd reads ^^!NAME^^! as a variable
echo  on this PC and * or ? as file names, and a double quote would be lost.
echo  [3] still clears it; or edit it on the phone.
timeout /t 6 /nobreak >nul
goto tw_icons

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
echo    (1 = pop-ups shown; 0 OR UNSET = notifications go straight to the shade)
echo  Applies to every app at once. Per-app control lives in the device's
echo  own notification settings, not here.
echo.
echo    %g%[%w%1%g%]%w% Enable pop-ups
echo    %g%[%w%2%g%]%w% Disable pop-ups
echo    %g%[%w%3%g%]%w% Delete the key - this turns pop-ups OFF, it is not a reset
echo    %g%[%w%4%g%]%w% Back
echo.
echo  %y%Note:%w% SystemUI reads this key with a default of OFF, so deleting it is the
echo  same as [2] rather than "back to how the phone shipped" - phones ship with the
echo  key already written to 1. Use [1] if you want pop-ups back.
set "hu=" & set /p hu="Choose An Option >> "
call :_noin hu || goto dcx_noinput
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
call :_noin fs || goto dcx_noinput
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
call :_noin FSNEW || goto dcx_noinput
if not defined FSNEW goto tw_font
set "FSNEW=!FSNEW:"=!"
if not defined FSNEW goto tw_font
:: A locale comma decimal, like 1,15, becomes a dot before it reaches adb.
set "FSNEW=!FSNEW:,=.!"
call :_tw_safechk FSNEW || goto tw_font_bad
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
call :_noin lpt || goto dcx_noinput
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
call :_noin LPTNEW || goto dcx_noinput
if not defined LPTNEW goto tw_lpt
set "LPTNEW=!LPTNEW:"=!"
if not defined LPTNEW goto tw_lpt
call :_tw_safechk LPTNEW || goto tw_lpt_bad
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
echo    %g%[%w%8%g%]%w% Delete the key - Android then uses AC only, the same as [2]
echo    %g%[%w%9%g%]%w% Back
set "saw=" & set /p saw="Choose An Option >> "
call :_noin saw || goto dcx_noinput
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
call :_noin SAWNEW || goto dcx_noinput
if not defined SAWNEW goto tw_stay
set "SAWNEW=!SAWNEW:"=!"
if not defined SAWNEW goto tw_stay
call :_tw_safechk SAWNEW || goto tw_stay_bad
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
:: A ROM that locks night mode ignores the command quietly; the mode shown above is the read-back.
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
call :_noin nm || goto dcx_noinput
if not defined nm goto tw_night
:: cmd uimode night writes secure ui_night_mode, so that is the key captured for undo.
if "!nm!"=="1" (call :_tw_undo_add secure ui_night_mode & adb shell cmd uimode night yes <nul & timeout /t 1 /nobreak >nul & goto tw_night)
if "!nm!"=="2" (call :_tw_undo_add secure ui_night_mode & adb shell cmd uimode night no <nul & timeout /t 1 /nobreak >nul & goto tw_night)
if "!nm!"=="3" (call :_tw_undo_add secure ui_night_mode & adb shell cmd uimode night auto <nul & timeout /t 1 /nobreak >nul & goto tw_night)
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
call :_noin NDT || goto dcx_noinput
if not defined NDT goto tw_night
set "NDT=!NDT:"=!"
if not defined NDT goto tw_night
call :_tw_safechk NDT || goto tw_night_bad
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
call :_noin dm || goto dcx_noinput
if not defined dm goto tw_demo
if "!dm!"=="1" goto tw_demo_enter
if "!dm!"=="2" goto tw_demo_exit
if "!dm!"=="3" goto tw_demo_clock
if "!dm!"=="4" goto tweaks
goto tw_demo

:tw_demo_enter
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
call :_noin DMH || goto dcx_noinput
if not defined DMH goto tw_demo
set "DMH=!DMH:"=!"
if not defined DMH goto tw_demo
call :_tw_safechk DMH || goto tw_demo_bad
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
:: Profiles: plain text files of settings keys, editable and shareable without DCX.
:: -------------------------------------------------------------------
:tw_profile
cls
title Profiles
call :logo
if not exist "!PROFDIR!" mkdir "!PROFDIR!"
del "!DCX_TMP!\pf_sel.txt" "!DCX_TMP!\pf_preset.txt" "!DCX_TMP!\pf_before.txt" >nul 2>&1
echo.
echo  A profile is a plain text file, one key per line:
echo      namespace^|key^|value      e.g.  global^|audio_safe_volume_state^|2
echo      namespace^|key^|DELETE     removes the key
echo  Lines starting with # are ignored, so you can annotate freely.
echo.
echo  Check compares a profile with the phone and writes nothing. Apply writes
echo  only the keys that differ and reads each one back.
echo  Folder: !PROFDIR!
echo.
echo    %g%[%w%1%g%]%w% Save Tweaks-only profile
echo    %g%[%w%2%g%]%w% Save full stack ^(Tweaks + Battery/Gaming keys^)
echo    %g%[%w%3%g%]%w% Check a profile against the phone
echo    %g%[%w%4%g%]%w% Apply a profile ^(changed keys only^)
echo    %g%[%w%5%g%]%w% Goal presets - Snappier, Longer battery, Easier to read
echo    %g%[%w%6%g%]%w% Re-apply after reboot
echo    %g%[%w%7%g%]%w% Open the profiles folder
echo    %g%[%w%8%g%]%w% Back

:tw_profile_ask
set "pr=" & set /p pr="Choose An Option >> "
call :_noin pr || goto dcx_noinput
if not defined pr goto tw_profile_ask
if "!pr!"=="1" (set "PROFMODE=tweaks" & goto tw_prof_save)
if "!pr!"=="2" (set "PROFMODE=stack" & goto tw_prof_save)
if "!pr!"=="3" (set "PFMODE=check" & goto tw_prof_pick)
if "!pr!"=="4" (set "PFMODE=apply" & goto tw_prof_pick)
if "!pr!"=="5" goto tw_preset
if "!pr!"=="6" goto tw_rearm
if "!pr!"=="7" (start "" "!PROFDIR!" & goto tw_profile)
if "!pr!"=="8" goto settools
goto tw_profile_ask

:tw_prof_save
echo.
:: No carets in a quoted set /p prompt: they print literally, and the quotes already protect it.
set "PROFNAME=" & set /p PROFNAME="Optional name (blank = auto timestamp) >> "
call :_noin PROFNAME || goto dcx_noinput
set "PROFNAME=!PROFNAME:"=!"
:: safechk first: it is pipe-free, and the findstr pipe below would re-parse metachars.
if defined PROFNAME call :_tw_safechk PROFNAME || set "PROFNAME="
if defined PROFNAME (
    echo(!PROFNAME!| findstr /r /x /c:"[a-zA-Z0-9_ .-][a-zA-Z0-9_ .-]*" >nul || (
        echo  %r%Name has unsafe characters - using timestamp instead.%w%
        set "PROFNAME="
    )
)
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
if defined PROFNAME (
    set "PROFF=!PROFDIR!\!PROFNAME!.txt"
) else (
    set "PROFF=!PROFDIR!\profile_%TS%.txt"
)
if defined PROFNAME if exist "!PROFF!" goto _tw_prof_exists

:_tw_prof_write
> "!PROFF!" echo # DCX profile saved %date% %time% mode=!PROFMODE!
>>"!PROFF!" echo # format: namespace^|key^|value   (value DELETE removes the key)
call :_tw_prof_add_tweaks PROFF
if /i "!PROFMODE!"=="stack" call :_tw_prof_add_stack PROFF
echo.
:: A failed redirect sets no errorlevel, and a phone that is gone leaves only comment lines.
if not exist "!PROFF!" goto _tw_prof_nowrite
findstr /v /b /c:"#" "!PROFF!" >nul 2>&1 || goto _tw_prof_nodata
echo  Saved: !PROFF!
echo  Edit it in Notepad to trim it down to just the keys you care about.
echo  Press any key . . .
pause >nul
goto tw_profile

:_tw_prof_exists
echo  !PROFNAME!.txt exists already - perhaps trimmed by hand.
echo    [Y] Replace it    [N] Save under a new timestamped name instead
:: Ctrl+C makes choice return 0: keep the file, as N does.
choice /c:YN /n >nul
if errorlevel 2 (set "PROFF=!PROFDIR!\profile_%TS%.txt" & goto _tw_prof_write)
if not errorlevel 1 (set "PROFF=!PROFDIR!\profile_%TS%.txt" & goto _tw_prof_write)
goto _tw_prof_write

:_tw_prof_nowrite
echo  [%r%^^!%w%] Could not write !PROFF! - check the folder is writable. Nothing was saved.
echo  Press any key . . .
pause >nul
goto tw_profile

:_tw_prof_nodata
del "!PROFF!" >nul 2>&1
echo  [%y%WARN%w%] The phone gave no values - nothing was saved. Check the connection and try again.
echo  Press any key . . .
pause >nul
goto tw_profile

:_tw_prof_add_tweaks
:: Arg 1 = NAME of the variable holding the profile file, passed on by name.
call :_tw_prof_add secure clock_seconds "%~1"
call :_tw_prof_add system status_bar_show_battery_percent "%~1"
call :_tw_prof_add global audio_safe_volume_state "%~1"
call :_tw_prof_add secure audio_safe_csd_as_a_feature_enabled "%~1"
call :_tw_prof_add secure icon_blacklist "%~1"
call :_tw_prof_add global heads_up_notifications_enabled "%~1"
call :_tw_prof_add system font_scale "%~1"
call :_tw_prof_add secure long_press_timeout "%~1"
call :_tw_prof_add global stay_on_while_plugged_in "%~1"
call :_tw_prof_add secure night_display_activated "%~1"
call :_tw_prof_add secure night_display_color_temperature "%~1"
call :_tw_prof_add global sysui_demo_allowed "%~1"
call :_tw_prof_add secure sysui_qs_tiles "%~1"
call :_tw_prof_add secure camera_double_tap_power_gesture_disabled "%~1"
call :_tw_prof_add global charging_sounds_enabled "%~1"
call :_tw_prof_add global sys_storage_threshold_percentage "%~1"
call :_tw_prof_add global low_power_trigger_level "%~1"
call :_tw_prof_add global enable_freeform_support "%~1"
call :_tw_prof_add secure ui_night_mode "%~1"
call :_tw_prof_add secure camera_double_twist_to_flip_enabled "%~1"
call :_tw_prof_add secure camera_gesture_disabled "%~1"
call :_tw_prof_add global charging_vibration_enabled "%~1"
call :_tw_prof_add global sys_storage_threshold_max_bytes "%~1"
call :_tw_prof_add global force_resizable_activities "%~1"
call :_tw_prof_add global default_install_location "%~1"
exit /b

:_tw_prof_add_stack
:: Battery / Gaming keys that Backup round-trips. Arg 1 = NAME of the profile file variable.
>>"!%~1!" echo # --- stack: Battery / Gaming ---
call :_tw_prof_add global window_animation_scale "%~1"
call :_tw_prof_add global transition_animation_scale "%~1"
call :_tw_prof_add global animator_duration_scale "%~1"
call :_tw_prof_add system min_refresh_rate "%~1"
call :_tw_prof_add system peak_refresh_rate "%~1"
call :_tw_prof_add global angle_gl_driver_all_angle "%~1"
call :_tw_prof_add global low_power "%~1"
call :_tw_prof_add global low_power_sticky "%~1"
call :_tw_prof_add global zram_enabled "%~1"
call :_tw_prof_add global wifi_scan_always_enabled "%~1"
call :_tw_prof_add global ble_scan_always_enabled "%~1"
call :_tw_prof_add global hotword_detection_enabled "%~1"
call :_tw_prof_add global always_finish_activities "%~1"
call :_tw_prof_add global package_verifier_enable "%~1"
call :_tw_prof_add global disable_window_blurs "%~1"
call :_tw_prof_add global reduce_motion "%~1"
call :_tw_prof_add secure reduce_motion "%~1"
call :_tw_prof_add secure accessibility_disable_animations "%~1"
call :_tw_prof_add global enable_back_animation "%~1"
call :_tw_prof_add global fancy_ime_animations "%~1"
call :_tw_prof_add secure multi_press_timeout "%~1"
call :_tw_prof_add global tcp_default_init_rwnd "%~1"
call :_tw_prof_add global private_dns_mode "%~1"
call :_tw_prof_add global preferred_network_mode "%~1"
call :_tw_prof_add global preferred_network_mode1 "%~1"
exit /b

:_tw_prof_add
:: Args: ns, key, NAME of the variable holding the profile file. An unset key is saved as DELETE.
:: Read with delayed expansion OFF so a bang survives. The goto exits pop both scopes via exit /b.
:: Empty output means no answer, not null: skip the key rather than write DELETE.
setlocal DisableDelayedExpansion
set "PVAL="
set "PGOT="
:: The inner for /f drops the trailing CR older adb builds leave.
for /f "delims=" %%v in ('adb shell settings get %~1 %~2 2^>nul ^<nul') do set "PGOT=1" & for /f delims^=^ eol^= %%w in ("%%v") do set "PVAL=%%w"
setlocal EnableDelayedExpansion
if not defined PGOT goto _tw_prof_unread
if /i "!PVAL!"=="null" goto _tw_prof_del
:: Skip a value holding a percent sign, exclamation mark or quote: Apply would expand the first two
:: as this PC's variables, and stripping any of them would save a different value.
call :_tw_safechk PVAL || goto _tw_prof_skip
call :_tw_pctbang PVAL || goto _tw_prof_skip
>>"!%~3!" echo %~1^|%~2^|!PVAL!
endlocal
endlocal
exit /b

:_tw_prof_del
>>"!%~3!" echo %~1^|%~2^|DELETE
exit /b

:_tw_prof_skip
>>"!%~3!" echo # %~1^|%~2 skipped - value holds a character DCX will not round-trip
exit /b

:_tw_prof_unread
>>"!%~3!" echo # %~1^|%~2 skipped - the device did not answer, value not captured
exit /b

:tw_prof_pick
cls
title Profiles : !PFMODE!
call :logo
echo.
if not exist "!DCX_TMP!\" goto tw_prof_notmp
call :_pf_list || goto tw_prof_none
echo     %g%[%w%0%g%]%w% Back

:tw_prof_pick_ask
set "PROFSEL=" & set /p PROFSEL="Which profile? >> "
call :_noin PROFSEL || goto dcx_noinput
if not defined PROFSEL goto tw_prof_pick_ask
if "!PROFSEL!"=="0" goto tw_profile
call :_pf_take PROFSEL || goto tw_prof_pick_ask
set "PFFILE=!DCX_TMP!\pf_sel.txt"
echo.
if "!PFMODE!"=="check" goto tw_prof_check
echo  Apply writes only the keys that differ, and reads each one back.
echo    [Y] Apply    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto tw_profile
if not errorlevel 1 goto tw_profile
echo.
call :_pf_run apply
if defined EXP_UNDO echo  Session undo script: !EXP_UNDO!
echo  Press any key . . .
pause >nul
goto tw_profile

:tw_prof_check
echo  Comparing with the phone - nothing is written.
echo.
call :_pf_run check
echo  Press any key . . .
pause >nul
goto tw_profile

:tw_prof_none
echo  No profiles yet - save one first, or drop a .txt into
echo  !PROFDIR!
timeout /t 3 /nobreak >nul
goto tw_profile

:tw_prof_notmp
echo [%r%^^!%w%] DCX's scratch folder could not be made - this screen needs it.
timeout /t 3 /nobreak >nul
goto tw_profile

:_pf_run
:: %1 = check, quiet (differences only) or apply. Reads the profile named by PFFILE.
set "_pf_mode=%~1"
set "_pf_same=0" & set "_pf_diff=0" & set "_pf_unr=0" & set "_pf_skip=0"
if "!_pf_mode!"=="apply" call :_act_reset
:: :_tw_pa_raw looks at each line with delayed expansion off, while a ! is still there to see.
for /f "usebackq eol=# tokens=1-3 delims=|" %%a in ("!PFFILE!") do (
    setlocal DisableDelayedExpansion
    set "_pa_rk=%%a|%%b"
    set "_pa_rv=%%c"
    call :_tw_pa_raw
    if errorlevel 2 (endlocal & set "_pa_odd=key") else if errorlevel 1 (endlocal & set "_pa_odd=val") else (endlocal & set "_pa_odd=")
    set "_pa_ns=%%a"
    set "_pa_key=%%b"
    set "_pa_val=%%c"
    call :_pf_line
)
if "!_pf_mode!"=="quiet" exit /b
echo.
if "!_pf_mode!"=="apply" goto _pf_run_sum
if "!_pf_same!!_pf_diff!!_pf_unr!"=="000" echo [%y%WARN%w%] No namespace^|key^|value line in this profile could be checked.
echo  !_pf_same! match, !_pf_diff! differ, !_pf_unr! not read, !_pf_skip! line^(s^) skipped. Nothing was written.
exit /b

:_pf_run_sum
if not "!_pf_skip!"=="0" echo  !_pf_skip! line^(s^) skipped - see above.
if "!_pf_same!!_pf_diff!!_pf_unr!"=="000" goto _pf_run_none
echo  [%b%i%w%] Read back means stored. A skin can still ignore a key it does not use.
call :_act_summary
exit /b

:_pf_run_none
echo [%y%WARN%w%] No line in this profile could be applied - nothing was written.
exit /b

:_pf_line
call :_pf_valid || goto _pf_l_skip
call :_pf_get !PNS! !PKEY!
set "_pf_now=!PNOW!"
if defined _pg_odd set "_pf_now=(a value with characters DCX will not show)"
if defined _pg_emp set "_pf_now=(empty)"
if defined _pg_unr goto _pf_l_unr
if "!PVAL!"=="DELETE" if /i "!PNOW!"=="null" goto _pf_l_same
if "!PNOW!"=="!PVAL!" goto _pf_l_same
set /a _pf_diff+=1
if "!_pf_mode!"=="apply" goto _pf_l_write
echo  [%y%WARN%w%] !PNS! !PKEY! differs: phone !_pf_now!, profile !PVAL!
exit /b

:_pf_l_same
set /a _pf_same+=1
if "!_pf_mode!"=="quiet" exit /b
if "!_pf_mode!"=="apply" set /a DCX_VOK+=1
echo  [%g%+%w%] !PNS! !PKEY! = !_pf_now!
exit /b

:_pf_l_unr
set /a _pf_unr+=1
if "!_pf_mode!"=="apply" set /a DCX_VFAIL+=1
echo  [%r%^^!%w%] !PNS! !PKEY!: no answer from the phone - not compared
exit /b

:_pf_l_skip
set /a _pf_skip+=1
exit /b

:_pf_l_write
call :_tw_undo_add !PNS! !PKEY!
if "!PVAL!"=="DELETE" goto _pf_l_del
:: One argument, value single-quoted for the phone's sh; the value set holds no quote.
adb shell "settings put !PNS! !PKEY! '!PVAL!'" <nul >nul 2>&1
goto _pf_l_rb

:_pf_l_del
adb shell settings delete !PNS! !PKEY! <nul >nul 2>&1

:_pf_l_rb
set "_pf_rc=!errorlevel!"
set "_pf_was=!_pf_now!"
call :_pf_get !PNS! !PKEY!
set "_pf_now=!PNOW!"
if defined _pg_odd set "_pf_now=(a value with characters DCX will not show)"
if defined _pg_emp set "_pf_now=(empty)"
if defined _pg_unr set "_pf_now=(no answer)"
if defined _pg_unr goto _pf_l_bad
if "!PVAL!"=="DELETE" if /i "!PNOW!"=="null" goto _pf_l_ok
if "!PNOW!"=="!PVAL!" goto _pf_l_ok

:_pf_l_bad
set /a DCX_VFAIL+=1
echo  [%r%^^!%w%] !PNS! !PKEY!: wanted !PVAL!, phone reports !_pf_now! ^(adb exit !_pf_rc!^)
exit /b

:_pf_l_ok
set /a DCX_VOK+=1
if "!PVAL!"=="DELETE" echo  [%g%+%w%] !PNS! !PKEY! deleted   ^(was !_pf_was!^)
if not "!PVAL!"=="DELETE" echo  [%g%+%w%] !PNS! !PKEY! = !PVAL!   ^(was !_pf_was!^)
exit /b

:_pf_valid
:: One line from _pa_ns / _pa_key / _pa_val into PNS / PKEY / PVAL. errorlevel 1 = skipped, reason shown.
set "PNS=!_pa_ns!"
set "PKEY=!_pa_key!"
set "PVAL=!_pa_val!"
:: A profile saved through an older adb ends its lines in CR CR LF; drop the CR.
set "_pv="
if defined PVAL for /f "delims=" %%v in ("!PVAL!") do set "_pv=%%v"
set "PVAL=!_pv!"
if "!_pa_odd!"=="key" goto _tw_pa_oddkey
if not defined PNS goto _tw_pa_short
if not defined PKEY goto _tw_pa_short
:: Sent in lowercase, the name Save writes, whatever case the line uses.
if /i "!PNS!"=="system" (set "PNS=system" & goto _tw_pa_ns_ok)
if /i "!PNS!"=="secure" (set "PNS=secure" & goto _tw_pa_ns_ok)
if /i "!PNS!"=="global" (set "PNS=global" & goto _tw_pa_ns_ok)
echo    skip - unknown namespace: !PNS!
exit /b 1

:_tw_pa_ns_ok
:: Pipe-free whitelists: every allowed character is a delimiter, and eol is one of them.
call :_tw_safechk PKEY || goto _tw_pa_badkey
set "_pabad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-" %%c in ("!PKEY!") do set "_pabad=1"
if defined _pabad goto _tw_pa_badkey
if "!_pa_odd!"=="val" goto _tw_pa_oddval
if /i "!PVAL!"=="DELETE" (set "PVAL=DELETE" & exit /b 0)
if not defined PVAL goto _tw_pa_badval
call :_tw_safechk PVAL || goto _tw_pa_badval
set "_pabad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.,:/=+()-" %%c in ("!PVAL!") do set "_pabad=1"
if defined _pabad goto _tw_pa_badval
exit /b 0

:_tw_pa_short
echo    skip - not a namespace^|key^|value line
exit /b 1

:_tw_pa_badkey
echo    skip - bad key name: !PKEY!
exit /b 1

:_tw_pa_badval
echo    skip - bad or unsafe value for !PKEY!
exit /b 1

:_tw_pa_oddkey
echo    skip - a line whose namespace or key holds %% or ^^! - not applied
exit /b 1

:_tw_pa_oddval
echo    skip - value for !PKEY! holds %% or ^^! - not applied, cmd would read it as a PC variable
exit /b 1

:_tw_pa_raw
:: Called by :_pf_run with delayed expansion OFF. errorlevel 2 = ns or key holds %% or !, 1 = the value does.
call :_tw_pctbang _pa_rk || exit /b 2
call :_tw_pctbang _pa_rv || exit /b 1
exit /b 0

:_pf_list
:: Numbered list of PROFDIR\*.txt, newest first, printed with delayed expansion off so a ! survives.
set "_pf_n=0"
for /f "delims=" %%f in ('dir /b /o-d /a-d "%%PROFDIR%%\*.txt" 2^>nul') do (
    set /a _pf_n+=1
    for /f %%n in ("!_pf_n!") do (
        setlocal DisableDelayedExpansion
        echo     %g%[%w%%%n%g%]%w% %%f
        endlocal
    )
)
if "!_pf_n!"=="0" exit /b 1
exit /b 0

:_pf_take
:: %1 = NAME of the variable holding the typed number. Copies that profile to !DCX_TMP!\pf_sel.txt.
set "_pf_s=!%~1:"=!"
if not defined _pf_s exit /b 1
set "_pf_bad="
for /f "eol=0 delims=0123456789" %%c in ("!_pf_s!") do set "_pf_bad=1"
if defined _pf_bad exit /b 1
del "!DCX_TMP!\pf_sel.txt" >nul 2>&1
set "_pf_c=0"
:: Appended with copy /b: type exits 0 on a file it could not read.
for %%y in ("!DCX_TMP!") do for %%z in ("!PROFDIR!") do for /f "delims=" %%f in ('dir /b /o-d /a-d "%%PROFDIR%%\*.txt" 2^>nul') do (
    set /a _pf_c+=1
    if "!_pf_c!"=="!_pf_s!" (
        setlocal DisableDelayedExpansion
        > "%%~y\pf_sel.txt" echo # from %%f
        copy /y /b "%%~y\pf_sel.txt" + "%%~z\%%f" "%%~y\pf_sel.txt" >nul 2>&1 || (del "%%~y\pf_sel.txt" >nul 2>&1 & echo  Could not read %%f)
        if exist "%%~y\pf_sel.txt" echo  Selected: %%f
        endlocal
    )
)
if not exist "!DCX_TMP!\pf_sel.txt" exit /b 1
exit /b 0

:_pf_get
:: %1 ns %2 key. PNOW = value or null; _pg_unr = no answer; _pg_odd = not shown, PNOW empty (_pg_emp = empty value).
setlocal DisableDelayedExpansion
set "_pgv="
for /f delims^=^ eol^= %%v in ('adb shell settings get %~1 %~2 2^>nul ^<nul') do for /f delims^=^ eol^= %%w in ("%%v") do set "_pgv=%%w"
setlocal EnableDelayedExpansion
if not defined _pgv goto _pf_get_none
set "_pgq=!_pgv:"=!"
if not "!_pgq!"=="!_pgv!" goto _pf_get_odd
set "_pgb="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.,:/=+()-" %%c in ("!_pgv!") do set "_pgb=1"
if defined _pgb goto _pf_get_odd
:: Only the profile value set is left, so this hand-over cannot lose a ! or a ^.
for /f "eol=! delims=" %%x in ("!_pgv!") do endlocal & endlocal & set "PNOW=%%x" & set "_pg_unr=" & set "_pg_odd=" & set "_pg_emp="
exit /b 0

:_pf_get_none
:: An empty value prints an empty line, which for /f skips; the exit code tells it from no answer.
adb shell settings get %~1 %~2 <nul >nul 2>&1
if errorlevel 1 goto _pf_get_unr
endlocal & endlocal & set "PNOW=" & set "_pg_unr=" & set "_pg_odd=1" & set "_pg_emp=1"
exit /b 0

:_pf_get_unr
endlocal & endlocal & set "PNOW=" & set "_pg_unr=1" & set "_pg_odd=" & set "_pg_emp="
exit /b 1

:_pf_get_odd
endlocal & endlocal & set "PNOW=" & set "_pg_unr=" & set "_pg_odd=1" & set "_pg_emp="
exit /b 0
:: -------------------------------------------------------------------
:: Goal presets, built each time from the rules below: each rule depends on the phone.
:: -------------------------------------------------------------------
:tw_preset
cls
title Profiles : goal presets
call :logo
echo.
if not exist "!DCX_TMP!\" goto tw_prof_notmp
echo  Each preset shows every key as now -^> preset before anything is written.
echo  It only moves a key toward the goal, and first saves a before_ profile of
echo  exactly the keys it changes. Applying that file is the undo.
echo.
echo    %g%[%w%1%g%]%w% Snappier        - animations at half length
echo    %g%[%w%2%g%]%w% Longer battery  - saver at 20%%, 30 s timeout, auto brightness, 60 Hz
echo    %g%[%w%3%g%]%w% Easier to read  - larger text, slower long-press, battery %%, contrast
echo    %g%[%w%4%g%]%w% Back

:tw_preset_ask
set "ps=" & set /p ps="Choose An Option >> "
call :_noin ps || goto dcx_noinput
if not defined ps goto tw_preset_ask
if "!ps!"=="1" (set "PSNAME=snappier" & goto tw_ps_build)
if "!ps!"=="2" (set "PSNAME=battery" & goto tw_ps_build)
if "!ps!"=="3" (set "PSNAME=reading" & goto tw_ps_build)
if "!ps!"=="4" goto tw_profile
goto tw_preset_ask

:tw_ps_build
cls
title Profiles : preset !PSNAME!
call :logo
echo.
set "PSF=!DCX_TMP!\pf_preset.txt"
set "PSB=!DCX_TMP!\pf_before.txt"
>"!PSF!" echo # DCX preset !PSNAME!: the keys this phone needs
>"!PSB!" echo # DCX preset !PSNAME! undo: applying this profile puts these keys back
set "_ps_n=0" & set "_ps_unr=0"
echo  Key                              Now          Preset
if "!PSNAME!"=="snappier" goto tw_ps_snap
if "!PSNAME!"=="battery" goto tw_ps_batt
call :_ps_rule system font_scale min 1.3 1.3 DELETE
call :_ps_rule secure long_press_timeout min 1000 1000 DELETE
call :_ps_rule system status_bar_show_battery_percent set 1 1 DELETE
:: Unset means 15 s (PowerManagerService's default), so it is raised too.
call :_ps_rule system screen_off_timeout min 120000 120000 DELETE
call :_ps_rule secure high_text_contrast_enabled set 1 1 DELETE
goto tw_ps_show

:tw_ps_snap
:: A deleted window or animator scale keeps its live value until reboot, so their undo writes 1.0.
call :_ps_rule global window_animation_scale max 0.5 0.5 1.0
call :_ps_rule global transition_animation_scale max 0.5 0.5 DELETE
call :_ps_rule global animator_duration_scale max 0.5 0.5 1.0
goto tw_ps_show

:tw_ps_batt
call :_ps_rule global low_power_trigger_level min 20 20 DELETE
call :_ps_rule system screen_off_timeout max 30000 30000 k
call :_ps_rule system screen_brightness_mode set 1 1 DELETE
:: peak_refresh_rate is read from Android 10 on; on a 60 Hz panel there is nothing to lower.
if %SDK% LSS 29 goto tw_ps_show
call :_ps_hzmax
if not defined _ps_hz echo  refresh rate                     the panel's modes could not be read - left alone
if not defined _ps_hz goto tw_ps_show
if !_ps_hz! LEQ 60 echo  refresh rate                     !_ps_hz! Hz panel - nothing to lower
if !_ps_hz! LEQ 60 goto tw_ps_show
call :_ps_rule system peak_refresh_rate cap 60 60 DELETE
:: The cap is max(min, peak), so a min above 60 goes to 0, its unset default (no floor).
call :_ps_rule system min_refresh_rate max 60 0 k
goto tw_ps_show

:tw_ps_show
echo.
if not "!_ps_unr!"=="0" echo [%r%^^!%w%] !_ps_unr! key^(s^) got no answer from the phone and are left alone.
if "!_ps_n!"=="0" goto tw_ps_none
findstr /l /c:"|low_power_trigger_level|" "!PSF!" >nul 2>&1 && call :_ps_batt_notes
findstr /l /c:"|font_scale|" "!PSF!" >nul 2>&1 && echo  [%b%i%w%] font_scale 1.3 can clip text in some apps.
findstr /l /c:"|high_text_contrast_enabled|" "!PSF!" >nul 2>&1 && echo  [%b%i%w%] Some skins ignore high_text_contrast_enabled.
echo  !_ps_n! key^(s^) will change. The before_ profile is saved first.
echo    [Y] Apply    [N] Cancel
choice /c:YN /n >nul
if errorlevel 2 goto tw_preset
if not errorlevel 1 goto tw_preset
set "TS=%date%_%time%"
set "TS=%TS::=-%"
set "TS=%TS:/=-%"
set "TS=%TS:\=-%"
set "TS=%TS:.=-%"
set "TS=%TS:,=-%"
set "TS=%TS: =_%"
:: Kept by name: :_tw_undo_ensure sets TS again during the apply below.
set "PSUN=before_!PSNAME!_!TS!.txt"
set "PSU=!PROFDIR!\!PSUN!"
if not exist "!PROFDIR!" mkdir "!PROFDIR!"
copy /y "!PSB!" "!PSU!" >nul 2>&1 || goto tw_ps_nosave
echo.
set "PFFILE=!PSF!"
call :_pf_run apply
echo.
echo  Undo this preset: Profiles - Apply - !PSUN!
echo  ^(puts back exactly the keys listed above^)
if defined EXP_UNDO echo  Session undo script ^(the first value of every key DCX changed this session^): !EXP_UNDO!
echo  Press any key . . .
pause >nul
goto tw_preset

:tw_ps_none
if "!_ps_unr!"=="0" echo  [%g%+%w%] Nothing to change - every key already meets this preset.
if not "!_ps_unr!"=="0" echo  Nothing was changed.
echo  Press any key . . .
pause >nul
goto tw_preset

:tw_ps_nosave
echo [%r%^^!%w%] Could not save !PSU! - nothing was changed.
echo  Press any key . . .
pause >nul
goto tw_preset

:_ps_rule
:: %1 ns %2 key %3 max/min/set/cap %4 limit %5 value written %6 if unset: k = meets the goal, else its undo value.
set "_pr_key=%~2"
set "_pr_t=%~4"
call :_pf_get %1 %2
set "_pr_now=!PNOW!"
if defined _pg_unr goto _ps_r_unr
if defined _pg_odd goto _ps_r_odd
if /i not "!PNOW!"=="null" goto _ps_r_cmp
if "%~6"=="k" goto _ps_r_keep
goto _ps_r_take

:_ps_r_cmp
if "%~3"=="set" goto _ps_r_set
call :_ps_x100 PNOW _pr_a
call :_ps_x100 _pr_t _pr_b
if not defined _pr_a goto _ps_r_nan
if "%~3"=="max" if !_pr_a! LEQ !_pr_b! goto _ps_r_keep
if "%~3"=="min" if !_pr_a! GEQ !_pr_b! goto _ps_r_keep
:: cap = max, but 0 means no cap at all.
if "%~3"=="cap" if !_pr_a! GTR 0 if !_pr_a! LEQ !_pr_b! goto _ps_r_keep
goto _ps_r_take

:_ps_r_set
if "!PNOW!"=="!_pr_t!" goto _ps_r_keep

:_ps_r_take
>>"!PSF!" echo %~1^|%~2^|%~5
set "_pr_old=!PNOW!"
if /i "!PNOW!"=="null" set "_pr_old=%~6"
>>"!PSB!" echo %~1^|%~2^|!_pr_old!
set /a _ps_n+=1
set "_pr_new=-> %~5"
goto _ps_row

:_ps_r_keep
set "_pr_new=kept"
goto _ps_row

:_ps_r_unr
set /a _ps_unr+=1
set "_pr_now=no answer"
set "_pr_new=left alone"
goto _ps_row

:_ps_r_odd
set "_pr_now=(other text)"
if defined _pg_emp set "_pr_now=(empty)"
set "_pr_new=left alone - cannot be saved for undo"
goto _ps_row

:_ps_r_nan
set "_pr_new=left alone - not a plain number"

:_ps_row
set "_pr_c=!_pr_key!                                 "
set "_pr_d=!_pr_now!             "
if "!_pr_now:~12!"=="" set "_pr_d=!_pr_d:~0,13!"
echo  !_pr_c:~0,33!!_pr_d!!_pr_new!
exit /b

:_ps_x100
:: %1 = NAME of a plain decimal, %2 = NAME set to it x100, empty if not one. Infinity or 8+ digits = 999999999.
set "%~2="
set "_xv=!%~1!"
if not defined _xv exit /b
if /i "!_xv!"=="Infinity" (set "%~2=999999999" & exit /b)
if "!_xv:~0,1!"=="." exit /b
if not "!_xv:..=!"=="!_xv!" exit /b
set "_xb="
for /f "eol=0 delims=0123456789." %%c in ("!_xv!") do set "_xb=1"
if defined _xb exit /b
set "_xi=" & set "_xf="
for /f "tokens=1,2* delims=." %%a in ("!_xv!") do (set "_xi=%%a" & set "_xf=%%b" & if not "%%c"=="" set "_xb=1")
if defined _xb exit /b
if not defined _xi exit /b
:: Leading zeros go first: set /a reads 08 as octal.
for /f "tokens=* delims=0" %%z in ("!_xi!") do set "_xi=%%z"
if not defined _xi set "_xi=0"
if not "!_xi:~7!"=="" (set "%~2=999999999" & exit /b)
set "_xf=!_xf!00"
set "_xf=!_xf:~0,2!"
for /f "tokens=* delims=0" %%z in ("!_xf!") do set "_xf=%%z"
if not defined _xf set "_xf=0"
set /a "%~2=_xi*100+_xf"
exit /b

:_ps_hzmax
:: _ps_hz = the highest fps= among the display modes dumpsys lists; empty when none could be read.
setlocal DisableDelayedExpansion
set "_hz="
for /f "tokens=2 delims==" %%h in ('adb shell "dumpsys display 2>/dev/null | grep -o 'fps=[0-9]*'" 2^>nul ^<nul') do for /f %%i in ("%%h") do set "_h=%%i" & call :_ps_hz1
endlocal & set "_ps_hz=%_hz%"
exit /b

:_ps_hz1
setlocal EnableDelayedExpansion
set "_hb="
for /f "eol=0 delims=0123456789" %%c in ("!_h!") do set "_hb=1"
if defined _hb exit /b
if not "!_h:~3!"=="" exit /b
if "!_h:~0,1!"=="0" exit /b
set "_hn=!_h!"
if defined _hz if !_hz! GEQ !_h! set "_hn=!_hz!"
endlocal & set "_hz=%_hn%"
exit /b

:_ps_batt_notes
if %SDK% LSS 29 goto _ps_bn_usb
call :_pf_get global automatic_power_save_mode
if "!PNOW!"=="1" echo  [%y%WARN%w%] Battery saver follows your routine on this phone, not a percentage: the
if "!PNOW!"=="1" echo         20%% trigger only counts once it is set to "Based on percentage".

:_ps_bn_usb
echo  [%b%i%w%] Battery saver never turns itself on while the phone charges - a USB cable charges it.
exit /b
:: -------------------------------------------------------------------
:: Re-apply after reboot: one armed profile per phone (ro.serialno), checked once per boot_id.
:: -------------------------------------------------------------------
:tw_rearm
cls
title Profiles : re-apply after reboot
call :logo
echo.
if not exist "!DCX_TMP!\" goto tw_prof_notmp
call :_ra_key || goto tw_rearm_nokey
echo  DCX can check one profile each time this phone connects after a reboot.
echo  Keys that drifted are listed, and re-applied only after you press Y.
echo.
set "_ra_hdr=nothing is armed for this phone"
if exist "!RAF!" set /p "_ra_hdr=" <"!RAF!"
if "!_ra_hdr:~0,2!"=="# " set "_ra_hdr=armed, !_ra_hdr:~2!"
echo  Now: !_ra_hdr!
echo.
echo    %g%[%w%1%g%]%w% Arm a profile for this phone
echo    %g%[%w%2%g%]%w% Turn it off for this phone
echo    %g%[%w%3%g%]%w% Back

:tw_rearm_ask
set "ra=" & set /p ra="Choose An Option >> "
call :_noin ra || goto dcx_noinput
if not defined ra goto tw_rearm_ask
if "!ra!"=="1" goto tw_rearm_pick
if "!ra!"=="2" goto tw_rearm_off
if "!ra!"=="3" goto tw_profile
goto tw_rearm_ask

:tw_rearm_pick
echo.
call :_pf_list || goto tw_prof_none
echo     %g%[%w%0%g%]%w% Back

:tw_rearm_pick_ask
set "RASEL=" & set /p RASEL="Arm which profile? >> "
call :_noin RASEL || goto dcx_noinput
if not defined RASEL goto tw_rearm_pick_ask
if "!RASEL!"=="0" goto tw_rearm
call :_pf_take RASEL || goto tw_rearm_pick_ask
call :_ra_boot || goto tw_rearm_noboot
if not exist "!PROFDIR!\rearm" mkdir "!PROFDIR!\rearm"
copy /y "!DCX_TMP!\pf_sel.txt" "!RAF!" >nul 2>&1 || goto tw_rearm_fail
>"!RAB!" echo !_ra_boot!
set "_ra_old="
if exist "!RAB!" set /p "_ra_old=" <"!RAB!"
if not "!_ra_old!"=="!_ra_boot!" goto tw_rearm_fail
echo.
echo  [%g%+%w%] Armed. After this phone reboots, DCX checks this copy of the profile when
echo      it connects. Edited the profile since? Arm it again to refresh the copy.
echo  Press any key . . .
pause >nul
goto tw_rearm

:tw_rearm_off
del "!RAF!" "!RAB!" >nul 2>&1
if exist "!RAF!" goto tw_rearm_fail
echo  [%g%+%w%] Off for this phone.
timeout /t 2 /nobreak >nul
goto tw_rearm

:tw_rearm_nokey
echo [%r%^^!%w%] This phone reports no serial DCX can use, or did not answer. Without one DCX
echo     cannot tell it from another phone, so re-apply after reboot is not offered for it.
echo  Press any key . . .
pause >nul
goto tw_profile

:tw_rearm_noboot
echo [%r%^^!%w%] The phone's boot id could not be read, so DCX could not tell when it reboots - not armed.
echo  Press any key . . .
pause >nul
goto tw_rearm

:tw_rearm_fail
echo [%r%^^!%w%] Could not write to !PROFDIR!\rearm - check the folder is writable.
echo  Press any key . . .
pause >nul
goto tw_rearm

:_uptime
:: _upt = time since the phone booted, from /proc/uptime as days, hours and minutes; empty when
:: the phone did not answer. uptime's own text changes shape below a day, so it is not parsed.
set "_upt=" & set "_ups="
for /f "tokens=1 delims=. " %%s in ('adb shell cat /proc/uptime ^<nul 2^>nul') do if not defined _ups set "_ups=%%s"
if not defined _ups exit /b
for /f "eol=0 delims=0123456789" %%c in ("!_ups!") do exit /b
if not "!_ups:~9!"=="" exit /b
set /a "_upd=_ups/86400, _uph=(_ups%%86400)/3600, _upm=(_ups%%3600)/60"
set "_upmm=0!_upm!"
set "_upt=!_upm! min"
if !_uph! GTR 0 set "_upt=!_uph!:!_upmm:~-2!"
if !_upd! EQU 1 set "_upt=1 day, !_upt!"
if !_upd! GTR 1 set "_upt=!_upd! days, !_upt!"
exit /b

:_phone_sn
:: _psn = the phone's own serial (ro.serialno), the same over USB and Wi-Fi; empty and errorlevel 1
:: when it is missing, unknown, longer than 64 or holds anything but letters, digits, . _ -.
set "_psn="
setlocal DisableDelayedExpansion
set "_psr="
for /f delims^=^ eol^= %%s in ('adb shell getprop ro.serialno 2^>nul ^<nul') do for /f delims^=^ eol^= %%t in ("%%s") do set "_psr=%%t"
setlocal EnableDelayedExpansion
if not defined _psr exit /b 1
if /i "!_psr!"=="unknown" exit /b 1
if not "!_psr:~64!"=="" exit /b 1
set "_psb="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_psr!") do set "_psb=1"
if defined _psb exit /b 1
for /f "eol=! delims=" %%x in ("!_psr!") do endlocal & endlocal & set "_psn=%%x"
exit /b 0

:_retarget
:: Arg 1 = NAME of the variable holding a backup or undo file. When the file's DCX_DEVICE (an adb
:: connection name) is not the connection in use but its DCX_PHONE matches this phone's own
:: serial, DCX_RETARGET = the connection in use, which the file then restores to. Else empty.
set "DCX_RETARGET="
set "_rtw=" & set "_rtp=" & set "_rth="
for /f "tokens=3" %%s in ('findstr /b /c:":: DCX_DEVICE " "%%%~1%%" 2^>nul') do set "_rtw=%%s"
for /f "tokens=3" %%s in ('findstr /b /c:":: DCX_PHONE " "%%%~1%%" 2^>nul') do set "_rtp=%%s"
if not defined _rtw exit /b 0
if not defined _rtp exit /b 0
for /f "delims=" %%s in ('adb get-serialno 2^>nul') do set "_rth=%%s"
if not defined _rth exit /b 0
if /i "!_rth!"=="!_rtw!" exit /b 0
call :_phone_sn || exit /b 0
if /i "!_psn!"=="!_rtp!" set "DCX_RETARGET=!_rth!"
exit /b 0

:_ra_key
:: RAF / RAB = this phone's armed profile and boot marker, named after ro.serialno. errorlevel 1 = no usable serial.
set "RAF=" & set "RAB="
setlocal DisableDelayedExpansion
set "_raser="
for /f delims^=^ eol^= %%s in ('adb shell getprop ro.serialno 2^>nul ^<nul') do for /f delims^=^ eol^= %%t in ("%%s") do set "_raser=%%t"
setlocal EnableDelayedExpansion
if not defined _raser exit /b 1
if /i "!_raser!"=="unknown" exit /b 1
set "_rsb="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-" %%c in ("!_raser!") do set "_rsb=1"
if defined _rsb exit /b 1
if not "!_raser:~64!"=="" exit /b 1
for /f "eol=! delims=" %%x in ("!_raser!") do endlocal & endlocal & set "_ra_ser=%%x"
set "RAF=!PROFDIR!\rearm\!_ra_ser!.txt"
set "RAB=!PROFDIR!\rearm\!_ra_ser!.boot"
exit /b 0

:_ra_boot
:: _ra_boot = /proc/sys/kernel/random/boot_id, a UUID new at every boot. errorlevel 1 = unreadable.
set "_ra_boot="
setlocal DisableDelayedExpansion
set "_rb="
for /f delims^=^ eol^= %%b in ('adb shell cat /proc/sys/kernel/random/boot_id 2^>nul ^<nul') do for /f delims^=^ eol^= %%c in ("%%b") do set "_rb=%%c"
setlocal EnableDelayedExpansion
if not defined _rb exit /b 1
set "_rbb="
for /f "eol=- delims=0123456789abcdefABCDEF-" %%c in ("!_rb!") do set "_rbb=1"
if defined _rbb exit /b 1
if not "!_rb:~36!"=="" exit /b 1
if "!_rb:~35!"=="" exit /b 1
for /f "eol=! delims=" %%x in ("!_rb!") do endlocal & endlocal & set "_ra_boot=%%x"
exit /b 0

:_ra_startup
:: From :detect_device. Nothing armed means no adb call at all.
if not exist "!PROFDIR!\rearm\*.txt" exit /b
call :_ra_key || exit /b
if not exist "!RAF!" exit /b
call :_ra_boot || exit /b
set "_ra_old="
if exist "!RAB!" set /p "_ra_old=" <"!RAB!"
if "!_ra_old!"=="!_ra_boot!" exit /b
:: Settings still loading right after boot would read as drift, so wait for the next connect.
setlocal DisableDelayedExpansion
set "_ra_bc="
for /f %%b in ('adb shell getprop sys.boot_completed 2^>nul ^<nul') do for /f %%c in ("%%b") do if "%%c"=="1" set "_ra_bc=1"
endlocal & set "_ra_bc=%_ra_bc%"
if not defined _ra_bc exit /b
echo.
echo [%b%i%w%] This phone rebooted since its re-apply profile was last checked - checking it . . .
set "PFFILE=!RAF!"
call :_pf_run quiet
if not "!_pf_unr!"=="0" goto _ra_st_unr
>"!RAB!" echo !_ra_boot!
if "!_pf_same!!_pf_diff!"=="00" goto _ra_st_none
if "!_pf_diff!"=="0" goto _ra_st_ok
echo.
echo  !_pf_diff! key^(s^) drifted. Re-apply them now? Each one is read back.
echo    [Y] Re-apply    [N] Not this boot
choice /c:YN /n >nul
if errorlevel 2 exit /b
if not errorlevel 1 exit /b
echo.
call :_pf_run apply
echo  Press any key . . .
pause >nul
exit /b

:_ra_st_ok
echo [%g%+%w%] Every key in it still matches.
timeout /t 2 /nobreak >nul
exit /b

:_ra_st_none
echo [%y%WARN%w%] No line in this phone's re-apply profile could be checked - see above.
timeout /t 3 /nobreak >nul
exit /b

:_ra_st_unr
echo [%y%WARN%w%] Some keys could not be read - DCX checks again the next time it connects.
timeout /t 3 /nobreak >nul
exit /b
:: ===================================================================
:: Tier 3: QS tile editor and assorted device tweaks. The battery saver trigger key is
:: low_power_trigger_level, not the constant name LOW_POWER_MODE_TRIGGER_LEVEL.
:: ===================================================================

:tw_qs
cls
title Quick Settings Tiles
call :logo
echo.
set "QSCUR="
call :_tw_wb_get secure sysui_qs_tiles QSCUR QSODD
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
call :_noin qs || goto dcx_noinput
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
:: Tiles in SystemUI's stock list but not its default list: on the device, not shown.
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
call :_noin QSSEL || goto dcx_noinput
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
call :_noin QSTOK || goto dcx_noinput
if not defined QSTOK goto tw_qs_pick
set "QSTOK=!QSTOK:"=!"
if not defined QSTOK goto tw_qs_pick
call :_tw_safechk QSTOK || goto tw_qs_bad
echo(!QSTOK!| findstr /r /x /c:"[a-z0-9_][a-z0-9_]*" >nul || goto tw_qs_bad
goto tw_qs_addgo

:tw_qs_addgo
if defined QSODD goto tw_qs_odd
if not defined QSCUR goto tw_qs_unread
call :_tw_undo_add secure sysui_qs_tiles
:: Rebuild, not append: drop the spec first so adding an existing tile moves it.
:: OEM lists hold custom tokens with parens a plain for breaks on, so :_tw_qs_enum splits them.
set "QSNEW="
if "!QSCUR!"=="null" goto _tw_qs_addnull
call :_tw_qs_enum
:: No tokens from a set list means the split failed: adding now would leave one tile, so refuse.
if "!QSN!"=="0" goto _tw_qs_nosplit
call :_tw_qs_rebuild_skip
:: explicit: :_tw_qs_addnull sits between here and :_tw_qs_addput, so this must not fall through
goto _tw_qs_addput

:_tw_qs_nosplit
echo.
echo  %y%The tile list could not be split%w% ^(PowerShell did not run, or the temp folder is
echo  not writable^), so nothing was written - adding now would leave a single tile.
echo  Press any key . . .
pause >nul
goto tw_qs

:tw_qs_del_nosplit
echo  %y%The tile list could not be split%w% ^(PowerShell did not run, or the temp folder is
echo  not writable^), so there is nothing to pick from and nothing was changed.
echo  Press any key . . .
pause >nul
goto tw_qs

:tw_qs_unread
echo.
echo [%r%^^!%w%] The list was not read when this screen opened, so nothing was changed. The
echo        screen reads it again now.
timeout /t 4 /nobreak >nul
goto tw_qs

:_tw_qs_addnull
:: Unset sysui_qs_tiles means an unreadable default list; adding would leave one tile, so refuse.
echo.
echo  %y%The panel is still on the device default%w% - sysui_qs_tiles is not set,
echo  so there is no list to add to. Adding a tile now would replace the whole
echo  panel with just that one tile, which is why it is refused.
echo.
echo  Edit Quick Settings once on the phone ^(pull down the shade, tap the pencil
echo  and move any tile^). That makes SystemUI write the real list out, and this
echo  screen can add to it from then on - the same thing the remove screen asks for.
timeout /t 6 /nobreak >nul
goto tw_qs

:_tw_qs_addput
if /i "!QSPOS!"=="front" (set "QSNEW=,!QSTOK!!QSNEW!") else (set "QSNEW=!QSNEW!,!QSTOK!")
set "QSNEW=!QSNEW:~1!"
call :_tw_qs_put
goto tw_qs

:tw_qs_del
cls
title Quick Settings Tiles : remove
call :logo
echo.
if defined QSODD goto tw_qs_odd
if not defined QSCUR goto tw_qs_unread
if "!QSCUR!"=="null" goto tw_qs_empty
call :_tw_qs_enum
:: No tokens from a set list means the split failed, not an empty panel.
if "!QSN!"=="0" goto tw_qs_del_nosplit
echo  Current tiles, in display order:
for /l %%i in (1,1,!QSN!) do echo     %g%[%w%%%i%g%]%w% !QST_%%i!
echo     %g%[%w%0%g%]%w% Back
set "QSPICK=" & set /p QSPICK="Remove which? >> "
call :_noin QSPICK || goto dcx_noinput
if not defined QSPICK goto tw_qs_del
if "!QSPICK!"=="0" goto tw_qs
call :_tw_safechk QSPICK || goto tw_qs_del
echo(!QSPICK!| findstr /r /x /c:"[0-9][0-9]*" >nul || goto tw_qs_del
set "QSTOK="
if defined QST_!QSPICK! for /f "delims=" %%v in ("!QSPICK!") do set "QSTOK=!QST_%%v!"
if not defined QSTOK goto tw_qs_del
call :_tw_undo_add secure sysui_qs_tiles
call :_tw_qs_rebuild_skip
:: An empty list is not a valid value, so removing the last tile is a reset.
if not defined QSNEW goto tw_qs_reset
set "QSNEW=!QSNEW:~1!"
call :_tw_qs_put
goto tw_qs

:_udiff
:: Line diff of two UTF-8 files into _UDO, as UTF-8: fc breaks non-ASCII letters whose UTF-8 bytes
:: fall in 0x80-0x9F. In: _UDA older file, _UDB newer file, _UDO output, _UDM new or add. Paths go
:: by environment. PowerShell resets the code page on exit, so 65001 is set again.
set "DCX_UDA=!_UDA!" & set "DCX_UDB=!_UDB!" & set "DCX_UDO=!_UDO!" & set "DCX_UDM=!_UDM!"
powershell -NoProfile -Command "$u=New-Object Text.UTF8Encoding $false; try{ $a=[IO.File]::ReadAllLines($env:DCX_UDA,$u); $b=[IO.File]::ReadAllLines($env:DCX_UDB,$u) }catch{ $o=@('Could not compare: '+$_.Exception.Message) ; if($env:DCX_UDM -eq 'add'){ [IO.File]::AppendAllLines($env:DCX_UDO,[string[]]$o,$u) }else{ [IO.File]::WriteAllLines($env:DCX_UDO,[string[]]$o,$u) }; exit 2 }; $ha=[Collections.Generic.HashSet[string]]::new([string[]]$a); $hb=[Collections.Generic.HashSet[string]]::new([string[]]$b); $ra=[Collections.Generic.List[string]]::new(); $rb=[Collections.Generic.List[string]]::new(); $n=0; foreach($l in $a){ $n++; if(-not $hb.Contains($l)){ $ra.Add(('{0,6}: {1}' -f $n,$l)) } }; $n=0; foreach($l in $b){ $n++; if(-not $ha.Contains($l)){ $rb.Add(('{0,6}: {1}' -f $n,$l)) } }; $o=[Collections.Generic.List[string]]::new(); if($ra.Count -eq 0 -and $rb.Count -eq 0){ $o.Add('No differences.') } else{ $o.Add('Only in the older file, '+[IO.Path]::GetFileName($env:DCX_UDA)+':'); if($ra.Count){ $o.AddRange($ra) }else{ $o.Add('       none') }; $o.Add(''); $o.Add('Only in the newer file, '+[IO.Path]::GetFileName($env:DCX_UDB)+':'); if($rb.Count){ $o.AddRange($rb) }else{ $o.Add('       none') } }; if($env:DCX_UDM -eq 'add'){ [IO.File]::AppendAllLines($env:DCX_UDO,[string[]]$o,$u) }else{ [IO.File]::WriteAllLines($env:DCX_UDO,[string[]]$o,$u) }"
chcp 65001 >nul
set "DCX_UDA=" & set "DCX_UDB=" & set "DCX_UDO=" & set "DCX_UDM="
exit /b

:_pkg_ok
:: Validates !_PKGCHK! as an Android package name; errorlevel 1 if it is not one.
:: Java-style: a letter first, then letters, digits, dots, underscores. Check before any adb probe.
:: PIPE-FREE ON PURPOSE: never echo the value into findstr - the pipe re-parses it, so an
:: ampersand splits it, findstr passes the first half and the rest runs. Every allowed char is a
:: delimiter, so the loop body runs only for a char outside the list. It sets a constant: a copy
:: of the char with delayed expansion on would drop an exclamation mark and pass the name.
if not defined _PKGCHK exit /b 1
:: A quote is refused, not stripped: the caller goes on to use its own copy of the name.
set "_pkq=!_PKGCHK:"=!"
if not "!_pkq!"=="!_PKGCHK!" exit /b 1
set "_pk_bad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%c in ("!_PKGCHK!") do set "_pk_bad=1"
if defined _pk_bad exit /b 1
:: shape: must start with a letter, not a digit or a dot
set "_pk_bad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" %%c in ("!_PKGCHK:~0,1!") do set "_pk_bad=1"
if defined _pk_bad exit /b 1
exit /b 0

:_pkg_pick
:: Arg 1 = NAME of the variable holding what was typed; arg 2 = inst (apps on the phone for this
:: user) or removed (apps removed for this user, which Restore can bring back). An exact name, and
:: text that cannot be part of a name, are left for the caller's own check. Part of a name lists
:: the matching apps by number, and the chosen one replaces the text in the variable.
:: errorlevel 1 = nothing chosen: no match, Enter at the list, or the phone did not answer.
set "_pp_v=%~1"
set "_pp_sc=%~2"
set "_pp_t=!%~1!"
if not defined _pp_t exit /b 0
set "_pp_q=!_pp_t:"=!"
if not "!_pp_q!"=="!_pp_t!" exit /b 0
set "_pp_bad="
for /f "eol=a delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._" %%c in ("!_pp_t!") do set "_pp_bad=1"
if defined _pp_bad exit /b 0
set "_ppd=!DCX_TMP!\pkgpick"
if exist "!_ppd!\" rd /s /q "!_ppd!" >nul 2>&1
md "!_ppd!" >nul 2>&1
if not exist "!_ppd!\" exit /b 0
echo  Looking for "!_pp_t!" on the phone...
:: --user 0 always: from Android 13 a bare list merges every user, a work profile included.
adb shell "pm list packages --user 0 && echo _DCXEND" <nul >"!_ppd!\inst.txt" 2>nul
findstr /c:"_DCXEND" "!_ppd!\inst.txt" >nul 2>&1 || goto _pkg_pick_noans
call :_pp_list inst
set "_pp_src=inst.ok"
if /i not "!_pp_sc!"=="removed" goto _pkg_pick_exact
:: -u adds the packages removed for this user with their data kept; the difference is what
:: install-existing can bring back. The .ok files hold checked names only, so plain reads are safe.
adb shell "pm list packages -u --user 0 && echo _DCXEND" <nul >"!_ppd!\all.txt" 2>nul
findstr /c:"_DCXEND" "!_ppd!\all.txt" >nul 2>&1 || goto _pkg_pick_noans
call :_pp_list all
for /f "delims==" %%v in ('set _ppI_ 2^>nul') do set "%%v="
for /f "usebackq delims=" %%n in ("!_ppd!\inst.ok") do set "_ppI_%%n=1"
:: echo( so that a package named on or off is written, not taken as the echo switch.
type nul >"!_ppd!\removed.ok"
for /f "usebackq delims=" %%n in ("!_ppd!\all.ok") do if not defined _ppI_%%n >>"!_ppd!\removed.ok" echo(%%n
for /f "delims==" %%v in ('set _ppI_ 2^>nul') do set "%%v="
set "_pp_src=removed.ok"

:_pkg_pick_exact
findstr /x /c:"!_pp_t!" "!_ppd!\!_pp_src!" >nul 2>&1 && exit /b 0
for /f "delims==" %%v in ('set _pp_m[ 2^>nul') do set "%%v="
set "_pp_n=0"
"%SystemRoot%\System32\sort.exe" "!_ppd!\!_pp_src!" /o "!_ppd!\sorted.ok" >nul 2>&1
if not exist "!_ppd!\sorted.ok" copy /y "!_ppd!\!_pp_src!" "!_ppd!\sorted.ok" >nul 2>&1
:: Substitution ignores case, so a changed copy means the name holds the typed text.
for /f "usebackq delims=" %%n in ("!_ppd!\sorted.ok") do (
    set "_pp_x=%%n"
    if not "!_pp_x:%_pp_t%=!"=="!_pp_x!" (
        set /a _pp_n+=1
        set "_pp_m[!_pp_n!]=%%n"
    )
)
if "!_pp_n!"=="0" goto _pkg_pick_none
echo.
if /i "!_pp_sc!"=="removed" (echo  Removed apps with "!_pp_t!" in the name:) else (echo  Apps with "!_pp_t!" in the name:)
for /l %%i in (1,1,25) do if defined _pp_m[%%i] echo     %g%[%w%%%i%g%]%w% !_pp_m[%%i]!
if !_pp_n! GTR 25 echo     ... !_pp_n! apps match and the first 25 are shown. Type more of the name.
echo.

:_pkg_pick_ask
set "_pp_c=" & set /p _pp_c="App number (Enter = back) >> "
call :_noin _pp_c || goto dcx_noinput
if not defined _pp_c exit /b 1
set "_pp_bad="
for /f "eol=0 delims=0123456789" %%c in ("!_pp_c!") do set "_pp_bad=1"
if defined _pp_bad goto _pkg_pick_ask
if "!_pp_c:~0,1!"=="0" goto _pkg_pick_ask
if not defined _pp_m[!_pp_c!] goto _pkg_pick_ask
for /f "delims=" %%k in ("!_pp_c!") do set "!_pp_v!=!_pp_m[%%k]!"
for /f "delims==" %%v in ('set _pp_m[ 2^>nul') do set "%%v="
exit /b 0

:_pkg_pick_none
if /i "!_pp_sc!"=="removed" (echo  [%r%x%w%] No app removed for this user has "!_pp_t!" in its name.) else (echo  [%r%x%w%] No app on the phone has "!_pp_t!" in its name.)
pause >nul
exit /b 1

:_pkg_pick_noans
echo  [%r%^^!%w%] The phone did not answer - check the connection ^(adb devices^).
pause >nul
exit /b 1

:_pp_list
:: Arg 1 = inst or all: the package:<name> lines of that pm answer whose name is valid - a letter,
:: then letters, digits, dots and underscores - go to <arg>.ok as plain names. One findstr checks
:: every line, so phone text never reaches a variable unchecked; a per-line call took 25 ms a line,
:: half a minute on a phone with 1200 apps. find first re-terminates adb's LF-only lines for /x.
find /v "" <"!_ppd!\%~1.txt" >"!_ppd!\%~1.crlf" 2>nul
findstr /r /x /c:"package:[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ][abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.]*" "!_ppd!\%~1.crlf" >"!_ppd!\%~1.flt" 2>nul
type nul >"!_ppd!\%~1.ok"
for /f "usebackq tokens=1,* delims=:" %%a in ("!_ppd!\%~1.flt") do >>"!_ppd!\%~1.ok" echo(%%b
exit /b

:_tw_qs_enum
:: Split QSCUR into QST_1..QST_n and QSN on commas outside parens, for OEM custom tokens.
for /f "delims==" %%v in ('set QST_ 2^>nul') do set "%%v="
set "QSN=0"
if not defined QSCUR exit /b
if /i "!QSCUR!"=="null" exit /b
set "_qs_tmp=!DCX_TMP!\qs_tokens.txt"
powershell -NoProfile -Command "$s=$env:QSCUR; if([string]::IsNullOrEmpty($s)){exit 0}; $d=0; $c=''; $l=New-Object System.Collections.Generic.List[string]; foreach($ch in $s.ToCharArray()){ if($ch -eq [char]'('){$d++} elseif($ch -eq [char]')'){$d--} elseif($ch -eq [char]',' -and $d -eq 0){ [void]$l.Add($c); $c=''; continue }; $c+=$ch }; if($c.Length -gt 0){[void]$l.Add($c)}; $l | Set-Content -LiteralPath $env:_qs_tmp -Encoding ascii"
:: PowerShell resets the console code page on exit: restore it here, not via the caller's redraw.
chcp 65001 >nul
if not exist "!_qs_tmp!" exit /b
for /f "usebackq delims=" %%t in ("!_qs_tmp!") do (
    set /a QSN+=1
    set "QST_!QSN!=%%t"
)
del "!_qs_tmp!" >nul 2>&1
exit /b

:_tw_qs_rebuild_skip
:: Build QSNEW=,tok,tok from QST_* skipping any token equal to QSTOK.
set "QSNEW="
for /l %%i in (1,1,!QSN!) do (
    set "QSHIT="
    if defined QSTOK if /i "!QST_%%i!"=="!QSTOK!" set "QSHIT=1"
    if not defined QSHIT set "QSNEW=!QSNEW!,!QST_%%i!"
)
exit /b

:_tw_qs_put
:: Write QSNEW with device-shell single-quoting so custom(...) survives adb.
set "_sv=!QSNEW:'='\''!"
adb shell "settings put secure sysui_qs_tiles '!_sv!'" <nul
exit /b

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

:tw_qs_odd
echo.
echo  %y%DCX will not rewrite this list%w% - it holds a ^^! or a double quote.
echo  Edited here it would not be the list the phone has: cmd reads ^^!NAME^^! as a variable
echo  on this PC, and a double quote would be lost.
echo  [4] still resets it; or edit the tiles on the phone.
timeout /t 6 /nobreak >nul
goto tw_qs

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
call :_noin mo || goto dcx_noinput
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
call :_noin cg || goto dcx_noinput
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
set "CHTOK=" & set /p CHTOK="Choose An Option >> "
call :_noin CHTOK || goto dcx_noinput
if not defined CHTOK goto tw_chg
if "!CHTOK!"=="1" (call :_tw_undo_add global charging_sounds_enabled & adb shell settings put global charging_sounds_enabled 0 <nul & goto tw_chg)
if "!CHTOK!"=="2" (call :_tw_undo_add global charging_sounds_enabled & adb shell settings put global charging_sounds_enabled 1 <nul & goto tw_chg)
if "!CHTOK!"=="3" (call :_tw_undo_add global charging_vibration_enabled & adb shell settings put global charging_vibration_enabled 0 <nul & goto tw_chg)
if "!CHTOK!"=="4" (call :_tw_undo_add global charging_vibration_enabled & adb shell settings put global charging_vibration_enabled 1 <nul & goto tw_chg)
if "!CHTOK!"=="5" goto tw_chg_reset
if "!CHTOK!"=="6" goto tw_more
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
call :_noin st || goto dcx_noinput
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
set "BSVPICK=" & set /p BSVPICK="Choose An Option >> "
call :_noin BSVPICK || goto dcx_noinput
if not defined BSVPICK goto tw_bsav
if "!BSVPICK!"=="1" (set "BSNEW=0" & goto tw_bsav_apply)
if "!BSVPICK!"=="2" (set "BSNEW=5" & goto tw_bsav_apply)
if "!BSVPICK!"=="3" (set "BSNEW=15" & goto tw_bsav_apply)
if "!BSVPICK!"=="4" (set "BSNEW=30" & goto tw_bsav_apply)
if "!BSVPICK!"=="5" (set "BSNEW=50" & goto tw_bsav_apply)
if "!BSVPICK!"=="6" goto tw_bsav_custom
if "!BSVPICK!"=="7" (call :_tw_undo_add global low_power_trigger_level & adb shell settings delete global low_power_trigger_level >nul 2>&1 <nul & goto tw_bsav)
if "!BSVPICK!"=="8" goto tw_more
goto tw_bsav

:tw_bsav_custom
echo.
set "BSNEW=" & set /p BSNEW="Percentage 0 - 99 (blank = cancel) >> "
call :_noin BSNEW || goto dcx_noinput
if not defined BSNEW goto tw_bsav
set "BSNEW=!BSNEW:"=!"
if not defined BSNEW goto tw_bsav
call :_tw_safechk BSNEW || goto tw_bsav_bad
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
call :_noin fw || goto dcx_noinput
if not defined fw goto tw_free
if "!fw!"=="1" (call :_tw_undo_add global enable_freeform_support & adb shell settings put global enable_freeform_support 1 <nul & goto tw_free)
if "!fw!"=="2" (call :_tw_undo_add global enable_freeform_support & adb shell settings put global enable_freeform_support 0 <nul & goto tw_free)
if "!fw!"=="3" (call :_tw_undo_add global force_resizable_activities & adb shell settings put global force_resizable_activities 1 <nul & goto tw_free)
if "!fw!"=="4" (call :_tw_undo_add global force_resizable_activities & adb shell settings put global force_resizable_activities 0 <nul & goto tw_free)
if "!fw!"=="5" goto tw_free_reset
if "!fw!"=="6" goto tw_free_reboot
if "!fw!"=="7" goto tw_more
goto tw_free

:tw_free_reboot
echo.
echo  %y%This reboots the connected phone now.%w% Anything unsaved on it is lost.
echo    [Y] Reboot the phone    [N] Cancel
:: Ctrl+C makes choice return 0, so not errorlevel 1 goes where N goes.
choice /c:YN /n >nul
if errorlevel 2 goto tw_free
if not errorlevel 1 goto tw_free
adb reboot <nul
timeout /t 1 /nobreak > nul
:: Disconnect only this phone, and only on Wi-Fi, as the main Reboot does.
if not defined ANDROID_SERIAL goto tw_free
if "!ANDROID_SERIAL!"=="!ANDROID_SERIAL::=!" goto tw_free
adb disconnect !ANDROID_SERIAL!
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
call :_noin il || goto dcx_noinput
if not defined il goto tw_inst
if "!il!"=="1" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 0 <nul & goto tw_inst)
if "!il!"=="2" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 1 <nul & goto tw_inst)
if "!il!"=="3" (call :_tw_undo_add global default_install_location & adb shell settings put global default_install_location 2 <nul & goto tw_inst)
if "!il!"=="4" (call :_tw_undo_add global default_install_location & adb shell settings delete global default_install_location >nul 2>&1 <nul & goto tw_inst)
if "!il!"=="5" goto tw_more
goto tw_inst
:: ===================================================================
:: Settings Tools, main menu 15: generic tools for any settings key. Tweaks is the curated list.
:: ===================================================================
:tw_watch
cls
title Watch settings key
call :logo
echo.
echo  Poll one settings key while you flip a toggle on the phone.
echo  Faster than snapshot/diff when you already know the namespace.
echo  Press %g%Q%w% to stop. Auto-stops when the value changes.
echo.
call :_tw_askns
if not defined EXP_NS goto settools
call :_tw_askkey
if not defined EXP_KEY goto settools
set "WATCH_NS=!EXP_NS!"
set "WATCH_KEY=!EXP_KEY!"
set "WATCH_PREV="
for /f "delims=" %%i in ('adb shell settings get !WATCH_NS! !WATCH_KEY! 2^>nul ^<nul') do set "WATCH_PREV=%%i"
:: Android prints null for an unset key, so an empty read means no answer: no baseline yet.
set "WATCH_QUIET="
if defined WATCH_PREV set "WATCH_PREV=!WATCH_PREV:"=!"
echo.
echo  Watching %g%!WATCH_NS!/!WATCH_KEY!%w%
if defined WATCH_PREV echo  Baseline: "!WATCH_PREV!"
if not defined WATCH_PREV echo  The phone did not answer yet - the baseline is its first answer.
echo  Flip the toggle on the device now...
echo.

:_tw_watch_loop
:: Q=quit (errorlevel 1), C=continue/timeout default (errorlevel 2+)
choice /c:QC /n /t 1 /d C >nul
if errorlevel 2 goto _tw_watch_poll
echo  Stopped.
pause >nul
goto settools

:_tw_watch_poll
set "WATCH_NOW="
for /f "delims=" %%i in ('adb shell settings get !WATCH_NS! !WATCH_KEY! 2^>nul ^<nul') do set "WATCH_NOW=%%i"
if not defined WATCH_NOW goto _tw_watch_noans
set "WATCH_NOW=!WATCH_NOW:"=!"
if not defined WATCH_PREV (set "WATCH_PREV=!WATCH_NOW!" & echo  Baseline: "!WATCH_NOW!" & goto _tw_watch_loop)
if "!WATCH_NOW!"=="!WATCH_PREV!" goto _tw_watch_loop
echo.
echo  [%g%+%w%] Value changed:
echo     was: "!WATCH_PREV!"
echo     now: "!WATCH_NOW!"
echo.
echo  Namespace/key: !WATCH_NS! !WATCH_KEY!
echo  Tip: save it into a Profile, or write it via Settings explorer.
echo.
pause >nul
goto settools

:_tw_watch_noans
if not defined WATCH_QUIET echo  [%y%WARN%w%] The phone did not answer - still watching. A missing answer is not a change.
set "WATCH_QUIET=1"
goto _tw_watch_loop

:settools
cls
title Settings Tools
call :logo
echo.
echo                               %m%Settings Tools%w%
echo.
echo  Generic tools for ANY settings key ^(list / get / put / watch / profile^).
echo  For the curated status-bar and system toggles, use Main Menu - Tweaks.
echo.
echo    %g%[%w%1%g%]%w% Settings explorer - list / get / put / delete
echo    %g%[%w%2%g%]%w% Settings snapshot and diff
echo    %g%[%w%3%g%]%w% Profiles - save, check, apply, goal presets
echo    %g%[%w%4%g%]%w% Watch a key - poll while you flip a toggle
echo    %g%[%w%5%g%]%w% Back to main menu
set "sx=" & set /p sx="Choose An Option >> "
call :_noin sx || goto dcx_noinput
if not defined sx goto settools
if "!sx!"=="1" goto tw_explorer
if "!sx!"=="2" goto tw_snapshot
if "!sx!"=="3" goto tw_profile
if "!sx!"=="4" goto tw_watch
if "!sx!"=="5" goto menu
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
:: SHARED HELPER: silence all WindowManager debug-trace channels. Used by :setupautorun, :offlogss.
:: disable-text mutes a channel's text output and disable turns it off; Android 12+ needs both.
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
    adb shell wm logging disable-text %%C <nul > nul 2>&1
    adb shell wm logging disable      %%C <nul > nul 2>&1
)
exit /b
:: ===================================================================
:: SHARED HELPER: mark common system_server dropbox channels low-priority to spare the quota.
:: Callers set the rate limit afterwards. Used by :setupautorun, :skiplogv, :onlogss.
:: ===================================================================
:dropbox_lowprio
adb shell cmd dropbox add-low-priority system_server <nul
adb shell cmd dropbox add-low-priority system_server/Subject <nul
adb shell cmd dropbox add-low-priority data_app_wtf <nul
adb shell cmd dropbox add-low-priority storage_trim <nul
adb shell cmd dropbox add-low-priority SYSTEM_BOOT <nul
adb shell cmd dropbox add-low-priority SYSTEM_AUDIT <nul
adb shell cmd dropbox add-low-priority system_server_wtf <nul
adb shell cmd dropbox add-low-priority SYSTEM_LAST_KMSG <nul
exit /b
:: ===================================================================
:: SHARED HELPER: :_settings_verify  ns  key  expected
:: After a settings put/delete - read the key back and report honestly.
:: expected = literal value, or DELETE (null/unset), or * (any set value).
:: ===================================================================
:_act_reset
set "DCX_VOK=0" & set "DCX_VFAIL=0" & set "DCX_VUNK=0"
exit /b

:_act_summary
if not defined DCX_VOK set "DCX_VOK=0"
if not defined DCX_VFAIL set "DCX_VFAIL=0"
if not defined DCX_VUNK set "DCX_VUNK=0"
echo.
:: Nothing verified is not success: a dropped phone skips every check, so say so.
if not "%DCX_VFAIL%"=="0" goto _act_summary_warn
if "%DCX_VOK%"=="0" goto _act_summary_none
echo [%g%OK%w%] %DCX_VOK% check^(s^) passed.
exit /b

:_act_summary_warn
if not "%DCX_VUNK%"=="0" goto _act_summary_unk
echo [%y%WARN%w%] %DCX_VOK% passed, %DCX_VFAIL% failed - see above.
exit /b

:_act_summary_unk
:: An unconfirmed step is counted in DCX_VFAIL too, so callers never print their success line.
set /a _as_bad=DCX_VFAIL-DCX_VUNK
echo [%y%WARN%w%] %DCX_VOK% passed, !_as_bad! failed, %DCX_VUNK% not confirmed: Android 6 and older
echo        report no result, so read the phone's answers above.
exit /b

:_act_summary_none
echo [%y%WARN%w%] Nothing was verified - no check actually ran.
echo        If everything above said "skip (not installed)", check the phone is
echo        still connected: a dropped device looks identical to one that has
echo        none of these packages.
exit /b

:_settings_verify
set "_sv_got="
for /f "delims=" %%i in ('adb shell settings get %~1 %~2 2^>nul ^<nul') do set "_sv_got=%%i"
if "!_sv_got!"=="" set "_sv_got=null"
if /i "%~3"=="DELETE" goto _settings_verify_del
if /i "%~3"=="*" (
    if /i not "!_sv_got!"=="null" (echo [%g%+%w%] %~2 = "!_sv_got!" & set /a DCX_VOK+=1 & exit /b 0)
    echo [%r%^^!%w%] %~2 did not stick ^(device reports null^).
    set /a DCX_VFAIL+=1
    exit /b 1
)
if "!_sv_got!"=="%~3" (echo [%g%+%w%] %~2 = "!_sv_got!" & set /a DCX_VOK+=1 & exit /b 0)
echo [%r%^^!%w%] wanted %~2=%~3, device reports "!_sv_got!".
set /a DCX_VFAIL+=1
exit /b 1

:_settings_verify_del
:: An empty answer reads as null, and so does a phone that is gone: ask it something first.
if /i not "!_sv_got!"=="null" goto _settings_verify_left
call :_phone_live || goto _settings_verify_gone
echo [%g%+%w%] %~2 deleted.
set /a DCX_VOK+=1
exit /b 0

:_settings_verify_left
echo [%r%^^!%w%] %~2 still reports "!_sv_got!" - delete may not have landed.
set /a DCX_VFAIL+=1
exit /b 1

:_settings_verify_gone
echo [%r%^^!%w%] %~2 - the phone did not answer, so the delete could not be checked.
set /a DCX_VFAIL+=1
exit /b 1

:_phone_live
:: errorlevel 0 when adb shell echo comes back from the phone.
set "_pl_ok="
for /f "delims=" %%i in ('adb shell echo _DCXRD 2^>nul ^<nul') do if "%%i"=="_DCXRD" set "_pl_ok=1"
if defined _pl_ok exit /b 0
exit /b 1

:_put_chk
:: %1 = namespace, %2 = key, %3 = value or DELETE. One settings write, then the read-back above.
if /i "%~3"=="DELETE" (adb shell settings delete %~1 %~2 <nul >nul 2>&1) else (adb shell settings put %~1 %~2 %~3 <nul >nul 2>&1)
call :_settings_verify %1 %2 %3
exit /b

:_prop_verify
:: Arg 1 = property, arg 2 = expected value or EMPTY for cleared. Counts into DCX_VOK / DCX_VFAIL.
:: EMPTY passes only if an adb shell echo shows the phone still answers.
set "_pv_got="
for /f "delims=" %%i in ('adb shell getprop %~1 2^>nul ^<nul') do set "_pv_got=%%i"
if /i not "%~2"=="EMPTY" goto _prop_verify_val
set "_pv_live="
for /f "delims=" %%i in ('adb shell echo _DCXRD 2^>nul ^<nul') do if "%%i"=="_DCXRD" set "_pv_live=1"
if not defined _pv_live goto _prop_verify_gone
if defined _pv_got goto _prop_verify_left
echo [%g%+%w%] %~1 cleared.
set /a DCX_VOK+=1
exit /b 0

:_prop_verify_left
echo [%r%^^!%w%] %~1 still reports "!_pv_got!" - the clear did not land.
set /a DCX_VFAIL+=1
exit /b 1

:_prop_verify_gone
echo [%r%^^!%w%] %~1 - the phone did not answer, so the clear could not be checked.
set /a DCX_VFAIL+=1
exit /b 1

:_prop_verify_val
if "!_pv_got!"=="%~2" (echo [%g%+%w%] %~1 = "!_pv_got!" & set /a DCX_VOK+=1 & exit /b 0)
echo [%r%^^!%w%] wanted %~1=%~2, device reports "!_pv_got!".
set /a DCX_VFAIL+=1
exit /b 1

:_act_rc
:: %1 = !errorlevel! of the adb call just made, %2 = what it did. adb passes the phone's
:: exit code back, and a dropped connection is an exit code of its own. Android 6 and older
:: always report 0, so there a 0 is counted as not confirmed.
if not "%~1"=="0" goto _act_rc_fail
if !SDK! GTR 0 if !SDK! LSS 24 goto _act_rc_blind
echo [%g%+%w%] %~2
set /a DCX_VOK+=1
exit /b 0

:_act_rc_blind
echo [%y%?%w%] %~2 - not confirmed: this Android reports no result.
set /a DCX_VFAIL+=1
set /a DCX_VUNK+=1
exit /b 0

:_act_rc_fail
echo [%r%^^!%w%] %~2 - failed ^(exit %~1^).
set /a DCX_VFAIL+=1
exit /b 1

:_am_uninst
:: %1 = a package name the caller has already checked. pm answers "Success" or
:: "Failure [reason]"; only "Success" counts. Counts into DCX_VOK / DCX_VFAIL.
set "_pmok="
set "_pmmsg="
for /f "delims=" %%r in ('adb shell pm uninstall -k --user 0 %~1 ^<nul 2^>^&1') do (
    if "%%r"=="Success" set "_pmok=1"
    set "_pmmsg=%%r"
)
if defined _pmok (echo [%g%+%w%] %~1 removed for the current user. & set /a DCX_VOK+=1 & exit /b 0)
if not defined _pmmsg set "_pmmsg=no answer from the phone"
echo [%r%^^!%w%] %~1 not removed: !_pmmsg!
set /a DCX_VFAIL+=1
exit /b 1
:: ===================================================================
:: SHARED HELPER: :_dcfgsync_verify  expected
:: Read back device_config get_sync_disabled_for_tests after a Tweaks write.
:: ===================================================================
:_dcfgsync_read
:: Reads the sync mode into DCS_VAL. Returns 1 when this device cannot be read.
:: Some builds lack the getter but accept the setter: report unreadable, never guess none.
set "DCS_VAL="
set "DCS_OK="
for /f "delims=" %%v in ('adb shell device_config get_sync_disabled_for_tests 2^>nul ^<nul') do set "DCS_VAL=%%v"
if not defined DCS_VAL exit /b 1
set "DCS_VAL=!DCS_VAL:"=!"
if /i "!DCS_VAL!"=="none" set "DCS_OK=1"
if /i "!DCS_VAL!"=="persistent" set "DCS_OK=1"
if /i "!DCS_VAL!"=="until_reboot" set "DCS_OK=1"
if not defined DCS_OK exit /b 1
exit /b 0

:_dcfgsync_verify
call :_dcfgsync_read || goto _dcfgsync_verify_blind
if /i "!DCS_VAL!"=="%~1" (
    echo [%g%+%w%] sync_disabled_for_tests = "!DCS_VAL!"
) else (
    echo [%y%WARN%w%] wanted sync mode %~1, device reports "!DCS_VAL!" - may need root on Android 14+.
)
exit /b

:_dcfgsync_verify_blind
echo [%y%NOTE%w%] this build does not implement the sync-mode readback, so DCX cannot
echo        confirm the change either way. Requested: %~1
exit /b
:: ===================================================================
:: SHARED HELPER: :_dcfg_verify  namespace  key  expected
:: Same idea for device_config get/put. On Android 14+ without root a
:: put often returns cleanly but writes nothing - readback catches that.
:: ===================================================================
:_dcfg_verify
set "_dv_got="
for /f "delims=" %%i in ('adb shell device_config get %~1 %~2 2^>nul ^<nul') do set "_dv_got=%%i"
if "!_dv_got!"=="" set "_dv_got=null"
:: An expected null needs proof that the phone answered at all, as a delete does above.
if "!_dv_got!"=="null" if /i "%~3"=="null" call :_phone_live || goto _dcfg_verify_gone
if "!_dv_got!"=="%~3" (echo [%g%+%w%] %~1/%~2 = "!_dv_got!" & set /a DCX_VOK+=1 & exit /b 0)
echo [%r%^^!%w%] wanted %~1/%~2=%~3, device reports "!_dv_got!".
set /a DCX_VFAIL+=1
exit /b 1

:_dcfg_verify_gone
echo [%r%^^!%w%] %~1/%~2 - the phone did not answer, so the value could not be checked.
set /a DCX_VFAIL+=1
exit /b 1
:: ===================================================================
:: SHARED HELPER: dexopt_all_mode filter heavy_flag - compiles ALL apps with the given filter.
:: API 33 and below: pm compile; heavy_flag 1 adds --check-prof false to compile every method.
:: API 34+: ART Service; never pass --check-prof or --compile-layouts, they are unknown options.
:: ===================================================================
:dexopt_all_mode
if %SDK% GEQ 34 goto _dexall_art
if "%~2"=="1" goto _dexall_heavy_legacy
echo   [pm dexopt / API %SDK%] pm compile -a -f -m %~1
adb shell pm compile -a -f -m %~1 <nul
exit /b

:_dexall_heavy_legacy
echo   [pm dexopt / API %SDK%] pm compile -a -f --check-prof false -m %~1
adb shell pm compile -a -f --check-prof false -m %~1 <nul
exit /b

:_dexall_art
echo   [ART Service / API %SDK%] pm compile -m %~1 -f -a
adb shell pm compile -m %~1 -f -a <nul
exit /b
:: ===================================================================
:: SHARED HELPER: run_bgdexopt - forces the background dexopt job, version-aware. API 33 and
:: below: pm bg-dexopt-job. API 34+: pm art dexopt-packages, else pm bg-dexopt-job.
:: ===================================================================
:run_bgdexopt
if %SDK% LSS 34 goto _bgdex_legacy
echo   [ART Service / API %SDK%] running background dexopt...
echo   (this can take a while and processes every app - please wait)
:: DCX_TMP is this window's own folder, so another DCX window never shares the log.
set "_dx_log=!DCX_TMP!\bgdex.txt"
adb shell pm art dexopt-packages -r bg-dexopt <nul > "!_dx_log!" 2>&1
set "_dx_rc=!errorlevel!"
:: If the command itself is unavailable, fall back to the legacy job.
findstr /I /C:"Unknown command" /C:"Usage:" "!_dx_log!" > nul && goto _bgdex_fallback
:: API 34+ passes the phone's exit code back; any other code (a dropped cable is one) is a failure.
if not "!_dx_rc!"=="0" goto _bgdex_failed
:: ART Service prints a line per package: show counts and only the failure lines.
set "_dx_perf=0"
set "_dx_fail=0"
:: ART prints [package], then one status line per dex file, then one Final Status for the run:
:: a package counts once if any of its files was PERFORMED (or FAILED).
set "_dxp=" & set "_dxf="
for /f "usebackq delims=" %%L in ("!_dx_log!") do (
    set "_dl=%%L"
    if "!_dl:~0,1!"=="[" (set "_dxp=" & set "_dxf=")
    if /i not "!_dl:~0,13!"=="Final Status:" (
        if not "!_dl:PERFORMED=!"=="!_dl!" if not defined _dxp (set "_dxp=1" & set /a _dx_perf+=1)
        if not "!_dl:FAILED=!"=="!_dl!" if not defined _dxf (set "_dxf=1" & set /a _dx_fail+=1)
    )
)
echo.
echo   Background dexopt finished.
echo     Packages optimised      : %_dx_perf%
echo     Packages with a failure : %_dx_fail%
:: Show at most 15 failures and say how many were withheld.
:: Keep comments outside the block below: a :: line inside a paren block makes cmd error out.
if not "%_dx_fail%"=="0" (
    echo.
    echo   Failed entries ^(first 15^):
    set "_dx_shown=0"
    for /f "delims=" %%L in ('findstr /I /C:"FAILED" "%%_dx_log%%" 2^>nul') do (
        set /a _dx_shown+=1
        if !_dx_shown! LEQ 15 echo     %%L
    )
    if !_dx_shown! GTR 15 (
        set /a _dx_more=!_dx_shown!-15
        echo     ... and !_dx_more! more - see the full log below.
    )
    echo.
    echo   Note: a few failures are normal - some system packages can't
    echo   be re-compiled. The full log is at:
    echo     !_dx_log!
    echo   ^(leaving it in place so you can inspect it^)
) else (
    echo   No failures. All good.
    del "!_dx_log!" > nul 2>&1
)
exit /b

:_bgdex_failed
:: errorlevel 1, so Auto Setup can count the step as failed.
echo.
echo   [%r%^^!%w%] Background dexopt did not finish ^(exit !_dx_rc!^). First lines of its answer:
set "_dx_shown=0"
for /f "usebackq delims=" %%L in ("!_dx_log!") do (
    set /a _dx_shown+=1
    if !_dx_shown! LEQ 5 echo     %%L
)
echo   The full log is at:
echo     !_dx_log!
exit /b 1

:_bgdex_fallback
echo   pm art unavailable on this build - using pm bg-dexopt-job...
adb shell pm bg-dexopt-job <nul
set "_dx_rc=!errorlevel!"
del "!_dx_log!" > nul 2>&1
exit /b !_dx_rc!

:_bgdex_legacy
adb shell pm bg-dexopt-job <nul
exit /b
:: ===================================================================
:: Command library entries, read by :_lib_load. Never run as code: each is a :: line. Fields:
:: id~category~risk~min API~command~note~undo. Categories 1 device, 2 apps, 3 battery, 4 display,
:: 5 network, 6 diagnostics, 7 settings, 8 installing apps. Risk r reads, c changes (undo given), d
:: deletes. No double quote, caret or exclamation mark (lost while loading, or stripped before adb),
:: no tilde (the field separator) and no pipe: grep and friends are missing on older phones.
:: ===================================================================
::LIB~d01~1~r~16~getprop~Every system property, sorted by name (long)~
::LIB~d02~1~r~16~getprop ro.product.model~Model name the phone reports~
::LIB~d03~1~r~16~getprop ro.build.version.release~Android version number~
::LIB~d04~1~r~16~getprop ro.build.version.sdk~API level - the number each Needs line compares with~
::LIB~d05~1~r~23~getprop ro.build.version.security_patch~Security patch date (YYYY-MM-DD)~
::LIB~d06~1~r~16~getprop ro.build.fingerprint~Build fingerprint - names the exact firmware~
::LIB~d07~1~r~23~uname -a~Kernel version, build date and CPU architecture~
::LIB~a01~2~r~16~pm list packages -3~Apps you installed (not part of the system image)~
::LIB~a02~2~r~16~pm path {PKG}~Where one app's install files (APK) are on the phone~
::LIB~a03~2~r~16~dumpsys package {PKG}~Everything Android knows about one app (long)~
::LIB~a04~2~d~16~pm clear {PKG}~Delete all of one app's data, as if just installed~
::LIB~a05~2~c~33~pm clear --cache-only {PKG}~Delete one app's cache and keep its data~Nothing to undo - the app rebuilds its cache
::LIB~a06~2~c~21~pm trim-caches 999G~Delete every app's cache to free space~Nothing to undo - apps rebuild their caches
::LIB~a07~2~c~16~am force-stop {PKG}~Force-stop one app (no alarms or pushes until opened)~Open the app once
::LIB~a08~2~c~16~am kill {PKG}~Kill one app's background processes (gentler)~Nothing to undo - the app starts again when needed
::LIB~a09~2~c~24~cmd package compile --reset {PKG}~Drop one app's compiled code (slower first start)~Roughly: cmd package compile -m speed-profile -f {PKG}
::LIB~a10~2~c~28~cmd appops set {PKG} RUN_ANY_IN_BACKGROUND ignore~Restrict one app's background work (Restricted mode)~cmd appops set {PKG} RUN_ANY_IN_BACKGROUND allow
::LIB~a11~2~r~34~cmd role get-role-holders android.app.role.HOME~Which app is the home screen (launcher)~
::LIB~b01~3~r~16~dumpsys battery~Battery level, temperature (in 0.1 C), voltage and charger~
::LIB~b02~3~r~33~cmd battery get level~Battery percentage as a bare number~
::LIB~b03~3~r~21~dumpsys batterystats --charged~Battery use per app since the last full charge (long)~
::LIB~b04~3~r~34~dumpsys batterystats --usage~Estimated power use per app in mAh~
::LIB~b05~3~d~21~dumpsys batterystats --reset~Erase the battery history and per-app statistics~
::LIB~b06~3~r~19~dumpsys power~What keeps the phone awake right now, and the screen state~
::LIB~b07~3~r~29~dumpsys thermalservice~Temperatures, and whether heat is slowing the phone down~
::LIB~b08~3~c~16~svc power stayon true~Keep the screen on while charging~svc power stayon false, if it was off before
::LIB~b09~3~c~21~settings put global low_power 1~Battery saver on - not while charging, and USB charges~settings put global low_power 0
::LIB~w01~4~r~18~wm size~Screen resolution and any override~
::LIB~w02~4~r~18~wm density~Screen density (DPI) and any override~
::LIB~w03~4~c~18~wm density {NUM}~Set the screen density in DPI (at least 72; wm density shows yours)~wm density reset, back to the panel's own density
::LIB~w04~4~c~18~wm density reset~Remove a screen density override~wm density N, N being the Override density shown before (none: nothing to undo)
::LIB~w05~4~r~17~dumpsys display~Display modes, refresh rates and brightness (long)~
::LIB~w06~4~r~19~dumpsys window displays~Windows on each display and which app has focus (long)~
::LIB~w07~4~r~16~dumpsys activity top~The app on screen now and its view tree (long)~
::LIB~w08~4~c~16~screencap -p /sdcard/dcx_screen.png~Screenshot saved on the phone as /sdcard/dcx_screen.png~rm /sdcard/dcx_screen.png
::LIB~w09~4~c~21~input keyevent KEYCODE_WAKEUP~Turn the screen on (does not unlock it)~input keyevent KEYCODE_SLEEP
::LIB~n01~5~r~30~cmd wifi status~Wi-Fi on or off, and the network it is connected to~
::LIB~n02~5~r~16~dumpsys wifi~Full Wi-Fi dump (long, lists saved network names)~
::LIB~n03~5~r~21~dumpsys connectivity~Networks, addresses and DNS servers (long)~
::LIB~n04~5~r~29~ip addr~Network interfaces and their IP addresses~
::LIB~n05~5~c~16~svc wifi disable~Turn Wi-Fi off (cuts a Wi-Fi adb connection)~svc wifi enable, over USB or on the phone
::LIB~n06~5~c~16~svc data disable~Turn mobile data off~svc data enable
::LIB~n07~5~r~28~cmd connectivity airplane-mode~Is airplane mode on or off~
::LIB~n08~5~c~28~cmd connectivity airplane-mode enable~Airplane mode on (cuts every radio, Wi-Fi adb too)~cmd connectivity airplane-mode disable, over USB or on the phone
::LIB~g01~6~r~19~logcat -t {NUM}~The last N lines of the phone's log~
::LIB~g02~6~r~21~logcat -b crash -d~Recent app crashes from the crash log~
::LIB~g03~6~d~16~logcat -c~Clear the phone's main, system and crash logs~
::LIB~g04~6~r~16~dumpsys meminfo~Memory use per app and in total (long)~
::LIB~g05~6~r~16~dumpsys meminfo {PKG}~Memory use of one running app~
::LIB~g06~6~r~16~dumpsys cpuinfo~CPU load and use per process~
::LIB~g07~6~r~26~top -b -n 1~One snapshot of running processes and their CPU use~
::LIB~g08~6~r~26~ps -A~Every running process~
::LIB~g09~6~r~24~df -h /data~Free and used space for apps and files~
::LIB~g10~6~r~19~uptime~Time since the last restart, and load~
::LIB~g11~6~r~16~service list~Every system service Android has registered~
::LIB~g12~6~r~24~dumpsys jobscheduler {PKG}~Scheduled background jobs of one app~
::LIB~s01~7~r~23~settings list global~Every global setting with its value (long)~
::LIB~s02~7~r~29~device_config list~Every hidden feature switch (DeviceConfig) and its value (long)~
::LIB~s03~7~c~17~settings put system screen_off_timeout {NUM}~Screen timeout in milliseconds (60000 = 1 minute)~the same command with the number shown as Its value now
::LIB~s04~7~c~17~settings put system show_touches 1~Show a dot where the screen is touched~settings put system show_touches 0
::LIB~s05~7~c~30~cmd notification set_dnd priority~Do Not Disturb on, priority only~cmd notification set_dnd off
::LIB~s06~7~c~24~cmd statusbar expand-notifications~Pull down the notification shade~cmd statusbar collapse
::LIB~i01~8~r~16~pm list packages -3 -i~Your apps and what installed each (null = adb install)~
::LIB~i02~8~r~26~cmd appops query-op REQUEST_INSTALL_PACKAGES allow~Apps you allowed to install other apps (blank = none)~
::LIB~i03~8~r~26~cmd appops get {PKG} REQUEST_INSTALL_PACKAGES~Whether one app may install apps (No operations = never set)~
::LIB~i04~8~c~26~cmd appops set {PKG} REQUEST_INSTALL_PACKAGES allow~Allow Install unknown apps for one app (if it can install)~cmd appops set {PKG} REQUEST_INSTALL_PACKAGES default
::LIB~i05~8~c~26~am start -a android.settings.MANAGE_UNKNOWN_APP_SOURCES -d package:{PKG}~Open the Install unknown apps page for one app~Press Back on the phone
::LIB~i06~8~r~17~settings get global verifier_verify_adb_installs~Are adb installs scanned by Play Protect (1 or null = yes)~
::LIB~i07~8~c~17~settings put global verifier_verify_adb_installs 0~Skip the Play Protect scan of adb installs (lowers protection)~settings put global verifier_verify_adb_installs 1

