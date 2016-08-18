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

set LOG_ENABLED=true
if "%MBSA_LOG_DISABLED%" == "1" set LOG_ENABLED=false 

rem # uncomment for synchronous/asynchronous stop command
set STOPCMD=stopsync
rem set STOPCMD=stop

rem # uncomment and modify the following line if mbs needs more than 60s for stopping
rem set MBSA_STOP_TIMEOUT=60

rem ..\lib\runtimes\%MBSA_TARGET_PLATFORM%\mbsae.core.exe mbsa.cmd=%STOPCMD% mbsa.log.file=.\logs\mbsa_stop.log core.log.enable=%LOG_ENABLED% %*
rem GE Modified
..\lib\runtimes\%MBSA_TARGET_PLATFORM%\mbsae.core.exe mbsa.cmd=%STOPCMD% mbsa.log.file=..\..\logs\mbsa\mbsa_stop.log core.log.enable=%LOG_ENABLED% %*
set RC=%ERRORLEVEL%

:done

rem ## return with errorlevel
echo mBSA exit code: %RC%
rem ### endlocal is implied upon exit
exit /b %RC%

rem ##########
rem # code 0   - mbsa stopped successfuly
rem # code 1   - mbsa stop failed (e.g. configuration issues)
rem # code 2   - mbsa already stopped (synch was unavailable upon script startup)
rem # code 3   - mbsa synch stop timeouted (consider increasing MBSA_STOP_TIMEOUT env. variable)
rem # code 99  - mbsa platform error
rem # code 100 - mbsa is stopping (retry until exit code=2 or exit code=1)
