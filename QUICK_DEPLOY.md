# BXE Quick Deploy Guide

## TL;DR - Single Command Deployment

```bash
# Deploy everything (golden image + 3 VMs) in one command:
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count 3
```

That's it! Wait ~90 minutes and you'll have:
- 1 golden image VM (shut off, ready for cloning)
- 3 running VMs with full Chipyard/FireSim installation
- All VMs have /tools mounted via virtiofs (read-only)

---

## What Just Happened?

The orchestration script automated everything:

```
1. Downloaded Ubuntu 24.04 cloud image
   ↓
2. Created VM with cloud-init (user, SSH keys, packages)
   ↓
3. Added virtiofs filesystem (/tools mount)
   ↓
4. Waited for cloud-init to finish
   ↓
5. SSH → ran setupBXE.sh (OS packages, Conda, virtiofs config)
   ↓
6. SSH → ran installBXE.sh (Chipyard + FireSim installation)
   ↓ (30-60 minutes)
7. Cleaned and shut down golden image
   ↓
8. Cloned 3 VMs (bxe-1, bxe-2, bxe-3)
   ↓
9. Started all cloned VMs
   ↓
DONE! ✓
```

---

## Common Commands

### Full Deployment
```bash
# Create golden + 5 VMs
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count 5
```

### Just Golden Image
```bash
# Create golden image only (no clones)
sudo ./orchestrate-bxe.sh create-golden --ssh-key ~/.ssh/id_rsa.pub
```

### Clone VMs Later
```bash
# After golden image is created, clone VMs
sudo ./orchestrate-bxe.sh clone --count 3
```

### Check Status
```bash
sudo ./orchestrate-bxe.sh status
```

### Named VMs
```bash
# Clone specific named VMs
sudo ./orchestrate-bxe.sh clone --targets alice-bxe,bob-bxe,charlie-bxe
```

---

## Access Your VMs

```bash
# Get VM IP addresses
sudo ./orchestrate-bxe.sh status

# SSH into a VM
ssh bxeuser@<vm-ip>

# Inside VM - verify environment
source ~/.bxe/bxe-firesim.sh
cd ~/chipyard/sims/firesim
firesim --help
```

---

## Time Investment

| Task | Time | Human Effort |
|------|------|--------------|
| **First deployment** | ~90 min | Run 1 command |
| **Clone 1 VM** | ~2 min | Run 1 command |
| **Clone 10 VMs** | ~5 min | Run 1 command |

---

## What If Something Breaks?

### Check status
```bash
sudo ./orchestrate-bxe.sh status
```

### View VM console
```bash
virsh console bxe-golden
# Press Ctrl+] to exit
```

### Manual setup (if automation fails)
```bash
# 1. Get VM IP
sudo ./orchestrate-bxe.sh status

# 2. SSH in
ssh bxeuser@<vm-ip>

# 3. Run setup manually
cd ~/bxe-utilities
sudo ./setupBXE.sh
./installBXE.sh chipyard ~/chipyard
```

### Full documentation
- **ORCHESTRATION.md** - Complete orchestration guide
- **DEPLOYMENT_GUIDE.md** - Detailed manual deployment
- **cloud-init/README.md** - Cloud-init specifics

---

## Summary

**Old way (manual):**
- 21 manual steps
- ~96 minutes
- Constant human interaction
- Error-prone

**New way (orchestrated):**
- 1 command
- ~92 minutes
- Zero human interaction
- Repeatable and consistent

**Command:**
```bash
sudo ./orchestrate-bxe.sh deploy --ssh-key ~/.ssh/id_rsa.pub --count <number_of_vms>
```
