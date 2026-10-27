@echo off
rem ---------------------------------------------------------------------------
rem  Builds the examples and test runners.
rem    build.bat [fpc|delphi|all] [win32|win64]        (defaults: all, win64)
rem  Delphi : needs RAD Studio 12+ (uses %BDS%, or the default 23.0 install dir)
rem  FPC    : needs fpc.exe on PATH (3.2.2+)
rem  Output : build\fpc-<platform>\bin   and   build\delphi-<platform>\bin
rem  Put libcurl.dll (+ its dependencies) of the SAME bitness next to the .exe
rem  files, or set CURL_DLL_DIR and it is copied for you.
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
set "ROOT=%~dp0"
set "WHICH=%~1"
if "%WHICH%"=="" set "WHICH=all"
set "PLAT=%~2"
if "%PLAT%"=="" set "PLAT=win64"

set "PROGRAMS=examples\Example.Get.dpr examples\Example.Post.dpr examples\Example.Builder.dpr examples\Example.Upload.dpr tests\RunUnitTests.dpr tests\RunIntegrationTests.dpr"
set "BUILT=0"
set "FAILED=0"

if /I "%WHICH%"=="fpc"    call :build_fpc    || set "FAILED=1"
if /I "%WHICH%"=="delphi" call :build_delphi || set "FAILED=1"
if /I "%WHICH%"=="all" (
  call :build_fpc    || set "FAILED=1"
  call :build_delphi || set "FAILED=1"
)
if "%BUILT%"=="0" (
  echo No compiler was available. Install Delphi 12+ or Free Pascal 3.2.2+.
  exit /b 1
)
if "%FAILED%"=="1" ( echo BUILD FAILED & exit /b 1 )
echo BUILD OK
exit /b 0

:build_fpc
where fpc >nul 2>&1
if errorlevel 1 (
  if /I "%WHICH%"=="fpc" ( echo error: fpc.exe not found on PATH & exit /b 1 )
  echo [skip] Free Pascal not found
  exit /b 0
)
set "OUT=%ROOT%build\fpc-%PLAT%"
if not exist "%OUT%\bin"   mkdir "%OUT%\bin"
if not exist "%OUT%\units" mkdir "%OUT%\units"
echo === Free Pascal ^(%PLAT%^) ===
for %%P in (%PROGRAMS%) do (
  echo Building %%P
  fpc -Mdelphi -O2 -vewn -Fi"%ROOT%src" -Fu"%ROOT%src" -Fu"%ROOT%src\curl" -Fu"%ROOT%vendor" -Fu"%ROOT%tests\support" -Fu"%ROOT%tests\unit" -Fu"%ROOT%tests\integration" -FU"%OUT%\units" -FE"%OUT%\bin" "%ROOT%%%P"
  if errorlevel 1 exit /b 1
)
call :copy_dll "%OUT%\bin"
set "BUILT=1"
exit /b 0

:build_delphi
set "RSVARS="
if defined BDS if exist "%BDS%\bin\rsvars.bat" set "RSVARS=%BDS%\bin\rsvars.bat"
if not defined RSVARS if exist "%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat" set "RSVARS=%ProgramFiles(x86)%\Embarcadero\Studio\23.0\bin\rsvars.bat"
if not defined RSVARS (
  if /I "%WHICH%"=="delphi" ( echo error: RAD Studio not found ^(set BDS^) & exit /b 1 )
  echo [skip] Delphi not found
  exit /b 0
)
call "%RSVARS%" >nul
set "DCC=dcc64.exe"
if /I "%PLAT%"=="win32" set "DCC=dcc32.exe"
set "OUT=%ROOT%build\delphi-%PLAT%"
if not exist "%OUT%\bin" mkdir "%OUT%\bin"
if not exist "%OUT%\dcu" mkdir "%OUT%\dcu"
echo === Delphi ^(%DCC%^) ===
set "UPATH=%ROOT%src;%ROOT%src\curl;%ROOT%vendor;%ROOT%tests\support;%ROOT%tests\unit;%ROOT%tests\integration"
for %%P in (%PROGRAMS%) do (
  echo Building %%P
  %DCC% -B -Q -$O+ -CC -NSSystem;System.Win;Winapi;Winapi.Windows -I"%ROOT%src" -U"!UPATH!" -E"%OUT%\bin" -N0"%OUT%\dcu" "%ROOT%%%P"
  if errorlevel 1 exit /b 1
)
call :copy_dll "%OUT%\bin"
set "BUILT=1"
exit /b 0

:copy_dll
if defined CURL_DLL_DIR (
  if exist "%CURL_DLL_DIR%\libcurl.dll" copy /Y "%CURL_DLL_DIR%\*.dll" %1 >nul
)
exit /b 0
