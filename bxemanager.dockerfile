FROM condaforge/miniforge3

RUN mkdir -p /opt/bxe/managers
COPY setupBXE.sh /opt/bxe
COPY installBXE.sh /opt/bxe
COPY managers/* /opt/bxe/managers

RUN /opt/bxe/setupBXE.sh container

# RUN /opt/bxe/installBXE.sh chipyard /opt/bxe/chipyard

