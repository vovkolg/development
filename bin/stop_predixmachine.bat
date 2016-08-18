@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.

SETLOCAL
SETLOCAL ENABLEEXTENSIONS

SET PREDIXHOME=%~dp0..
CD "%PREDIXHOME%"

REM Attempt a graceful shutdown
IF EXIST "%PREDIXHOME%\yeti\stop_yeti.bat" (
	CALL "%PREDIXHOME%\yeti\stop_yeti.bat"
	GOTO :ENDGRACEFUL
)
IF EXIST "%PREDIXHOME%\mbsa\bin" (
	CD "%PREDIXHOME%\mbsa\bin"
	CALL mbsa_stop.bat
	CD "%PREDIXHOME%"
	GOTO :ENDGRACEFUL
)
IF EXIST "%PREDIXHOME%\machine\bin\predix\stop_container.bat" (
	CALL "%PREDIXHOME%\machine\bin\predix\stop_container.bat"
	GOTO :ENDGRACEFUL
)

:ENDGRACEFUL

REM Wait up to 60 seconds for processes to shutdown
SET SHUTDOWNCHECKCNT=1
:SHUTDOWNCHECK
	IF !SHUTDOWNCHECKCNT! GEQ 61 (
		REM Processes still remain. Kill them forcibly
		GOTO :CLEANUP
	)
	SET yetipid=
	SET adminyetipid=
	SET mbsapid=
	SET pmpid=
	TASKLIST /FI "WINDOWTITLE EQ Yeti - start_yeti.bat" 2>NUL | find /I /N "cmd.exe">NUL
	IF %ERRORLEVEL% EQU 0 (
		GOTO :PROCESSESALIVE
	)
	TASKLIST /FI "WINDOWTITLE EQ Administrator: =Yeti - start_yeti.bat" 2>NUL | find /I /N "cmd.exe">NUL
	IF %ERRORLEVEL% EQU 0 (
		GOTO :PROCESSESALIVE
	)
	IF EXIST "%PREDIXHOME%\yeti\lock" (
		GOTO :PROCESSESALIVE
	)
	TASKLIST /FI "IMAGENAME EQ mbsae.core.exe" 2>NUL | find /I /N "mbsae.core.exe">NUL
	IF %ERRORLEVEL% EQU 0 (
		GOTO :PROCESSESALIVE
	)
	JPS -l | FINDSTR "com.prosyst.mbs.impl.framework.Start"
	IF %ERRORLEVEL% EQU 0 (
		GOTO :PROCESSESALIVE
	)
	REM No processes are alive at this point
	GOTO :EOF
	REM One or more processes remain
	:PROCESSESALIVE
	PING 127.0.0.1 -n 5 >NUL
	SET /A SHUTDOWNCHECKCNT+=1
	GOTO :SHUTDOWNCHECK

:CLEANUP
REM Clean up any remaining processes. There shouldn't be any

IF EXIST "%PREDIXHOME%\yeti\stop_yeti.bat" (
	CALL "%PREDIXHOME%\yeti\stop_yeti.bat"
	GOTO :ENDGRACEFUL
)
IF EXIST "%PREDIXHOME%\mbsa\bin" (
	CD "%PREDIXHOME%\mbsa\bin"
	CALL mbsa_stop.bat
	CD "%PREDIXHOME%"
	GOTO :ENDGRACEFUL
)
IF EXIST "%PREDIXHOME%\machine\bin\predix\stop_container.bat" (
	CALL "%PREDIXHOME%\machine\bin\predix\stop_container.bat"
	GOTO :ENDGRACEFUL
)

REM Reset variables
SET yetipid=
SET adminyetipid=
SET mbsapid=
SET pmpid=


IF EXIST "%PREDIXHOME%\yeti\lock" (
	DEL /Q "%PREDIXMACHINELOCK%\lock"
)

TASKLIST /FI "WINDOWTITLE EQ Yeti - start_yeti.bat" 2>NUL | find /I /N "cmd.exe">NUL
IF %ERRORLEVEL% EQU 0 (
	FOR /F "tokens=2 delims==; " %%i IN ('TASKLIST /FI "WINDOWTITLE EQ Yeti - start_yeti.bat"') DO set yetipid=%%i
)

TASKLIST /FI "WINDOWTITLE EQ Administrator: =Yeti - start_yeti.bat" 2>NUL | find /I /N "cmd.exe">NUL
IF %ERRORLEVEL% EQU 0 (
	FOR /F "tokens=2 delims==; " %%i IN ('TASKLIST /FI "WINDOWTITLE EQ Administrator: =Yeti - start_yeti.bat"') DO set yetipid=%%i
)

TASKLIST /FI "IMAGENAME EQ mbsae.core.exe" 2>NUL | find /I /N "mbsae.core.exe">NUL
IF %ERRORLEVEL% EQU 0 (
	FOR /F "tokens=2 delims==; " %%i IN ('TASKLIST /FI "IMAGENAME EQ mbsae.core.exe"') DO SET mbsapid=%%i
)
FOR /F "tokens=1 delims==; " %%i IN ('JPS -l ^| FINDSTR "com.prosyst.mbs.impl.framework.Start"') DO SET pmpid=%%i

IF DEFINED yetipid (
	TASKKILL /F /PID "%yetipid%"
)
IF DEFINED adminyetipid (
	TASKKILL /F /PID "%adminyetipid%"
)
IF DEFINED mbsapid (
	TASKKILL /F /PID "%mbsapid%"
)
IF DEFINED pmpid (
	TASKKILL /F /PID "%pmpid%"
)

:EOF