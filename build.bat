@echo off
setlocal enabledelayedexpansion
ECHO ----------------------------------------------------------
ECHO [STATUS] Setting environment variables...
ECHO ----------------------------------------------------------

REM Search for the latest Delphi version
SET "RSVARS_PATH="
SET "LATEST_VERSION="

ECHO [STATUS] Searching for Delphi installations...

REM Find all version directories and sort them to get the latest
FOR /F "delims=" %%V IN ('DIR "C:\Program Files (x86)\Embarcadero\Studio" /B /AD /O-N 2^>nul') DO (
    IF EXIST "C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat" (
        SET "LATEST_VERSION=%%V"
        SET "RSVARS_PATH=C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat"
        GOTO :FOUND_VERSION
    )
)

:FOUND_VERSION
IF DEFINED RSVARS_PATH (
    ECHO [STATUS] Found Delphi !LATEST_VERSION! at: !RSVARS_PATH!
    CALL "!RSVARS_PATH!"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO [ERROR] Failed to execute rsvars.bat
        GOTO :SCRIPTERROR
    )
) ELSE (
    ECHO [WARNING] Could not automatically find rsvars.bat
    ECHO [PROMPT] Please enter the full path to rsvars.bat:
    SET /P "RSVARS_PATH="
    
    IF NOT DEFINED RSVARS_PATH (
        ECHO [ERROR] No path provided
        GOTO :SCRIPTERROR
    )
    
    IF NOT EXIST "!RSVARS_PATH!" (
        ECHO [ERROR] File not found: !RSVARS_PATH!
        GOTO :SCRIPTERROR
    )
    
    ECHO [STATUS] Using provided path: !RSVARS_PATH!
    CALL "!RSVARS_PATH!"
    IF !ERRORLEVEL! NEQ 0 (
        ECHO [ERROR] Failed to execute rsvars.bat
        GOTO :SCRIPTERROR
    )
)

ECHO ----------------------------------------------------------
ECHO [STATUS] Cleanup in progress...
ECHO ----------------------------------------------------------
ECHO [STATUS] Removing all files from "build"
del "build\*" /S /Q /F >nul 2>&1
ECHO [STATUS] Removing folder "build"
rd /s /q "build" >nul 2>&1

ECHO ----------------------------------------------------------
ECHO [STATUS] Build in progress...
ECHO ----------------------------------------------------------
ECHO [STATUS] Building ACMEClientConsole.dproj (Release Win32 ), please wait...
MSBUILD "source\demo\ACMEClientConsole.dproj" /t:Build /p:Config=Release /p:Platform=Win32  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

ECHO [STATUS] Building ACMEClientConsole.dproj (Release Win64 ), please wait...
MSBUILD "source\demo\ACMEClientConsole.dproj" /t:Build /p:Config=Release /p:Platform=Win64  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

ECHO [STATUS] Building ACMEClientGUI.dproj (Release Win32 ), please wait...
MSBUILD "source\demo\ACMEClientGUI.dproj" /t:Build /p:Config=Release /p:Platform=Win32  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

ECHO [STATUS] Building ACMEClientGUI.dproj (Release Win64 ), please wait...
MSBUILD "source\demo\ACMEClientGUI.dproj" /t:Build /p:Config=Release /p:Platform=Win64  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

ECHO [STATUS] Building ACMEHTTPServerDemo.dproj (Release Win32 ), please wait...
MSBUILD "source\demo\ACMEHTTPServerDemo.dproj" /t:Build /p:Config=Release /p:Platform=Win32  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

ECHO [STATUS] Building ACMEHTTPServerDemo.dproj (Release Win64 ), please wait...
MSBUILD "source\demo\ACMEHTTPServerDemo.dproj" /t:Build /p:Config=Release /p:Platform=Win64  /verbosity:q /ds /nologo
IF %ERRORLEVEL% NEQ 0 GOTO :BUILDERROR

GOTO :COMPLETE
:COMPLETE
ECHO [STATUS] Build complete
ECHO ----------------------------------------------------------
EXIT /B 0

:SCRIPTERROR
ECHO [STATUS] Script failed (Error: %ERRORLEVEL%)
EXIT /B %ERRORLEVEL%

:TESTERROR
ECHO [STATUS] Tests failed (Error: %ERRORLEVEL%)
EXIT /B %ERRORLEVEL%

:BUILDERROR
ECHO [STATUS] Build failed (Error: %ERRORLEVEL%)
EXIT /B %ERRORLEVEL%

:ERROR
ECHO [STATUS] Build failed
EXIT /B 1
