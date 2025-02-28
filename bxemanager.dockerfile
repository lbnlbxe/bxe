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

ENV BXE_CONTAINER="container"
ARG BXE_CONFIG_DIR="${UHOME}/.bxe"
ARG BXE_CHIPYARD_PATH="${UHOME}/chipyard"

RUN mkdir -p /opt/bxe/managers
COPY setupBXE.sh /opt/bxe
COPY installBXE.sh /opt/bxe
COPY managers/* /opt/bxe/managers

RUN /opt/bxe/setupBXE.sh

RUN echo 'source /opt/conda/etc/profile.d/conda.sh' >> ${UHOME}/.bashrc
RUN echo 'source /opt/conda/etc/profile.d/mamba.sh' >> ${UHOME}/.bashrc
RUN ln -sf ${UHOME}/.bashrc ${UHOME}/.bash_profile

RUN chown -R ${UID}:${GID} ${UHOME}


FROM bxebase AS bxeinstall

USER ${UNAME}

# RUN <<EOF
# source /opt/conda/etc/profile.d/conda.sh && \
# source /opt/conda/etc/profile.d/mamba.sh && \
# /opt/bxe/installBXE.sh chipyard ${BXE_CHIPYARD_PATH} 2>${BXE_CONFIG_DIR}/chipyard_errors.log; true
# EOF
RUN <<EOF
source /opt/conda/etc/profile.d/conda.sh && \
source /opt/conda/etc/profile.d/mamba.sh && \
/opt/bxe/installBXE.sh chipyard ${BXE_CHIPYARD_PATH}
EOF

# RUN chown -R ${UID}:${GID} ${UHOME}

WORKDIR ${UHOME}
