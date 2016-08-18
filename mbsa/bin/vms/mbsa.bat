@echo off

rem Check for required variables from server_common script
if "%MBS_ROOT%" == "" echo [WARNING] MBS_ROOT variable is not set!

rem mBSA root (relative to fwk MBS_ROOT variable)
rem set MBSA_ROOT=%MBS_ROOT%
rem ###[IM]### set MBSA_ROOT=%MBS_ROOT%\..\mbsa
set MBSA_ROOT=%MBS_ROOT%\..\mbsa

rem ### SDK 8.0 support
set MBSA_TARGET_PLATFORM=%TARGET_PLATFORM%

rem # if PROCESSOR not defined and 64bit arch is detected, assume x86_64
set MBSA_PROCESSOR=%PROCESSOR%
if "%MBSA_PROCESSOR%" == "" if not "%PROCESSOR_ARCHITECTURE%"=="x86" set MBSA_PROCESSOR=x86_64
if "%MBSA_PROCESSOR%" == "" set MBSA_PROCESSOR=x86

rem # TARGET_PLATFORM has higher priority than PROCSSOR variable
if "%MBSA_TARGET_PLATFORM%" == "" set MBSA_TARGET_PLATFORM=win32\%MBSA_PROCESSOR%

set MBS_NATIVE_PATH=%MBS_NATIVE_PATH%;%MBSA_ROOT%\lib\runtimes\%MBSA_TARGET_PLATFORM%;%MBSA_ROOT%\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins

rem avoid setting ";;" in MBS_SERVER_JAR, which causes warnings 
if defined MBS_SERVER_JAR ( 
	set MBS_SERVER_JAR=%MBS_SERVER_JAR%;%MBSA_ROOT%\lib\mbsa.jar
) else (
	set MBS_SERVER_JAR=%MBSA_ROOT%\lib\mbsa.jar
)

set LOG_ENABLED=true
if "%MBSA_LOG_DISABLED%" == "1" set LOG_ENABLED=false 

rem Update Manager related configuration
if exist "%MBSA_ROOT%\..\update_storage" (
  set FEATURES=%FEATURES% -Dmbs.um.storage=%MBSA_ROOT%\..\update_storage
)
set FEATURES=%FEATURES% -Dmbs.um.osUpdate=false

rem Uncomment to force overriding of main mBSA TargetInfo address to localhost
set FEATURES=%FEATURES% -Dmbsa.lib.tm.mbsa.override=127.0.0.1

rem mBSA Core setup
set FEATURES=%FEATURES% -Dmbsa.lib.core.prs=%MBSA_ROOT%\bin\java\configs\win32\mbsal.core.prs -Dmbsa.lib.core.plugins.dir=%MBSA_ROOT%\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins

rem Uncomment to enable mBSA FaultManager support
set FEATURES=%FEATURES% -Dmbs.fm.class=com.prosyst.mbs.impl.framework.module.fm.MBSAFaultManagerImpl

rem Uncomment to enable mBSA console debug/stacktraces
rem set FEATURES=%FEATURES% -Dmbsa.debug=true -Dmbsa.events.debug=true -Dmbsa.stacktrace=true

rem Set mBSA java core log configuration
rem set FEATURES=%FEATURES% -Dmbsa.lib.core.log=%MBSA_ROOT%\bin\logs\fwcore\mbsaj.core.log -Dmbsa.lib.core.log.parts=2 -Dmbsa.lib.core.log.maxsize=250 -Dmbsa.lib.core.log.maxcount=10 -Dmbsa.lib.core.log.enable=%LOG_ENABLED%
rem GE Modified
set FEATURES=%FEATURES% -Dmbsa.lib.core.log=%MBSA_ROOT%\..\logs\mbsa\fwcore\mbsaj.core.log -Dmbsa.lib.core.log.parts=2 -Dmbsa.lib.core.log.maxsize=250 -Dmbsa.lib.core.log.maxcount=10 -Dmbsa.lib.core.log.enable=%LOG_ENABLED%

rem mBS watchdog setup (ping timeout should be "mbs.manager.ping.timeout" / 2). mbs.mbsa.commsErrors (if > 0, mbs will exit after specified comms send errors)
set FEATURES=%FEATURES% -Dmbs.comms=comms3 -Dmbs.mbsa.ping.timeout=30000 -Dmbs.mbsa.commsErrors=3

rem Prevent Framweork shutdown hook for SIGTERM
set FEATURES=%FEATURES% -Dmbs.addShutdownHook=false

echo.
echo Features        : "%FEATURES%"
echo MBS_NATIVE_PATH : "%MBS_NATIVE_PATH%"
echo MBSA_ROOT       : "%MBSA_ROOT%"
echo Update Storage  : "%MBSA_ROOT%\..\update_storage"
echo TARGET_PLATFORM : "%TARGET_PLATFORM%"
echo MBSA_PLATFORM   : "%MBSA_TARGET_PLATFORM%"
echo.


rem # sanity checks...
if not exist %MBSA_ROOT% ( echo [WARNING] MBSA_ROOT path "%MBSA_ROOT%" is inconsistent! )
if not exist %MBSA_ROOT%\lib\mbsa.jar ( echo [WARNING] "%MBSA_ROOT%\lib\mbsa.jar" is inconsistent! )
if not exist %MBSA_ROOT%\bin\java\configs\win32\mbsal.core.prs ( echo [WARNING] "%MBSA_ROOT%\bin\java\configs\win32\mbsal.core.prs" is inconsistent! )
if not exist %MBSA_ROOT%\lib\runtimes\%MBSA_TARGET_PLATFORM% ( echo [WARNING] Target platform "\lib\runtimes\%MBSA_TARGET_PLATFORM%" is inconsistent! )
if not exist %MBSA_ROOT%\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins ( echo [WARNING] Target platform "\lib\runtimes\%MBSA_TARGET_PLATFORM%\plugins" is inconsistent! )

rem pause