#!/bin/sh
# Copyright (c) 2012-2016 General Electric Company. All rights reserved.
# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')
if [ "x$pmpid" != "x" ]; then
    echo "Another instance of Predix Machine is running. Please shut it down \
    before continuing."
    exit 1
fi

ROOT_ARG=
root=false
while [ "$1" != "" ]; do
    case "$1" in
        --force-root )  root=true
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
    ROOT_ARG="--force-root"
fi

# Exit if keytool is not installed.
command -v keytool >/dev/null 2>&1 || { echo >&2 "Java keytool not found.  Exiting."; exit 1; }

START_ORIGIN="$(pwd)"
cd "$(dirname "$0")/.."

if [ -f "./yeti/start_yeti.sh" ]; then
    ./yeti/start_yeti.sh $ROOT_ARG
elif [ -f "./mbsa/bin/mbsa_start.sh" ]; then
    ./mbsa/bin/mbsa_start.sh
elif [ -f "./machine/bin/predix/start_container.sh" ]; then
    ./machine/bin/predix/start_container.sh
else
    echo "The directory structure was not recognized.  Predix Machine could not be started."
    cd "$START_ORIGIN"
    exit 1
fi

cd "$START_ORIGIN"