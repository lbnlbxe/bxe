#!/bin/bash

XDMA_KERNEL_MOD=$(find /lib/modules/$(uname -r) -name "xdma.ko")

if lsmod | grep -wq "xdma"; then
	echo "$XDMA_KERNEL_MOD is loaded!"
else
	echo "Loading $XDMA_KERNEL_MOD..."
	insmod $XDMA_KERNEL_MOD poll_mode=1
fi

