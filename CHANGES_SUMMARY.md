# BXE Utilities - Recent Changes Summary

## Overview of Changes

This document summarizes the recent updates to the BXE utilities for VM deployment and user management.

---

## 1. FireSim Group-Based Access Control

### What Changed

**Before:**
- Only `bxeuser` had sudo NOPASSWD access (configured per-user)
- No group-based access control

**After:**
- Created `firesim` group for all FireSim users
- All members of `firesim` group get sudo NOPASSWD access
- `bxeuser` automatically added to `firesim` group during cloud-init

### Implementation

**Cloud-init config (`cloud-init/bxe-user-data.yaml`):**

```yaml
# Create firesim group
groups:
  - firesim

# Add bxeuser to firesim group
users:
  - name: bxeuser
    groups: [sudo, firesim]

# Sudo rule for firesim group
write_files:
  - path: /etc/sudoers.d/90-firesim-group
    permissions: '0440'
    content: |
      # Allow members of firesim group to run all commands without password
      %firesim ALL=(ALL) NOPASSWD:ALL
```

### Benefits

- ✅ Centralized permission management
- ✅ Easy to add new users: `sudo usermod -aG firesim alice`
- ✅ Clear separation of FireSim users vs regular users
- ✅ Follows principle of least privilege

### Usage

```bash
# Add user to firesim group (as admin)
sudo usermod -aG firesim alice

# Verify
groups alice
# Output: alice : alice firesim

# User logs out and back in
# Now alice has sudo without password
```

---

## 2. Flexible Network Interface Configuration

### What Changed

**Before:**
```yaml
ethernets:
  enp1s0:  # Hardcoded interface name
    dhcp4: true
```

**After:**
```yaml
ethernets:
  all-ethernet:
    match:
      name: "en*"  # Match any interface starting with "en"
    dhcp4: true
```

### Benefits

- ✅ Works with any interface name: `enp1s0`, `ens3`, `enp2s0`, etc.
- ✅ More portable across different VM configurations
- ✅ No need to know exact interface name beforehand

---

## 3. Scripts Copied to /opt/bxe (No Git Clone Needed)

### What Changed

**Before:**
- Cloud-init cloned git repository into each VM
- Users ran scripts from `~/bxe-utilities/`

**After:**
- Scripts injected via `virt-customize` during golden image creation
- `setupBXE.sh` copies scripts to `/opt/bxe/`
- Users run `/opt/bxe/installBXE.sh` directly
- No git repository needed in VMs

### Implementation Flow

```
1. virt-customize injects repo → /tmp/bxe-utilities
2. setupBXE.sh runs from /tmp/bxe-utilities
3. setupBXE.sh copies files → /opt/bxe/
   ├── installBXE.sh
   └── managers/ (config templates)
4. Users run: /opt/bxe/installBXE.sh chipyard ~/chipyard
```

### Benefits

- ✅ No git dependency in VMs
- ✅ Cleaner VM images
- ✅ Scripts always available system-wide
- ✅ Users don't need to know about repository

---

## 4. Enhanced Documentation

### New Files

1. **USER_WORKFLOW.md** - Complete user and admin workflow
2. **ORCHESTRATION.md** - Orchestration script documentation
3. **QUICK_DEPLOY.md** - Quick reference guide
4. **DEPLOYMENT_GUIDE.md** - Detailed deployment guide
5. **MULTI_USER_WORKFLOW.md** - Multi-user setup guide

### Updated Files

1. **cloud-init/bxe-user-data.yaml** - FireSim group, welcome message
2. **cloud-init/bxe-network-config.yaml** - Flexible interface matching
3. **setupBXE.sh** - Copy scripts to /opt/bxe, virtiofs setup
4. **orchestrate-bxe.sh** - Full automation script

---

## 5. SSH Authentication Clarifications

### Current Configuration

**Password authentication: DISABLED** (`ssh_pwauth: false`)

This is a **system-wide** setting affecting all users:
- `bxeuser` - requires SSH key
- Any users created later - also require SSH keys
- Cannot login with passwords

### To Enable Password Auth

Edit `cloud-init/bxe-user-data.yaml`:

```yaml
# Change this:
ssh_pwauth: false

# To this:
ssh_pwauth: true
```

Then recreate golden image.

---

## 6. DHCP and IP Address Handling

### Clarification

- VMs use **DHCP** to get IP addresses from your network
- No static IP configuration needed
- `orchestrate-bxe.sh status` shows current IPs
- `virsh domifaddr <vm-name>` also shows IPs

### Works with

- libvirt's built-in DHCP
- External DHCP servers on your network
- Any DHCP configuration

---

## Summary of Files Modified

### Cloud-Init Configuration
- `cloud-init/bxe-user-data.yaml` - FireSim group, sudo rules, no git clone
- `cloud-init/bxe-network-config.yaml` - Flexible interface matching
- `cloud-init/create-bxe-golden.sh` - Inject scripts with virt-customize

### System Setup
- `setupBXE.sh` - Copy scripts to /opt/bxe, virtiofs configuration

### Orchestration
- `orchestrate-bxe.sh` - Run setupBXE from /tmp/bxe-utilities, use /opt/bxe/installBXE.sh

### Documentation
- `USER_WORKFLOW.md` - FireSim group docs, multi-user setup
- `ORCHESTRATION.md` - Complete orchestration guide
- `DEPLOYMENT_GUIDE.md` - End-to-end deployment
- `QUICK_DEPLOY.md` - Quick reference
- `CHANGES_SUMMARY.md` - This file

---

## Migration Guide

### If You Have Existing VMs

**Option 1: Recreate from scratch (recommended)**

```bash
# Create new golden image with updated config
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub --no-setup

# Clone new VMs
sudo ./orchestrate-bxe.sh clone --count 5
```

**Option 2: Update existing VMs manually**

```bash
# On each existing VM:

# 1. Create firesim group
sudo groupadd firesim

# 2. Add bxeuser to group
sudo usermod -aG firesim bxeuser

# 3. Create sudo rule
sudo tee /etc/sudoers.d/90-firesim-group << 'EOF'
# Allow members of firesim group to run all commands without password
%firesim ALL=(ALL) NOPASSWD:ALL
EOF

sudo chmod 0440 /etc/sudoers.d/90-firesim-group

# 4. Copy scripts to /opt/bxe
sudo mkdir -p /opt/bxe/managers
sudo cp ~/bxe-utilities/installBXE.sh /opt/bxe/
sudo cp ~/bxe-utilities/managers/* /opt/bxe/managers/
sudo chmod +x /opt/bxe/installBXE.sh
```

---

## Testing Checklist

After deploying with new configuration, verify:

- [ ] `firesim` group exists: `getent group firesim`
- [ ] `bxeuser` is in firesim group: `groups bxeuser`
- [ ] Sudo works without password: `sudo whoami`
- [ ] `/etc/sudoers.d/90-firesim-group` exists with correct permissions (0440)
- [ ] Scripts exist in `/opt/bxe/`: `ls -la /opt/bxe/`
- [ ] Network uses DHCP: `ip addr show`
- [ ] New users can be added to firesim group: `sudo usermod -aG firesim testuser`

---

## Key Commands

### Admin Commands

```bash
# Create golden image (system setup only)
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub --no-setup

# Clone VMs
sudo ./orchestrate-bxe.sh clone --count 5

# Check status
sudo ./orchestrate-bxe.sh status

# Add user to firesim group
sudo usermod -aG firesim alice
```

### User Commands

```bash
# First login - install Chipyard
/opt/bxe/installBXE.sh chipyard ~/chipyard

# Load environment
source ~/.bxe/bxe-firesim.sh

# Use FireSim
cd ~/chipyard/sims/firesim
firesim --help
```

---

## Questions or Issues?

See documentation:
- **USER_WORKFLOW.md** - Complete workflow guide
- **ORCHESTRATION.md** - Automation details
- **DEPLOYMENT_GUIDE.md** - Step-by-step deployment

For troubleshooting, see the "Troubleshooting" section in USER_WORKFLOW.md.
