FROM ubuntu:24.04 AS bxebase

LABEL name="bxedocker"
LABEL version="2.3.0"
LABEL author="ffard@lbl.gov"
LABEL org="Lawrence Berkeley National Lab"

SHELL ["/bin/bash", "-c"]

ARG UNAME=ubuntu
ARG UID=1000
ARG GID=${UID}
ARG UHOME=/home/${UNAME}

# Environment variables for BXE
ENV BXE_CONTAINER="container"
ENV BXE_CONFIG_DIR="${UHOME}/.bxe"
ENV CONDA_ROOT="/opt/conda"

ARG BXE_CHIPYARD_PATH="${UHOME}/chipyard"

# ===== Install OS Prerequisites =====
# Using single RUN command with layer optimization
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=America/Los_Angeles apt-get install -y \
    # General Prerequisites
    nfs-common \
    openssh-server \
    libguestfs-tools \
    wget \
    curl \
    vim \
    tree \
    emacs \
    tmux \
    git \
    build-essential \
    sudo \
    # FireSim Prerequisites
    libc6-dev \
    screen \
    libtinfo-dev && \
    # Clear apt cache to reduce image size
    rm -rf /var/lib/apt/lists/*

# ===== Install Conda =====
# Using BuildKit cache mount for faster rebuilds
RUN --mount=type=cache,target=/tmp/conda-cache \
    cd /tmp && \
    wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash Miniforge3-Linux-x86_64.sh -b -p "${CONDA_ROOT}" && \
    rm Miniforge3-Linux-x86_64.sh && \
    ln -sf ${CONDA_ROOT}/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    ln -sf ${CONDA_ROOT}/etc/profile.d/mamba.sh /etc/profile.d/mamba.sh

# Set conda environment variables
ENV PATH="${CONDA_ROOT}/bin:${PATH}"

# ===== Setup BXE Configuration =====
RUN mkdir -p /opt/bxe/managers && \
    mkdir -p ${BXE_CONFIG_DIR}

# Copy BXE scripts and configuration files
COPY managers/* /opt/bxe/managers/
COPY installBXE.sh /opt/bxe/
COPY docker-entrypoint.sh /opt/bxe/

# Copy configuration template and initialize
RUN cp /opt/bxe/managers/bxe-firesim.sh ${BXE_CONFIG_DIR}/bxe-firesim.sh && \
    chmod +x /opt/bxe/docker-entrypoint.sh

# ===== User Setup =====
# Create user and setup bashrc with conda initialization
RUN groupadd -g ${GID} ${UNAME} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${UNAME} && \
    echo "${UNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Setup shell environment for ubuntu user
RUN echo 'source /opt/conda/etc/profile.d/conda.sh' >> ${UHOME}/.bashrc && \
    echo 'source /opt/conda/etc/profile.d/mamba.sh' >> ${UHOME}/.bashrc && \
    echo 'source ${HOME}/.bxe/bxe-firesim.sh' >> ${UHOME}/.bashrc && \
    ln -sf ${UHOME}/.bashrc ${UHOME}/.bash_profile

# Fix ownership
RUN chown -R ${UID}:${GID} ${UHOME} ${BXE_CONFIG_DIR}

# ===== Stage 2: Install Chipyard/FireSim =====
FROM bxebase AS bxeinstall

USER ${UNAME}

# Set conda to auto-approve installations
ENV CONDA_ALWAYS_YES="true"

# Install Chipyard/FireSim
# Using heredoc for better readability and proper error handling
RUN <<EOF
set -e
source /opt/conda/etc/profile.d/conda.sh
source /opt/conda/etc/profile.d/mamba.sh

# Run the BXE installer
/opt/bxe/installBXE.sh chipyard ${BXE_CHIPYARD_PATH}
EOF

# Unset auto-approve after installation
ENV CONDA_ALWAYS_YES=""

WORKDIR ${UHOME}

# Declare /tools volume mount point
# This must be mounted from the host at runtime (contains Xilinx Vitis tools)
VOLUME ["/tools"]

# Set entrypoint to validate /tools mount
ENTRYPOINT ["/opt/bxe/docker-entrypoint.sh"]
CMD ["/bin/bash"]

# Add label with build information
LABEL chipyard.location="${BXE_CHIPYARD_PATH}"
LABEL firesim.version="main"
LABEL chipyard.version="main"
LABEL tools.required="true"
LABEL tools.mount="/tools"
