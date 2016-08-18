@echo off
setlocal
set SKIP_BOOTINI="true"
set PROCESSOR=x86_64

rem *** Global configuration - EDIT THE VALUES BELOW IF YOU WANT TO ENABLE SOME FEATURE WITHOUT PASSING PARAMETERS
rem * an integer in the interval [14,18]
if not defined VM_VERSION set VM_VERSION=15

rem * vm specific code - safe to change though not recommended
set VM_ARGS_v14=
set VM_ARGS_v15=
set VM_ARGS_v16=-Dsun.lang.ClassLoader.allowArraySyntax=true

rem *** DO NOT EDIT BELOW!!!!!

rem * locate VM
set JAVA=java
if not defined VM_HOME goto vmOK
if exist %VM_HOME%\bin\java.exe set JAVA=%VM_HOME%\bin\java.exe
if exist %VM_HOME%\bin\java.exe goto vmOk
echo Please or VM_HOME variables to point to the location, where the VM is installed.
goto end
:vmOk

rem *** Parses the command line parameters
:doParse
if x%1==x goto doSetup
rem * version
if %1==jdk1.4 set VM_VERSION=14
if %1==jdk1.5 set VM_VERSION=15
if %1==jdk1.6 set VM_VERSION=15
if %1==jdk1.6 set VM_ARGS_v15=%VM_ARGS_v15% %VM_ARGS_v16%
rem * help
if %1==help goto help
rem * shift to next argument and re-run
set _ARGS=%_ARGS% %1
shift
goto doParse

rem *** Processes the command line parameters and sets the VM-specific features
:doSetup
rem * version specific parameters, disable JIT & enables some optimizations
if %VM_VERSION%==14 set VM_ARGS=%VM_ARGS% %VM_ARGS_v14%
if %VM_VERSION%==15 set VM_ARGS=%VM_ARGS% %VM_ARGS_v15%
if %VM_VERSION% geq 16 set VM_ARGS=%VM_ARGS% %VM_ARGS_v15% %VM_ARGS_v16%
if %VM_VERSION% geq 16 set VM_VERSION=15
rem * server setup
set _SERVER=..\..\..\lib\framework\serverjvm%VM_VERSION%%_SERVER_SUFFIX%.jar
rem * run common setup routine
call ..\server_common.bat %_ARGS%
rem * setup extra bootclasspath if not framework loader is set
if not defined FWLOADER set mCP=%MBS_SERVER_JAR%
rem * set classpath
if not defined FWAPPCP set CP=-Xbootclasspath/a:%_SERVER%;%mCP% -cp ..\..\..\lib\framework\fwtime.jar;%EXTRA_CP%
if     defined FWAPPCP set CP=-cp %_SERVER%;%mCP%;..\..\..\lib\framework\fwtime.jar;%EXTRA_CP%
rem * remote debugging
set _VM_SUSPEND=n
if defined VM_DEBUG_SUSPEND set _VM_SUSPEND=y
if defined VM_DEBUG if %VM_VERSION% GEQ 15 set VM_ARGS=%VM_ARGS% -agentlib:jdwp=transport=dt_socket,server=y,address=0.0.0.0:%VM_DEBUG_PORT%,suspend=%_VM_SUSPEND%
if defined VM_DEBUG if %VM_VERSION% LSS 15 set VM_ARGS=%VM_ARGS% -Xdebug -Xrunjdwp:transport=dt_socket,server=y,address=%VM_DEBUG_PORT%,suspend=%_VM_SUSPEND%


:start
rem * re-read boot class path extensions
set BOOTCP=
if exist bootcp.set set /p BOOTCP= < bootcp.set
if defined BOOTCP set BOOTCP="%BOOTCP%"
if defined FWBOOTCP set BOOTCP=%FWBOOTCP%;%BOOTCP%
if defined BOOTCP set BOOTCP=-Xbootclasspath/p:%BOOTCP%
rem * start the server
echo %JAVA% %VM_ARGS% %BOOTCP% %CP% %FEATURES% %FWCLEAN% %MAIN_CLASS%
if not defined FWDUMPCMD %JAVA% %VM_ARGS% %BOOTCP% %CP% %FEATURES% %FWCLEAN% %MAIN_CLASS%
rem framework extension was installed - restart
set FWEXITCODE=%ERRORLEVEL%
if %FWEXITCODE% == 23 goto restart
if %FWEXITCODE% == 25 goto restart_clean
goto end

:restart
set FWCLEAN=
goto start

:restart_clean
set FWCLEAN=-Dmbs.storage.delete=true
goto start

:help
type ..\server_common_help.txt
type server_help.txt

:end
call ..\server_common.bat default_title
endlocal
