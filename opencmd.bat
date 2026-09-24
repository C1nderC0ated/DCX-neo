@echo off
:: DisableDelayedExpansion, explicitly: the setting is otherwise inherited from whoever started
:: this file - a DelayedExpansion=1 registry default (see cmd /?) or a calling batch that has it
:: on - and with it on, the %~dp0 reads below drop a "!" from this folder's name, so a folder
:: like D:\Tools\DC!X said "ADB was not found" (and printed its [!] as []). Measured.
setlocal EnableExtensions DisableDelayedExpansion
cls
title ADB Console (starting)
:: ---------------------------------------------------------------------------
:: opencmd.bat - open a command prompt that is ready for ADB work:
::   * changes into the local .\adb folder if one is bundled (same rule DCX uses)
::   * verifies adb is actually runnable, and stops with a clear message if not
::   * starts the adb server up front so the first real command is not slow
::   * reports what is attached AND its state (device / unauthorized / offline)
::   * then hands you an interactive prompt via `cmd /k` - so the working folder
::     and the running server persist into the shell you type in.
:: `@cmd` alone did none of this: no server, no device check, just a bare prompt.
:: ---------------------------------------------------------------------------
:: Same adb-location rule as DCX.bat: prefer the bundled adb folder, else PATH.
:: FIX: the first test was relative to the CURRENT directory while the cd went to %~dp0adb,
:: so the two could disagree - and being in the folder is not enough on its own. Windows
:: images that set NoDefaultCurrentDirectoryInExePath (hardened and enterprise builds) do not
:: search the current directory for executables, so "adb" failed here with adb.exe sitting
:: right there, and the script blamed the user for not installing it. Put the folder on PATH.
:: FIX (a ";" in this folder's name): ";" separates PATH entries, so D:\Tools\q;r\adb went on
:: as D:\Tools\q and r\adb, and with that setting an older adb from PATH ran instead. cmd reads
:: an entry in quotes as one entry, so such a folder goes on quoted - through a for variable,
:: whose quotes the parser never sees, so an & in the same name cannot split the line. Every
:: other folder goes on exactly as before. Measured. (where.exe skips a quoted entry.)
set "_ocq="
set "_ocd=%~dp0adb"
if not "%_ocd:;=%"=="%_ocd%" set "_ocq=1"
if not exist "%~dp0adb\adb.exe" goto _oc_nolocal
cd /d "%~dp0adb"
:: FIX (a quoted PATH entry holding ")"): these two lines used to sit inside a ( ) block, which
:: expands %PATH% when the block is parsed - so an entry such as "C:\Prog (x86)\x" ended the
:: set's quotes early and its ")" closed the block: the file stopped at once. Outside a block a
:: ")" closes nothing, the same as the two PATH lines at the end of this file. Measured.
if not defined _ocq set "PATH=%~dp0adb;%PATH%"
if defined _ocq for %%Q in ("%~dp0adb") do set "PATH=%%Q;%PATH%"

:_oc_nolocal
:: Verify adb is runnable before promising anything.
adb version >nul 2>&1
if errorlevel 1 (
    echo [!] ADB was not found.
    echo.
    echo     Put this script next to an "adb" folder that contains adb.exe,
    echo     or install platform-tools and add it to your PATH.
    echo.
    echo     Press any key to close.
    pause >nul
    exit /b 1
)
:: Bring the server up now so the first command in the shell is not the one
:: that pays the ~1s startup cost.
title ADB Console (starting server)
adb start-server >nul 2>&1
cls
title ADB Console
for /f "delims=" %%v in ('adb version 2^>nul ^| findstr /i /c:"Android Debug Bridge"') do set "ADBVER=%%v"
echo ==========================================================
echo   ADB Console
if defined ADBVER echo   %ADBVER%
:: quoted: an ^& in the path would otherwise be read as a command separator
echo   Folder: "%CD%"
echo ==========================================================
echo.
:: Report attached devices AND their state, honestly. `adb devices` lists a
:: header line then one "<serial>\t<state>" line per device; state is device,
:: unauthorized (accept the RSA prompt on the phone), or offline (re-plug / re-auth).
set "DEVCOUNT=0"
set "UNAUTH=0"
set "OFFLINE=0"
for /f "skip=1 tokens=1,2" %%a in ('adb devices 2^>nul') do (
    if not "%%a"=="" (
        set /a DEVCOUNT+=1
        if /i "%%b"=="unauthorized" set /a UNAUTH+=1
        if /i "%%b"=="offline"      set /a OFFLINE+=1
        echo   Attached: %%a  [%%b]
    )
)
if "%DEVCOUNT%"=="0" (
    echo   No devices attached.
    echo     - USB: enable USB debugging, plug in, accept the prompt on the phone.
    echo     - Wi-Fi, Android 11+: Developer options -^> Wireless debugging shows the
    echo       ip:port to use -  adb connect ^<IP^>:^<PORT^>  - and it is NOT 5555; the
    echo       port changes each time. Pair first with  adb pair ^<IP^>:^<PAIRPORT^>.
    echo     - Wi-Fi, older builds put on Wi-Fi with  adb tcpip 5555 :  adb connect ^<IP^>:5555
) else (
    if not "%UNAUTH%"=="0" echo   Note: an "unauthorized" device needs you to accept the RSA prompt on it.
    if not "%OFFLINE%"=="0" echo   Note: an "offline" device usually needs a re-plug or  adb kill-server ^&^& adb start-server.
)
echo.
echo ----------------------------------------------------------
echo   Handy:
echo     adb devices -l                list devices with model/details
echo     adb shell                     interactive device shell
echo     adb logcat                    live logs  (Ctrl+C to stop)
echo     adb install ^<file.apk^>        sideload an APK
echo     adb pull ^<remote^> ^<local^>     copy a file off the device
echo     adb push ^<local^> ^<remote^>     copy a file onto the device
echo     adb reboot                    reboot the device
echo     adb kill-server               reset adb if it acts up
echo.
echo   Type  exit  to close this window.
echo ----------------------------------------------------------
echo.
:: Hand over an interactive prompt in THIS folder, with the server already up.
::
:: Careful: endlocal RESTORES the working directory that setlocal saved, so a plain
:: "endlocal & cmd /k" would drop the shell back in the original folder, not .\adb -
:: defeating the whole point. So capture the current dir, end the local scope while
:: passing that dir OUT through the classic for/f-endlocal tunnel, cd back into it,
:: then open the prompt. The adb server persists regardless (it is a separate process).
::
:: After endlocal this file runs with its caller's delayed-expansion setting again. If that is
:: on, the set below and the two lines after the block would drop a "!" from the folder, so the
:: shell would open elsewhere with a wrong PATH entry. "!!" reads as empty only when it is on:
:: then one more setlocal turns it off for the rest of the file. That scope ends when this file
:: does, i.e. after the shell below exits, so only in that case does the calling prompt get its
:: own folder and PATH back afterwards. With it off - the normal case - nothing changes.
set "_here=%CD%"
for /f "delims=" %%d in ("%_here%") do (
    endlocal
    if "!!"=="" setlocal DisableDelayedExpansion
    set "_adbdir=%%d"
)
:: Outside the block on purpose: endlocal discards every variable change made inside the
:: setlocal scope, so PATH has to be set once we are back out of it. (The ')' in
:: "Program Files (x86)" is not a problem either way - the quotes around set "PATH=..."
:: protect it inside a block too; measured, not assumed.)
cd /d "%_adbdir%"
:: A ";" in the folder: quoted, as at the top.
if "%_adbdir:;=%"=="%_adbdir%" set "PATH=%_adbdir%;%PATH%"
if not "%_adbdir:;=%"=="%_adbdir%" for %%Q in ("%_adbdir%") do set "PATH=%%Q;%PATH%"
set "_adbdir="
cmd /k

