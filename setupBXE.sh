#!/bin/bash

set -e
# set -x

function displayUsage() {
    echo "Usage: sudo $0 <native|container>"
    echo "  <native|container> : Select installation type"
    echo "                       - native: For installations directly on hosts or VMs"
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
    local IS_NATIVE=$1
    echo "----- Installing OS Prequisites -----"
    apt update
    echo "1. Installing General Prerequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y nfs-common openssh-server libguestfs-tools \
        wget curl vim tree emacs tmux git build-essential
    
    if [ "$IS_NATIVE" = true ]; then
        DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y tigervnc-standalone-server
    fi

    echo "2. Installing Firesim Prerequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libc6-dev screen libtinfo-dev

    # echo "3. Installing Xilinx Prequisites"
    # DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libtinfo5 libncurses5 python3-pip #libstdc++6:i386 \
    #    libgtk2.0-0:i386 dpkg-dev:i386
    echo "----- OS Prequisites Complete -----"
}

function addToolsNFS() {
    echo "----- Adding Tools NFS Mount -----"
    mkdir -p /tools
    sed -i -e '$avizion.lbl.gov:/mnt/vmpool/nfs/tools\t/tools\tnfs\tdefaults,timeo=900,retrans=5,_netdev\t0\t0\n' /etc/fstab
    systemctl daemon-reload
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

function installConda() {
    echo "----- Installing Conda -----"
    if ! command -v conda 2>&1 >/dev/null; then
        echo "conda is not installed. Installing Miniforge3..."
        cd /tmp
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        bash Miniforge3-Linux-x86_64.sh -b -p "/opt/conda"
        rm Miniforge3-Linux-x86_64.sh
        source "/opt/conda/etc/profile.d/conda.sh"
        source "/opt/conda/etc/profile.d/mamba.sh"
    fi
    echo "----- Conda Install Complete -----"
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
        installOSPreqs true
        installConda
        addToolsNFS
        installBXEScripts
        installGuestMountService
        ;;
    
    "container")
        checkSudo
        installOSPreqs false
        installConda
        installBXEScripts
        installGuestMountService
        ;;
    
    *)
        echo "Invalid argument: $(APP_INSTALLER_TYPE)"
        displayUsage
        exit 1
        ;;
        
esac
