@ECHO OFF
REM Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM The copyright to the computer software herein is the property of
REM General Electric Company. The software may be used and/or copied only
REM with the written permission of General Electric Company or in accordance
REM with the terms and conditions stipulated in the agreement/contract
REM under which the software has been supplied.

SET pmpid=
FOR /F "tokens=1 delims==; " %%i IN ('JPS -l ^| FINDSTR "com.prosyst.mbs.impl.framework.Start"') DO SET pmpid=%%i

IF DEFINED pmpid (
	TASKKILL /F /PID "%pmpid%"
)