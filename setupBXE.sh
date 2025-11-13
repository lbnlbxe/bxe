#!/bin/bash

set -e
# set -x

function displayUsage() {
    echo "Usage: sudo $0"
    echo "  NOTE : This script expects \$BXE_CONTAINER if being run in a container."
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
    # DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y nfs-common openssh-server libguestfs-tools \
        # wget curl vim tree emacs tmux git build-essential sudo
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y openssh-server libguestfs-tools \
        wget curl vim tree emacs tmux git build-essential sudo
    
    if [ "$IS_NATIVE" = true ]; then
        echo "Installing desktop environment and remote access tools..."
        DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y \
            xfce4 xfce4-goodies dbus dbus-x11 \
            tigervnc-standalone-server xrdp
    fi

    echo "2. Installing Firesim Prerequisites"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libc6-dev screen libtinfo-dev

    # echo "3. Installing Xilinx Prequisites"
    # DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libtinfo5 libncurses5 python3-pip #libstdc++6:i386 \
    #    libgtk2.0-0:i386 dpkg-dev:i386

    # Clear apt cache
    rm -rf /var/lib/apt/lists/*

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
    local SOURCE_DIR=$1
    echo "----- Installing BXE Scripts -----"
    mkdir -p /opt/bxe
    mkdir -p /opt/bxe/managers

    # Copy system scripts
    if [ -f "${SOURCE_DIR}/firesim-guestmount.service" ]; then
        cp "${SOURCE_DIR}/firesim-guestmount.service" /opt/bxe/.
    fi
    if [ -f "${SOURCE_DIR}/firesim-guestmount.sh" ]; then
        cp "${SOURCE_DIR}/firesim-guestmount.sh" /opt/bxe/.
    fi
    if [ -f "${SOURCE_DIR}/regenSSHKey.sh" ]; then
        cp "${SOURCE_DIR}/regenSSHKey.sh" /opt/bxe/.
    fi

    # Copy installBXE.sh and dependencies for users
    if [ -f "${SOURCE_DIR}/installBXE.sh" ]; then
        cp "${SOURCE_DIR}/installBXE.sh" /opt/bxe/.
        chmod +x /opt/bxe/installBXE.sh
    fi

    # Copy managers directory (needed by installBXE.sh)
    if [ -d "${SOURCE_DIR}/managers" ]; then
        cp "${SOURCE_DIR}"/managers/* /opt/bxe/managers/.
    fi

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
        ln -sf /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
    fi
    echo "----- Conda Install Complete -----"
}

function setupToolsVirtioFS() {
    echo "----- Setting up virtiofs mount for /tools -----"
    mkdir -p /tools

    # Add to fstab if not already present
    if ! grep -q "virtiofs" /etc/fstab; then
        echo "tools  /tools  virtiofs  ro,defaults  0  0" >> /etc/fstab
        echo "Added /tools virtiofs mount to /etc/fstab"
    else
        echo "/tools virtiofs mount already in /etc/fstab"
    fi

    # Try to mount (will succeed if VM XML has filesystem defined)
    if ! mountpoint -q /tools; then
        if mount /tools 2>/dev/null; then
            echo "/tools mounted successfully via virtiofs"
        else
            echo "Note: /tools will mount at next boot (requires virtiofs in VM XML)"
            echo "      Add filesystem device to VM with: virsh edit <vm-name>"
        fi
    else
        echo "/tools already mounted"
    fi

    echo "----- virtiofs mount setup complete -----"
}

# Determine script source directory
SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${BXE_CONTAINER}" ]; then
    checkSudo
    installOSPreqs true
    installConda
    setupToolsVirtioFS
    installBXEScripts "${SETUP_SCRIPT_DIR}"
    installGuestMountService
else
    checkSudo
    installOSPreqs false
    installConda
    # Container doesn't use virtiofs (uses Docker volume mounts)
    # installBXEScripts "${SETUP_SCRIPT_DIR}"
    # installGuestMountService
fi        

echo "BXE Setup Complete!"
