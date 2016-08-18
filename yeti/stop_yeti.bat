@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.

SET PREDIXHOME=%~dp0..
IF NOT DEFINED PREDIXMACHINELOCK (
    SET PREDIXMACHINELOCK=%PREDIXHOME%\yeti
)
SET RUNDATE=%date:~-10,2%%date:~-7,2%%date:~-2,4%%time:~-11,2%%time:~-8,2%%time:~-5,2%
SET LOG=%~dp0..\logs\installations\yeti_stop_log%RUNDATE%.txt
CALL :WRITECONSOLELOG "SHUTTING DOWN..."
DEL /Q "%PREDIXMACHINELOCK%\lock"
IF %ERRORLEVEL% EQU 1 (
	CALL :WRITECONSOLELOG "Error shutting down Yeti, access to remove lock file at %PREDIXMACHINELOCK%\lock is denied."
	PAUSE
	EXIT /B 1
)
SET SHUTDOWNCHECKCNT=1
:SHUTDOWNCHECK
	IF !SHUTDOWNCHECKCNT! GEQ 180 (
		CALL :WRITECONSOLELOG "Shutdown took longer than 3 minutes.  Check the logs in logs/installations for more information."
		EXIT /B 1
	)
	TASKLIST /FI "IMAGENAME EQ mbsae.core.exe" 2>NUL | find /I /N "mbsae.core.exe">NUL
	IF %ERRORLEVEL% EQU 0 (
		CALL :WRITECONSOLELOG "Checking for shutdown completion. Check number %SHUTDOWNCHECKCNT%"
		TIMEOUT /T 1 > NUL
		SET /A SHUTDOWNCHECKCNT+=1
		GOTO :SHUTDOWNCHECK
	)
ECHO Complete. Yeti has shutdown. Press enter to exit...
CALL :WRITECONSOLELOG "Complete. Yeti has shutdown."
TIMEOUT /T 10 > NUL
EXIT /B 0

:TIMESTAMP
	SET RUNTIME=%date:~4,10% %time:~0,8%
	EXIT /B

:WRITECONSOLELOG
	CALL :TIMESTAMP
	ECHO %RUNTIME% %~1 >> "%LOG%"
	ECHO %RUNTIME% %~1
	EXIT /B