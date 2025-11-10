# BXE Manager Docker - Quick Start

## TL;DR

```bash
# Build the image
DOCKER_BUILDKIT=1 docker build -f bxemanager.dockerfile -t bxemanager:latest .

# Run with /tools mounted from host (REQUIRED)
docker run -it --rm -v /tools:/tools:ro bxemanager:latest
```

## Common Commands

### Using docker-compose (Recommended)

```bash
# Start container in background
docker-compose up -d

# Attach to container
docker-compose exec bxemanager /bin/bash

# Stop container
docker-compose down
```

### Using docker run

```bash
# Interactive session
docker run -it --rm -v /tools:/tools:ro bxemanager:latest

# With persistent workspace
docker run -it --rm \
  -v /tools:/tools:ro \
  -v $HOME/bxe-workspace:/home/ubuntu \
  bxemanager:latest

# Background with SSH (port 2222)
docker run -d \
  -v /tools:/tools:ro \
  -p 2222:22 \
  --name bxemanager \
  bxemanager:latest /usr/sbin/sshd -D
```

## Important Notes

1. **`/tools` mount is REQUIRED** - Container will exit with error if not mounted
2. **Recommended to mount read-only** - Use `:ro` flag for safety
3. **`/tools` must contain** - `/tools/source-vitis-2023.1.sh` for Xilinx Vitis tools
4. **Chipyard location** - `/home/ubuntu/chipyard` inside container
5. **Default user** - `ubuntu` (UID: 1000)

## Troubleshooting

**Container exits immediately:**
- Check that `/tools` is mounted: `-v /tools:/tools:ro`

**"vitis not found" error:**
- Verify `/tools/source-vitis-2023.1.sh` exists on host
- Source the environment: `source ~/.bxe/bxe-firesim.sh`

**Build fails during Chipyard install:**
- Check available disk space (needs ~30GB)
- Check available RAM (recommended 16GB+)
- Build just base stage: `docker build --target bxebase ...`

**Need to debug:**
- Bypass entrypoint: `docker run --entrypoint /bin/bash ...`
- Build base only: `docker build --target bxebase ...`

## Where to Find More Info

- Full build guide: `DOCKER_BUILD.md`
- Docker Compose config: `docker-compose.yml`
- Native installation: `installBXE.sh --help`
