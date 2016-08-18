@echo off
set PROCESSOR=x86_64
setlocal 

rem ### SDK 8.0 support
set MBSA_TARGET_PLATFORM=%TARGET_PLATFORM%

rem # if PROCESSOR not defined and 64bit arch is detected, assume x86_64
set MBSA_PROCESSOR=%PROCESSOR%
if "%MBSA_PROCESSOR%" == "" if not "%PROCESSOR_ARCHITECTURE%"=="x86" set MBSA_PROCESSOR=x86_64
if "%MBSA_PROCESSOR%" == "" set MBSA_PROCESSOR=x86

rem # TARGET_PLATFORM has higher priority than PROCSSOR variable
if "%MBSA_TARGET_PLATFORM%" == "" set MBSA_TARGET_PLATFORM=win32\%MBSA_PROCESSOR%

rem ## check TARGET_PLATFORM consistency
if not exist "%CD%\..\lib\runtimes\%MBSA_TARGET_PLATFORM%" (
	echo Target platform "%MBSA_TARGET_PLATFORM%" is missing in mBSA runtimes: "%CD%\..\lib\runtimes\"
	set RC=99
	goto done
)

rem ## mBSA natives setup
set PATH="%CD%\..\lib\runtimes\%MBSA_TARGET_PLATFORM%";"%CD%\..\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins";%PATH%

rem ## Uncomment for auto updating of main mbsa TargetID, when external ip is changed
rem ## MBSA_AUTO_IP Format is "#" for using hostname to resolve external ip, or filename e.g. "/tmp/.mbsa.host.ip" to read IP when changed
rem set MBSA_AUTO_IP=#

rem set hostname
if "%MBSA_AUTO_IP%" == "#" ( for /f %%x in ( 'hostname' ) do set HOSTNAME=%%x) 
if "%MBSA_AUTO_IP%" == "#" ( 
  echo Using MBSA_AUTO_IP: from hostname: "%HOSTNAME%"
) else (
  if NOT "%MBSA_AUTO_IP%" == "" echo Using MBSA_AUTO_IP: from file: %MBSA_AUTO_IP%
)

rem ## mBSA modules print on console enablers
rem # Uncomment for enabilng dumps from mbs manager plugin on mbsa console
rem set LOG_MBSMANAGER=1

rem # Uncomment to force shared console for mbsa and launched runtimes
rem set MBSA_SHARED_CONSOLE=1

rem ## Global mBSA log disable
rem set MBSA_LOG_DISABLED=1
set LOG_ENABLED=true
if "%MBSA_LOG_DISABLED%" == "1" set LOG_ENABLED=false 

rem ## Uncomment to override default mBSA crash log dir "." (dir must exist)
rem set MBSA_CRASHDIR=%TEMP%
rem GE Modified
set MBSA_CRASHDIR=..\logs\mbsa

rem ## mBSA Log configuration
set LOG_CFG=core.log.maxsize=250 core.log.parts=2 core.log.maxcount=10 core.log.enable=%LOG_ENABLED%

echo Starting mBSA ["%CD%\..\lib\runtimes\%MBSA_TARGET_PLATFORM%\mbsae.core.exe"]...
rem ..\lib\runtimes\%MBSA_TARGET_PLATFORM%\mbsae.core.exe mbsa.cmd=start core.plugins.dir=..\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins mbsa.log.file=.\logs\mbsa_start.log core.log.file=.\logs\core.log core.prs.file=.\configs\win32\mbsal.core.prs mbsa.gui.notify=false %LOG_CFG% %*
rem GE Modified
..\lib\runtimes\%MBSA_TARGET_PLATFORM%\mbsae.core.exe mbsa.cmd=start core.plugins.dir=..\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins mbsa.log.file=..\..\logs\mbsa\mbsa_start.log core.log.file=..\..\logs\mbsa\core.log core.prs.file=.\configs\win32\mbsal.core.prs mbsa.gui.notify=false %LOG_CFG% %*
set RC=%ERRORLEVEL%
echo mBSA exit code: %RC%

rem ##########
rem # code 0    - mbsa started and exitted normally
rem # code 1    - mbsa start failed (e.g. configuration issues)
rem # code 2    - mbsa already started
rem # code 99   - mbsa platform error
rem # code 9020 - Missing required vcredist


if %RC% NEQ 9020 goto done

  echo.
  echo Missing required Microsoft.VC80.CRT package:
  if "%MBSA_PROCESSOR%" == "x86" ( 
    echo   x86: x86_Microsoft.VC80.CRT_1fc8b3b9a1e18e3b_8.0.50727.42_x-ww_0de06acd
  ) else ( 
    echo   x64: amd64_Microsoft.VC80.CRT_1fc8b3b9a1e18e3b_8.0.50727.42_x-ww_3fea50ad
  )
  echo.

  echo # List of currently installed Microsoft.VC80.CRT packages #
  echo.
  dir /b %WINDIR%\winsxs\*microsoft.vc80.crt*
  echo.
  echo.
  echo.

  pause

:done
rem ## return with errorlevel
echo mBSA exit code: %RC%
rem ### endlocal is implied upon exit

REM GE MODIFIED: CMD must exit and close Window for mBSA updates to be possible
REM exit /b %RC%
EXIT %RC%
