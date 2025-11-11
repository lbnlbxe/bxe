#!/bin/bash
# First Login Setup for BXE Users
# Run this script the first time you log into a BXE VM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function print_header() {
    echo "================================================"
    echo "  $1"
    echo "================================================"
}

function print_success() {
    echo "✓ $1"
}

function print_info() {
    echo "ℹ $1"
}

function displayUsage() {
    cat << EOF
Usage: $0 [options]

This script sets up your personal BXE environment.

Options:
  --install-type <type>   Install type: chipyard|firesim (default: chipyard)
  --install-path <path>   Installation path (default: ~/chipyard or ~/firesim)
  --skip-install          Skip Chipyard/FireSim installation (just setup config)

Examples:
  # Default: Install Chipyard to ~/chipyard
  $0

  # Install standalone FireSim
  $0 --install-type firesim

  # Install to custom path
  $0 --install-type chipyard --install-path ~/my-chipyard

  # Just setup BXE config, skip installation
  $0 --skip-install

EOF
}

# Defaults
INSTALL_TYPE="chipyard"
INSTALL_PATH=""
SKIP_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-type)
            INSTALL_TYPE="$2"
            shift 2
            ;;
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --skip-install)
            SKIP_INSTALL=true
            shift
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

# Set default install path
if [ -z "$INSTALL_PATH" ]; then
    if [ "$INSTALL_TYPE" = "chipyard" ]; then
        INSTALL_PATH="${HOME}/chipyard"
    else
        INSTALL_PATH="${HOME}/firesim"
    fi
fi

print_header "BXE First Login Setup for $(whoami)"

echo ""
echo "Configuration:"
echo "  User:          $(whoami)"
echo "  Install Type:  $INSTALL_TYPE"
echo "  Install Path:  $INSTALL_PATH"
echo "  Skip Install:  $SKIP_INSTALL"
echo ""

# Check if already set up
if [ -f "${HOME}/.bxe/bxe-firesim.sh" ] && [ "$SKIP_INSTALL" = false ]; then
    echo "⚠ Warning: BXE configuration already exists at ~/.bxe/"
    read -p "Do you want to continue and reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting without changes."
        exit 0
    fi
fi

# Verify bxe-utilities exists
if [ ! -d "${SCRIPT_DIR}" ]; then
    echo "Error: bxe-utilities directory not found."
    echo "Expected at: ${SCRIPT_DIR}"
    exit 1
fi

# Verify Conda is available
print_info "Checking for Conda installation..."
if ! command -v conda &> /dev/null; then
    # Try to source conda
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        source /opt/conda/etc/profile.d/conda.sh
    elif [ -f "${HOME}/.conda/etc/profile.d/conda.sh" ]; then
        source "${HOME}/.conda/etc/profile.d/conda.sh"
    else
        echo "Error: Conda not found. setupBXE.sh may not have been run."
        echo "Contact your system administrator."
        exit 1
    fi
fi
print_success "Conda found"

# Verify /tools is mounted
print_info "Checking /tools mount..."
if ! mountpoint -q /tools; then
    echo "Warning: /tools is not mounted"
    echo "This is needed for Xilinx Vitis tools."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
else
    print_success "/tools is mounted"
fi

# Run installBXE.sh
if [ "$SKIP_INSTALL" = false ]; then
    print_header "Running installBXE.sh"
    echo ""
    echo "This will take 30-60 minutes to complete."
    echo "The script will:"
    echo "  1. Create ~/.bxe/ configuration directory"
    echo "  2. Clone $INSTALL_TYPE from GitHub"
    echo "  3. Run build-setup.sh"
    echo "  4. Configure your environment"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."

    cd "${SCRIPT_DIR}"
    if ./installBXE.sh "$INSTALL_TYPE" "$INSTALL_PATH"; then
        print_success "installBXE.sh completed successfully!"
    else
        echo "Error: installBXE.sh failed"
        exit 1
    fi
else
    print_info "Skipping installation (--skip-install specified)"

    # Just create BXE config without installation
    cd "${SCRIPT_DIR}"
    mkdir -p "${HOME}/.bxe"
    cp managers/* "${HOME}/.bxe/."

    # Update .bashrc
    BXE_SED_STRING="source \"${HOME}/.bxe/bxe-firesim.sh\""
    if ! grep -q "${BXE_SED_STRING}" "${HOME}/.bashrc"; then
        echo "" >> "${HOME}/.bashrc"
        echo "# BXE Environment" >> "${HOME}/.bashrc"
        echo "${BXE_SED_STRING}" >> "${HOME}/.bashrc"
    fi

    print_success "BXE configuration created"
fi

print_header "Setup Complete!"

echo ""
echo "Next steps:"
echo ""
if [ "$SKIP_INSTALL" = false ]; then
    echo "1. Load your environment:"
    echo "   source ~/.bxe/bxe-firesim.sh"
    echo ""
    echo "2. Navigate to your installation:"
    echo "   cd $INSTALL_PATH"
    if [ "$INSTALL_TYPE" = "chipyard" ]; then
        echo "   cd sims/firesim"
    fi
    echo ""
    echo "3. Start using FireSim:"
    echo "   firesim --help"
else
    echo "1. Run installBXE.sh when ready:"
    echo "   cd ${SCRIPT_DIR}"
    echo "   ./installBXE.sh chipyard ~/chipyard"
fi
echo ""
echo "For help, see: ${SCRIPT_DIR}/DEPLOYMENT_GUIDE.md"
echo ""

exit 0
