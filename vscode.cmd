@echo off
rem This script launches the vscode with the msvc tools environment set up.

setlocal EnableExtensions DisableDelayedExpansion

title Gagis - Visual Studio Developer Environment

set "PROJECT=."
set "LOG=%~dp0launch-vscode.log"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

echo Starting VS Code...
echo Diagnostic log: "%LOG%"
echo.

> "%LOG%" echo Started: %date% %time%

call :MAIN >> "%LOG%" 2>&1
set "RESULT=%ERRORLEVEL%"

if "%RESULT%"=="0" goto SUCCESS

echo.
echo ========================================
echo ERROR: The launcher failed
echo ========================================
echo.
type "%LOG%"
echo.
echo The diagnostic log is:
echo "%LOG%"
echo.
pause
exit /b %RESULT%


:SUCCESS
exit /b 0


:MAIN
echo [INFO] Checking project directory...

if exist "%PROJECT%\" goto PROJECT_OK

echo [ERROR] Project directory does not exist:
echo         %PROJECT%
exit /b 1


:PROJECT_OK
echo [INFO] Checking vswhere.exe...

if exist "%VSWHERE%" goto VSWHERE_OK

echo [ERROR] vswhere.exe was not found:
echo         %VSWHERE%
exit /b 1


:VSWHERE_OK
echo [INFO] Finding Visual Studio installation...

set "VSTEMP=%TEMP%\vswhere-%RANDOM%-%RANDOM%.txt"

"%VSWHERE%" ^
    -latest ^
    -products * ^
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
    -property installationPath ^
    > "%VSTEMP%" 2>&1

if errorlevel 1 goto VSWHERE_FAILED

set "VSPATH="
set /p "VSPATH="<"%VSTEMP%"
del "%VSTEMP%" >nul 2>&1

if defined VSPATH goto VS_FOUND

echo [ERROR] No suitable Visual Studio installation was found.
exit /b 1


:VSWHERE_FAILED
echo [ERROR] vswhere.exe failed:
type "%VSTEMP%"
del "%VSTEMP%" >nul 2>&1
exit /b 1


:VS_FOUND
echo [INFO] Visual Studio:
echo        %VSPATH%

set "VSDEVCMD=%VSPATH%\Common7\Tools\VsDevCmd.bat"

if exist "%VSDEVCMD%" goto VSDEVCMD_FOUND

echo [ERROR] VsDevCmd.bat was not found:
echo         %VSDEVCMD%
exit /b 1


:VSDEVCMD_FOUND
echo [INFO] Initializing Visual Studio developer environment...

call "%VSDEVCMD%" -arch=amd64 -host_arch=amd64

if errorlevel 1 goto VSDEVCMD_FAILED
goto FIND_CODE


:VSDEVCMD_FAILED
echo [ERROR] VsDevCmd.bat failed.
exit /b 1


:FIND_CODE
echo [INFO] Finding VS Code...

set "CODE="
set "CODETEMP=%TEMP%\codewhere-%RANDOM%-%RANDOM%.txt"

where.exe code.cmd > "%CODETEMP%" 2>nul

if errorlevel 1 goto CODE_PATH_NOT_FOUND

set /p "CODE="<"%CODETEMP%"
del "%CODETEMP%" >nul 2>&1

if defined CODE goto CODE_FOUND


:CODE_PATH_NOT_FOUND
del "%CODETEMP%" >nul 2>&1

set "CODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
if exist "%CODE%" goto CODE_FOUND

set "CODE=%ProgramFiles%\Microsoft VS Code\bin\code.cmd"
if exist "%CODE%" goto CODE_FOUND

set "CODE=%ProgramFiles(x86)%\Microsoft VS Code\bin\code.cmd"
if exist "%CODE%" goto CODE_FOUND

set "CODE="

echo [ERROR] code.cmd was not found.
echo.
echo Checked PATH and the standard VS Code installation directories.
exit /b 1


:CODE_FOUND
echo [INFO] VS Code command:
echo        %CODE%
echo.
echo [INFO] Opening project:
echo        %PROJECT%
echo.
echo [INFO] This CMD process will remain open until VS Code closes.

call "%CODE%" --new-window --wait "%PROJECT%"

set "CODE_RESULT=%ERRORLEVEL%"

if not "%CODE_RESULT%"=="0" goto CODE_FAILED

echo [INFO] VS Code closed normally.
exit /b 0


:CODE_FAILED
echo [ERROR] VS Code exited with code %CODE_RESULT%.
exit /b %CODE_RESULT%
