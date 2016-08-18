@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.
title=Yeti - start_yeti.bat
SETLOCAL EnableDelayedExpansion
SET PREDIXHOME=%~dp0..
IF NOT DEFINED PREDIXMACHINELOCK (
    SET PREDIXMACHINELOCK=%PREDIXHOME%\yeti
)
SET RUNDATE=%date:~-10,2%%date:~-7,2%%date:~-2,4%%time:~-11,2%%time:~-8,2%%time:~-5,2%
SET LOG=%~dp0..\logs\installations\yeti_log%RUNDATE%.txt
SET TEMPDIR=%USERPROFILE%\AppData\Local\Temp
SET AIRSYNC=%PREDIXHOME%\appdata\airsync

SET ROOT=false
:CHECKARGS 
IF "%1" == "" (
	GOTO :ENDCHECKARGS
) ELSE (
	IF "%1" == "--force-root" (
		SET ROOT=true
	) ELSE (
		CALL :USAGE
		EXIT /B 1
	)
	SHIFT
)
GOTO :CHECKARGS
:ENDCHECKARGS

NET SESSION > NUL 2>&1
IF %ERRORLEVEL% EQU 0 (
	(
	CALL :WRITECONSOLELOG "Predix Machine should not be run as admin.  We recommend you create a low privileged predixmachineuser, allowing them only the required admin privileges to execute machine.  Bypass this error message with the argument --force-root"
  	)
  	IF "%ROOT%" == "false" (
  		EXIT /B 1
  	)
)

REM Exit if keytool is not installed.
WHERE keytool >NUL 2>NUL
IF %ERRORLEVEL% EQU 1 (
    CALL :WRITECONSOLELOG "Java keytool not found. Exiting."
    EXIT /B 1
)

CALL :WRITECONSOLELOG "Yeti started..."

REM Check if a mBSA is already running
TASKLIST /FI "IMAGENAME eq mbsae.core.exe" 2>NUL | find /I /N "mbsae.core.exe">NUL
IF %ERRORLEVEL% EQU 0 (
	CALL :WRITECONSOLELOG "An instance of Predix Machine is already running. Please shut down this instance before continuing."
	EXIT /B 1	
)
:ENDMBSACHECK
REM Check if previous run was shut down correctly.
IF EXIST "%PREDIXMACHINELOCK%\lock" (
	DEL "%PREDIXMACHINELOCK%\lock"
)
IF NOT EXIST "%PREDIXHOME%\mbsa\bin\mbsa_start.bat" (
	CALL :TIMESTAMP
	CALL :WRITECONSOLELOG "The mBSA application does not exist.  This is a required application for Yeti."
	EXIT /B 1
)
REM Startup mBSA
CD "%PREDIXHOME%\mbsa\bin"
CMD /C START "yeti" mbsa_start.bat > NUL 2>&1
CD "%PREDIXHOME%"

REM Write the process ID to the lock file
FOR /F "tokens=2 delims==; " %%A in ('TASKLIST /FI "WINDOWTITLE EQ Yeti - start_yeti.bat"') DO (
	ECHO %%A > "%PREDIXMACHINELOCK%\lock"
)
CALL :WRITECONSOLELOG "mBSA started, ready to install new packages."
:UPDATEPOLL
	IF NOT EXIST "%PREDIXMACHINELOCK%\lock" (
		CALL :WRITECONSOLELOG "Stopping yeti..."
		CALL :KILLMBSA
		title=Command Prompt
		GOTO :EOF
	)
	IF EXIST "%PREDIXHOME%\installations\*.zip" (
		CD "%PREDIXHOME%"
		FOR %%F IN ("%PREDIXHOME%\installations\*.zip") DO (		
			SET UNZIPDIR=%TEMPDIR%\%%~NF
			SET ZIP=%%F
			SET ZIPNAME=%%~NF
			SET WAITCNT=0
			:WAITFORSIG
				IF !WAITCNT! GEQ 5 (
					SET MESSAGE=No signature file found for associated zip. Package origin could not be verified.
					SET ERRORCODE=1
					CALL :WRITEFAILUREJSON
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				)
				IF NOT EXIST "!ZIP!.sig" (
					REM Windows lacks a timeout that doesn't allow input redirection so use ping instead
					PING 127.0.0.1 -n 5 >NUL 
					SET /A WAITCNT+=1
					GOTO :WAITFORSIG
				)
			FOR %%j IN ("%PREDIXHOME%"\yeti\com.ge.dspmicro.yetiappsignature-*.jar) DO (
				SET JAR=%%j
			)
			REM Windows lacks a timeout that doesn't allow input redirection so use ping instead
			PING 127.0.0.1 -n 5 >NUL
			CALL java -jar "!JAR!" "%PREDIXHOME%" "!ZIP!">>"%LOG%" 2>&1

			IF !ERRORLEVEL! NEQ 0 (
			 	SET MESSAGE=Package origin was not verified to be from the Predix Cloud. Installation failed.
				SET ERRORCODE=1
				CALL :WRITEFAILUREJSON
				CALL :INSTALLFAILED
				GOTO :UPDATEPOLL
			) ELSE (
			CALL :WRITECONSOLELOG "Package origin has been verified. Continuing installation."
			)

			IF EXIST "!UNZIPDIR!" (
				RMDIR /S /Q "!UNZIPDIR!" >>"%LOG%" 2>&1
			)
			MKDIR "!UNZIPDIR!"
			CD "!UNZIPDIR!"
			WHERE jar >NUL 2>NUL
			IF !ERRORLEVEL! NEQ 0 (
				SET MESSAGE=No jar utility found. Unable to extract archive. Cannot perform upgrade.
				SET ERRORCODE=2
				CALL :WRITEFAILUREJSON
				CALL :INSTALLFAILED
				GOTO :UPDATEPOLL
			)
			CALL jar xf "!ZIP!"
			CD "%TEMPDIR%"
			SET CNT=0
			FOR /D %%A IN ("!UNZIPDIR!\*") DO (
				IF "%%A" NEQ "!UNZIPDIR!\__MACOSX" (
					SET APPNAME=%%A
					SET /A CNT+=1
				)
			)
			IF NOT EXIST "!UNZIPDIR!\install\install.bat" (
				IF !CNT! NEQ 1 (
					SET MESSAGE=Incorrect zip format.  Applications should be a single folder with the packagename/install/install.sh structure, zipped with Windows zip utility.
					SET ERRORCODE=3
					CALL :WRITEFAILUREJSON
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				)
				IF NOT EXIST "!APPNAME!\install\install.bat" (				
					SET MESSAGE=Incorrect zip format.  Applications should be a single folder with the packagename/install/install.sh structure, zipped with Windows zip utility.
					SET ERRORCODE=3
					CALL :WRITEFAILUREJSON
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				)
				COPY "!APPNAME!\install\install.bat" "!UNZIPDIR!/install.bat" /Y /V >>"%LOG%" 2>&1	
			) ELSE (
				COPY "!UNZIPDIR!\install\install.bat" "!UNZIPDIR!/install.bat" /Y /V >>"%LOG%" 2>&1	
			)
			CALL :WRITECONSOLELOG "Running the !ZIPNAME! install script..."
			CD !UNZIPDIR!
			CMD /C install.bat "%PREDIXHOME%" "!UNZIPDIR!" "!ZIPNAME!"
			SET CODE=!ERRORLEVEL!
			CD "%PREDIXHOME%"
			IF !CODE! EQU 0 (
				IF EXIST "%AIRSYNC%\!ZIPNAME!.json" (
					DEL /Q "!ZIP!" >>"%LOG%" 2>&1
					RMDIR /S /Q "!UNZIPDIR!" >>"%LOG%" 2>&1
					CALL :WRITECONSOLELOG "Installation of !ZIPNAME! was successful."
					CALL :TIMESTAMP
					ECHO %RUNTIME% ##########################################################################>>"%LOG%"
					ECHO %RUNTIME% #                      Installation successful                           #>>"%LOG%"
					ECHO %RUNTIME% ##########################################################################>>"%LOG%"
				) ELSE (
					SET MESSAGE=The !ZIPNAME! installation script did not produce a JSON result to verify its completion.  Installation status unknown. Error Code: !CODE!
					SET ERRORCODE=!CODE!
					CALL :WRITEFAILUREJSON
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				)
			) ELSE (
				IF EXIST "%AIRSYNC%\!ZIPNAME!.json" (
					SET MESSAGE=Installation of !ZIPNAME! failed. Error Code: !CODE!
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				) ELSE (
					SET MESSAGE=An error occurred while running the install script. A JSON result was not created by the installation script.  Check the logs/installation logs for more details. Error Code: !CODE!
					SET ERRORCODE=!CODE!
					CALL :WRITEFAILUREJSON
					CALL :INSTALLFAILED
					GOTO :UPDATEPOLL
				)
			)
		)
		CALL :WRITECONSOLELOG "Done."
	) ELSE (
		REM Windows lacks a timeout that doesn't allow input redirection so use ping instead
		PING 127.0.0.1 -n 5 >NUL
	)
	GOTO :UPDATEPOLL

:TIMESTAMP
	SET RUNTIME=%date:~4,10% %time:~0,8%
	EXIT /B

:WRITECONSOLELOG
	CALL :TIMESTAMP
	ECHO %RUNTIME% %~1 >> "%LOG%"
	ECHO %RUNTIME% %~1
	EXIT /B

:USAGE
    ECHO usage: start_yeti.bat [--force-root]
    ECHO     --force-root    Allow container to be run with elevated administrator privileges. Not recommended.
    EXIT /B

:INSTALLFAILED
	DEL /Q "!ZIP!" >>"%LOG%" 2>&1
	RMDIR /S /Q "!UNZIPDIR!" >>"%LOG%" 2>&1
	CALL :WRITECONSOLELOG "!MESSAGE!"
	CALL :TIMESTAMP
	ECHO %RUNTIME% ##########################################################################>> "%LOG%"
	ECHO %RUNTIME% #                           Installation failed.                         #>> "%LOG%"
	ECHO %RUNTIME% ##########################################################################>> "%LOG%"
	CALL :WRITECONSOLELOG "Done."
	EXIT /B

:WRITEFAILUREJSON
	(
	ECHO {
	ECHO     "status" : "failure",
	ECHO     "errorcode" : %ERRORCODE%,
	ECHO     "message" : "%MESSAGE%"
	ECHO }
	) > "%PREDIXHOME%\appdata\airsync\%ZIPNAME%.json"
	EXIT /B

:KILLMBSA
	CD "%PREDIXHOME%\mbsa\bin"
	CALL "mbsa_stop.bat" >> "%LOG%" 2>&1
	IF !ERRORLEVEL! EQU 0 (
		REM code is an empty string unless mbsa throws an error. Empty string is equivalent to exit code 0
		CALL :WRITECONSOLELOG "MBSA stopped, container shutting down..."
	) ELSE (
		IF !ERRORLEVEL! EQU 2 (
			REM 2 is the exit code mBSA sends when attempting to stop an already stopped container
			CALL :WRITECONSOLELOG "MBSA is shut down, no container was running."
		) ELSE (
			CD "%PREDIXHOME%"
			CALL :WRITECONSOLELOG "MBSA failed to shut down the container. Will attempt to forcibly stop..."
		)
	)
	FOR /F "tokens=2 delims==; " %%A in (' TASKLIST /FI "IMAGENAME EQ mbsae.core.exe" ') DO (
		TASKKILL /F /PID %%A > NUL 2>&1
	)
	EXIT /B
:EOF