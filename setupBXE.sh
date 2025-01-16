#!/bin/bash

set -e
# set -x

function usage() {
    echo "Usage: sudo $0"
}

function checkSudo() {
	# display usage if the script is not run as root user
	if [[ "${EUID}" -ne 0 ]]; then
		echo "This script must be run with super-user privileges."
		usage
		exit 1
	fi
}

function installOSPreqs() {
    echo "----- Installing OS Prequisites -----"
    apt update
    echo "1. Installing General Prerequisites"
    apt install -y nfs-common openssh-server libguestfs-tools \
        wget curl vim tree emacs tmux git build-essential \
        tigervnc-standalone-server

    echo "2. Installing Firesim Prerequisites"
    apt install -y libc6-dev screen libtinfo-dev libtinfo5

    echo "3. Installing Xilinx Prequisites"
    apt install -y libtinfo5 libncurses5 python3-pip libstdc++6:i386 \
    libgtk2.0-0:i386 dpkg-dev:i386
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

checkSudo
installOSPreqs
addToolsNFS
installBXEScripts
installGuestMountService
