#!/bin/sh
# Copyright (c) 2012-2016 General Electric Company. All rights reserved.
# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

writeConsoleLog () {
    echo "$(date +"%m/%d/%y %H:%M:%S") $1"
    if [ "x$LOG" != "x" ]; then
	   echo "$(date +"%m/%d/%y %H:%M:%S") $1" >> "$LOG"
	fi
}

killmbsa () {
    if [ "x$LOG" != "x" ]; then
    	sh "$PREDIXHOME/mbsa/bin/mbsa_stop.sh" >> "$LOG" 2>&1 || code=$?
    	if [ -z "$code" ] || [ $code -eq 0 ]; then
    		# code is an empty string unless mbsa throws an error. Empty string is equivalent to exit code 0
    		writeConsoleLog "MBSA stopped, container shutting down..."
    	elif [ $code -eq 2 ]; then
    		# 2 is the exit code mBSA sends when attempting to stop an already stopped container
    		writeConsoleLog "MBSA is shut down, no container was running."
    	else
    		writeConsoleLog "MBSA failed to shut down the container. Attempting to forcibly close..."
    	fi
    	mbsapid=$(ps w | grep mbsae.core | grep -v grep | awk '{ print $1 }')
    	for mbsaprcs in $mbsapid; do
    		kill -9 $mbsaprcs
    		echo -n "Killed mbsa (process $mbsaprcs)"
    	done
    fi
}

installFailed () {
	rm "$zip"
	rm -rf "$TEMPDIR/$unzipDir"
	writeConsoleLog "$message"
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") #                           Installation failed.                         #">> "$LOG"
	echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$LOG"
}

writeFailureJSON () {
	printf "{\n\t\"status\" : \"failure\",\n\t\"errorcode\" : $errorcode,\n\t\"message\" : \"$message\"\n}\n" > "$PREDIXHOME/appdata/airsync/$unzipDir.json"
}

installInProgress () {
	writeConsoleLog "Installation in progress.  Yeti will shut down after installation completes."
}

finish () {
	# Check for the yeti stop signal
	writeConsoleLog "Yeti is shutting down."
	killmbsa
	if ps w | grep mbsae.core | grep -v grep > /dev/null; then
		writeConsoleLog "Error exiting mBSA processes, processes may need to be killed manually."
	fi
	if [ -e "$PREDIXMACHINELOCK/lock" ]; then		
		rm "$PREDIXMACHINELOCK/lock"
	fi
	if [ -d "$TEMPDIR" ]; then
		rm -rf "$TEMPDIR"
	fi
	writeConsoleLog "Shutdown complete."
	exit 0
}

#SCRIPT ACTUALLY STARTS HERE. ALL THAT CAME BEFORE ARE FUNCTIONS.
trap finish INT TERM

root=false
while [ "$1" != "" ]; do
	case "$1" in
		--force-root )	root=true
				;;
	esac
	shift
done

# Exit if user is running as root
if [ $(id -u) -eq 0 ]; then
    if [ "$root" = "false" ]; then
        echo "Predix Machine should not be run as root.  We recommend you create a low privileged \
predixmachineuser, allowing them only the required root privileges to execute machine.  Bypass \
this error message with the argument --force-root"
        exit 1
    fi
fi

# Exit if keytool is not installed.
command -v keytool >/dev/null 2>&1 || { echo >&2 "Java keytool not found.  Exiting."; exit 1; }

cd "$(dirname "$0")/.."
PREDIXHOME="$(pwd)"
if [ ! -n "${PREDIXMACHINELOCK+1}" ]; then
	PREDIXMACHINELOCK="$PREDIXHOME/yeti"
fi
RUNDATE=`date +%m%d%y%H%M%S`
LOG=$PREDIXHOME/logs/installations/yeti_log${RUNDATE}.txt
# The Airsync directory where JSON files are picked up.
AIRSYNC=$PREDIXHOME/appdata/airsync


pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')
if [ "x$pmpid" != "x" ]; then
    echo "Another instance of Predix Machine is running. Please shut it down \
before continuing."
    exit 1
fi

# Write the process ID to the lock file
if [ -f "$PREDIXMACHINELOCK/lock" ]; then
	rm "$PREDIXMACHINELOCK/lock"
fi
echo $$ > "$PREDIXMACHINELOCK/lock"

echo "$(date +"%m/%d/%y %H:%M:%S") $(date)" > "$LOG"
writeConsoleLog "Yeti started..."

# Take care of permissions for an unzip
chmod +x "$PREDIXHOME/mbsa/bin/mbsa_start.sh"
chmod +x "$PREDIXHOME/mbsa/bin/mbsa_stop.sh"
chmod +x "$PREDIXHOME/mbsa/bin/network_monitor.sh"
chmod +x "$PREDIXHOME/mbsa/lib/runtimes/macosx/x86_64/mbsae.core"
chmod +x "$PREDIXHOME/mbsa/lib/runtimes/linux/x86_64/mbsae.core"
chmod +x "$PREDIXHOME/machine/bin/predix/start_container.sh"

# Cleanup and Setup for yeti
(umask 077 && mkdir /tmp/tempdir.$$) || code=$?
if [ "$code" != "0" ] && [ "$code" != "" ]; then
	writeConsoleLog "Error creating temporary directory. Error: $code"
	exit 1
fi
# Check if an mbsa is already running
if ps w | grep mbsae.core | grep -v grep > /dev/null; then
	writeConsoleLog "A mBSA instance is already running. Cleaning up mBSA processes and restarting."
	killmbsa
	if ps w | grep mbsae.core | grep -v grep > /dev/null; then
		writeConsoleLog "Error exiting mBSA processes."
		exit 1
	fi
else
	writeConsoleLog "The mBSA application was not running, starting mBSA..."
fi

if [ ! -f "$PREDIXHOME/mbsa/bin/mbsa_start.sh" ]; then
	writeConsoleLog "The mBSA application does not exist.  This is a required application for Yeti."
	exit 1
fi
nohup sh "$PREDIXHOME/mbsa/bin/mbsa_start.sh" > /dev/null 2>&1 &

writeConsoleLog "mBSA started, ready to install new packages."
TEMPDIR="/tmp/tempdir.$$"
while true; do
	trap finish INT TERM
	zips=$(ls "${PREDIXHOME}"/installations/*.zip 2> /dev/null)
	if [ "$zips" != "" ]; then
        for zip in "${PREDIXHOME}"/installations/*.zip; do
			# Verify the zip
			trap installInProgress INT TERM
			unzipDir=$(basename "$zip")
			unzipDir="${unzipDir%.*}"
			if [ -d "$TEMPDIR" ]; then
				rm -rf "$TEMPDIR"
			fi
			waitcnt=0
			while [ $waitcnt -lt 5 ] && [ ! -f "$zip.sig" ]; do
				waitcnt=$((waitcnt+1))
				sleep 5
			done
			if [ $waitcnt -eq 5 ]; then
				message="No signature file found for associated zip. Package origin could not be verified."
				errorcode="1"
				writeFailureJSON
				installFailed
				continue
			fi
			mkdir "$TEMPDIR"
			cd "$TEMPDIR"
			java -jar "${PREDIXHOME}"/yeti/com.ge.dspmicro.yetiappsignature-*.jar "${PREDIXHOME}" "$zip">>"$LOG" 2>&1
			if [ $? -ne 0 ]; then
				message="Package origin was not verified to be from the Predix Cloud. Installation failed"
				errorcode="1"
				writeFailureJSON
				installFailed
				continue
			else
				writeConsoleLog "Package origin has been verified. Continuing installation."
			fi
			unzipAvailable=0
			which jar > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				which unzip > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					message="Unable to extract archive using jar or unzip utilities. Cannot perform upgrade."
					errorcode="2"
					writeFailureJSON
					installFailed
					continue
				fi
				unzip -q "$zip"
			else
				jar xf "$zip"
			fi
			cd "$PREDIXHOME"
			cnt=0
			for app in "$TEMPDIR"/*; do
				if [ $app != "$TEMPDIR/__MACOSX" ]; then
					appname="$app"
					cnt=$((cnt+1))
				fi
			done
			if [ "$cnt" -ne 1 ] || [ ! -f "$appname/install/install.sh" ] && [ ! -f "$TEMPDIR/install/install.sh" ]; then
				message="Incorrect zip format.  Applications should be a single folder with the packagename/install/install.sh structure, zipped with unix zip utility."
				errorcode="3"
				writeFailureJSON
				installFailed
				continue
			fi
			writeConsoleLog "Running the install script"
			if [ -f "$TEMPDIR/install/install.sh" ]; then
				sh "$TEMPDIR/install/install.sh" "$PREDIXHOME" "$TEMPDIR" "$unzipDir"
			else
				sh "$appname/install/install.sh" "$PREDIXHOME" "$TEMPDIR" "$unzipDir"
			fi
			code=$?
			if [ $code -eq 0 ] && [ -f "$AIRSYNC/$unzipDir.json" ]; then
				rm "$zip"
				rm -rf "$TEMPDIR"
				writeConsoleLog "Installation of $unzipDir was successful."
				echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$LOG"
				echo "$(date +"%m/%d/%y %H:%M:%S") #                         Installation successful                        #">> "$LOG"
				echo "$(date +"%m/%d/%y %H:%M:%S") ##########################################################################">> "$LOG"
			elif [ $code -ne 0 ] && [ -f "$AIRSYNC/$unzipDir.json" ]; then
				message="Installation of $unzipDir failed. Error Code: $code"
				installFailed
			else
				if [ $code -eq 0 ]; then
					message="The $unzipDir installation script did not produce a JSON result to verify its completion.  Installation status unknown. Error Code: $code"
				else
					message="An error occurred while running the install script. A JSON result was not created by the installation script.  Check the logs/installation logs for more details. Error Code: $code"
				fi
				errorcode=$code
				writeFailureJSON
				installFailed
			fi
		done
		writeConsoleLog "Done."
	else
		sleep 5
	fi
done