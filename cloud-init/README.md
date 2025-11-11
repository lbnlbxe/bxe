# Cloud-Init Configuration for BXE VMs

This directory contains cloud-init configuration files for automated BXE VM deployment.

## Files

- **bxe-user-data.yaml**: Main cloud-init configuration (users, packages, setup)
- **bxe-network-config.yaml**: Network configuration (optional - can use defaults)
- **create-bxe-golden.sh**: Helper script to create golden image VM

## Quick Start

### Prerequisites

```bash
# On your KVM hypervisor
sudo apt install virt-install libvirt-daemon-system qemu-kvm cloud-image-utils

# Download Ubuntu 24.04 cloud image
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### Create Golden Image VM

**Option 1: Use the helper script**

```bash
cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/cloud-init
sudo ./create-bxe-golden.sh
```

**Option 2: Manual creation**

```bash
# 1. Create a working copy of the cloud image
cp noble-server-cloudimg-amd64.img bxe-golden.qcow2
qemu-img resize bxe-golden.qcow2 50G

# 2. Create VM with cloud-init
virt-install \
  --name bxe-golden \
  --memory 16384 \
  --vcpus 8 \
  --disk bxe-golden.qcow2,format=qcow2,bus=virtio \
  --import \
  --cloud-init user-data=bxe-user-data.yaml,network-config=bxe-network-config.yaml \
  --network bridge=br1,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --osinfo ubuntu24.04 \
  --noautoconsole

# 3. Wait for cloud-init to complete (~2-3 minutes)
# Watch logs:
virsh console bxe-golden  # Ctrl+] to exit

# 4. SSH into VM
ssh bxeuser@<vm-ip>
```

### Complete BXE Setup

Once cloud-init finishes and you're logged into the VM:

```bash
# 1. Run setupBXE.sh (installs OS packages, Conda, virtiofs mount)
cd ~/bxe-utilities
sudo ./setupBXE.sh

# 2. Install Chipyard/FireSim
./installBXE.sh chipyard ~/chipyard

# 3. Wait for build-setup.sh to complete (~30-60 min)

# 4. Clean up for template creation
history -c
sudo cloud-init clean --logs --seed
sudo apt clean
sudo poweroff
```

### Clone VMs from Golden Image

```bash
# On hypervisor
cd /home/ffard/Documents/git/socks/ffard/bxe-utilities/kvm

# Clone for users
sudo ./bxe-vm-clone.sh bxe-golden alice-bxe
sudo ./bxe-vm-clone.sh bxe-golden bob-bxe

# Start VMs
virsh start alice-bxe
virsh start bob-bxe
```

## Customization

### Update User SSH Keys

Edit `bxe-user-data.yaml` line 13:

```yaml
ssh_authorized_keys:
  - ssh-rsa YOUR_PUBLIC_KEY_HERE user@hostname
```

### Change Default User

Edit `bxe-user-data.yaml` line 7:

```yaml
users:
  - name: youruser  # Change from bxeuser
```

### Add Repository URL

Edit `bxe-user-data.yaml` line 36 to point to your repository:

```yaml
- sudo -u bxeuser git clone https://github.com/YOUR_ORG/bxe-utilities /home/bxeuser/bxe-utilities
```

### Adjust Network Interface

If your VMs use a different network interface name (not `enp1s0`), edit `bxe-network-config.yaml`:

```bash
# Find your interface name in a test VM:
ip link show

# Update bxe-network-config.yaml accordingly
```

## VM XML Configuration for virtiofs

After creating the golden image, add virtiofs filesystem sharing:

```bash
virsh edit bxe-golden
```

Add this section inside `<devices>`:

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/tools'/>
  <target dir='tools'/>
  <readonly/>
</filesystem>
```

And add this before `<devices>`:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

## Troubleshooting

### Cloud-init not running

```bash
# Check cloud-init status
cloud-init status --wait

# View logs
sudo cat /var/log/cloud-init.log
sudo cloud-init query -a  # Show all cloud-init data
```

### Can't SSH into VM

```bash
# Check VM IP address
virsh domifaddr bxe-golden

# Access via console
virsh console bxe-golden

# Check SSH service
sudo systemctl status ssh
```

### Wrong network interface name

```bash
# Inside VM, find actual interface
ip link show

# Update network-config.yaml and recreate VM
```

### VM doesn't resize disk

```bash
# Inside VM, check disk size
df -h

# Resize if needed
sudo growpart /dev/vda 1
sudo resize2fs /dev/vda1
```

## Additional Resources

- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [virt-install Manual](https://manpages.ubuntu.com/manpages/noble/man1/virt-install.1.html)
