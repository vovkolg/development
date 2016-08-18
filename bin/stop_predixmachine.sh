#!/bin/sh
# Copyright (c) 2012-2016 General Electric Company. All rights reserved.
# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

START_ORIGIN="$(pwd)"
cd "$(dirname "$0")/.."
PREDIXHOME="$(pwd)"
if [ ! -n "${PREDIXMACHINELOCK+1}" ]; then
    PREDIXMACHINELOCK="$PREDIXHOME/yeti"
fi
cd "$PREDIXHOME"

# Attempt a graceful shutdown

if [ -f "$PREDIXMACHINELOCK/lock" ]; then
    sh "$PREDIXHOME/yeti/stop_yeti.sh"
fi
mbsapid=$(ps w | grep mbsae.core | grep -v grep | awk '{print $1}')
if [ "x$mbsapid" != "x" ]; then
    sh "$PREDIXHOME/mbsa/bin/mbsa_stop.sh"
fi
pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')
if [ "x$pmpid" != "x" ]; then
    sh "$PREDIXHOME/machine/bin/predix/stop_container.sh"
fi

# Wait up to a minute for shutdown to complete.
SHUTDOWNCHECKCNT=1
while [ "$SHUTDOWNCHECKCNT" -le 60 ]; do
    yetipid=
    if [ -f "$PREDIXMACHINELOCK/lock" ]; then
        read yetipid <"$PREDIXMACHINELOCK/lock"
    fi
    mbsapid=$(ps w | grep mbsae.core | grep -v grep | awk '{print $1}')
    pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')
    if [ "x$yetipid" = "x" ] && [ "x$mbsapid" = "x" ] && [ "x$pmpid" = "x" ]; then
        break
    fi
    sleep 1
    SHUTDOWNCHECKCNT=$((SHUTDOWNCHECKCNT+1))
done

# Clean up any remaining processes. There shouldn't be any
yetipid=
if [ -f "$PREDIXMACHINELOCK/lock" ]; then
    read yetipid <"$PREDIXMACHINELOCK/lock"
fi
mbsapid=$(ps w | grep mbsae.core | grep -v grep | awk '{print $1}')
pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')

for pid in $yetipid; do
    kill -9 $pid
    echo "Killed Yeti process (process $pid)"
done
for pid in $mbsapid; do
    kill -9 $pid
    echo "Killed mBSA process (process $pid)"
done
for pid in $pmpid; do
    kill -9 $pid
    echo "Killed Predix Machine process (process $pid)"
done

cd "$START_ORIGIN"