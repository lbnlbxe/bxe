#!/bin/bash

set -e
# set -x

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Xilinx tools version to use for prerequisite installation.
# Override at runtime, for example: XILINX_TOOLS_VERSION=2025.1 sudo ./setupBXE.sh
XILINX_TOOLS_VERSION="${XILINX_TOOLS_VERSION:-2023.1}"

# Desired content for /etc/sudoers.d/firesim
desired_firesim_sudoers=$(
cat <<'EOF'
%firesim ALL=(ALL) NOPASSWD: /usr/local/bin/firesim-*
EOF
)

# Desired Rename FireSim Scripts
declare -a rename_firesim_scripts=(
    "firesim-mount"
    "firesim-mount-with-uid-gid"
    "firesim-unmount"
)

# Groups that the BXE user should be a member of
declare -a GROUPS_TO_JOIN=(
    "firesim"
    "kvm"
)

function displayUsage() {
    echo "Usage: sudo $0 [manager|runner]"
    echo "  manager (default) : Set up tools via virtiofs mount (for BXE managers)"
    echo "  runner            : Set up tools via NFS mount (for BXE runners)"
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

function checkXilinxTools() {
    echo -e "${BLUE}==>${NC} Checking Xilinx tools in /tools..."
    local version_year
    version_year=$(echo "${XILINX_TOOLS_VERSION}" | cut -d'.' -f1)

    if [[ "${version_year}" -ge 2025 ]]; then
        XILINX_TOOLS_INSTALL_PATH="/tools/AMD"
        if [[ ! -f "${XILINX_TOOLS_INSTALL_PATH}/XILINX_TOOLS_VERSION" ]]; then
            echo -e "${RED}Error: Xilinx tools not found at ${XILINX_TOOLS_INSTALL_PATH}/XILINX_TOOLS_VERSION${NC}"
            echo -e "${RED}       Missing tools: expected Xilinx ${XILINX_TOOLS_VERSION} installation at ${XILINX_TOOLS_INSTALL_PATH}${NC}"
            exit 1
        fi
    else
        XILINX_TOOLS_INSTALL_PATH="/tools/Xilinx/Vitis"
        if [[ ! -f "${XILINX_TOOLS_INSTALL_PATH}/XILINX_TOOLS_VERSION" ]]; then
            echo -e "${RED}Error: Xilinx tools not found at ${XILINX_TOOLS_INSTALL_PATH}/XILINX_TOOLS_VERSION${NC}"
            echo -e "${RED}       Missing tools: expected Xilinx ${XILINX_TOOLS_VERSION} installation at ${XILINX_TOOLS_INSTALL_PATH}${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ Xilinx tools found at ${XILINX_TOOLS_INSTALL_PATH}${NC}"
}

function installOSPreqs() {
    local IS_NATIVE=$1
    echo -e "${BLUE}==>${NC} Installing OS Prerequisites..."
    apt update
    echo -e "${BLUE}  1. Installing General Prerequisites${NC}"
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

    echo -e "${BLUE}  3. Installing Xilinx Prerequisites${NC}"
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt install -y libtinfo6
    if [[ ! -e "/usr/lib/x86_64-linux-gnu/libtinfo.so.5" ]]; then
        ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5
        echo -e "${YELLOW}  Created libtinfo.so.5 -> libtinfo.so.6 symlink${NC}"
    else
        echo -e "${YELLOW}  libtinfo.so.5 already exists, skipping symlink${NC}"
    fi
    local version_year
    version_year=$(echo "${XILINX_TOOLS_VERSION}" | cut -d'.' -f1)
    local install_libs_path
    if [[ "${version_year}" -ge 2025 ]]; then
        install_libs_path="${XILINX_TOOLS_INSTALL_PATH}/Vivado/scripts/installLibs.sh"
    else
        install_libs_path="${XILINX_TOOLS_INSTALL_PATH}/scripts/installLibs.sh"
    fi
    if [[ ! -f "${install_libs_path}" ]]; then
        echo -e "${RED}Error: installLibs.sh not found at ${install_libs_path}${NC}"
        exit 1
    fi
    bash "${install_libs_path}"

    # Clear apt cache
    rm -rf /var/lib/apt/lists/*

    echo -e "${GREEN}✓ OS Prerequisites installed${NC}"
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

function setupTools() {
    local type=$1
    local fstab_entry fstab_grep description mount_note mount_hint

    case "$type" in
        virtiofs)
            fstab_entry="tools  /tools  virtiofs  ro,defaults  0  0"
            fstab_grep="virtiofs"
            description="virtiofs"
            mount_note="requires virtiofs in VM XML"
            mount_hint="        Add filesystem device to VM with: virsh edit <vm-name>"
            ;;
        nfs)
            fstab_entry=$'# /tools from socks.lbl.gov\nsocks.lbl.gov:/mnt/md0/tools    /tools  nfs  defaults,timeo=900,retrans=5,_netdev 0 0'
            fstab_grep="socks.lbl.gov:/mnt/md0/tools"
            description="NFS"
            mount_note="requires network access to socks.lbl.gov"
            mount_hint=""
            ;;
        *)
            echo -e "${RED}Error: unknown tools mount type '${type}'.${NC}"
            exit 1
            ;;
    esac

    echo -e "${BLUE}==>${NC} Setting up ${description} mount for /tools..."
    mkdir -p /tools

    # Check for any existing /tools entry in fstab
    local existing_entry
    existing_entry=$(grep -E '^[^#]*[[:space:]]+/tools[[:space:]]' /etc/fstab || true)
    if [[ -n "${existing_entry}" ]]; then
        if grep -q "${fstab_grep}" /etc/fstab; then
            echo -e "${YELLOW}  /tools ${description} mount already in /etc/fstab${NC}"
        else
            echo -e "${RED}Error: /etc/fstab already has a /tools entry that does not match the expected ${description} configuration:${NC}"
            echo -e "${RED}  Found: ${existing_entry}${NC}"
            exit 1
        fi
    else
        printf "%s\n" "${fstab_entry}" >> /etc/fstab
        echo -e "${YELLOW}  Added /tools ${description} mount to /etc/fstab${NC}"
        systemctl daemon-reload
    fi

    # Try to mount
    if ! mountpoint -q /tools; then
        if mount /tools 2>/dev/null; then
            echo -e "${GREEN}  ✓ /tools mounted successfully via ${description}${NC}"
        else
            echo -e "${YELLOW}  Warning: failed to mount /tools via ${description}${NC}"
            [[ -n "${mount_hint}" ]] && echo -e "${YELLOW}${mount_hint}${NC}"
        fi
    else
        echo -e "${YELLOW}  /tools already mounted${NC}"
    fi

    echo -e "${GREEN}✓ ${description} mount setup complete${NC}"
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

    # Hiding firesim scripts to force the use of guestmount
    echo -e "${YELLOW}  Hiding firesim-mount* and firesim-unmount to force the use of guestmount...${NC}"
    cd /usr/local/bin
    for src in "${rename_firesim_scripts[@]}"; do
        dst="O_${src}"
        if [[ -f "$src" ]]; then
            echo -e "${BLUE}  Renaming \"${src}\" → \"${dst}\""
            if mv -- "$src" "$dst"; then
                echo -e "${GREEN}  Renamed \"${src}\" to \"${dst}\" ${NC}"
            else
                echo -e "${RED}  Renamed failed for \"${src}\" (mv returned $?).${NC}"
            fi
        else
            echo -e "${YELLOW}  \"${src}\" does not exist or is not a regular file - nothing to do."
        fi
    done
    
    # Clean up temporary directory
    echo -e "${YELLOW}  Cleaning up temporary files...${NC}"
    cd /
    rm -rf "${TEMP_FIRESIM_DIR}"

    echo -e "${GREEN}✓ FireSim scripts installed${NC}"
}

function addBXEUser() {
    echo -e "${BLUE}==>${NC} Adding BXE user..."
    local username="bxeuser"
    local fullname="BXE User"
    local password_hash='$6$DwysQpQ8jfdfcgJW$DjRWBwwLhi/x.4h0GNXjvffhfjHSOI8YZwZyWtqE7YKT9nS9TudlnOv1/wT0sDbnNWV/mmZBdNP9t8S9Emjbh0'
    
    if id "$username" >/dev/null 2>&1; then
        echo -e "${YELLOW}  User $username already exists, updating password${NC}"
        usermod -p "$password_hash" "$username"
    else
        useradd -m -c "$fullname" -p "$password_hash" "$username"
        echo -e "${GREEN}  ✓ User $username created${NC}"
    fi

    # Handle group memberships
    for group in "${GROUPS_TO_JOIN[@]}"; do
        if getent group "$group" >/dev/null; then
            if ! id -nG "$username" | grep -qw "$group"; then
                usermod -aG "$group" "$username"
                echo -e "${GREEN}  ✓ Added $username to $group group${NC}"
            else
                echo -e "${YELLOW}  User $username already in $group group${NC}"
            fi
        else
            echo -e "${YELLOW}  $group group not found, skipping addition${NC}"
        fi
    done

    echo -e "${GREEN}✓ BXE user setup complete${NC}"
}

# Determine script source directory

SETUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-manager}"
if [[ "$MODE" != "manager" && "$MODE" != "runner" ]]; then
    echo -e "${RED}Error: invalid mode '${MODE}'. Must be 'manager' or 'runner'.${NC}"
    displayUsage
    exit 1
fi

checkSudo
if [[ "$MODE" == "manager" ]]; then
    setupTools virtiofs
else
    setupTools nfs
fi
checkXilinxTools
installOSPreqs true
installConda
installBXEScripts "${SETUP_SCRIPT_DIR}"
installGuestMountService
setupFireSimGroup
addBXEUser
installFireSimScripts

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BXE Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
