# BXE User Workflow

## Overview

This document describes the simplified workflow for BXE VMs where users run `installBXE.sh` from `/opt/bxe`.

## Design Principles

1. **No git repository needed in VMs** - Scripts are copied to `/opt/bxe` during setup
2. **Per-user installations** - Each user runs `installBXE.sh` to get their own Chipyard/FireSim
3. **Shared system setup** - Golden image has all OS-level dependencies pre-installed
4. **DHCP-based networking** - VMs get IP addresses automatically from network DHCP

## Architecture

```
Hypervisor
├── /tools (NFS mount from network)
│   └── Shared across all VMs via virtiofs
│
├── Golden Image VM (bxe-golden) [shut off]
│   ├── /opt/bxe/ (system-wide scripts)
│   │   ├── installBXE.sh ← Users run this
│   │   ├── managers/ (config templates)
│   │   ├── firesim-guestmount.sh
│   │   └── other system scripts
│   ├── /opt/conda/ (system-wide Conda)
│   └── /tools → virtiofs mount (read-only)
│
└── Cloned VMs (alice-vm, bob-vm, ...)
    └── Each user:
        ├── Runs: /opt/bxe/installBXE.sh chipyard ~/chipyard
        ├── Gets: ~/chipyard/ (personal installation)
        └── Gets: ~/.bxe/ (personal config)
```

## Admin Workflow (One-Time Setup)

### Step 1: Create Golden Image

```bash
cd /path/to/bxe-utilities

# Create golden image with system setup only (no per-user installation)
sudo ./orchestrate-bxe.sh create-golden \
  --ssh-key ~/.ssh/id_rsa.pub \
  --no-setup

# This takes ~5 minutes and creates a VM with:
# - Ubuntu 24.04
# - OS packages installed
# - Conda installed at /opt/conda
# - Scripts copied to /opt/bxe/
# - /tools virtiofs configured
```

**OR** if you want to test the full installation in golden image first:

```bash
# Create golden image WITH full Chipyard installation (for testing)
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub

# This takes ~90 minutes but validates everything works
```

### Step 2: Clone VMs for Users

```bash
# Clone VMs from golden image
sudo ./orchestrate-bxe.sh clone --count 5
# Creates: bxe-1, bxe-2, bxe-3, bxe-4, bxe-5

# OR clone with specific names
sudo ./orchestrate-bxe.sh clone --targets alice-vm,bob-vm,charlie-vm
```

### Step 3: Inform Users

Give users the VM IP addresses:

```bash
sudo ./orchestrate-bxe.sh status
```

Output:
```
Running VMs with IP addresses:
  alice-vm             192.168.1.101
  bob-vm               192.168.1.102
  charlie-vm           192.168.1.103
```

## User Workflow (First Login)

### Step 1: SSH into VM

```bash
# User receives VM IP from admin
ssh bxeuser@192.168.1.101
```

### Step 2: Read Welcome Message

```bash
cat ~/README.txt
```

Shows:
```
Welcome to BXE!

To set up your personal Chipyard/FireSim environment, run:

  /opt/bxe/installBXE.sh chipyard ~/chipyard

This will:
  1. Clone Chipyard from GitHub to your home directory
  2. Run build-setup.sh (takes 30-60 minutes)
  3. Configure your environment in ~/.bxe/

After installation completes:
  source ~/.bxe/bxe-firesim.sh
  cd ~/chipyard/sims/firesim
  firesim --help

For more options:
  /opt/bxe/installBXE.sh --help
```

### Step 3: Run installBXE.sh

```bash
# Install Chipyard (default)
/opt/bxe/installBXE.sh chipyard ~/chipyard

# OR install standalone FireSim
/opt/bxe/installBXE.sh firesim ~/firesim

# OR install to custom path
/opt/bxe/installBXE.sh chipyard ~/my-custom-path
```

**This takes 30-60 minutes** - go get coffee!

### Step 4: Use FireSim

```bash
# Load environment (auto-added to ~/.bashrc)
source ~/.bxe/bxe-firesim.sh

# Navigate to FireSim
cd ~/chipyard/sims/firesim

# Use FireSim
firesim --help
firesim managerinit
```

## What's in /opt/bxe/?

```
/opt/bxe/
├── installBXE.sh              ← Main script users run
├── managers/                   ← Config templates
│   ├── bxe-firesim.sh         (environment template)
│   ├── config_build.yaml      (build farm config)
│   └── config_runtime.yaml    (runtime config)
├── firesim-guestmount.sh      ← System script
├── firesim-guestmount.service ← Systemd service
└── regenSSHKey.sh             ← SSH key regeneration
```

## How It Works

### During Golden Image Creation

1. **virt-customize** injects bxe-utilities repo into `/tmp/bxe-utilities`
2. **Cloud-init** creates `bxeuser` account with SSH key
3. **setupBXE.sh** (called by orchestration):
   - Installs OS packages
   - Installs Conda to `/opt/conda`
   - **Copies scripts to `/opt/bxe/`** from `/tmp/bxe-utilities`
   - Configures virtiofs for `/tools`
   - Sets up systemd services

### When User Runs /opt/bxe/installBXE.sh

1. Creates `~/.bxe/` directory
2. Copies config templates from `/opt/bxe/managers/` to `~/.bxe/`
3. Clones Chipyard or FireSim from GitHub to user's home
4. Runs `build-setup.sh` (installs toolchains, dependencies)
5. Updates `~/.bxe/bxe-firesim.sh` with installation paths
6. Copies YAML configs to FireSim deploy directory
7. Adds `source ~/.bxe/bxe-firesim.sh` to `~/.bashrc`

## Multi-User Isolation

Each user gets:
- **Own home directory** with full Chipyard/FireSim installation
- **Own `~/.bxe/` config** directory
- **Own Conda environments** (created by build-setup.sh)
- **Own build artifacts** and simulation results

Shared resources:
- **System Conda** installation at `/opt/conda`
- **OS packages** installed system-wide
- **/tools** directory (Xilinx Vitis) - read-only via virtiofs
- **Scripts** at `/opt/bxe/`
- **FireSim group membership** - controls sudo access

## FireSim Group Benefits

The `firesim` group provides a clean way to manage user permissions:

**What it provides:**
- Sudo access without password (`NOPASSWD:ALL`)
- Configured via `/etc/sudoers.d/90-firesim-group`
- Created automatically during cloud-init

**Adding users to firesim group:**
```bash
# Add existing user to firesim group
sudo usermod -aG firesim alice

# Verify membership
groups alice
# Output: alice : alice firesim

# User needs to re-login for group membership to take effect
```

**Why use a group instead of per-user sudo rules?**
- ✅ Centralized management (one sudo rule for all FireSim users)
- ✅ Easy to add/remove users
- ✅ Clear separation: firesim users vs regular users
- ✅ Follows principle of least privilege

## Networking

- **DHCP-based**: VMs get IP addresses from your network's DHCP server
- **Bridge networking**: VMs are on `br1` bridge (configured in orchestration)
- **No static IPs**: IPs may change on reboot (use hostname or check `orchestrate-bxe.sh status`)
- **Login node visibility**: As long as login node is on same network/VLAN, it can see VMs

## SSH Key Setup

- **Admin SSH key**: Added to `bxeuser` account during cloud-init
  - Used for: Admin access, orchestration scripts
  - Location: `~/.ssh/authorized_keys` for bxeuser

- **Password authentication**: **DISABLED by default** (`ssh_pwauth: false` in cloud-init)
  - This is a **system-wide** setting affecting ALL users
  - All users must use SSH key authentication
  - To enable password login, change `ssh_pwauth: true` in `cloud-init/bxe-user-data.yaml` before creating golden image

- **FireSim group**: Users who need FireSim access should be added to the `firesim` group
  - Members of `firesim` group have sudo access without password (via `/etc/sudoers.d/90-firesim-group`)
  - `bxeuser` is automatically added to `firesim` group during cloud-init

- **Users**: Currently all use `bxeuser` account
  - If you need per-user accounts, create them after VM cloning:
    ```bash
    # On each VM
    sudo adduser alice

    # Add alice to firesim group (gives sudo NOPASSWD access)
    sudo usermod -aG firesim alice

    # Add alice's SSH public key (required since password auth is disabled)
    sudo mkdir -p /home/alice/.ssh
    sudo vim /home/alice/.ssh/authorized_keys  # Paste alice's public key
    sudo chown -R alice:alice /home/alice/.ssh
    sudo chmod 700 /home/alice/.ssh
    sudo chmod 600 /home/alice/.ssh/authorized_keys

    # Then alice can SSH in and run:
    # /opt/bxe/installBXE.sh chipyard ~/chipyard
    ```

## Troubleshooting

### "Permission denied (publickey)" when SSH'ing

**Cause:** SSH key not added to VM, and password auth is disabled.

**Fix:**
```bash
# Option 1: Add your SSH key to cloud-init BEFORE creating golden image
# Edit cloud-init/bxe-user-data.yaml line 15 with your public key

# Option 2: Enable password authentication
# Edit cloud-init/bxe-user-data.yaml:
# Change: ssh_pwauth: false
# To:     ssh_pwauth: true

# Option 3: Add key to existing VM via console
virsh console <vm-name>
# Login as bxeuser (if you can)
# Then: echo "ssh-rsa YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
```

### "installBXE.sh: command not found"

```bash
# Use full path
/opt/bxe/installBXE.sh chipyard ~/chipyard
```

### "Conda not found" during installBXE.sh

```bash
# Source conda manually
source /opt/conda/etc/profile.d/conda.sh

# Then retry
/opt/bxe/installBXE.sh chipyard ~/chipyard
```

### "/tools not mounted" warning

```bash
# Check if mounted
mount | grep /tools

# If not mounted, contact admin
# The VM needs virtiofs configured in its XML
```

### "Directory exists, cannot override"

```bash
# installBXE.sh won't overwrite existing installations
# Either:
# 1. Remove old installation
rm -rf ~/chipyard

# 2. Install to different path
/opt/bxe/installBXE.sh chipyard ~/chipyard-v2

# 3. Update configs only
/opt/bxe/installBXE.sh bxe ~/chipyard/sims/firesim
```

### "sudo: a password is required" or permission denied

**Cause:** User is not in the `firesim` group.

**Fix:**
```bash
# Check current group membership
groups
# If 'firesim' is not listed:

# Have an admin add you to the group
sudo usermod -aG firesim $USER

# Log out and log back in for group membership to take effect
exit
# Then SSH back in

# Verify
groups
# Should now show: username : username firesim

# Test sudo
sudo whoami
# Should work without asking for password
```

## Summary

**Admin (one-time):**
```bash
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub --no-setup
sudo ./orchestrate-bxe.sh clone --count 5
```

**User (first login):**
```bash
ssh bxeuser@<vm-ip>
/opt/bxe/installBXE.sh chipyard ~/chipyard
source ~/.bxe/bxe-firesim.sh
cd ~/chipyard/sims/firesim
```

**Result:**
- No git repository needed in VMs
- Each user has isolated installation
- Simple, clean workflow
- Uses existing `installBXE.sh` script as-is
