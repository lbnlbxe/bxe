# BXE Desktop Environment Access

This document describes how to access the Xfce desktop environment on BXE VMs via XRDP or VNC.

## Overview

BXE VMs include:
- **Xfce 4** - Lightweight, reliable desktop environment (matches Xubuntu)
- **TigerVNC** - VNC server for remote desktop
- **XRDP** - RDP server for Windows Remote Desktop Protocol
- **dbus** - Message bus for desktop services

## Quick Start

### Option 1: XRDP (Recommended for Windows/Linux)

**Note:** `bxeuser` is SSH-key-only and cannot login via XRDP. Create a separate user account for XRDP access.

```bash
# Create a user account for XRDP access (on the VM)
sudo adduser alice
sudo usermod -aG firesim alice

# Then on your local machine, login via XRDP:
xfreerdp /v:<vm-ip> /u:alice /p:<password>

# Or on Windows, use Remote Desktop Connection:
# Computer: <vm-ip>
# Username: alice
# Password: <password>
```

**If you need bxeuser via XRDP:**
- Use SSH instead: `ssh -X bxeuser@<vm-ip>` (requires SSH key)
- Or enable password for bxeuser (not recommended for security)

### Option 2: VNC (Works everywhere)

```bash
# On your local machine (requires VNC client installed)
vncviewer <vm-ip>:5901
```

## Detailed Setup

### First-Time Desktop Configuration

When you first connect via XRDP/VNC, you may need to configure the desktop session.

#### Via XRDP

1. Connect with your RDP client to `<vm-ip>:3389`
2. Username: `bxeuser`
3. XRDP will prompt for session type - **select Xvnc**
4. You may need to set VNC password (see below)

#### Via VNC

1. Start VNC server:
   ```bash
   vncserver -geometry 1920x1080 -depth 24
   ```

2. Connect from local machine:
   ```bash
   vncviewer <vm-ip>:5901
   ```

3. Enter VNC password when prompted

### Setting VNC Password

```bash
# On the VM
vncpasswd

# Follow prompts to set password
# Then start VNC server:
vncserver -geometry 1920x1080 -depth 24 -alwaysshared
```

### Configure VNC for Auto-Start (Optional)

Create `~/.vnc/xstartup`:

```bash
#!/bin/bash
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
dbus-launch --exit-with-session startxfce4 &
```

Make executable:
```bash
chmod +x ~/.vnc/xstartup
```

Then start VNC:
```bash
vncserver -geometry 1920x1080 -depth 24 -alwaysshared
```

## Accessing Xilinx Tools GUI

The Xilinx Vitis tools are available at `/tools/source-vitis-2023.1.sh`.

### Using Xilinx GUI via Desktop

```bash
# 1. SSH into VM
ssh bxeuser@<vm-ip>

# 2. Source Xilinx tools
source /tools/source-vitis-2023.1.sh

# 3. Launch Vitis via X forwarding OR
vitis &

# OR connect via XRDP/VNC first, then:
# - Open Terminal in Xfce
# - Source Vitis
# - Launch GUI
```

### Using X Forwarding (SSH)

If XRDP/VNC is not available:

```bash
# On local machine (Linux/Mac)
ssh -X bxeuser@<vm-ip>

# Then on VM:
source /tools/source-vitis-2023.1.sh
vitis &
```

## Troubleshooting

### XRDP Connection Fails

**Check XRDP service:**
```bash
# On VM
sudo systemctl status xrdp
sudo systemctl status xrdp-sesman

# Restart if needed
sudo systemctl restart xrdp
sudo systemctl restart xrdp-sesman
```

**Check logs:**
```bash
# XRDP logs
tail -f /var/log/xrdp.log
tail -f /var/log/xrdp-sesman.log

# Session logs
ls -la ~/.xsession-errors
cat ~/.xsession-errors
```

### VNC Connection Fails

**Check if VNC server is running:**
```bash
# List running VNC servers
ps aux | grep vnc
vncserver -list
```

**Start VNC server:**
```bash
vncserver -geometry 1920x1080 -depth 24
```

**Kill and restart VNC:**
```bash
vncserver -kill :1
vncserver -geometry 1920x1080 -depth 24
```

### "Xilinx tools not found" in GUI

Make sure to source Xilinx before launching GUI:

```bash
# In terminal on VM (via XRDP/VNC):
source /tools/source-vitis-2023.1.sh
vitis &
```

OR edit `~/.bashrc` to auto-source on login:

```bash
# Add to ~/.bashrc
if [ -f /tools/source-vitis-2023.1.sh ]; then
    source /tools/source-vitis-2023.1.sh
fi
```

### Desktop Environment Doesn't Display

**Try Xfce panel reset:**
```bash
# Kill Xfce processes
pkill -f xfce
pkill -f xfwm

# Restart VNC or XRDP session
vncserver -kill :1
vncserver -geometry 1920x1080 -depth 24
```

**Or reinstall Xfce:**
```bash
sudo apt update
sudo apt install --reinstall xfce4 xfce4-goodies
```

## Performance Tips

### Resolution and Depth

For better performance, adjust resolution:

```bash
# Lower resolution (faster)
vncserver -geometry 1280x720 -depth 16

# Higher resolution (slower but sharper)
vncserver -geometry 1920x1080 -depth 24
```

### Network Optimization

If experiencing lag:

1. **Use XRDP instead of VNC** - Generally faster
2. **Reduce color depth** - Use 16-bit instead of 24-bit
3. **Reduce resolution** - 1280x720 instead of 1920x1080
4. **Enable compression** - XRDP compresses by default

### Local Client Tips

- **Linux**: Use `xfreerdp` for XRDP (faster than Windows RDP)
- **Mac**: Install "Remote Desktop" from App Store for RDP
- **Windows**: Built-in Remote Desktop Connection works great

## Advanced: XRDP Configuration

Edit `/etc/xrdp/xrdp.ini` to customize XRDP:

```ini
# Set default session type
[xrdp1]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
```

Restart XRDP:
```bash
sudo systemctl restart xrdp
```

## Advanced: VNC Configuration

Edit `~/.vnc/config`:

```
geometry=1920x1080
depth=24
securityTypes=VncAuth
```

## Summary

| Access Method | Setup | Performance | Compatibility |
|---------------|-------|-------------|---------------|
| **XRDP** | Easy | Good | Windows, Linux, Mac |
| **VNC** | Easy | Good | All platforms |
| **X Forward** | Complex | Slow | Linux, Mac |

**Recommended:** Use XRDP for daily work, VNC as backup.

## Common Workflows

### Xilinx Vitis Development

```bash
# 1. Connect via XRDP
# 2. Open Terminal in Xfce
# 3. Navigate to your project
cd ~/chipyard/sims/firesim

# 4. Source Xilinx tools (if not in .bashrc)
source /tools/source-vitis-2023.1.sh

# 5. Launch Vitis
vitis &

# 6. Work in GUI
```

### Running FireSim with GUI Tools

```bash
# 1. Terminal via XRDP/VNC
# 2. Source environment
source ~/.bxe/bxe-firesim.sh

# 3. Use FireSim manager
cd ~/chipyard/sims/firesim
firesim --help

# 4. Launch GUI tools if needed
vivado &  # Xilinx Vivado
vitis_hls &  # HLS compiler
```

## Ports and Services

| Service | Port | Access |
|---------|------|--------|
| XRDP | 3389 | RDP clients |
| VNC | 5901 | VNC clients (if running) |
| SSH | 22 | SSH clients (X forwarding) |

All services use your BXE SSH keys for authentication (no additional setup needed).
