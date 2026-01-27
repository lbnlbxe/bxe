#!/bin/bash

if [[ -z "${FIRESIM_HASH}" ]]; then
	echo "Error: FIRESIM_HASH is undefined"
	exit 1
fi

mkdir /tmp/firesim-script-installs && cd /tmp/firesim-script-installs
git clone https://github.com/firesim/firesim
cd firesim
git checkout ${FIRESIM_HASH}
sudo cp deploy/sudo-scripts/* /usr/local/bin/.
sudo cp platforms/xilinx_alveo_u250/scripts/* /usr/local/bin/.
cd && rm -rf /tmp/firesim-script-installs
sudo chmod 755 /usr/local/bin/firesim*
sudo chgrp firesim /usr/local/bin/firesim*

