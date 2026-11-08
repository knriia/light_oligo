@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." >nul
if errorlevel 1 (
    echo ERROR: cannot enter repository root.
    exit /b 2
)

set "LAZBUILD_CMD="
if defined LAZBUILD set "LAZBUILD_CMD=%LAZBUILD%"
if not defined LAZBUILD_CMD (
    for /f "delims=" %%I in ('where.exe lazbuild.exe 2^>nul') do if not defined LAZBUILD_CMD set "LAZBUILD_CMD=%%I"
)
if not defined LAZBUILD_CMD (
    if exist "C:\lazarus\lazbuild.exe" set "LAZBUILD_CMD=C:\lazarus\lazbuild.exe"
)
if not defined LAZBUILD_CMD (
    echo ERROR: lazbuild was not found.
    echo Set LAZBUILD to the lazbuild executable path or add lazbuild.exe to PATH.
    popd
    exit /b 2
)

echo Using lazbuild: %LAZBUILD_CMD%
set "FAILED=0"
set "FAILED_LIST="

call :build_and_run "src\platform\tests\platform_tests.lpi" "src\platform\tests\platform_tests.exe"
call :build_and_run "src\laser\tests\laser_tests.lpi" "src\laser\tests\laser_tests.exe"
call :build_and_run "src\manual\tests\manual_tests.lpi" "src\manual\tests\manual_tests.exe"
call :build_and_run "src\oligo\tests\oligo_tests.lpi" "src\oligo\tests\oligo_tests.exe"
call :build_and_run "src\protocol\tests\protocol_tests.lpi" "src\protocol\tests\protocol_tests.exe"
call :build_and_run "src\synthesis\tests\synthesis_tests.lpi" "src\synthesis\tests\synthesis_tests.exe"
call :build_and_run "src\station\tests\configuration_tests.lpi" "src\station\tests\configuration_tests.exe"
call :build_and_run "src\laser\tests\markezd_tests.lpi" "bin\markezd_tests.exe"

echo.
if "%FAILED%"=="0" (echo ALL TEST PROJECTS PASSED) else (echo FAILED PROJECTS:%FAILED_LIST%)
popd
exit /b %FAILED%

:build_and_run
echo.
echo === Building %~1 ===
"%LAZBUILD_CMD%" "%~1"
if errorlevel 1 (
    echo ERROR: build failed for %~1
    set "FAILED=1"
    set "FAILED_LIST=%FAILED_LIST% %~1"
    exit /b 0
)

if not exist "%~2" (
    echo ERROR: expected test executable was not produced: %~2
    set "FAILED=1"
    set "FAILED_LIST=%FAILED_LIST% %~1"
    exit /b 0
)

if not "%~3"=="" (
    echo === Running %~2 %~3 ===
    "%~2" %~3
) else (
    echo === Running %~2 ===
    "%~2"
)
if errorlevel 1 (
    echo ERROR: tests failed for %~1
    set "FAILED=1"
    set "FAILED_LIST=%FAILED_LIST% %~1"
) else (
    echo Tests passed for %~1
)
exit /b 0
