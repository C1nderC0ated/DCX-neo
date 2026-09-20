@echo off
setlocal EnableExtensions
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
if exist "%~dp0adb\adb.exe" (
    cd /d "%~dp0adb"
    set "PATH=%~dp0adb;%PATH%"
)

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
set "_here=%CD%"
for /f "delims=" %%d in ("%_here%") do (
    endlocal
    set "_adbdir=%%d"
)
:: Outside the block on purpose: endlocal discards every variable change made inside the
:: setlocal scope, so PATH has to be set once we are back out of it. (The ')' in
:: "Program Files (x86)" is not a problem either way - the quotes around set "PATH=..."
:: protect it inside a block too; measured, not assumed.)
cd /d "%_adbdir%"
set "PATH=%_adbdir%;%PATH%"
set "_adbdir="
cmd /k
