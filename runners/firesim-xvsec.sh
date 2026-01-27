#!/bin/bash

XVSEC_KERNEL_MOD="/lib/modules/$(uname -r)/updates/kernel/drivers/xvsec/xvsec.ko"
XVSEC_REPO="https://github.com/paulmnt/dma_ip_drivers"
XVSEC_HASH=302856a

if [ ! -f "${XDMA_KERNEL_MOD}" ]; then
	echo "XVSEC Driver not found; rebuilding driver for kernel $(uname -r)..."
	if [ ! -d "/opt/bxe/dma_ip_drivers_xvsec" ]; then
		echo "Cloning XVSEC driver repo at hash ${XVSEC_HASH}..."
		mkdir -p "/opt/bxe" && cd /opt/bxe
		git clone ${XVSEC_REPO} dma_ip_drivers_xvsec
		cd dma_ip_drivers_xvsec
		git checkout ${XVSEC_HASH}
		echo "XVSEC repo clone complete!"
	fi
	echo "Building XVSEC driver..."
	cd /opt/bxe/dma_ip_drivers_xvsec/XVSEC/linux-kernel/
	make clean all
	make install
	echo "Building XVSEC driver complete!"
fi


if lsmod | grep -wq "xvsec"; then
	echo "XVSEC is loaded!"
else
	echo "Loading XVSEC..."
	modprobe xvsec
	echo "XVSEC is loaded!"
fi

