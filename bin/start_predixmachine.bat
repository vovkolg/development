@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.

SETLOCAL

SET PREDIXHOME=%~dp0..
CD "%PREDIXHOME%"
SET LOG=%PREDIXHOME%\logs\predixmachine_start.log

SET ROOT=false
:CHECKARGS 
IF "%1" == "" (
	GOTO :ENDCHECKARGS
) ELSE (
	IF "%1" == "--force-root" (
		SET ROOT=true
	) ELSE (
		EXIT /B 1
	)
	SHIFT
)
GOTO :CHECKARGS
:ENDCHECKARGS

NET SESSION > NUL 2>&1
IF %ERRORLEVEL% EQU 0 (
  	IF "%ROOT%" == "false" (
		(
			CALL :WRITECONSOLELOG "Predix Machine should not be run as admin.  We recommend you create a low privileged predixmachineuser, allowing them only the required admin privileges to execute machine.  Bypass this error message with the argument --force-root"
   		)
  		EXIT /B 1
  	)
)

ECHO Starting Predix Machine > "%LOG%"

FOR /F "tokens=1 delims==; " %%i IN ('JPS -l ^| FINDSTR "com.prosyst.mbs.impl.framework.Start"') DO SET pmpid=%%i
IF NOT "%pmpid%"=="" (
	CALL :WRITECONSOLELOG "Another instance of Predix Machine is running. Please shut it down before continuing."
	EXIT /B 1
)
IF EXIST "%PREDIXHOME%\yeti\start_yeti.bat" (
	CALL "%PREDIXHOME%\yeti\start_yeti.bat" --force-root
	GOTO :EOF
)
IF EXIST "%PREDIXHOME%\mbsa\bin\mbsa_start.bat" (
	CD "%PREDIXHOME%\mbsa\bin"
	CALL mbsa_start.bat
	CD "%PREDIXHOME%"
	GOTO :EOF
)
IF EXIST "%PREDIXHOME%\machine\bin\predix\start_container.bat" (
	CALL "%PREDIXHOME%\machine\bin\predix\start_container.bat"
	GOTO :EOF
) ELSE (
	CALL :WRITECONSOLELOG "The directory structure was not recognized.  Predix Machine could not be started."
	EXIT /B 1
)

:TIMESTAMP
	SET RUNTIME=%date:~4,10% %time:~0,8%
	EXIT /B

:WRITECONSOLELOG
	CALL :TIMESTAMP
	ECHO %RUNTIME% %~1 >> "%LOG%"
	ECHO %RUNTIME% %~1
	EXIT /B

:EOF