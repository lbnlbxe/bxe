# BXE VM Orchestration

Complete automation for BXE VM deployment using the `orchestrate-bxe.sh` script.

## Overview

The orchestration script automates the **entire** VM deployment workflow:

```
orchestrate-bxe.sh
    ↓
Creates Golden VM → Adds virtiofs → Runs setupBXE → Runs installBXE → Clones VMs
    ↓
Ready-to-use VMs in ~90 minutes (once) or ~2 minutes (per clone)
```

## Quick Examples

### Fully Automated Golden Image + 3 VMs

```bash
# Single command to deploy everything
sudo ./orchestrate-bxe.sh deploy \
  --ssh-key ~/.ssh/id_rsa.pub \
  --count 3

# This will:
# 1. Create golden image VM
# 2. Configure virtiofs
# 3. Run setupBXE.sh and installBXE.sh (takes ~60 min)
# 4. Clean and shutdown golden image
# 5. Clone 3 VMs: bxe-1, bxe-2, bxe-3
# 6. Start all cloned VMs
# 7. Show status
```

### Just Create Golden Image

```bash
# Fully automated golden image creation
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub

# Create golden image, but skip the setup (do it manually later)
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub --no-setup
```

### Complete Setup on Existing VM

```bash
# If you created VM with --no-setup, complete the setup:
sudo ./orchestrate-bxe.sh setup-golden --name bxe-golden
```

### Clone VMs from Golden Image

```bash
# Clone 5 VMs with auto-generated names (bxe-1, bxe-2, ...)
sudo ./orchestrate-bxe.sh clone --count 5

# Clone specific VMs
sudo ./orchestrate-bxe.sh clone --targets alice-bxe,bob-bxe,charlie-bxe

# Clone with custom prefix
sudo ./orchestrate-bxe.sh clone --count 3 --prefix research
# Creates: research-1, research-2, research-3
```

### Check Status

```bash
sudo ./orchestrate-bxe.sh status
```

## Commands

### `create-golden` - Create Golden Image

Creates a golden VM from scratch with full automation.

**Options:**
- `--name <name>` - Golden VM name (default: bxe-golden)
- `--ssh-key <file>` - SSH public key to add (highly recommended)
- `--bridge <br>` - Network bridge (default: br1)
- `--tools <path>` - Tools path on hypervisor (default: /tools)
- `--no-virtiofs` - Skip virtiofs configuration
- `--no-setup` - Skip setupBXE/installBXE (create VM only)

**What it does:**
1. Updates cloud-init with your SSH key
2. Calls `create-bxe-golden.sh` (downloads cloud image, creates VM)
3. Waits for VM to boot and get IP
4. Adds virtiofs filesystem for /tools
5. Waits for cloud-init to complete
6. SSH into VM and runs `setupBXE.sh`
7. SSH into VM and runs `installBXE.sh` (30-60 min)
8. Cleans up and shuts down VM
9. Golden image ready for cloning

**Example:**
```bash
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub
```

---

### `setup-golden` - Setup Existing Golden VM

Runs setupBXE/installBXE on an existing VM (useful if you used `--no-setup`).

**Options:**
- `--name <name>` - VM name (default: bxe-golden)
- `--install-type <type>` - chipyard or firesim (default: chipyard)
- `--install-path <path>` - Installation path (default: ~/chipyard)

**What it does:**
1. Gets VM IP
2. Waits for SSH
3. Runs `setupBXE.sh` via SSH
4. Runs `installBXE.sh` via SSH
5. Cleans and shuts down

**Example:**
```bash
# Setup with Chipyard (default)
sudo ./orchestrate-bxe.sh setup-golden --name bxe-golden

# Setup with standalone FireSim
sudo ./orchestrate-bxe.sh setup-golden --install-type firesim --install-path ~/firesim
```

---

### `clone` - Clone VMs from Golden Image

Clone one or more VMs from the golden image.

**Options:**
- `--source <name>` - Source VM (default: bxe-golden)
- `--targets <list>` - Comma-separated VM names
- `--count <n>` - Number of VMs to create with auto-names
- `--prefix <prefix>` - Prefix for auto-generated names (default: bxe)

**What it does:**
1. Verifies source VM exists and is shut off
2. Calls `bxe-vm-clone.sh` for each target
3. Starts each cloned VM
4. Shows success/failure summary

**Examples:**
```bash
# Clone 3 VMs: bxe-1, bxe-2, bxe-3
sudo ./orchestrate-bxe.sh clone --count 3

# Clone specific VMs
sudo ./orchestrate-bxe.sh clone --targets alice,bob,charlie

# Clone with custom prefix: dev-1, dev-2
sudo ./orchestrate-bxe.sh clone --count 2 --prefix dev

# Clone from different source
sudo ./orchestrate-bxe.sh clone --source my-golden --targets test-vm-1,test-vm-2
```

---

### `deploy` - Full End-to-End Deployment

Combines `create-golden` and `clone` into a single command.

**Options:**
- Accepts all options from `create-golden` and `clone`

**What it does:**
1. Creates golden image (with all setup)
2. Optionally clones VMs (if --count or --targets specified)
3. Shows final status

**Examples:**
```bash
# Create golden + 5 clones in one command
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count 5

# Create golden + specific VMs
sudo ./orchestrate-bxe.sh deploy \
  --ssh-key ~/.ssh/id_rsa.pub \
  --targets alice-bxe,bob-bxe,charlie-bxe

# Just create golden, no clones
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub
```

---

### `status` - Show VM Status

Shows all BXE VMs and their status.

**Example:**
```bash
sudo ./orchestrate-bxe.sh status
```

**Output:**
```
================================================
  BXE VM Status
================================================

All VMs:
 Id   Name          State
---------------------------------
 -    bxe-golden    shut off
 12   bxe-1         running
 13   bxe-2         running
 14   bxe-3         running

Running VMs with IP addresses:
  bxe-1                192.168.122.45
  bxe-2                192.168.122.46
  bxe-3                192.168.122.47
```

---

## Automation Features

### What's Automated

✅ **Golden Image Creation**
- Downloads Ubuntu cloud image
- Creates VM with cloud-init
- Configures virtiofs XML automatically
- Waits for cloud-init completion
- Runs setupBXE.sh via SSH
- Runs installBXE.sh via SSH
- Cleans and shuts down VM

✅ **VM Cloning**
- Batch cloning support
- Auto-generated VM names
- Automatic startup after clone
- Error handling and retry logic

✅ **SSH Key Management**
- Automatically injects your SSH key into cloud-init
- No password authentication needed

✅ **IP Detection**
- Automatically finds VM IP addresses
- Waits for network configuration

✅ **Error Handling**
- Checks dependencies before starting
- Validates VM states
- Timeouts for long-running operations
- Colored output for easy debugging

✅ **Progress Tracking**
- Clear status messages
- Colored output (green=success, red=error, yellow=warning)
- Step-by-step progress indicators

---

## Advanced Usage

### Parallel Deployment

```bash
# Create golden image in background
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub &

# While that runs, prepare additional resources...
```

### Custom Network Bridge

```bash
sudo ./orchestrate-bxe.sh create-golden \
  --ssh-key ~/.ssh/id_rsa.pub \
  --bridge br0
```

### Skip virtiofs (use NFS instead)

```bash
sudo ./orchestrate-bxe.sh create-golden \
  --ssh-key ~/.ssh/id_rsa.pub \
  --no-virtiofs
```

### Create VM Shell Only (Manual Setup)

```bash
# Create VM but don't run setup scripts
sudo ./orchestrate-bxe.sh create-golden \
  --ssh-key ~/.ssh/id_rsa.pub \
  --no-setup

# Get IP and SSH in manually
sudo ./orchestrate-bxe.sh status
ssh bxeuser@<vm-ip>

# Run setup manually
cd ~/bxe-utilities
sudo ./setupBXE.sh
./installBXE.sh chipyard ~/chipyard
```

---

## Workflow Comparison

### Manual Workflow (Old)

```bash
# 1. Download cloud image manually
wget https://cloud-images.ubuntu.com/.../noble-server-cloudimg-amd64.img

# 2. Create VM
cp noble-server-cloudimg-amd64.img bxe-golden.qcow2
qemu-img resize bxe-golden.qcow2 50G
virt-install --name bxe-golden ... (long command)

# 3. Wait for cloud-init
# ... check console, get IP ...

# 4. Edit VM XML for virtiofs
virsh shutdown bxe-golden
virsh edit bxe-golden
# ... manually edit XML ...
virsh start bxe-golden

# 5. SSH into VM
ssh bxeuser@<vm-ip>

# 6. Run setup
cd ~/bxe-utilities
sudo ./setupBXE.sh
./installBXE.sh chipyard ~/chipyard
# ... wait 60 minutes ...

# 7. Clean up
history -c
sudo cloud-init clean --logs --seed
sudo poweroff

# 8. Clone VMs
sudo ./kvm/bxe-vm-clone.sh bxe-golden vm-1
sudo ./kvm/bxe-vm-clone.sh bxe-golden vm-2
sudo ./kvm/bxe-vm-clone.sh bxe-golden vm-3
virsh start vm-1
virsh start vm-2
virsh start vm-3

# Total time: ~90 minutes + manual work
# Manual steps: ~15 steps
```

### Orchestrated Workflow (New)

```bash
# Single command
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count 3

# Total time: ~90 minutes (fully automated)
# Manual steps: 1 command
```

**Time Savings:**
- First deployment: Same time (~90 min), but **zero manual intervention**
- Additional VMs: ~2 minutes per VM (automated cloning)
- Manual effort: Reduced from ~15 steps to 1 command

---

## Troubleshooting

### Script fails with "Missing dependency"

```bash
# Install required packages
sudo apt install virt-install libvirt-daemon-system qemu-kvm \
  libvirt-clients libguestfs-tools openssh-client
```

### "Timeout waiting for SSH"

**Causes:**
- Cloud-init taking longer than expected
- Network issues
- SSH key not properly configured

**Solutions:**
```bash
# Check VM console
virsh console bxe-golden

# Manually check cloud-init status inside VM
cloud-init status --wait

# Verify SSH key was added
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub
# Make sure the key file exists and is valid

# Increase SSH timeout (edit orchestrate-bxe.sh)
SSH_TIMEOUT=600  # Change from 300 to 600 (10 minutes)
```

### "virtiofs configuration failed"

**Causes:**
- VM doesn't support virtiofs
- /tools directory doesn't exist on hypervisor
- Permissions issue

**Solutions:**
```bash
# Verify /tools exists on hypervisor
ls -la /tools

# Check if virtiofs is supported
qemu-system-x86_64 -device help | grep virtiofs

# Skip virtiofs and use NFS instead
sudo ./orchestrate-bxe.sh create-golden --no-virtiofs
```

### "setupBXE.sh failed"

**Causes:**
- Network connectivity issues
- Disk space issues
- Package repository issues

**Solutions:**
```bash
# Check VM logs
virsh console bxe-golden

# SSH in manually and debug
ssh bxeuser@<vm-ip>
cd ~/bxe-utilities
sudo ./setupBXE.sh  # Run manually to see errors
```

### Clone fails with "VM already exists"

```bash
# Remove existing VM
virsh undefine <vm-name> --remove-all-storage

# Or use different names
sudo ./orchestrate-bxe.sh clone --prefix test --count 3
```

---

## Configuration

### Defaults (edit at top of orchestrate-bxe.sh)

```bash
DEFAULT_GOLDEN_NAME="bxe-golden"    # Golden VM name
DEFAULT_BRIDGE="br1"                 # Network bridge
DEFAULT_TOOLS_PATH="/tools"          # Tools path on hypervisor
SSH_USER="bxeuser"                   # SSH username
SSH_TIMEOUT=300                      # SSH wait timeout (5 min)
```

### Cloud-Init Customization

The orchestration script uses the cloud-init configs in `cloud-init/`:
- `bxe-user-data.yaml` - User data (modified by --ssh-key)
- `bxe-network-config.yaml` - Network config

You can edit these files directly for more customization.

---

## Integration Examples

### With CI/CD

```yaml
# .gitlab-ci.yml
deploy_vms:
  stage: deploy
  script:
    - sudo ./orchestrate-bxe.sh deploy --ssh-key $SSH_PUBLIC_KEY --count 5
```

### With Ansible

```yaml
# ansible-playbook.yml
- name: Deploy BXE VMs
  hosts: hypervisor
  tasks:
    - name: Create golden image
      command: ./orchestrate-bxe.sh create-golden --ssh-key /root/.ssh/id_rsa.pub
      args:
        chdir: /path/to/bxe-utilities

    - name: Clone VMs
      command: ./orchestrate-bxe.sh clone --count {{ vm_count }}
      args:
        chdir: /path/to/bxe-utilities
```

### With Terraform

```hcl
# main.tf
resource "null_resource" "bxe_deploy" {
  provisioner "local-exec" {
    command = "sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count ${var.vm_count}"
    working_dir = "/path/to/bxe-utilities"
  }
}
```

---

## Summary

The orchestration script provides **full automation** for BXE VM deployment:

| Task | Manual | Orchestrated |
|------|--------|--------------|
| Create golden image | 15 steps, ~90 min | 1 command, ~90 min |
| Clone 3 VMs | 6 steps, ~6 min | 1 command, ~2 min |
| Full deployment | 21 steps, ~96 min | 1 command, ~92 min |
| **Human interaction** | **Constant** | **Zero** |

**Key Features:**
- ✅ Single-command deployment
- ✅ Automatic virtiofs configuration
- ✅ SSH-based remote execution
- ✅ Batch VM cloning
- ✅ Error handling and retries
- ✅ Progress tracking
- ✅ Status monitoring

**Use Cases:**
- Development labs (quick VM provisioning)
- Teaching environments (consistent student VMs)
- CI/CD pipelines (automated testing)
- Research clusters (parallel simulation runs)
