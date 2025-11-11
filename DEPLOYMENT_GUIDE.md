# BXE VM Deployment Guide

Complete guide for deploying BXE manager VMs using cloud-init and the golden image approach.

## Quick Start (TL;DR)

```bash
# On hypervisor
cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/cloud-init
sudo ./create-bxe-golden.sh

# Wait 2-3 minutes, then SSH into VM
ssh bxeuser@<vm-ip>

# Inside VM - complete BXE setup
cd ~/bxe-utilities
sudo ./setupBXE.sh
./installBXE.sh chipyard ~/chipyard

# After install completes, clean and shutdown
history -c && sudo cloud-init clean --logs --seed && sudo poweroff

# Clone VMs from golden image
cd ../kvm
sudo ./bxe-vm-clone.sh bxe-golden alice-bxe
```

## Detailed Workflow

### Phase 1: Prepare Hypervisor

#### 1.1 Install Required Packages

```bash
sudo apt update
sudo apt install -y virt-install libvirt-daemon-system qemu-kvm \
    cloud-image-utils libvirt-clients libguestfs-tools
```

#### 1.2 Verify /tools is Mounted

```bash
# Ensure your hypervisor has /tools NFS mount
mount | grep /tools
# Should show: vizion.lbl.gov:/mnt/vmpool/nfs/tools on /tools type nfs

# If not mounted, mount it:
sudo mkdir -p /tools
sudo mount vizion.lbl.gov:/mnt/vmpool/nfs/tools /tools

# Add to /etc/fstab for persistence
echo "vizion.lbl.gov:/mnt/vmpool/nfs/tools  /tools  nfs  defaults,timeo=900,retrans=5,_netdev  0  0" | sudo tee -a /etc/fstab
```

#### 1.3 Configure Bridge Network

```bash
# Verify br1 bridge exists
ip link show br1

# If not, create it (example using netplan)
sudo cat > /etc/netplan/01-bridge.yaml << EOF
network:
  version: 2
  ethernets:
    enp1s0:  # Replace with your physical interface
      dhcp4: no
  bridges:
    br1:
      interfaces: [enp1s0]
      dhcp4: yes
EOF

sudo netplan apply
```

---

### Phase 2: Create Golden Image VM

#### 2.1 Customize Cloud-Init Configuration

```bash
cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/cloud-init

# Edit user-data to add your SSH key
vim bxe-user-data.yaml
# Update line 13 with your public SSH key

# Update repository URL if needed
# Update line 36 with your repository URL
```

#### 2.2 Run Golden Image Creation Script

```bash
sudo ./create-bxe-golden.sh
```

**What this does:**
1. Downloads Ubuntu 24.04 cloud image
2. Creates 50GB VM disk
3. Creates VM with cloud-init configuration
4. Adds virtiofs filesystem for /tools
5. Starts the VM

#### 2.3 Wait for Cloud-Init to Complete

```bash
# Monitor VM console (optional)
virsh console bxe-golden
# Press Ctrl+] to exit

# Or watch for cloud-init completion
virsh domifaddr bxe-golden  # Get IP when ready

# Wait ~2-3 minutes for cloud-init to finish
```

#### 2.4 Add virtiofs Configuration

```bash
# Shutdown VM first
virsh shutdown bxe-golden

# Wait for shutdown
virsh list --all | grep bxe-golden

# Edit VM XML
virsh edit bxe-golden
```

Add these sections (see `cloud-init/VM_XML_TEMPLATE.md` for details):

**Before `<devices>`:**
```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

**Inside `<devices>`:**
```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/tools'/>
  <target dir='tools'/>
  <readonly/>
</filesystem>
```

Save and exit, then start VM:
```bash
virsh start bxe-golden
```

---

### Phase 3: Complete BXE Setup Inside VM

#### 3.1 SSH Into Golden VM

```bash
# Get VM IP
virsh domifaddr bxe-golden

# SSH in
ssh bxeuser@<vm-ip>
```

#### 3.2 Verify Virtiofs Mount

```bash
# Check /tools is mounted
mount | grep /tools
# Expected: tools on /tools type virtiofs (ro,relatime)

# Verify Vitis tools exist
ls /tools/source-vitis-2023.1.sh
```

#### 3.3 Run setupBXE.sh

```bash
cd ~/bxe-utilities
sudo ./setupBXE.sh
```

**This installs:**
- OS packages (openssh-server, libguestfs-tools, git, build-essential, etc.)
- VNC/XRDP for remote desktop
- FireSim prerequisites
- Conda/Miniforge to `/opt/conda`
- Virtiofs mount configuration for `/tools` (adds to /etc/fstab)
- BXE scripts to `/opt/bxe`
- firesim-guestmount systemd service

#### 3.4 Run installBXE.sh

```bash
./installBXE.sh chipyard ~/chipyard
```

**This will:**
- Clone Chipyard from GitHub
- Run `build-setup.sh` (takes 30-60 minutes)
- Configure environment in `~/.bxe/bxe-firesim.sh`
- Copy YAML configs to FireSim deploy directory
- Add BXE profile to `.bashrc`

**Wait for completion** - go get coffee, this takes a while.

#### 3.5 Verify Installation

```bash
# Source environment
source ~/.bxe/bxe-firesim.sh

# Verify Chipyard
cd ~/chipyard
ls

# Verify FireSim
cd sims/firesim
firesim --help
```

#### 3.6 Clean Up for Golden Image

```bash
# Clear bash history
history -c

# Clean cloud-init
sudo cloud-init clean --logs --seed

# Clean apt cache
sudo apt clean

# Optional: Zero out free space to reduce image size
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY

# Shutdown
sudo poweroff
```

---

### Phase 4: Clone VMs from Golden Image

#### 4.1 Clone VMs

```bash
# On hypervisor
cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/kvm

# Clone for each user
sudo ./bxe-vm-clone.sh bxe-golden alice-bxe
sudo ./bxe-vm-clone.sh bxe-golden bob-bxe
sudo ./bxe-vm-clone.sh bxe-golden charlie-bxe
```

**What bxe-vm-clone.sh does:**
- Uses `virt-clone` to duplicate disk and VM definition
- Runs `virt-sysprep` to:
  - Regenerate SSH host keys
  - Update hostname
  - Keep user account (bxeuser)
  - Enable serial console
  - Copy updated BXE scripts

#### 4.2 Start Cloned VMs

```bash
virsh start alice-bxe
virsh start bob-bxe
virsh start charlie-bxe
```

#### 4.3 Verify Cloned VMs

```bash
# Get IP addresses
virsh domifaddr alice-bxe
virsh domifaddr bob-bxe

# SSH into cloned VMs
ssh bxeuser@<alice-ip>

# Inside cloned VM, verify:
# 1. Environment loads
source ~/.bxe/bxe-firesim.sh

# 2. /tools is mounted
mount | grep /tools

# 3. Chipyard works
cd ~/chipyard/sims/firesim
firesim --help
```

---

## Post-Deployment Configuration

### Per-User Customization

Each cloned VM may need:

#### 1. SSH Keys for FireSim

```bash
# Generate FireSim SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/firesim.pem -N ""

# Copy to authorized_keys if needed
cat ~/.ssh/firesim.pem.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 2. Update FireSim Configs

```bash
cd ~/chipyard/sims/firesim

# Edit build farm config
vim deploy/config_build.yaml

# Edit runtime config
vim deploy/config_runtime.yaml
```

#### 3. Test FireSim

```bash
# Source environment
source ~/.bxe/bxe-firesim.sh

# Initialize FireSim manager
firesim managerinit

# Run a simple build test (optional)
cd ~/chipyard/sims/firesim
firesim buildbitstream
```

---

## Directory Structure

After complete deployment, each VM will have:

```
/opt/
├── conda/                          # System-wide Conda installation
└── bxe/                            # BXE system scripts
    ├── firesim-guestmount.service
    ├── firesim-guestmount.sh
    └── regenSSHKey.sh

/home/bxeuser/
├── bxe-utilities/                  # This repository
│   ├── setupBXE.sh
│   ├── installBXE.sh
│   ├── cloud-init/
│   ├── kvm/
│   └── managers/
├── chipyard/                       # Chipyard installation
│   ├── sims/firesim/               # FireSim (embedded)
│   │   └── deploy/
│   │       ├── config_build.yaml
│   │       └── config_runtime.yaml
│   └── software/firemarshal/
└── .bxe/                           # BXE user configuration
    ├── bxe-firesim.sh              # Environment setup script
    ├── config_build.yaml
    └── config_runtime.yaml

/tools/                             # Mounted via virtiofs (read-only)
└── source-vitis-2023.1.sh          # Xilinx Vitis tools
```

---

## Troubleshooting

### Cloud-Init Issues

**VM doesn't get IP address:**
```bash
# Check cloud-init status
virsh console bxe-golden
# Login with default ubuntu/ubuntu if needed
cloud-init status --wait
```

**Can't SSH with key:**
```bash
# Verify SSH key was added to cloud-init config
cat cloud-init/bxe-user-data.yaml | grep ssh-rsa

# Try password auth first (if enabled in cloud-init)
ssh bxeuser@<vm-ip>
```

### Virtiofs Issues

**/tools not mounted:**
```bash
# Inside VM
mount | grep tools
# If empty:

# Check fstab
cat /etc/fstab | grep tools

# Try manual mount
sudo mount /tools

# If fails, check VM XML has filesystem device
# On hypervisor:
virsh dumpxml bxe-golden | grep filesystem
```

**Permission denied in /tools:**
```bash
# On hypervisor, verify /tools exists and is readable
ls -la /tools

# Verify virtiofs uses passthrough mode
virsh dumpxml bxe-golden | grep -A 3 filesystem
# Should show: accessmode='passthrough'
```

### Installation Issues

**setupBXE.sh fails:**
```bash
# Check you ran with sudo
sudo ./setupBXE.sh

# Check internet connectivity
ping -c 3 google.com

# Check disk space
df -h
```

**installBXE.sh fails during build-setup.sh:**
```bash
# Check available memory
free -h
# Need at least 8GB, recommend 16GB+

# Check disk space
df -h ~/chipyard
# Need at least 30GB free

# Check logs
tail -f ~/chipyard/build-setup.log
```

**Chipyard clone is slow:**
```bash
# Use shallow clone if network is slow
cd ~
git clone --depth 1 https://github.com/ucb-bar/chipyard
cd chipyard
./build-setup.sh
```

### VM Cloning Issues

**virt-clone fails:**
```bash
# Check VM is shut down
virsh list --all | grep bxe-golden
# Should show "shut off"

# If running, shut down:
virsh shutdown bxe-golden
```

**virt-sysprep fails:**
```bash
# Check libguestfs is installed
dpkg -l | grep libguestfs

# If missing:
sudo apt install libguestfs-tools
```

---

## Performance Optimization

### Hypervisor Level

```bash
# Enable KSM (Kernel Same-page Merging) for memory deduplication
echo 1 | sudo tee /sys/kernel/mm/ksm/run

# Adjust VM CPU pinning for dedicated cores
virsh vcpupin bxe-golden 0 4
virsh vcpupin bxe-golden 1 5
# etc.
```

### VM Level

```bash
# Inside VM - enable hugepages for better memory performance
echo "vm.nr_hugepages=1024" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## Maintenance

### Update Golden Image

When you need to update all VMs:

```bash
# 1. Start golden image
virsh start bxe-golden

# 2. SSH in and update
ssh bxeuser@<golden-ip>
cd ~/bxe-utilities
git pull
sudo ./setupBXE.sh  # If needed
./installBXE.sh bxe ~/chipyard/sims/firesim  # Update configs only

# 3. Clean and shutdown
history -c && sudo cloud-init clean --logs --seed && sudo poweroff

# 4. Re-clone VMs
sudo ./kvm/bxe-vm-clone.sh bxe-golden alice-bxe-v2
```

### Backup Strategy

```bash
# Export VM definition
virsh dumpxml bxe-golden > bxe-golden.xml

# Backup VM disk
cp /var/lib/libvirt/images/bxe-golden.qcow2 /backups/

# Or create snapshot
virsh snapshot-create-as bxe-golden snapshot1 "Before update"
```

---

## Summary

**Golden Image Workflow:**
```
1. Hypervisor prep (NFS mount, bridge network)
   ↓
2. Create golden VM with cloud-init
   ↓
3. Add virtiofs configuration
   ↓
4. Run setupBXE.sh + installBXE.sh
   ↓
5. Clean and shutdown
   ↓
6. Clone VMs with bxe-vm-clone.sh
   ↓
7. Per-VM customization (SSH keys, configs)
```

**Time Investment:**
- One-time setup: ~90 minutes (golden image creation)
- Per-clone: ~2 minutes (automated)

**Benefits:**
- Consistent environment across all VMs
- Fast deployment (2 min vs 90 min per VM)
- Single /tools NFS mount (at hypervisor)
- Easy updates (update golden, re-clone)
