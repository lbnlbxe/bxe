#!/bin/bash

XVSEC_BINARY="/opt/bxe/dma_ip_drivers_xvsec/XVSEC/linux-kernel/build/xvsecctl"

if lsmod | grep -wq "xvsec"; then
	echo "xvsec is loaded!"
else
	echo "Loading xvsec..."
	modprobe xvsec
fi

