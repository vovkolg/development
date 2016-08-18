@ECHO OFF

REM  Copyright (c) 2012-2016 General Electric Company. All rights reserved.
REM  The copyright to the computer software herein is the property of
REM  General Electric Company. The software may be used and/or copied only
REM  with the written permission of General Electric Company or in accordance
REM  with the terms and conditions stipulated in the agreement/contract
REM  under which the software has been supplied
setlocal
SET DIRNAME="%~dp0"
SET PREDIX_MACHINE_HOME1=%DIRNAME%..\..\..
SET UNQUOTED_PREDIX_MACHINE_HOME=%PREDIX_MACHINE_HOME1:"=%
SET PREDIX_MACHINE_HOME=%~dp0..\..\..

SET UNQUOTED_JAVA_HOME=%JAVA_HOME:"=%
SET VM_HOME="%UNQUOTED_JAVA_HOME%"

:checkusage
SET arg=%1
SET P_FLAG=false
IF DEFINED arg (
    IF "%arg%"=="-h" GOTO usage
    IF "%arg%"=="-p" GOTO password
    SHIFT
    GOTO checkusage
)
GOTO endusage

:usage
ECHO   STARTUP OPTIONS:
ECHO   -p  your_password -  password for the newly generated keystore password and key passwords
ECHO   -h - start_container usage information
ECHO   clean - clear the storage
ECHO   debug - start debug listener for attaching from IDE on port 8000.
ECHO   debug dbg_port 8000 dbg_suspend - attach for debugging but don't start the container until debugger is attached. This allows for debugging activate. 
EXIT /B 1

:password
SHIFT
SET KEYPASS=%1
IF DEFINED KEYPASS (
REM Check that the command was entered correctly and the following argument is in fact a password
    IF "%KEYPASS%"=="debug" GOTO usage
    IF "%KEYPASS%"=="dbg_suspend" GOTO usage  
    IF "%KEYPASS%"=="dbg_port" GOTO usage 
    IF "%KEYPASS%"=="clean" GOTO usage
    IF "%KEYPASS%"=="-h" GOTO usage
    IF "%KEYPASS%"=="-p" GOTO usage 
    SET P_FLAG=true
    GOTO endusage
) ELSE (
    ECHO Key password is not defined
    GOTO usage
)

:endusage

REM Exit if keytool is not installed.
where keytool >nul 2>nul
if %errorlevel%==1 (
    @echo Java keytool not found. Exiting.
    EXIT /B 1
)

REM Generate the full path for "predix.home.dir" system define for permission. This can not be passed in VM_ARGS.

SET PREDIX_MACHINE_HOME_SLASH=%PREDIX_MACHINE_HOME:\=/%
ECHO predix.home.dir=%PREDIX_MACHINE_HOME_SLASH% > "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bin\predix\predix.home.prs"

REM **************************************************************************************
REM framework extension and property setup
REM **************************************************************************************
SET EXTPRS="..\..\..\..\configuration\machine\predix.prs;..\..\predix\predix.home.prs;.\machine.prs"
SET MBS_SERVER_JAR="..\..\..\lib\framework\com.prosyst.util.log.buffer.jar"
SET VM_ARGS=-Dmbs.log.custom=com.prosyst.util.log.buffer.BufferedLogger -Dmbs.log.useEventThread=false -Dmbs.log.file.entriesThreshold=0 -Dorg.osgi.framework.bootdelegation=org.bouncycastle.* 
REM  turn on java security permissions in ..\machine\bin\vms\policy.all. Comment out the line to turn it off.
SET FWSECURITY=on

REM Add javax.servlet if it exists to the classpath.
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\javax.servlet-api-3.1.0.jar" (
    SET EXTRA_CP=..\..\bundles\javax.servlet-api-3.1.0.jar
)

REM Add websocket-api if it exists to the classpath since they are needed for websockets.
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\javax.websocket-api-1.0.jar" (
    SET EXTRA_CP=%EXTRA_CP%;..\..\bundles\javax.websocket-api-1.0.jar
)

REM Add bcpkix if it exists to the classpath since they are needed for OPC-UA. JCE provider requires absolute path
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\bcpkix-jdk15on-1.52.jar" (
    SET EXTRA_CP=%EXTRA_CP%;%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\bcpkix-jdk15on-1.52.jar
)

REM Add bcprov if it exists to the classpath since they are needed for OPC-UA. JCE provider requires absolute path
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\bcprov-jdk15on-1.52.jar" (
    SET EXTRA_CP=%EXTRA_CP%;%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\bcprov-jdk15on-1.52.jar
)

REM Add RXTX libraries for Modbus serial communication
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\lib\rxtx\rxtx-2.2pre2-bins\RXTXcomm.jar" (
    if not defined RXTX_LIBRARY_PATH set RXTX_LIBRARY_PATH=%UNQUOTED_PREDIX_MACHINE_HOME%\machine\lib\rxtx\rxtx-2.2pre2-bins\win64
    SET EXTRA_CP="%EXTRA_CP%;..\..\..\lib\rxtx\rxtx-2.2pre2-bins\RXTXcomm.jar"
)
SET PATH=%RXTX_LIBRARY_PATH%;%PATH%

REM **************************************************************************************
REM Boot feature (*.ini files) file setup.
REM **************************************************************************************

set FEATURE_INI=( provision.ini messaging.ini machinegateway.ini websocket.ini solution.ini )

REM EnableDelayedExpansion is required whenever a variable is assigned and re-read inside a block 
REM statement as demarcated by ()
SETLOCAL EnableDelayedExpansion
for %%M in %FEATURE_INI% do (
    REM If a the ".ini" file exists in the machine\bin\vms directory
    IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%"\machine\bin\vms\%%M (
        set EXTBOOTFILE=!EXTBOOTFILE!;..\%%M
    )
)

REM Check if Technician console should be loaded. This is can also be based on a property enabled.
set PROPERTY_FILE="%UNQUOTED_PREDIX_MACHINE_HOME%\configuration\machine\com.ge.dspmicro.device.techconsole.config"
set PROPERTY_REGEX="com.ge.dspmicro.device.techconsole.console.enabled=B\"true\""
IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%"\machine\bin\vms\webconsole.ini (
    IF EXIST %PROPERTY_FILE% (
        FINDSTR /R /C:%PROPERTY_REGEX% %PROPERTY_FILE% > NUL 2>&1 && (
            ECHO "Technician console enabled" 
            SET EXTBOOTFILE=%EXTBOOTFILE%;..\webconsole.ini
        ) || (
            ECHO "Technician console disabled"
        )
    ) ELSE (
        SET EXTBOOTFILE=%EXTBOOTFILE%;..\webconsole.ini
    )
)


REM **************************************************************************************
REM Setup the machine environment variables if it is used.
REM **************************************************************************************
IF EXIST %DIRNAME%setvars.bat (
    CALL %DIRNAME%setvars.bat
)

CD %PREDIX_MACHINE_HOME%\machine\bin\vms\jdk\

REM **************************************************************************************
REM Generate new keystores and keys if they does not exist
REM **************************************************************************************

SET TLS_CLIENT_KEYSTORE_PATH=security/tls_client_keystore.jks
SET TLS_CLIENT_KEYSTORE_PATH_PROP=com.ge.dspmicro.securityadmin.sslcontext.client.keystore.path
SET TLS_CLIENT_KEYSTORE_TYPE_PROP=com.ge.dspmicro.securityadmin.sslcontext.client.keystore.type
SET TLS_CLIENT_KEYSTORE_PW_PROP=com.ge.dspmicro.securityadmin.sslcontext.client.keystore.password
SET TLS_CLIENT_KEYSTORE_KEY_PW_PROP=com.ge.dspmicro.securityadmin.sslcontext.client.keymanager.password
SET TLS_CLIENT_KEYSTORE_KEY_ALIAS_PROP=com.ge.dspmicro.securityadmin.sslcontext.client.keymanager.alias

SET TLS_SERVER_KEYSTORE_PATH=security/tls_server_keystore.jks
SET TLS_SERVER_KEYSTORE_PATH_PROP=com.ge.dspmicro.securityadmin.sslcontext.server.keystore.path
SET TLS_SERVER_KEYSTORE_TYPE_PROP=com.ge.dspmicro.securityadmin.sslcontext.server.keystore.type
SET TLS_SERVER_KEYSTORE_PW_PROP=com.ge.dspmicro.securityadmin.sslcontext.server.keystore.password
SET TLS_SERVER_KEYSTORE_KEY_PW_PROP=com.ge.dspmicro.securityadmin.sslcontext.server.keymanager.password
SET TLS_SERVER_KEYSTORE_KEY_ALIAS_PROP=com.ge.dspmicro.securityadmin.sslcontext.server.keymanager.alias


IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\com.ge.dspmicro.machineadapter-opcua-16.2.2.jar" (
    SET OPCUA_KEYSTORE_PATH="%UNQUOTED_PREDIX_MACHINE_HOME%\security\opcua_keystore.jks"
)

IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\com.ge.dspmicro.opcua-server-16.2.2.jar" (
    SET OPCUA_SERVER_KEYSTORE_PATH="%UNQUOTED_PREDIX_MACHINE_HOME%\security\opcuaserver_keystore.jks"
)

SET MISC_KEYSTORE_PATH=security/misc_keystore.jks
SET MISC_KEYSTORE_PATH_PROP=com.ge.dspmicro.securityadmin.default.keystore.path
SET MISC_KEYSTORE_TYPE_PROP=com.ge.dspmicro.securityadmin.default.keystore.type
SET MISC_KEYSTORE_PW_PROP=com.ge.dspmicro.securityadmin.default.keystore.password
SET MISC_ALIAS_PW_PROP=com.ge.dspmicro.securityadmin.default.keystore.alias
SET MISC_KEY_PW_PROP=com.ge.dspmicro.securityadmin.default.keystore.aliasPassword

SET USER_STORE_PATH=security/users.store
SET SECRET_KEYSTORE_PATH=security/secretkey_keystore.jceks
SET SECRET_KEYSTORE_PATH_PROP=com.ge.dspmicro.securityadmin.encryption.keystore.path
SET SECRET_KEYSTORE_TYPE_PROP=com.ge.dspmicro.securityadmin.encryption.keystore.type
SET SECRET_KEYSTORE_PW_PROP=com.ge.dspmicro.securityadmin.encryption.keystore.password
SET SECRET_KEY_ALIAS_PROP=com.ge.dspmicro.securityadmin.encryption.alias
SET SECRET_KEY_PW_PROP=com.ge.dspmicro.securityadmin.encryption.alias.password

SET SECURITYADMIN_CFG_PATH="%UNQUOTED_PREDIX_MACHINE_HOME%\security\com.ge.dspmicro.securityadmin.cfg"
SET SECURITY_CFG_PROP_PATH="%UNQUOTED_PREDIX_MACHINE_HOME%\security\securityConfig.properties"

SET PASSWORD_LENGTH=20
SET KEYPASS=blank

CALL :checkpropertyset %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_PATH_PROP%
IF "%VALUE_IS_SET%"=="false" (
    IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_CLIENT_KEYSTORE_PATH%" (
        ECHO Removing previous client TLS keystore, generating a new one. WARNING: This may take several minutes on small devices
        DEL /F "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_CLIENT_KEYSTORE_PATH%"
    ) ELSE (
        ECHO Default client TLS keystore not found, generating a new one. WARNING: This may take several minutes on small devices
    )
    IF NOT "%P_FLAG%"=="true" (
        CALL :generatepassword %PASSWORD_LENGTH%
        
    )
    CALL keytool -genkey ^
        -keystore "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_CLIENT_KEYSTORE_PATH%" ^
        -alias dspmicro ^
        -storepass !KEYPASS! ^
        -keypass !KEYPASS! ^
        -keyalg RSA ^
        -sigalg SHA256withRSA ^
        -keysize 2048 ^
        -storetype JKS ^
        -validity 3650 ^
        -dname "CN=localhost, OU=Predix, O=GE L=San Ramon, S=CA, C=US"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_KEY_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_PATH_PROP% "%TLS_CLIENT_KEYSTORE_PATH%"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_TYPE_PROP% JKS
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_CLIENT_KEYSTORE_KEY_ALIAS_PROP% dspmicro
    )
)

CALL :checkpropertyset %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_PATH_PROP%
IF "%VALUE_IS_SET%"=="false" (
    IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_SERVER_KEYSTORE_PATH%" (
        ECHO Removing previous client TLS keystore, generating a new one. WARNING: This may take several minutes on small devices
        DEL /F "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_SERVER_KEYSTORE_PATH%"
    ) ELSE (
        ECHO Default server TLS keystore not found, generating a new one. WARNING: This may take several minutes on small devices
    )
    IF NOT "%P_FLAG%"=="true" (
        CALL :generatepassword %PASSWORD_LENGTH%
        
    )
    CALL keytool -genkey ^
        -keystore "%UNQUOTED_PREDIX_MACHINE_HOME%\%TLS_SERVER_KEYSTORE_PATH%" ^
        -alias dspmicro ^
        -storepass !KEYPASS! ^
        -keypass !KEYPASS! ^
        -keyalg RSA ^
        -sigalg SHA256withRSA ^
        -keysize 2048 ^
        -storetype JKS ^
        -validity 3650 ^
        -dname "CN=localhost, OU=Predix, O=GE L=San Ramon, S=CA, C=US"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_KEY_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_PATH_PROP% "%TLS_SERVER_KEYSTORE_PATH%"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_TYPE_PROP% JKS
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %TLS_SERVER_KEYSTORE_KEY_ALIAS_PROP% dspmicro
    )
)

CALL :checkpropertyset %SECURITYADMIN_CFG_PATH% %MISC_KEYSTORE_PATH_PROP%
IF "%VALUE_IS_SET%"=="false" (
    IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\%MISC_KEYSTORE_PATH%" (
        ECHO Removing previous Misc keystore, generating a new one. WARNING: This may take several minutes on small devices
        DEL /F "%UNQUOTED_PREDIX_MACHINE_HOME%\%MISC_KEYSTORE_PATH%"
    ) ELSE (
        ECHO Default Misc keystore not found, generating a new one. WARNING: This may take several minutes on small devices
    )
    IF NOT "%P_FLAG%"=="true" (
        CALL :generatepassword %PASSWORD_LENGTH%
    )
    CALL keytool -genkey ^
        -keystore "%UNQUOTED_PREDIX_MACHINE_HOME%\%MISC_KEYSTORE_PATH%" ^
        -alias dspmicro ^
        -storepass !KEYPASS! ^
        -keypass !KEYPASS! ^
        -keyalg RSA ^
        -sigalg SHA256withRSA ^
        -keysize 2048 ^
        -storetype JKS ^
        -validity 3650 ^
        -dname "CN=dspmicro, OU=Predix, O=GE L=San Ramon, S=CA, C=US"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %MISC_KEYSTORE_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %MISC_KEY_PW_PROP% !KEYPASS!
    CALL :setProperty %SECURITYADMIN_CFG_PATH% %MISC_KEYSTORE_PATH_PROP% "%MISC_KEYSTORE_PATH%"
    CALL :setProperty %SECURITYADMIN_CFG_PATH% %MISC_KEYSTORE_TYPE_PROP% JKS
    CALL :setProperty %SECURITYADMIN_CFG_PATH% %MISC_ALIAS_PW_PROP% dspmicro
    )
)

IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\com.ge.dspmicro.machineadapter-opcua-16.2.2.jar" (
    IF NOT EXIST "%OPCUA_KEYSTORE_PATH:"=%" (
        ECHO Default OPC-UA keystore not found, generating a new one. WARNING: This may take several minutes on small devices
        REM We do no generate the password since it must be exported for use.
        IF NOT "%P_FLAG%"=="true" (
            SET KEYPASS=dspmicro
        )
        CALL keytool -genkey ^
            -keystore "%OPCUA_KEYSTORE_PATH:"=%" ^
            -alias dspmicro ^
            -storepass !KEYPASS! ^
            -keypass !KEYPASS! ^
            -keyalg RSA ^
            -sigalg SHA256withRSA ^
            -keysize 2048 ^
            -storetype JKS ^
            -validity 3650 ^
            -dname "CN=dspmicro, OU=Predix, O=GE L=San Ramon, S=CA, C=US"
        REM Set no properties as the defaults in the configuration files are these defaults. 
    )
)

IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\machine\bundles\com.ge.dspmicro.opcua-server-16.2.2.jar" (
    IF NOT EXIST "%OPCUA_SERVER_KEYSTORE_PATH:"=%" (
        ECHO Default OPC-UA Server keystore not found, generating a new one. WARNING: This may take several minutes on small devices
        REM We do no generate the password since it must be exported for use.
        IF NOT "%P_FLAG%"=="true" (
            SET KEYPASS=dspmicro
        )
        CALL keytool -genkey ^
            -keystore "%OPCUA_SERVER_KEYSTORE_PATH:"=%" ^
            -alias dspmicro ^
            -storepass !KEYPASS! ^
            -keypass !KEYPASS! ^
            -keyalg RSA ^
            -sigalg SHA256withRSA ^
            -keysize 2048 ^
            -storetype JKS ^
            -validity 3650 ^
            -dname "CN=dspmicro, OU=Predix, O=GE L=San Ramon, S=CA, C=US"
        REM Set no properties as the defaults in the configuration files are these defaults. 
    )
)

CALL :checkpropertyset %SECURITYADMIN_CFG_PATH% %SECRET_KEYSTORE_PATH_PROP%
IF "%VALUE_IS_SET%"=="false" (
    IF EXIST "%UNQUOTED_PREDIX_MACHINE_HOME%\%SECRET_KEYSTORE_PATH%" (
        ECHO Removing previous secret keystore, generating a new one. WARNING: This may take several minutes on small devices
        DEL /F "%UNQUOTED_PREDIX_MACHINE_HOME%\%SECRET_KEYSTORE_PATH%"
        ECHO Removing previous user.store
        DEL /F "%UNQUOTED_PREDIX_MACHINE_HOME%\%USER_STORE_PATH%"
    ) ELSE (
        ECHO Default secret keystore not found, generating a new one. WARNING: This may take several minutes on small devices
    )
    IF NOT "%P_FLAG%"=="true" (
        CALL :generatepassword %PASSWORD_LENGTH%
    )
    CALL keytool -genseckey ^
        -alias manglekey ^
        -keyalg AES ^
        -keysize 128 ^
        -keystore "%UNQUOTED_PREDIX_MACHINE_HOME%\%SECRET_KEYSTORE_PATH%" ^
        -storetype JCEKS ^
        -storepass !KEYPASS! ^
        -keypass !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %SECRET_KEYSTORE_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %SECRET_KEY_PW_PROP% !KEYPASS!
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %SECRET_KEYSTORE_PATH_PROP% "%SECRET_KEYSTORE_PATH%"
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %SECRET_KEYSTORE_TYPE_PROP% JCEKS
    CALL :setproperty %SECURITYADMIN_CFG_PATH% %SECRET_KEY_ALIAS_PROP% manglekey
    )
)
SET KEYPASS=

REM **************************************************************************************
REM startup options:
REM   -p  your_password -  password for the newly generated keystore password and key passwords
REM   -h - start_container usage information
REM   clean - clear the storage
REM   debug - start debug listener for attaching from IDE on port 8000.
REM   debug dbg_port 8000 dbg_suspend - attach for debugging but don't start the container until debugger is attached. This allows for debugging activate. 
REM 
REM "%*" invokes server with the same arguments this script received
REM **************************************************************************************

REM Container must be started with clean each time. No data should be read from cache.
CALL server.bat clean %*

CD %DIRNAME%

EXIT /B 0

REM **************************************************************************************
REM Functions
REM Define your functions here
REM **************************************************************************************

REM Sets a property in a key=value format property file
REM Args:
REM  1 - path to file
REM  2 - key of value to replace
REM  3 - the value to set
:setproperty
SETLOCAL EnableDelayedExpansion
set TMPTEXTFILE="%~1.tmp"
for /f "tokens=1,* delims=" %%A in ('type %1') do (
    set "line=%%A"
    if NOT x!line!==x!line:%~2=! (
        set "subline=!line:%~2=!"
        set "WROTE_IN_FOR=false"
        for /f "tokens=1,2 delims==" %%i in ("!subline!") do (
            set "WROTE_IN_FOR=true"
            if [%%j]==[] (
                echo %~2=%~3>>%TMPTEXTFILE%
            ) ELSE (
REM the following line should not have spaces around the '>>' operator. This will concatenate ' ' into the output
                echo !line!>>%TMPTEXTFILE%
            )
        )
        if !WROTE_IN_FOR!==false (
            echo %~2=%~3>>%TMPTEXTFILE%
        )
    ) ELSE (
REM the following line should not have spaces around the '>>' operator. This will concatenate ' ' into the output
        echo !line!>>%TMPTEXTFILE%
    )
)
del "%~1"

FOR %%A in ("%~1") do (
    SET filename=%%~nxA
)

ren "%TMPTEXTFILE:"=%" %filename%
EXIT /B 0

REM Check if a property contains a value in property file
REM Args:
REM  1 - path to file
REM  2 - property key to check
REM Returns: sets VALUE_IS_SET to true if property is set, false otherwise
:checkpropertyset
SET "VALUE_IS_SET=false"
for /f "tokens=1,2 delims==" %%A in ('type %1') do (
    SET line=%%A
    SET propvalue=%%B
    if NOT x!line!==x!line:%~2=! (
        if NOT "!propvalue!" == "" (
            set "VALUE_IS_SET=true"
        )
    )
)
EXIT /B 0

REM Generates a random password of custom length and sets the value in variable KEYPASS
REM Args:
REM  1 - length
:generatepassword
SET _Len=0
Set _RNDLength=%~1
Set _Alphanumeric=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_+{}?[]@
Set _Str=%_Alphanumeric%987654321
:LenLoop
IF NOT "%_Str:~18%"=="" SET _Str=%_Str:~9%& SET /A _Len+=9& GOTO :LenLoop
SET _tmp=%_Str:~9,1%
SET /A _Len=_Len+_tmp
Set _count=0
SET _RndAlphaNum=
:loop
Set /a _count+=1
SET _RND=%Random%
Set /A _RND=_RND%%%_Len%
SET _RndAlphaNum=!_RndAlphaNum!!_Alphanumeric:~%_RND%,1!
If !_count! lss %_RNDLength% goto loop
SET KEYPASS=!_RndAlphaNum!
EXIT /B 0