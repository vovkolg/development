@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.

NET SESSION > NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
	ECHO Installing the Predix Machine Service requires system administrator privileges. Please try again with an elevated command prompt.
	EXIT /B
)

SET MSI=%~dp0
MSIEXEC /i %MSI%\PredixMachineSetup.msi /qn /L pmserviceinstall.log
IF %ERRORLEVEL% NEQ 0 (
	ECHO Predix Machine Service installation failed with an error. View the pmserviceinstall.log for more details.
) ELSE (
	ECHO Predix Machine Service installed successfully.
)