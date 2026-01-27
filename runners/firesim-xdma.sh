#!/bin/bash

XDMA_KERNEL_MOD=$(find /lib/modules/$(uname -r) -name "xdma.ko")
XDMA_REPO="https://github.com/Xilinx/dma_ip_drivers"
XDMA_HASH=0e8d321

if [ -z "${XDMA_KERNEL_MOD}" ]; then
	echo "XDMA Driver not found; rebuilding driver for kernel $(uname -r)..."
	if [ ! -d "/opt/bxe/dma_ip_drivers" ]; then
		echo "Cloning XDMA driver repo at hash ${XDMA_HASH}..."
		mkdir -p "/opt/bxe" && cd /opt/bxe
		git clone ${XDMA_REPO}
		cd dma_ip_drivers
		git checkout ${XDMA_HASH}
		echo "XDMA repo clone complete!"
	fi
	echo "Building XDMA driver..."
	cd /opt/bxe/dma_ip_drivers/XDMA/linux-kernel/xdma
	make clean && make install
	XDMA_KERNEL_MOD=$(find /lib/modules/$(uname -r) -name "xdma.ko")
	echo "Building XDMA driver complete!"
fi

if lsmod | grep -wq "xdma"; then
	echo "${XDMA_KERNEL_MOD} is loaded!"
else
	echo "Loading ${XDMA_KERNEL_MOD}..."
	insmod ${XDMA_KERNEL_MOD} poll_mode=1
	echo "${XDMA_KERNEL_MOD} loaded!"
fi
