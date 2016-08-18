@echo off

setlocal

rem If storage dir is specified and exists, delete only it and exit
set STORAGE=%1
if NOT "%STORAGE%" == "" (
	echo # Deleting requested storage [ %STORAGE% ]
	if EXIST %STORAGE%\NUL (
		rmdir /s/q %STORAGE%\data
		rmdir /s/q %STORAGE%\bundles
	) else (
		echo # Requested storage [ %STORAGE% ] is not valid directory!
	)
	goto DONE
)

rem search for subdirs, containing storage directories...
set BASEDIR=%~dp0
echo # Deleting all storage dirs in [ %BASEDIR% ]

rem sanity check for basedir\domain.crp
if NOT EXIST %BASEDIR%domain.crp (
	echo # Script directory not valid: %BASEDIR%domain.crp is missing!
	goto DONE
)

for /F %%d in ('dir /ad/b %BASEDIR%') do ( 
	if EXIST %BASEDIR%%%d\storage\NUL (
		echo   - Deleting [ %BASEDIR%%%d\storage ]
		rmdir /s/q %BASEDIR%%%d\storage\data
		rmdir /s/q %BASEDIR%%%d\storage\bundles
	)
)

:DONE

endlocal