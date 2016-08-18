#!/bin/sh
# Copyright (c) 2012-2016 General Electric Company. All rights reserved.
# The copyright to the computer software herein is the property of
# General Electric Company. The software may be used and/or copied only
# with the written permission of General Electric Company or in accordance
# with the terms and conditions stipulated in the agreement/contract
# under which the software has been supplied.

pmpid=$(ps w | grep com.prosyst.mbs.impl.framework.Start | grep -v grep | awk '{print $1}')

if [ "x$pmpid" != "x" ]; then
	for pmprcs in $pmpid; do
		kill -INT $pmprcs
	done
fi