#!/bin/bash

set -e
# set -x

function displayUsage() {
    echo "Usage: sudo $0 <native|container>"
    echo "  <native|container> : Select installation type"
    echo "                       - native: For installations direcly on hosts or VMs"
    echo "                       - container: For installation within a container"
}

function checkSudo() {
	# display usage if the script is not run as root user
	if [[ "${EUID}" -ne 0 ]]; then
		echo "This script must be run with super-user privileges."
		displayUsage
		exit 1
	fi
}

function installOSPreqs() {
    echo "----- Installing OS Prequisites -----"
    apt update
    echo "1. Installing General Prerequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y nfs-common openssh-server libguestfs-tools \
        wget curl vim tree emacs tmux git build-essential \
        tigervnc-standalone-server

    echo "2. Installing Firesim Prerequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libc6-dev screen libtinfo-dev libtinfo5

    echo "3. Installing Xilinx Prequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libtinfo5 libncurses5 python3-pip #libstdc++6:i386 \
    #    libgtk2.0-0:i386 dpkg-dev:i386
    echo "----- OS Prequisites Complete -----"
}

function addToolsNFS() {
    echo "----- Adding Tools NFS Mount -----"
    mkdir -p /tools
    sed -i -e '$avizion.lbl.gov:/mnt/vmpool/nfs/tools\t/tools\tnfs\tdefaults,timeo=900,retrans=5,_netdev\t0\t0\n' /etc/fstab
    mount /tools
    echo "----- Tools NFS Mount Complete -----"
}

function installBXEScripts() {
    echo "----- Installing BXE Scripts -----"
    mkdir -p /opt/bxe
    cp /tools/bxe/bxe-utilities/firesim-guestmount.s* /opt/bxe/.
    cp /tools/bxe/bxe-utilities/regenSSHKey.sh /opt/bxe/.
    echo "----- BXE Scripts Install Complete -----"
}

function installGuestMountService() {
    echo "----- Adding Guest Mount Service -----"
    ln -sf /opt/bxe/firesim-guestmount.service /etc/systemd/system/.
    systemctl daemon-reload
    systemctl enable --now firesim-guestmount
    echo "----- Guest Mount Service Complete -----"
}

function changeCondaSolver() {
    echo "----- Changing Conda Solver -----"
    if ! command -v conda 2>&1 >/dev/null; then
        # echo "Conda not installed!"
        # exit 1
        cd /tmp
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        bash Miniforge3-Linux-x86_64.sh -b -p "/opt/conda"
        rm Miniforge3-Linux-x86_64.sh
        source "/opt/conda/etc/profile.d/conda.sh"
        source "/opt/conda/etc/profile.d/mamba.sh"
    fi
    conda install -y -n base conda-libmamba-solver
    conda config --set solver libmamba
    echo "----- Conda Solver Change Complete -----"
}

if [ "$#" -ne 1 ]; then
    echo "Incorrect number of arguments"
    displayUsage
    exit 1
fi

APP_INSTALLER_TYPE=$1

case "$APP_INSTALLER_TYPE" in
    "native")
        checkSudo
        installOSPreqs
        addToolsNFS
        installBXEScripts
        installGuestMountService
        ;;
    
    "container")
        checkSudo
        installOSPreqs
        changeCondaSolver
        ;;
    
    *)
        echo "Invalid argument: $(APP_INSTALLER_TYPE)"
        displayUsage
        exit 1
        ;;
        
esac
