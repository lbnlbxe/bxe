#!/bin/bash
# Helper script to create BXE golden image VM using cloud-init

set -e

# Configuration
VM_NAME="bxe-golden"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
CLOUD_IMG_NAME="noble-server-cloudimg-amd64.img"
DISK_NAME="${VM_NAME}.qcow2"
DISK_SIZE="50G"
MEMORY="16384"  # 16GB
VCPUS="8"
NETWORK_BRIDGE="br1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA="${SCRIPT_DIR}/bxe-user-data.yaml"
NETWORK_CONFIG="${SCRIPT_DIR}/bxe-network-config.yaml"

function displayUsage() {
    echo "Usage: sudo $0 [--image-dir /path/to/images]"
    echo ""
    echo "Options:"
    echo "  --image-dir   Directory to store VM images (default: /var/lib/libvirt/images)"
    echo ""
    echo "Example:"
    echo "  sudo $0 --image-dir /home/images"
}

function checkSudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script must be run with super-user privileges."
        displayUsage
        exit 1
    fi
}

function checkDependencies() {
    echo "----- Checking Dependencies -----"
    local missing_deps=0

    for cmd in virt-install qemu-img wget virsh; do
        if ! command -v $cmd &> /dev/null; then
            echo "ERROR: $cmd not found"
            missing_deps=1
        fi
    done

    if [ $missing_deps -eq 1 ]; then
        echo ""
        echo "Install missing dependencies with:"
        echo "  sudo apt install virt-install libvirt-daemon-system qemu-kvm cloud-image-utils"
        exit 1
    fi

    echo "All dependencies found."
}

function checkCloudInitConfigs() {
    echo "----- Checking Cloud-Init Configs -----"

    if [ ! -f "$USER_DATA" ]; then
        echo "ERROR: Cloud-init user-data not found: $USER_DATA"
        exit 1
    fi

    if [ ! -f "$NETWORK_CONFIG" ]; then
        echo "WARNING: Network config not found: $NETWORK_CONFIG"
        echo "Will use cloud-init defaults."
        NETWORK_CONFIG=""
    fi

    echo "Cloud-init configs validated."
}

function downloadCloudImage() {
    local img_dir=$1

    echo "----- Downloading Ubuntu Cloud Image -----"

    if [ -f "${img_dir}/${CLOUD_IMG_NAME}" ]; then
        echo "Cloud image already exists: ${img_dir}/${CLOUD_IMG_NAME}"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    cd "$img_dir"
    wget -O "${CLOUD_IMG_NAME}" "${CLOUD_IMG_URL}"
    echo "Cloud image downloaded."
}

function createDisk() {
    local img_dir=$1

    echo "----- Creating VM Disk -----"

    if [ -f "${img_dir}/${DISK_NAME}" ]; then
        echo "ERROR: Disk already exists: ${img_dir}/${DISK_NAME}"
        echo "Please remove it first or use a different name."
        exit 1
    fi

    # Create copy of cloud image
    cp "${img_dir}/${CLOUD_IMG_NAME}" "${img_dir}/${DISK_NAME}"

    # Resize disk
    qemu-img resize "${img_dir}/${DISK_NAME}" "$DISK_SIZE"

    echo "Disk created: ${img_dir}/${DISK_NAME} (${DISK_SIZE})"

    # Inject BXE scripts into the image for setupBXE.sh to use
    echo "----- Injecting BXE scripts into image -----"
    if command -v virt-customize &> /dev/null; then
        # Copy the entire bxe-utilities repo to /tmp in the image
        virt-customize -a "${img_dir}/${DISK_NAME}" \
            --copy-in "${SCRIPT_DIR}/..":/tmp \
            --run-command "chown -R 1000:1000 /tmp/bxe-utilities" || \
            echo "Warning: Could not inject scripts (will rely on cloud-init)"
    else
        echo "Warning: virt-customize not found, scripts will not be pre-injected"
        echo "Install with: sudo apt install libguestfs-tools"
    fi
}

function createVM() {
    local img_dir=$1

    echo "----- Creating VM with Cloud-Init -----"

    # Check if VM already exists
    if virsh list --all | grep -q "$VM_NAME"; then
        echo "ERROR: VM '$VM_NAME' already exists"
        echo "Remove it with: virsh undefine $VM_NAME --remove-all-storage"
        exit 1
    fi

    # Build virt-install command
    local virt_cmd="virt-install \
        --name $VM_NAME \
        --memory $MEMORY \
        --vcpus $VCPUS \
        --disk ${img_dir}/${DISK_NAME},format=qcow2,bus=virtio \
        --import \
        --cloud-init user-data=${USER_DATA}"

    # Add network config if it exists
    if [ -n "$NETWORK_CONFIG" ]; then
        virt_cmd="${virt_cmd},network-config=${NETWORK_CONFIG}"
    fi

    virt_cmd="${virt_cmd} \
        --network bridge=${NETWORK_BRIDGE},model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --osinfo ubuntu24.04 \
        --noautoconsole"

    # Execute
    eval $virt_cmd

    echo ""
    echo "VM '$VM_NAME' created successfully!"
}

function addVirtioFS() {
    echo "----- Adding virtiofs filesystem for /tools -----"

    # Wait a moment for VM definition to settle
    sleep 2

    # Create temporary XML snippet
    local tmp_xml=$(mktemp)
    cat > "$tmp_xml" << 'EOF'
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/tools'/>
  <target dir='tools'/>
  <readonly/>
</filesystem>
EOF

    # Attach filesystem to VM (must be stopped)
    virsh attach-device "$VM_NAME" "$tmp_xml" --config || echo "WARNING: Could not auto-add virtiofs. Add manually with 'virsh edit $VM_NAME'"

    rm -f "$tmp_xml"

    echo "virtiofs configuration added (requires VM restart to take effect)"
}

function printNextSteps() {
    echo ""
    echo "======================================================================"
    echo "  BXE Golden Image VM Created: $VM_NAME"
    echo "======================================================================"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Wait for cloud-init to complete (~2-3 minutes):"
    echo "   virsh console $VM_NAME"
    echo "   (Press Ctrl+] to exit console)"
    echo ""
    echo "2. Find VM IP address:"
    echo "   virsh domifaddr $VM_NAME"
    echo ""
    echo "3. SSH into the VM:"
    echo "   ssh bxeuser@<vm-ip>"
    echo ""
    echo "4. Inside the VM, complete BXE setup:"
    echo "   cd ~/bxe-utilities"
    echo "   sudo ./setupBXE.sh"
    echo "   ./installBXE.sh chipyard ~/chipyard"
    echo ""
    echo "5. After installation completes, clean and shut down:"
    echo "   history -c"
    echo "   sudo cloud-init clean --logs --seed"
    echo "   sudo apt clean"
    echo "   sudo poweroff"
    echo ""
    echo "6. Clone VMs from this golden image:"
    echo "   cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/kvm"
    echo "   sudo ./bxe-vm-clone.sh $VM_NAME <new-vm-name>"
    echo ""
    echo "======================================================================"
    echo ""
    echo "To view VM status: virsh list --all"
    echo "To start VM:       virsh start $VM_NAME"
    echo "To stop VM:        virsh shutdown $VM_NAME"
    echo "To remove VM:      virsh undefine $VM_NAME --remove-all-storage"
    echo ""
}

# Main execution
checkSudo
checkDependencies
checkCloudInitConfigs

# Parse arguments
IMAGE_DIR="/var/lib/libvirt/images"
while [[ $# -gt 0 ]]; do
    case $1 in
        --image-dir)
            IMAGE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            displayUsage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            displayUsage
            exit 1
            ;;
    esac
done

# Verify image directory exists
if [ ! -d "$IMAGE_DIR" ]; then
    echo "ERROR: Image directory does not exist: $IMAGE_DIR"
    exit 1
fi

echo "Using image directory: $IMAGE_DIR"
echo ""

downloadCloudImage "$IMAGE_DIR"
createDisk "$IMAGE_DIR"
createVM "$IMAGE_DIR"
addVirtioFS

printNextSteps

exit 0
