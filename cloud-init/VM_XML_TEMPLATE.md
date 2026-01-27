# VM XML Configuration for virtiofs

After creating your golden image VM, you need to add virtiofs filesystem sharing configuration.

## Method 1: Edit Existing VM (Recommended)

```bash
# Edit the VM definition
virsh edit bxe-golden
```

Add these sections to the XML:

### 1. Add Memory Backing (before `<devices>` section)

```xml
<domain type='kvm'>
  <!-- ... existing configuration ... -->

  <memoryBacking>
    <source type='memfd'/>
    <access mode='shared'/>
  </memoryBacking>

  <devices>
    <!-- existing devices -->
  </devices>
</domain>
```

### 2. Add Filesystem Device (inside `<devices>` section)

```xml
<devices>
  <!-- ... existing devices ... -->

  <filesystem type='mount' accessmode='passthrough'>
    <driver type='virtiofs'/>
    <source dir='/tools'/>
    <target dir='tools'/>
    <readonly/>
  </filesystem>

</devices>
```

## Method 2: Complete XML Example

Here's a complete minimal VM XML with virtiofs configured:

```xml
<domain type='kvm'>
  <name>bxe-golden</name>
  <memory unit='GiB'>16</memory>
  <vcpu placement='static'>8</vcpu>

  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <boot dev='hd'/>
  </os>

  <features>
    <acpi/>
    <apic/>
  </features>

  <cpu mode='host-passthrough'/>

  <memoryBacking>
    <source type='memfd'/>
    <access mode='shared'/>
  </memoryBacking>

  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>

    <!-- Disk -->
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/bxe-golden.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <!-- Network -->
    <interface type='bridge'>
      <source bridge='br1'/>
      <model type='virtio'/>
    </interface>

    <!-- virtiofs for /tools -->
    <filesystem type='mount' accessmode='passthrough'>
      <driver type='virtiofs'/>
      <source dir='/tools'/>
      <target dir='tools'/>
      <readonly/>
    </filesystem>

    <!-- Serial console -->
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>

    <!-- Graphics (optional) -->
    <graphics type='vnc' port='-1' autoport='yes'/>

  </devices>
</domain>
```

## Verification

After adding virtiofs configuration:

### 1. Restart the VM

```bash
virsh shutdown bxe-golden
virsh start bxe-golden
```

### 2. Inside the VM, verify the mount

```bash
# Check if /tools is mounted
mount | grep /tools
# Expected output: tools on /tools type virtiofs (ro,relatime)

# Verify files are accessible
ls /tools/source-vitis-2023.1.sh
# Should show the file

# Test loading
source /tools/source-vitis-2023.1.sh
# Should source successfully
```

### 3. Verify it persists across reboots

```bash
# Inside VM
sudo reboot

# After reboot, check again
mount | grep /tools
```

## Troubleshooting

### virtiofs mount fails with "No such device"

**Cause:** VM doesn't have the virtiofs filesystem device configured

**Fix:**
```bash
# On hypervisor
virsh edit <vm-name>
# Add the filesystem device as shown above
virsh shutdown <vm-name>
virsh start <vm-name>
```

### "mount: /tools: unknown filesystem type 'virtiofs'"

**Cause:** Kernel doesn't support virtiofs (very old kernel)

**Fix:** Upgrade to Ubuntu 22.04+ or kernel 5.4+, or use virtio-9p instead:

```bash
# In VM /etc/fstab, replace:
tools  /tools  virtiofs  ro,defaults  0  0
# With:
tools  /tools  9p  ro,trans=virtio,version=9p2000.L  0  0
```

And in VM XML, replace:
```xml
<filesystem type='mount' accessmode='mapped'>
  <source dir='/tools'/>
  <target dir='tools'/>
  <readonly/>
</filesystem>
```

### /tools mount point exists but is empty

**Cause:** Hypervisor's `/tools` directory is empty or not mounted

**Fix:**
```bash
# On hypervisor, verify /tools exists and has content
ls /tools

# If empty, mount NFS on hypervisor first
sudo mount vizion.lbl.gov:/mnt/vmpool/nfs/tools /tools
```

### Permission denied accessing files in /tools

**Cause:** User/group ID mismatch or passthrough mode issue

**Fix:**
```bash
# Option 1: Use mapped mode instead of passthrough
# In VM XML, change:
<filesystem type='mount' accessmode='mapped'>

# Option 2: Ensure user IDs match between hypervisor and VM
# Check on hypervisor:
ls -ln /tools/source-vitis-2023.1.sh

# Check in VM:
id bxeuser
```

## Alternative: virtio-9p (for older systems)

If virtiofs doesn't work, use virtio-9p:

### VM XML Configuration

```xml
<filesystem type='mount' accessmode='mapped'>
  <source dir='/tools'/>
  <target dir='tools_mount'/>
  <readonly/>
</filesystem>
```

### Inside VM (/etc/fstab)

```bash
tools_mount  /tools  9p  ro,trans=virtio,version=9p2000.L  0  0
```

**Note:** virtio-9p is slower than virtiofs but more compatible with older systems.
