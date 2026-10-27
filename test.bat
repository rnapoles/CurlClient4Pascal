@echo off
rem ---------------------------------------------------------------------------
rem  Builds, then runs unit tests, integration tests (bundled local echo server,
rem  started automatically) and the examples as a smoke test.
rem    test.bat [fpc|delphi] [win32|win64]        (defaults: fpc if present, win64)
rem  Integration tests need Python 3 (python or py) and curl.exe (Windows 10+).
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
set "ROOT=%~dp0"
set "WHICH=%~1"
if "%WHICH%"=="" (
  where fpc >nul 2>&1 && (set "WHICH=fpc") || (set "WHICH=delphi")
)
set "PLAT=%~2"
if "%PLAT%"=="" set "PLAT=win64"
if "%TEST_PORT%"=="" set "TEST_PORT=18080"
set "BASE=http://127.0.0.1:%TEST_PORT%"
set "FAILED=0"

call "%ROOT%build.bat" %WHICH% %PLAT%
if errorlevel 1 exit /b 1
set "BIN=%ROOT%build\%WHICH%-%PLAT%\bin"

echo.
echo === Unit tests ^(no network^) ===
"%BIN%\RunUnitTests.exe" || set "FAILED=1"

echo.
echo === Integration tests ^(libcurl^) ===
set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY ( where py >nul 2>&1 && set "PY=py -3" )
where curl.exe >nul 2>&1 || set "PY="
if not defined PY (
  echo Python 3 or curl.exe not found: integration tests that need the server are skipped.
  "%BIN%\RunIntegrationTests.exe" || set "FAILED=1"
  goto :done
)

start "echo-server" /B %PY% "%ROOT%tests\support\echo_server.py" %TEST_PORT% >nul 2>&1
set /a TRIES=0
:wait
curl.exe -s -o nul "%BASE%/status/200"
if errorlevel 1 (
  set /a TRIES+=1
  if !TRIES! GTR 50 ( echo echo server did not start & set "FAILED=1" & goto :stop )
  ping -n 2 127.0.0.1 >nul
  goto :wait
)

set "HTTP_TEST_BASE_URL=%BASE%"
"%BIN%\RunIntegrationTests.exe" || set "FAILED=1"

echo.
echo === Examples ^(smoke test against local server^) ===
if not exist "%ROOT%build\run" mkdir "%ROOT%build\run"
pushd "%ROOT%build\run"
for %%E in (Example.Get Example.Post Example.Builder) do (
  "%BIN%\%%E.exe" %BASE% >nul 2>&1 && (echo [PASS] %%E) || (echo [FAIL] %%E & set "FAILED=1")
)
popd

:stop
curl.exe -s -o nul "%BASE%/__shutdown"
:done
echo.
if "%FAILED%"=="0" (echo ALL GREEN) else (echo SOME TESTS FAILED)
exit /b %FAILED%
