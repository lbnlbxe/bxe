# FROM condaforge/miniforge3
FROM ubuntu:24.04
SHELL ["/bin/bash", "-c"]
ARG BXE_CONTAINER="container"

RUN mkdir -p /opt/bxe/managers
COPY setupBXE.sh /opt/bxe
COPY installBXE.sh /opt/bxe
COPY managers/* /opt/bxe/managers

RUN /opt/bxe/setupBXE.sh

RUN echo 'source /opt/conda/etc/profile.d/conda.sh' >> /home/ubuntu/.bashrc
RUN echo 'source /opt/conda/etc/profile.d/mamba.sh' >> /home/ubuntu/.bashrc

USER ubuntu

RUN <<EOF
source /opt/conda/etc/profile.d/conda.sh && \
source /opt/conda/etc/profile.d/mamba.sh && \
/opt/bxe/installBXE.sh chipyard
EOF

WORKDIR /home/ubuntu
