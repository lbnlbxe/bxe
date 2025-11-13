# BXE Authentication Strategy

## Overview

The BXE VMs implement a **hybrid authentication approach** for security and usability:

- **bxeuser**: SSH key only (admin account - high security)
- **New users**: Password authentication enabled (for XRDP, ease of use)
- **Remote desktop (XRDP)**: Works via password-authenticated user accounts
- **SSH access**: `bxeuser` uses SSH keys; other users can use passwords or keys

## Authentication Configuration

### bxeuser (Admin Account)

**Authentication method:** SSH key only
```bash
lock_passwd: true  # Password login disabled
ssh_authorized_keys:  # SSH public key required
  - ssh-rsa AAAAB3NzaC1yc2E...
```

**Access methods:**
- ✅ SSH with key: `ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>`
- ❌ SSH with password: Not allowed
- ❌ XRDP: Not allowed (SSH key only)
- ❌ Console password: Not allowed

**Rationale:** `bxeuser` is the admin account with sudo access, so it uses the most secure method (SSH keys only).

### New User Accounts

**Authentication method:** Password authentication enabled

When you create additional user accounts:

```bash
# Create user (will be prompted for password)
sudo adduser alice

# Add to firesim group (for sudo access)
sudo usermod -aG firesim alice
```

**Access methods:**
- ✅ SSH with password: `ssh alice@<vm-ip>` (then enter password)
- ✅ SSH with key: Configure if desired
- ✅ XRDP with password: `xfreerdp /v:<vm-ip> /u:alice /p:<password>`
- ✅ VNC: Works via desktop environment

**Rationale:** Regular users don't need SSH-key-only access. Passwords are simpler for most users and enable XRDP access.

## System-Wide Settings

```yaml
# From cloud-init bxe-user-data.yaml
ssh_pwauth: true   # Enable password authentication system-wide
disable_root: true # Disable root login (for security)
```

**What this means:**
- Password authentication is enabled for all users except `bxeuser`
- Users can change their passwords with `passwd`
- Root account login is disabled (even with password)
- Emergency access via console still possible if needed

## Access Scenarios

### Scenario 1: Admin Access via SSH

**Requirement:** Need to SSH as `bxeuser` (admin account)

```bash
# Your machine
ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>

# Inside VM
sudo ./setupBXE.sh
/opt/bxe/installBXE.sh chipyard ~/chipyard
```

**Requirements:**
- Your SSH public key added to cloud-init config (before golden image creation)
- SSH private key on your local machine

### Scenario 2: User XRDP Access

**Requirement:** User wants to access Xilinx GUI via XRDP

**Setup (admin does once):**
```bash
# SSH into VM as bxeuser
ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>

# Create user account
sudo adduser alice
sudo usermod -aG firesim alice
```

**User access:**
```bash
# On user's machine
xfreerdp /v:<vm-ip> /u:alice /p:<password>

# Or Windows Remote Desktop:
# Computer: <vm-ip>
# Username: alice
# Password: <password>
```

### Scenario 3: User SSH Access

**Requirement:** User wants to SSH into VM

**Two options:**

**Option A: Password-based (simpler)**
```bash
# User's machine
ssh alice@<vm-ip>
# Prompted for password

# Inside VM
/opt/bxe/installBXE.sh chipyard ~/chipyard
```

**Option B: SSH key-based (more secure)**
```bash
# Admin adds user's public key
ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>
mkdir -p /home/alice/.ssh
echo "ssh-rsa AAAA..." >> /home/alice/.ssh/authorized_keys
chown -R alice:alice /home/alice/.ssh
chmod 700 /home/alice/.ssh
chmod 600 /home/alice/.ssh/authorized_keys

# User can now SSH with key
ssh -i ~/.ssh/id_rsa alice@<vm-ip>
```

## Security Implications

### Strong Points

✅ **Admin account (bxeuser)** uses SSH keys only
- Immune to brute-force password attacks
- Requires key management (which we have)
- Suitable for automation (orchestration scripts)

✅ **User accounts** use passwords
- Easier for non-technical users
- Works with XRDP (no key management needed)
- Users can change passwords independently

✅ **Root login disabled**
- Prevents root brute-force attacks
- Users must use `sudo` with their account

✅ **FireSim group** controls privileges
- Only firesim users get sudo access
- Easy to revoke by removing from group

### Considerations

⚠️ **Password strength**
- Admins should enforce strong passwords for user accounts
- Consider password policies: `sudo apt install libpam-pwquality`

⚠️ **SSH key management**
- `bxeuser` SSH key should be kept secure
- Private key should not be shared
- Consider using ssh-agent for key management

⚠️ **VNC passwords**
- If using VNC, set a strong VNC password: `vncpasswd`
- VNC passwords are separate from Linux passwords

## Recommended Practices

### For Admins

1. **Keep your SSH key secure**
   ```bash
   chmod 600 ~/.ssh/id_rsa
   # Don't share the private key
   ```

2. **Store SSH key securely**
   - Don't put on shared systems
   - Consider hardware security keys for production

3. **Use ssh-agent to avoid typing passphrase**
   ```bash
   ssh-agent bash
   ssh-add ~/.ssh/id_rsa
   ```

4. **Enforce password policies for users** (optional)
   ```bash
   sudo apt install libpam-pwquality
   ```

### For Users

1. **Set a strong password**
   ```bash
   passwd
   # You'll be prompted for old password, then new password (twice)
   ```

2. **Use SSH key for extra security** (if admin sets it up)
   ```bash
   ssh -i ~/.ssh/id_rsa alice@<vm-ip>
   ```

3. **Don't share your password**

4. **Change password periodically**

## Authentication Troubleshooting

### "Permission denied (publickey)" for bxeuser SSH

**Cause:** SSH key not configured
**Fix:** Add your SSH public key to cloud-init before creating golden image

### "Permission denied" for XRDP as bxeuser

**Cause:** `bxeuser` has password disabled by design
**Fix:** Use a different user account, or use SSH with key instead

### "Permission denied (password)" for new user SSH

**Cause:** Password not set correctly
**Fix:**
```bash
# As admin, set password for user
sudo passwd alice

# Or have user change it
passwd
```

### "XRDP connects but hangs on login"

**Cause:** Xfce desktop environment issue
**Fix:**
```bash
# SSH as bxeuser and check:
sudo systemctl status xrdp
sudo systemctl restart xrdp

# Check user's home directory permissions
sudo chown -R alice:alice /home/alice
```

## Changing Authentication Settings

### Enable Password Login for bxeuser (NOT RECOMMENDED)

If you really need password access for `bxeuser`:

```bash
# SSH as bxeuser (using key)
ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>

# Enable password login
sudo passwd bxeuser
# Set password when prompted

# To revert (make SSH-key-only again):
sudo usermod -L bxeuser  # Lock password
```

### Disable Password Auth System-Wide (if desired)

```bash
# SSH as bxeuser
ssh -i ~/.ssh/id_rsa bxeuser@<vm-ip>

# Edit SSH config
sudo vim /etc/ssh/sshd_config
# Change: PasswordAuthentication yes
# To:     PasswordAuthentication no

# Restart SSH
sudo systemctl restart ssh
```

## Summary Table

| Account | Password Auth | SSH Key | XRDP | Console |
|---------|---------------|---------|------|---------|
| **bxeuser** | ❌ Disabled | ✅ Required | ❌ No | ❌ No |
| **New users** | ✅ Enabled | ✅ Optional | ✅ Yes | ✅ Yes |
| **root** | ❌ Disabled | ❌ No | ❌ No | ❌ No |

## Best Practices Summary

1. **Never share bxeuser private key**
2. **Always update bxeuser SSH key to cloud-init before golden image**
3. **Create separate user accounts for each person**
4. **Use strong passwords for user accounts**
5. **Regularly review who has access**
6. **Remove firesim group membership for users who don't need it**

## References

- [SSH Key-Based Authentication](https://www.ssh.com/ssh/public-key-authentication)
- [PAM - Pluggable Authentication Modules](https://linux.die.net/man/5/pam)
- [XRDP Security](https://github.com/neutrinolabs/xrdp/wiki)
