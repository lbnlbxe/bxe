# Docker Build Guide for BXE Manager

## Overview

The BXE Manager Docker image has been refactored to use Docker-native instructions while maintaining compatibility with the shell scripts for native installations.

## Prerequisites

### Host Requirements

The BXE Manager container requires the following from the host:

1. **`/tools` directory** - Must contain Xilinx Vitis tools
   - Required file: `/tools/source-vitis-2023.1.sh`
   - This will be mounted into the container at runtime
   - Recommended: Mount read-only for safety

## Build Instructions

### Basic Build

```bash
docker build -f bxemanager.dockerfile -t bxemanager:latest .
```

### Build with BuildKit (Recommended)

BuildKit enables better caching and faster builds:

```bash
DOCKER_BUILDKIT=1 docker build -f bxemanager.dockerfile -t bxemanager:latest .
```

### Build Specific Stage Only

To build just the base image without installing Chipyard/FireSim:

```bash
docker build -f bxemanager.dockerfile --target bxebase -t bxemanager:base .
```

### Custom Build Arguments

Override default user settings:

```bash
docker build -f bxemanager.dockerfile \
  --build-arg UNAME=myuser \
  --build-arg UID=1001 \
  --build-arg GID=1001 \
  -t bxemanager:custom .
```

Override Chipyard installation path:

```bash
docker build -f bxemanager.dockerfile \
  --build-arg BXE_CHIPYARD_PATH=/opt/chipyard \
  -t bxemanager:opt .
```

## Architecture

### Multi-Stage Build

The Dockerfile uses a two-stage build:

1. **Stage 1: bxebase**
   - Base Ubuntu 24.04 image
   - OS package installation (apt packages)
   - Conda/Mamba installation
   - User creation and shell setup
   - BXE configuration initialization

2. **Stage 2: bxeinstall**
   - Chipyard/FireSim installation
   - Final working environment

### Key Improvements Over Previous Version

#### 1. Native Docker Instructions
- **Before**: Called `setupBXE.sh` which handled everything
- **After**: OS packages and conda installed via native RUN commands
- **Benefit**: Better layer caching, faster rebuilds

#### 2. Optimized Package Installation
- **Before**: Multiple apt-get calls in shell script
- **After**: Single consolidated RUN command
- **Benefit**: Fewer layers, smaller image size

#### 3. BuildKit Cache Mounts
- **Before**: Re-downloaded conda installer every build
- **After**: Uses `--mount=type=cache` for downloads
- **Benefit**: Significantly faster rebuilds

#### 4. Better Error Handling
- **Before**: Errors suppressed with `|| :` in scripts
- **After**: Proper `set -e` and `set -o pipefail`
- **Benefit**: Builds fail fast on errors

#### 5. Clear Configuration
- **Before**: Complex sed operations appending to empty variables
- **After**: Clean sed substitutions replacing full lines
- **Benefit**: More reliable, easier to debug

#### 6. Environment Variables
- **Before**: `.bashrc` modifications only
- **After**: ENV directives in Dockerfile + `.bashrc`
- **Benefit**: Variables available in all contexts

## Versioning Strategy

Since Chipyard/FireSim use `main` as the latest version:

- **Image tags** should reflect build date or custom version
- **Labels** capture the git commit hash at build time
- **Check commit hash**: `docker inspect bxemanager:latest | grep chipyard`

Example tagging strategy:
```bash
# Tag with date
docker build -f bxemanager.dockerfile -t bxemanager:$(date +%Y%m%d) .

# Tag with custom version
docker build -f bxemanager.dockerfile -t bxemanager:2.3.0 .
```

## Troubleshooting

### Build Failures

If the build fails during Chipyard installation:

1. **Check build logs** for specific errors
2. **Build just base stage** to verify OS setup:
   ```bash
   docker build -f bxemanager.dockerfile --target bxebase -t bxebase-debug .
   ```
3. **Run interactive debug**:
   ```bash
   docker run -it bxebase-debug /bin/bash
   # Then manually run installation commands
   ```

### Slow Builds

- Ensure BuildKit is enabled: `export DOCKER_BUILDKIT=1`
- Check Docker has sufficient resources (RAM, disk space)
- Chipyard clone and build is inherently slow (20+ GB download)

### Layer Caching Issues

If you need to force rebuild without cache:
```bash
docker build --no-cache -f bxemanager.dockerfile -t bxemanager:latest .
```

## Running the Container

### Basic Run

Run the container with `/tools` mounted from the host:

```bash
docker run -it --rm \
  -v /tools:/tools:ro \
  bxemanager:latest
```

### Common Run Options

**With persistent home directory:**
```bash
docker run -it --rm \
  -v /tools:/tools:ro \
  -v $HOME/bxe-workspace:/home/ubuntu \
  bxemanager:latest
```

**With SSH access:**
```bash
docker run -d \
  -v /tools:/tools:ro \
  -v $HOME/.ssh:/home/ubuntu/.ssh:ro \
  -p 2222:22 \
  --name bxemanager \
  bxemanager:latest /usr/sbin/sshd -D
```

**Override default user:**
```bash
docker run -it --rm \
  -v /tools:/tools:ro \
  --user $(id -u):$(id -g) \
  bxemanager:latest
```

### Required Mounts

The container **requires** `/tools` to be mounted:

| Mount | Required | Purpose |
|-------|----------|---------|
| `/tools` | **Yes** | Xilinx Vitis tools (contains `source-vitis-2023.1.sh`) |

If `/tools` is not mounted, the container will exit with an error message explaining how to fix it.

### Entrypoint Validation

The container uses `/opt/bxe/docker-entrypoint.sh` which:
- Validates that `/tools` is mounted
- Checks for expected files (e.g., `source-vitis-2023.1.sh`)
- Warns if `/tools` is mounted read-write (recommends read-only)
- Provides helpful error messages if requirements are not met

To bypass the entrypoint (for debugging):
```bash
docker run -it --rm \
  -v /tools:/tools:ro \
  --entrypoint /bin/bash \
  bxemanager:latest
```

## Docker Compose

A `docker-compose.yml` file is provided for easier container management.

### Start the Container

```bash
docker-compose up -d
```

### Attach to Running Container

```bash
docker-compose exec bxemanager /bin/bash
```

### Stop the Container

```bash
docker-compose down
```

### View Logs

```bash
docker-compose logs -f bxemanager
```

### Customizing docker-compose.yml

The provided `docker-compose.yml` includes commented examples for:
- Building from source instead of using pre-built image
- Mounting SSH keys for FireSim
- Exposing SSH port for remote access
- Setting resource limits (CPU/memory)
- Running in privileged mode
- Using host networking

Edit the file to uncomment and customize these options as needed.

## Comparison with Native Installation

The same shell scripts (`installBXE.sh`) work for both:

- **Native**: `./installBXE.sh chipyard`
- **Container**: Automatically detected via `BXE_CONTAINER` env var

Key differences:
- Container uses `/opt/conda` vs `~/.conda`
- Container skips VNC server installation
- Container uses optimized Chipyard build args (`--skip 9 --skip 11`)
- Container requires `/tools` mounted from host

## Future Enhancements

Potential optimizations:

1. **Pre-built Chipyard layer**: Maintain a separate base image with Chipyard pre-installed
2. **Multi-arch builds**: Support ARM64 for Apple Silicon
3. **Slim variants**: Create minimal images for specific use cases
4. **CI/CD integration**: Automated builds on Chipyard releases
