#!/bin/bash
# BXE VM Orchestration Script
# Fully automates the golden image creation and VM cloning process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT_DIR="${SCRIPT_DIR}/cloud-init"
KVM_DIR="${SCRIPT_DIR}/kvm"

# Configuration
DEFAULT_GOLDEN_NAME="bxe-golden"
DEFAULT_BRIDGE="br1"
DEFAULT_TOOLS_PATH="/tools"
SSH_USER="bxeuser"
SSH_TIMEOUT=300  # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

function print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

function displayUsage() {
    cat << EOF
Usage: sudo $0 <command> [options]

Commands:
  create-golden     Create golden image VM from scratch
  setup-golden      Run setupBXE/installBXE inside existing golden VM
  clone             Clone VM(s) from golden image
  deploy            Full deployment (create golden + clone VMs)
  status            Show status of BXE VMs

Options (create-golden):
  --name <name>           Golden VM name (default: ${DEFAULT_GOLDEN_NAME})
  --bridge <bridge>       Network bridge (default: ${DEFAULT_BRIDGE})
  --tools <path>          Tools path on hypervisor (default: ${DEFAULT_TOOLS_PATH})
  --ssh-key <file>        SSH public key file to add to VM
  --no-virtiofs           Skip virtiofs configuration
  --no-setup              Create VM but don't run setupBXE/installBXE

Options (setup-golden):
  --name <name>           Golden VM name (default: ${DEFAULT_GOLDEN_NAME})
  --install-type <type>   Install type: chipyard|firesim (default: chipyard)
  --install-path <path>   Installation path (default: ~/chipyard or ~/firesim)

Options (clone):
  --source <name>         Source VM name (default: ${DEFAULT_GOLDEN_NAME})
  --targets <list>        Comma-separated list of VM names to create
  --count <n>             Create N VMs with auto-generated names (vm-1, vm-2, ...)
  --prefix <prefix>       Prefix for auto-generated names (default: bxe)

Options (deploy):
  Combines create-golden and clone options

Examples:
  # Create golden image with full automation
  sudo $0 create-golden --ssh-key ~/.ssh/id_rsa.pub

  # Create golden image, skip automatic setup
  sudo $0 create-golden --no-setup

  # Run setup on existing golden VM
  sudo $0 setup-golden --name bxe-golden

  # Clone 3 VMs
  sudo $0 clone --count 3

  # Clone specific VMs
  sudo $0 clone --targets alice-bxe,bob-bxe,charlie-bxe

  # Full deployment: create golden + clone 5 VMs
  sudo $0 deploy --ssh-key ~/.ssh/id_rsa.pub --count 5

  # Show status
  sudo $0 status

EOF
}

function checkSudo() {
    if [[ "$EUID" -ne 0 ]]; then
        print_error "This script must be run with sudo"
        displayUsage
        exit 1
    fi
}

function checkDependencies() {
    local missing=0
    for cmd in virsh virt-install qemu-img virt-clone virt-sysprep ssh-keyscan; do
        if ! command -v $cmd &> /dev/null; then
            print_error "Missing dependency: $cmd"
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        print_error "Install missing dependencies:"
        echo "  sudo apt install virt-install libvirt-daemon-system qemu-kvm libvirt-clients libguestfs-tools openssh-client"
        exit 1
    fi
}

function waitForVM() {
    local vm_name=$1
    local timeout=${2:-60}

    print_info "Waiting for VM '$vm_name' to boot..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; then
            print_success "VM is running"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    print_error "Timeout waiting for VM to start"
    return 1
}

function getVMIP() {
    local vm_name=$1
    local timeout=${2:-120}

    print_info "Getting IP address for VM '$vm_name'..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local ip=$(virsh domifaddr "$vm_name" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
        if [ -n "$ip" ]; then
            echo "$ip"
            print_success "VM IP: $ip"
            return 0
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done

    print_error "Could not get IP for VM '$vm_name'"
    return 1
}

function waitForSSH() {
    local ip=$1
    local user=$2
    local timeout=${3:-300}

    print_info "Waiting for SSH on ${user}@${ip}..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${user}@${ip}" "exit 0" 2>/dev/null; then
            print_success "SSH is ready"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        if [ $((elapsed % 30)) -eq 0 ]; then
            print_info "Still waiting for SSH... (${elapsed}s elapsed)"
        fi
    done

    print_error "Timeout waiting for SSH"
    return 1
}

function addVirtioFS() {
    local vm_name=$1
    local tools_path=$2

    print_info "Adding virtiofs configuration to VM '$vm_name'..."

    # Check if VM is running, shut it down if needed
    if virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; then
        print_info "Shutting down VM to add virtiofs..."
        virsh shutdown "$vm_name" --mode acpi
        sleep 5

        # Wait for shutdown
        local timeout=60
        local elapsed=0
        while virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "VM didn't shut down gracefully, forcing off..."
                virsh destroy "$vm_name"
                break
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done
    fi

    # Create temporary XML file for virtiofs filesystem
    local tmp_xml=$(mktemp)
    cat > "$tmp_xml" << EOF
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='${tools_path}'/>
  <target dir='tools'/>
  <readonly/>
</filesystem>
EOF

    # Attach the filesystem device
    if virsh attach-device "$vm_name" "$tmp_xml" --config --persistent 2>/dev/null; then
        print_success "virtiofs filesystem added"
    else
        print_warning "Could not attach virtiofs automatically, trying manual XML edit..."

        # Fall back to manual XML modification
        local vm_xml=$(mktemp)
        virsh dumpxml "$vm_name" > "$vm_xml"

        # Check if memoryBacking already exists
        if ! grep -q "<memoryBacking>" "$vm_xml"; then
            # Add memoryBacking before <devices>
            sed -i '/<devices>/i \  <memoryBacking>\n    <source type='"'"'memfd'"'"'/>\n    <access mode='"'"'shared'"'"'/>\n  </memoryBacking>' "$vm_xml"
        fi

        # Add filesystem inside <devices> if not already present
        if ! grep -q "virtiofs" "$vm_xml"; then
            sed -i '/<\/devices>/i \    <filesystem type='"'"'mount'"'"' accessmode='"'"'passthrough'"'"'>\n      <driver type='"'"'virtiofs'"'"'/>\n      <source dir='"'"''"${tools_path}"''"'"'/>\n      <target dir='"'"'tools'"'"'/>\n      <readonly/>\n    </filesystem>' "$vm_xml"
        fi

        # Define the modified XML
        if virsh define "$vm_xml"; then
            print_success "virtiofs added via XML modification"
        else
            print_error "Failed to add virtiofs"
            rm -f "$tmp_xml" "$vm_xml"
            return 1
        fi

        rm -f "$vm_xml"
    fi

    rm -f "$tmp_xml"

    # Start VM back up
    virsh start "$vm_name"
    print_success "VM restarted with virtiofs"

    return 0
}

function runInVM() {
    local vm_ip=$1
    local user=$2
    shift 2
    local command="$@"

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${user}@${vm_ip}" "$command"
}

function createGoldenImage() {
    local vm_name=$1
    local bridge=$2
    local tools_path=$3
    local ssh_key_file=$4
    local skip_virtiofs=$5
    local skip_setup=$6

    print_header "Creating Golden Image: $vm_name"

    # Update cloud-init with SSH key if provided
    if [ -n "$ssh_key_file" ] && [ -f "$ssh_key_file" ]; then
        print_info "Adding SSH key from $ssh_key_file to cloud-init config"
        local ssh_key=$(cat "$ssh_key_file")
        local user_data="${CLOUD_INIT_DIR}/bxe-user-data.yaml"

        # Backup original
        cp "$user_data" "${user_data}.bak"

        # Replace SSH key placeholder
        sed -i "s|ssh-rsa AAAAB3NzaC1yc2E.*|${ssh_key}|" "$user_data"
    fi

    # Run create-bxe-golden.sh
    cd "$CLOUD_INIT_DIR"
    if ./create-bxe-golden.sh; then
        print_success "Golden VM created"
    else
        print_error "Failed to create golden VM"
        return 1
    fi

    # Wait for VM and get IP
    waitForVM "$vm_name" 60 || return 1
    local vm_ip=$(getVMIP "$vm_name" 120) || return 1

    # Add virtiofs if not skipped
    if [ "$skip_virtiofs" != "true" ]; then
        addVirtioFS "$vm_name" "$tools_path" || print_warning "virtiofs configuration failed, continuing..."

        # Get new IP after restart
        waitForVM "$vm_name" 60 || return 1
        vm_ip=$(getVMIP "$vm_name" 120) || return 1
    fi

    # Wait for cloud-init to complete
    print_info "Waiting for cloud-init to complete..."
    waitForSSH "$vm_ip" "$SSH_USER" "$SSH_TIMEOUT" || return 1

    # Wait a bit more for cloud-init to fully finish
    sleep 10

    # Run setup if not skipped
    if [ "$skip_setup" != "true" ]; then
        setupGoldenImage "$vm_name" "$vm_ip" "chipyard" "~/chipyard"
    else
        print_warning "Skipping setupBXE/installBXE (--no-setup specified)"
        print_info "To complete setup later, run:"
        print_info "  sudo $0 setup-golden --name $vm_name"
    fi

    print_success "Golden image creation complete!"

    return 0
}

function setupGoldenImage() {
    local vm_name=$1
    local vm_ip=${2:-}
    local install_type=${3:-chipyard}
    local install_path=${4:-~/chipyard}

    print_header "Setting up BXE in Golden Image: $vm_name"

    # Get VM IP if not provided
    if [ -z "$vm_ip" ]; then
        waitForVM "$vm_name" 60 || return 1
        vm_ip=$(getVMIP "$vm_name" 120) || return 1
        waitForSSH "$vm_ip" "$SSH_USER" "$SSH_TIMEOUT" || return 1
    fi

    # Run setupBXE.sh
    print_info "Running setupBXE.sh..."
    # Scripts were injected into /tmp/bxe-utilities by virt-customize
    if runInVM "$vm_ip" "$SSH_USER" "cd /tmp/bxe-utilities && sudo ./setupBXE.sh"; then
        print_success "setupBXE.sh completed"
    else
        print_error "setupBXE.sh failed"
        return 1
    fi

    # Run installBXE.sh
    print_info "Running installBXE.sh (this will take 30-60 minutes)..."
    print_info "Installing: $install_type to $install_path"

    if runInVM "$vm_ip" "$SSH_USER" "/opt/bxe/installBXE.sh $install_type $install_path"; then
        print_success "installBXE.sh completed"
    else
        print_error "installBXE.sh failed"
        return 1
    fi

    # Clean up for golden image
    print_info "Cleaning up for golden image creation..."
    runInVM "$vm_ip" "$SSH_USER" "history -c"
    runInVM "$vm_ip" "$SSH_USER" "sudo cloud-init clean --logs --seed"
    runInVM "$vm_ip" "$SSH_USER" "sudo apt clean"

    # Shutdown
    print_info "Shutting down golden image..."
    runInVM "$vm_ip" "$SSH_USER" "sudo poweroff" || true

    # Wait for shutdown
    sleep 10
    local timeout=60
    local elapsed=0
    while virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "VM didn't shut down gracefully, forcing off..."
            virsh destroy "$vm_name"
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    print_success "Golden image setup complete and VM shut down"
    print_info "Golden image is ready for cloning"

    return 0
}

function cloneVMs() {
    local source_vm=$1
    shift
    local target_vms=("$@")

    print_header "Cloning VMs from: $source_vm"

    # Verify source VM exists and is shut off
    if ! virsh dominfo "$source_vm" &>/dev/null; then
        print_error "Source VM '$source_vm' does not exist"
        return 1
    fi

    if virsh domstate "$source_vm" 2>/dev/null | grep -q "running"; then
        print_error "Source VM '$source_vm' must be shut off before cloning"
        print_info "Run: virsh shutdown $source_vm"
        return 1
    fi

    local success_count=0
    local fail_count=0

    for target_vm in "${target_vms[@]}"; do
        print_info "Cloning: $source_vm → $target_vm"

        if virsh dominfo "$target_vm" &>/dev/null; then
            print_warning "VM '$target_vm' already exists, skipping"
            fail_count=$((fail_count + 1))
            continue
        fi

        if "${KVM_DIR}/bxe-vm-clone.sh" "$source_vm" "$target_vm"; then
            print_success "Cloned: $target_vm"
            success_count=$((success_count + 1))

            # Start the cloned VM
            print_info "Starting: $target_vm"
            virsh start "$target_vm"
        else
            print_error "Failed to clone: $target_vm"
            fail_count=$((fail_count + 1))
        fi
    done

    print_header "Cloning Summary"
    print_success "Successfully cloned: $success_count VMs"
    if [ $fail_count -gt 0 ]; then
        print_error "Failed to clone: $fail_count VMs"
    fi

    return 0
}

function showStatus() {
    print_header "BXE VM Status"

    echo ""
    echo "All VMs:"
    virsh list --all | grep -E "bxe|golden" || echo "  No BXE VMs found"

    echo ""
    echo "Running VMs with IP addresses:"
    local vms=$(virsh list --name --state-running | grep -E "bxe|golden")
    if [ -n "$vms" ]; then
        while IFS= read -r vm; do
            if [ -n "$vm" ]; then
                local ip=$(virsh domifaddr "$vm" 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -1)
                if [ -n "$ip" ]; then
                    printf "  %-20s %s\n" "$vm" "$ip"
                else
                    printf "  %-20s %s\n" "$vm" "(no IP yet)"
                fi
            fi
        done <<< "$vms"
    else
        echo "  No running BXE VMs"
    fi

    echo ""
}

# Parse command
if [ "$#" -lt 1 ]; then
    displayUsage
    exit 1
fi

COMMAND=$1
shift

# Parse options
GOLDEN_NAME="$DEFAULT_GOLDEN_NAME"
BRIDGE="$DEFAULT_BRIDGE"
TOOLS_PATH="$DEFAULT_TOOLS_PATH"
SSH_KEY_FILE=""
SKIP_VIRTIOFS=false
SKIP_SETUP=false
INSTALL_TYPE="chipyard"
INSTALL_PATH=""
SOURCE_VM="$DEFAULT_GOLDEN_NAME"
TARGET_VMS=()
CLONE_COUNT=0
CLONE_PREFIX="bxe"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            GOLDEN_NAME="$2"
            SOURCE_VM="$2"
            shift 2
            ;;
        --bridge)
            BRIDGE="$2"
            shift 2
            ;;
        --tools)
            TOOLS_PATH="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_FILE="$2"
            shift 2
            ;;
        --no-virtiofs)
            SKIP_VIRTIOFS=true
            shift
            ;;
        --no-setup)
            SKIP_SETUP=true
            shift
            ;;
        --install-type)
            INSTALL_TYPE="$2"
            shift 2
            ;;
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --source)
            SOURCE_VM="$2"
            shift 2
            ;;
        --targets)
            IFS=',' read -ra TARGET_VMS <<< "$2"
            shift 2
            ;;
        --count)
            CLONE_COUNT="$2"
            shift 2
            ;;
        --prefix)
            CLONE_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            displayUsage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            displayUsage
            exit 1
            ;;
    esac
done

# Set default install path if not specified
if [ -z "$INSTALL_PATH" ]; then
    if [ "$INSTALL_TYPE" = "chipyard" ]; then
        INSTALL_PATH="~/chipyard"
    else
        INSTALL_PATH="~/firesim"
    fi
fi

# Execute command
case "$COMMAND" in
    create-golden)
        checkSudo
        checkDependencies
        createGoldenImage "$GOLDEN_NAME" "$BRIDGE" "$TOOLS_PATH" "$SSH_KEY_FILE" "$SKIP_VIRTIOFS" "$SKIP_SETUP"
        ;;

    setup-golden)
        checkSudo
        checkDependencies
        setupGoldenImage "$GOLDEN_NAME" "" "$INSTALL_TYPE" "$INSTALL_PATH"
        ;;

    clone)
        checkSudo
        checkDependencies

        # Generate target VMs if count is specified
        if [ $CLONE_COUNT -gt 0 ]; then
            for i in $(seq 1 $CLONE_COUNT); do
                TARGET_VMS+=("${CLONE_PREFIX}-${i}")
            done
        fi

        if [ ${#TARGET_VMS[@]} -eq 0 ]; then
            print_error "No target VMs specified (use --targets or --count)"
            exit 1
        fi

        cloneVMs "$SOURCE_VM" "${TARGET_VMS[@]}"
        ;;

    deploy)
        checkSudo
        checkDependencies

        # Create golden image
        createGoldenImage "$GOLDEN_NAME" "$BRIDGE" "$TOOLS_PATH" "$SSH_KEY_FILE" "$SKIP_VIRTIOFS" "$SKIP_SETUP"

        # Clone VMs if requested
        if [ $CLONE_COUNT -gt 0 ] || [ ${#TARGET_VMS[@]} -gt 0 ]; then
            print_info "Waiting 10 seconds before starting cloning..."
            sleep 10

            # Generate target VMs if count is specified
            if [ $CLONE_COUNT -gt 0 ]; then
                for i in $(seq 1 $CLONE_COUNT); do
                    TARGET_VMS+=("${CLONE_PREFIX}-${i}")
                done
            fi

            cloneVMs "$GOLDEN_NAME" "${TARGET_VMS[@]}"
        fi

        showStatus
        ;;

    status)
        showStatus
        ;;

    *)
        print_error "Unknown command: $COMMAND"
        displayUsage
        exit 1
        ;;
esac

exit 0
