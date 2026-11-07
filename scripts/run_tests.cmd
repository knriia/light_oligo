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
    echo ERROR: lazbuild was not found in PATH.
    echo Set LAZBUILD to the lazbuild executable path or add lazbuild.exe to PATH.
    popd
    exit /b 2
)

echo Using lazbuild: %LAZBUILD_CMD%
set "FAILED=0"

call :build_and_run "src\laser\tests\markezd_tests.lpi" "bin\markezd_tests.exe"
call :build_and_run "src\syringe_station\tests\configuration_tests.lpi" "src\syringe_station\tests\configuration_tests.exe"

popd
exit /b %FAILED%

:build_and_run
echo.
echo === Building %~1 ===
"%LAZBUILD_CMD%" "%~1"
if errorlevel 1 (
    echo ERROR: build failed for %~1
    set "FAILED=1"
    exit /b 0
)

if not exist "%~2" (
    echo ERROR: expected test executable was not produced: %~2
    set "FAILED=1"
    exit /b 0
)

echo === Running %~2 ===
"%~2"
if errorlevel 1 (
    echo ERROR: tests failed for %~1
    set "FAILED=1"
) else (
    echo Tests passed for %~1
)
exit /b 0
