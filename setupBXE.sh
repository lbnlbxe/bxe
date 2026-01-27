#!/bin/bash

set -e
# set -x

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Desired content for /etc/sudoers.d/firesim
desired_firesim_sudoers=$(
cat <<'EOF'
%firesim ALL=(ALL) NOPASSWD: /usr/local/bin/firesim-*
%firesim ALL=(ALL) NOPASSWD: /usr/bin/mount
EOF
)

function displayUsage() {
    echo "Usage: sudo $0"
    echo "  NOTE : This script expects \$BXE_CONTAINER if being run in a container."
}

function checkSudo() {
	# display usage if the script is not run as root user
	if [[ "${EUID}" -ne 0 ]]; then
		echo -e "${RED}Error: This script must be run with super-user privileges.${NC}"
		displayUsage
		exit 1
	fi
}

function installOSPreqs() {
    local IS_NATIVE=$1
    echo -e "${BLUE}==>${NC} Installing OS Prerequisites..."
    apt update
    echo -e "${BLUE}  1. Installing General Prerequisites${NC}"
    # DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y nfs-common openssh-server libguestfs-tools \
        # wget curl vim tree emacs tmux git build-essential sudo
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y openssh-server libguestfs-tools \
        wget curl vim tree emacs tmux git build-essential sudo

    if [ "$IS_NATIVE" = true ]; then
        echo -e "${BLUE}  Installing desktop environment and remote access tools...${NC}"
        DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y \
            xfce4 xfce4-goodies dbus dbus-x11 \
            tigervnc-standalone-server xrdp
    fi

    echo -e "${BLUE}  2. Installing FireSim Prerequisites${NC}"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libc6-dev screen libtinfo-dev

    # echo "3. Installing Xilinx Prerequisites"
    # DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libtinfo5 libncurses5 python3-pip #libstdc++6:i386 \
    #    libgtk2.0-0:i386 dpkg-dev:i386

    # Clear apt cache
    rm -rf /var/lib/apt/lists/*

    echo -e "${GREEN}✓ OS Prerequisites installed${NC}"
}

function addToolsNFS() {
    echo -e "${BLUE}==>${NC} Adding Tools NFS Mount..."
    mkdir -p /tools
    sed -i -e '$avizion.lbl.gov:/mnt/vmpool/nfs/tools\t/tools\tnfs\tdefaults,timeo=900,retrans=5,_netdev\t0\t0\n' /etc/fstab
    systemctl daemon-reload
    mount /tools
    echo -e "${GREEN}✓ Tools NFS Mount configured${NC}"
}

function installBXEScripts() {
    local SOURCE_DIR=$1
    echo -e "${BLUE}==>${NC} Installing BXE Scripts..."
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

    echo -e "${GREEN}✓ BXE Scripts installed${NC}"
}

function installGuestMountService() {
    echo -e "${BLUE}==>${NC} Adding Guest Mount Service..."
    ln -sf /opt/bxe/firesim-guestmount.service /etc/systemd/system/.
    systemctl daemon-reload
    systemctl enable --now firesim-guestmount
    echo -e "${GREEN}✓ Guest Mount Service configured${NC}"
}

function installConda() {
    echo -e "${BLUE}==>${NC} Installing Conda..."
    if ! command -v conda 2>&1 >/dev/null; then
        echo -e "${YELLOW}  conda not installed, installing Miniforge3...${NC}"
        cd /tmp
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
        bash Miniforge3-Linux-x86_64.sh -b -p "/opt/conda"
        rm Miniforge3-Linux-x86_64.sh
        source "/opt/conda/etc/profile.d/conda.sh"
        ln -sf /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
        echo -e "${GREEN}  ✓ Miniforge3 installed${NC}"
    else
        echo -e "${YELLOW}  conda already installed${NC}"
    fi
    echo -e "${GREEN}✓ Conda ready${NC}"
}

function setupToolsVirtioFS() {
    echo -e "${BLUE}==>${NC} Setting up virtiofs mount for /tools..."
    mkdir -p /tools

    # Add to fstab if not already present
    if ! grep -q "virtiofs" /etc/fstab; then
        echo "tools  /tools  virtiofs  ro,defaults  0  0" >> /etc/fstab
        echo -e "${YELLOW}  Added /tools virtiofs mount to /etc/fstab${NC}"
    else
        echo -e "${YELLOW}  /tools virtiofs mount already in /etc/fstab${NC}"
    fi

    # Try to mount (will succeed if VM XML has filesystem defined)
    if ! mountpoint -q /tools; then
        if mount /tools 2>/dev/null; then
            echo -e "${GREEN}  ✓ /tools mounted successfully via virtiofs${NC}"
        else
            echo -e "${YELLOW}  Note: /tools will mount at next boot (requires virtiofs in VM XML)${NC}"
            echo -e "${YELLOW}        Add filesystem device to VM with: virsh edit <vm-name>${NC}"
        fi
    else
        echo -e "${YELLOW}  /tools already mounted${NC}"
    fi

    echo -e "${GREEN}✓ virtiofs mount setup complete${NC}"
}

function setupFireSimGroup() {
    echo -e "${BLUE}==>${NC} Setting up firesim group and sudoers..."

    # Check if firesim group exists, create if not
    if ! getent group firesim >/dev/null; then
        echo -e "${YELLOW}  firesim group not found, creating...${NC}"
        groupadd firesim
        echo -e "${GREEN}  ✓ firesim group created${NC}"
    else
        echo -e "${YELLOW}  firesim group already exists${NC}"
    fi

    # If the file is missing or its contents differ, replace it
    if [ ! -f /etc/sudoers.d/firesim ] || ! diff -q <(printf "%s\n" "$desired_firesim_sudoers") /etc/sudoers.d/firesim >/dev/null; then
        echo -e "${YELLOW}  Updating sudoers file for firesim...${NC}"
        printf "%s\n" "$desired_firesim_sudoers" > /etc/sudoers.d/firesim
        chmod 440 /etc/sudoers.d/firesim
        echo -e "${GREEN}  ✓ firesim sudoers file updated${NC}"
    else
        echo -e "${YELLOW}  firesim sudoers file already matches${NC}"
    fi

    echo -e "${GREEN}✓ firesim group setup complete${NC}"
}

function installFireSimScripts() {
    echo -e "${BLUE}==>${NC} Installing FireSim scripts..."
    local TEMP_FIRESIM_DIR=$(mktemp -d)
    echo -e "${YELLOW}  Cloning FireSim repository to ${TEMP_FIRESIM_DIR}...${NC}"

    cd "${TEMP_FIRESIM_DIR}"
    git clone https://github.com/firesim/firesim .

    # Copy sudo scripts
    if [ -d "deploy/sudo-scripts" ]; then
        echo -e "${YELLOW}  Copying deploy/sudo-scripts...${NC}"
        cp deploy/sudo-scripts/* /usr/local/bin/
    fi

    # Copy xilinx alveo scripts
    if [ -d "platforms/xilinx_alveo_u250/scripts" ]; then
        echo -e "${YELLOW}  Copying platforms/xilinx_alveo_u250/scripts...${NC}"
        cp platforms/xilinx_alveo_u250/scripts/* /usr/local/bin/
    fi

    # Set permissions and group
    echo -e "${YELLOW}  Setting permissions and group for firesim scripts...${NC}"
    chmod 755 /usr/local/bin/firesim*
    chgrp firesim /usr/local/bin/firesim*

    # Clean up temporary directory
    echo -e "${YELLOW}  Cleaning up temporary files...${NC}"
    cd /
    rm -rf "${TEMP_FIRESIM_DIR}"

    echo -e "${GREEN}✓ FireSim scripts installed${NC}"
}

# Determine script source directory
SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

checkSudo
installOSPreqs true
installConda
setupToolsVirtioFS
installBXEScripts "${SETUP_SCRIPT_DIR}"
installGuestMountService
setupFireSimGroup
installFireSimScripts

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BXE Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
