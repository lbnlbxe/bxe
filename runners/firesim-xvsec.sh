#!/bin/bash

set -e

XVSEC_KERNEL_MOD="/lib/modules/$(uname -r)/updates/kernel/drivers/xvsec/xvsec.ko"
XVSEC_REPO="https://github.com/joonho3020/dma_ip_drivers"
XVSEC_HASH=ubuntu-24-xvsec

if [ ! -f "${XDMA_KERNEL_MOD}" ]; then
	echo "XVSEC Driver not found; rebuilding driver for kernel $(uname -r)..."
    TEMP_XVSEC_DIR=$(mktemp -d)

	echo "Cloning XVSEC driver repo at hash ${XVSEC_HASH} into ${TEMP_XVSEC_DIR}..."
	cd ${TEMP_XVSEC_DIR}
	git clone ${XVSEC_REPO} ${TEMP_XDMA_DIR}
	git checkout ${XVSEC_HASH}
	echo "XVSEC repo clone complete!"

	echo "Building XVSEC driver..."
	cd ${TEMP_XVSEC_DIR}/XVSEC/linux-kernel/
	make clean all
	make install
	echo "Building XVSEC driver complete!"

	cd && rm -rf ${TEMP_XVSEC_DIR}
fi


if lsmod | grep -wq "xvsec"; then
	echo "XVSEC is loaded!"
else
	echo "Loading XVSEC..."
	modprobe xvsec
	echo "XVSEC is loaded!"
fi
