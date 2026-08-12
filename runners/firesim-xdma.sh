#!/bin/bash

set -e

XDMA_KERNEL_MOD=$(find /lib/modules/$(uname -r) -name "xdma.ko")
XDMA_REPO="https://github.com/lbnlbxe/dma_ip_drivers"
XDMA_HASH=xdma

if [ -z "${XDMA_KERNEL_MOD}" ]; then
	echo "XDMA Driver not found; rebuilding driver for kernel $(uname -r)..."
    TEMP_XDMA_DIR=$(mktemp -d)

	echo "Cloning XDMA driver repo at hash ${XDMA_HASH} in ${TEMP_XDMA_DIR}..."
	cd ${TEMP_XDMA_DIR}
	git clone ${XDMA_REPO} .
	git checkout ${XDMA_HASH}
	echo "XDMA repo clone complete!"

	echo "Building XDMA driver..."
	cd ${TEMP_XDMA_DIR}/XDMA/linux-kernel/xdma
	make clean && make install
	XDMA_KERNEL_MOD=$(find /lib/modules/$(uname -r) -name "xdma.ko")
	echo "Building XDMA driver complete!"

	cd && rm -rf "${TEMP_XDMA_DIR}"
fi

if lsmod | grep -wq "xdma"; then
	echo "${XDMA_KERNEL_MOD} is loaded!"
else
	echo "Loading ${XDMA_KERNEL_MOD}..."
	insmod ${XDMA_KERNEL_MOD} poll_mode=1
	echo "${XDMA_KERNEL_MOD} loaded!"
fi
