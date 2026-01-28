# Berkeley eXtensible Environment (BXE)

BXE provides an automated setup and configuration framework for deploying FireSim and Chipyard development environments. It streamlines the installation of system prerequisites, tools, and user environments, making it easier to bootstrap hardware simulation infrastructure on both native Linux systems and virtual machines. BXE handles the complex setup of FireSim's dependencies, conda environments, SSH key management, and custom configuration files, enabling researchers and developers to quickly establish consistent, reproducible RISC-V hardware design and simulation environments.

## Installing BXE Prerequisites

```bash
sudo ./setupBXE.sh
```

The `setupBXE.sh` script must be run with root privileges and installs all system-level prerequisites required for BXE and FireSim. This includes installing essential OS packages (openssh-server, libguestfs-tools, build-essential), setting up Conda (Miniforge3) in `/opt/conda`, configuring virtiofs mounts for `/tools` directories, creating the `firesim` group with appropriate sudoers permissions, and installing FireSim's privileged scripts. The script also installs BXE management scripts to `/opt/bxe` and sets up the guestmount service for handling disk image operations. For native installations, it optionally installs desktop environment components (XFCE4) and remote access tools (VNC, XRDP).

## Setting Up the BXE User Environment

```bash
./installBXE.sh <chipyard|firesim|bxe> [install_path]
```

The `installBXE.sh` script runs as a regular user and configures the user-specific environment for working with FireSim and Chipyard. It supports three installation modes:

- **`chipyard`** - Installs Chipyard with FireSim as a submodule
- **`firesim`** - Standalone FireSim installation
- **`bxe`** - Installs BXE configuration files to an existing FireSim installation (requires `install_path`)

The script creates configuration files in `~/.bxe`, updates the user's `.bashrc` to source the BXE environment, generates or verifies SSH keys for FireSim runner machines, and deploys custom BXE FireSim configuration YAML files. It automatically detects whether it's running in a container or native environment and adjusts build parameters accordingly.

## Future Work

### VM FireSim Runners

Support for FireSim runners in virtual machine environments is under development. This work will enable BXE to leverage VM-based infrastructure for FireSim simulations, providing greater flexibility for deployment scenarios where dedicated FPGA hardware is not available. See [FireSim PR: VM infrastructure for FireSim deployment #1860](https://github.com/firesim/firesim/pull/1860) for ongoing development.

### BXE Container

Future development will provide Docker container images for portable BXE deployments. This will enable teams to quickly spin up consistent BXE environments without manual system configuration, simplifying onboarding and ensuring reproducibility across different infrastructure.

## References

- [FireSim](https://fires.im) - FPGA-accelerated Cycle-Accurate Hardware Simulation in the Cloud
- [Chipyard](https://chipyard.readthedocs.io/en/main/) - An Agile RISC-V SoC Design Framework with in-order cores, out-of-order cores, accelerators, and more

## Copyright Notice

Berkeley eXtensible Environment (BXE) Copyright (c) 2026, The Regents of the University of California, through Lawrence Berkeley National Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.

If you have questions about your rights to use or distribute this software, please contact Berkeley Lab's Intellectual Property Office at IPO@lbl.gov.

NOTICE.  This Software was developed under funding from the U.S. Department of Energy and the U.S. Government consequently retains certain rights.  As such, the U.S. Government has been granted for itself and others acting on its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the Software to reproduce, distribute copies to the public, prepare derivative works, and perform publicly and display publicly, and to permit others to do so.

## Funding Acknowledgement

This research is based upon work supported by the Office of the Director of National Intelligence (ODNI), Intelligence Advanced Research Projects Activity (IARPA), through the Advanced Graphical Intelligence Logical Computing Environment (AGILE) research program, under Army Research Office (ARO) contract number D2021-2106030006. The views and conclusions contained herein are those of the authors and should not be interpreted as necessarily representing the official policies or endorsements, either expressed or implied, of the ODNI, IARPA, ARO, or the U.S. Government.
