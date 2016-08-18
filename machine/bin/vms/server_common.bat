@echo off
title ProSyst OSGi Implementation

if b%1==b goto begin_file:
if %1==default_title goto default_title
:begin_file

rem *** Global configuration - EDIT THE VALUES BELOW IF YOU WANT TO ENABLE SOME FEATURE WITHOUT PASSING PARAMETERS

rem * enable framework loader or bundle extensions
set FWLOADER=on
rem set FWEXT=on

rem * enable JIT
set FWJIT=on

rem * to disable lazy support for bundles
rem set FWLAZY=off

rem * to enable security by default
rem set FWSECURITY=on

rem * to enable security certificated
if not defined FWCERT set FWCERT=on

rem * to enable profiling of framework startup by default
rem set FWMEASUREMENTS=on

rem * to enable resource monitoring
rem set FWRESMAN=on

rem * to enable self validation mode
rem set FWVALIDATE=on

rem * to change the boot file
rem set FWBOOTFILE=<path_to_boot.ini>

rem * to change the boot properties file
rem set FWPRS=<path_to_file.prs>

rem * to change the default storage folder
rem set FWSTORAGE=storage

rem * to clean the storage on startup
rem set FWCLEAN= -Dmbs.storage.delete=true

rem * to dump all framework errors on console
if not defined FWERR set FWERR=on

rem * to run the framework in the application class path
rem set FWAPPCP=on

rem * to enable the Uncaught Exception Manager
rem set FWUEM=on

rem * to enable the Framework Logger
if not defined FWLOG set FWLOG=on

rem * to enable the Simple Console Logger
rem LOG_SIMPLE=on

rem * set the arch name; used to load the correct libtime & resman related dll-s
rem * the processor will be set to 64 bit x86 when running on a 64 bit Windows,
rem * even if the JVM is 32 bit. In this case the processor must manually be set to 32 bit
rem GE Modified - only support x86_64
set PROCESSOR=x86_64
if not defined PROCESSOR if not "%PROCESSOR_ARCHITECTURE%" == "x86" set PROCESSOR=x86_64

rem * enable the debug (JDWP as example) mode of the virtual machine.
rem set VM_DEBUG=on

rem * explicitely set the debug port, the default is 8000, matters only if VM_DEBUG is enabled
if not defined VM_DEBUG_PORT set VM_DEBUG_PORT=8000

rem * instruct the VM to immediately suspend after starting, matters only if VM_DEBUG is enabled
rem set VM_DEBUG_SUSPEND=on

rem * pause after the VM process has exited
rem set WAITONEXIT=true

rem *** DO NOT EDIT BELOW
if not defined MBS_ROOT set MBS_ROOT=..\..\..
set MAIN_CLASS=com.prosyst.mbs.impl.framework.Start

rem *** These are "DEFAULT" variables that can be set by the caller script
if not defined _FWBOOTFILE     set _FWBOOTFILE=..\boot.ini
if not defined _FWPRS          set _FWPRS=default.prs;..\common.prs
if not defined _SERVER         set _SERVER=%MBS_ROOT%\lib\framework\serverjvm13.jar
if not defined PROCESSOR       set PROCESSOR=x86
if not defined MBS_DEVICE_ID   set MBS_DEVICE_ID=%COMPUTERNAME%

set EXTARGS=
:doParse
if x%1==x goto doSetup
rem * features
if %1==measurements   set FWMEASUREMENTS=on
if %1==nomeasurements set FWMEASUREMENTS=
if %1==resman         set FWRESMAN=on
if %1==noresman       set FWRESMAN=
if %1==validate       set FWVALIDATE=on
if %1==novalidate     set FWVALIDATE=
if %1==lazy           set FWLAZY=
if %1==nolazy         set FWLAZY=OFF
if %1==jit            set FWJIT=on
if %1==JIT            set FWJIT=on
if %1==nojit          set FWJIT=
if %1==security       set FWSECURITY=on
if %1==nosecurity     set FWSECURITY=
if %1==cert           set FWCERT=on
if %1==nocert         set FWCERT=
if %1==clean          set FWCLEAN= -Dmbs.storage.delete=true
if %1==noclean        set FWCLEAN=
if %1==fwloader       set FWLOADER=on
if %1==nofwloader     set FWLOADER=
if %1==fwext          set FWEXT=on
if %1==nofwext        set FWEXT=
if %1==fwerr          set FWERR=on
if %1==nofwerr        set FWERR=
if %1==uem            set FWUEM=on
if %1==nouem          set FWUEM=
if %1==fwlog          set FWLOG=on
if %1==nofwlog        set FWLOG=
if %1==logsimple      set LOG_SIMPLE=on
if %1==nologsimple    set LOG_SIMPLE=
if %1==logconsole     set LOG_SIMPLE=on
if %1==nologconsole   set LOG_SIMPLE=
if %1==appcp          set FWAPPCP=on
if %1==noappcp        set FWAPPCP=
if %1==debug          set VM_DEBUG=on
if %1==nodebug        set VM_DEBUG=
if %1==dbg_suspend    set VM_DEBUG_SUSPEND=on
if %1==dbg_nosuspend  set VM_DEBUG_SUSPEND=
if %1==dbg_port       set VM_DEBUG_PORT=%2
if %1==dbg_port       shift
if %1==waitonexit     set WAITONEXIT=true
rem * collect setup files
if exist %1.bat set EXT_FILES=%EXT_FILES% %1.bat
if not exist %1.bat if exist ..\%1.bat set EXT_FILES=%EXT_FILES% ..\%1.bat
if not exist %1.bat if not exist ..\%1.bat if exist %1.ini set EXTBOOTFILE=%EXTBOOTFILE%;%1.ini
if not exist %1.bat if not exist ..\%1.bat if not exist %1.ini if exist ..\%1.ini set EXTBOOTFILE=%EXTBOOTFILE%;..\%1.ini
rem * shift to next argument and re-run
set EXTARGS=%EXTARGS% %1
shift
goto doParse

rem *** Processes the command line parameters and sets the VM-specific features
:doSetup
rem * call setup files & auto start files
for %%F in (%EXT_FILES%)  do call %%F %EXTARGS%
for %%F in (auto*.bat)    do call %%F %EXTARGS%
for %%F in (..\auto*.bat) do call %%F %EXTARGS%
rem * sane parameters
if not defined FWPRS      set FWPRS=%EXTPRS%;%_FWPRS%
rem * disable extension boot file processing
if defined FW_NOEXTBOOTFILE set EXTBOOTFILE=
rem * fix boot file
if not defined FWBOOTFILE set FWBOOTFILE=%_FWBOOTFILE%;%EXTBOOTFILE%
rem * make sure FWEXT switches FWLOADER too
if defined FWEXT          set FWLOADER=on
rem * set features
if defined FWPRS          set FEATURES=%FEATURES% -Dmbs.prs.name=%FWPRS%
if defined FWLOADER       set FEATURES=%FEATURES% -Dmbs.customFrameworkLoader=true -Dmbs.server.jar=%_SERVER%;%MBS_SERVER_JAR%
if defined FWRESMAN       set FEATURES=%FEATURES% -Dmbs.resman.enabled=true
if defined FWVALIDATE     set FEATURES=%FEATURES% -Dmbs.um.validation=true
if defined FWEXT          set FEATURES=%FEATURES% -Dorg.osgi.supports.framework.extension=true
if not defined FWERR      set FEATURES=%FEATURES% -Dmbs.log.errorlevel=false
if defined FWLAZY         set FEATURES=%FEATURES% -Dmbs.bundles.lazy=false
if defined FWSECURITY     set FEATURES=%FEATURES% -Dmbs.security=jdk12 -Djava.security.policy=../policy.all -Dmbs.sm=true
if not defined FWCERT     set FEATURES=%FEATURES% -Dmbs.certificates=false
if defined FWBOOTFILE     set FEATURES=%FEATURES% -Dmbs.boot.bootfile=%FWBOOTFILE%
if defined FWMEASUREMENTS set FEATURES=%FEATURES% -Dmbs.measurements.intermediate=true
if defined FWSTORAGE      set FEATURES=%FEATURES% -Dmbs.storage.root=%FWSTORAGE%
if defined FWUEM          set FEATURES=%FEATURES% -Dmbs.thread.uem=true
if defined FWCLEAN (
                          if exist bootcp.set del bootcp.set
                          if exist restart.set del restart.set
                          if exist properties.set del properties.set
)
if defined FWLOG          set FEATURES=%FEATURES% -Dmbs.log.file.dir=logs
if defined LOG_SIMPLE     set FEATURES=%FEATURES% -Dmbs.log.simple=true
if defined MBS_DEVICE_ID  set FEATURES=%FEATURES% -Dcom.prosyst.mbs.deviceId=%MBS_DEVICE_ID%
rem * setup the library path
set MBS_STORAGE=%FWSTORAGE%
if "x%MBS_STORAGE%" == "x" set MBS_STORAGE=storage
set MBS_NATIVE_PATH=%MBS_NATIVE_PATH%;%MBS_ROOT%\lib\framework\runtimes\win-%PROCESSOR%;%MBS_STORAGE%\native
rem * add native path to the system path, where libraries can be loaded succesfully
set PATH=%MBS_NATIVE_PATH%;%PATH%
rem * always add Windows os alias & swith the JIT off
if not defined JIT set JIT=-Djava.compiler=
if defined FWJIT set JIT=
set VM_ARGS=%VM_ARGS% %JIT% -Dos.aliases=Win32,win* -Dmbs.osinfo.class=com.prosyst.util.os.win.OsInfo_Impl

goto end_file

:default_title
if defined WAITONEXIT pause
title %comspec%

:end_file
exit /b %FWEXITCODE%