#!/bin/bash

set -e
set -x

export BXE_CONFIG_DIR=${HOME}/.bxe

function usage() {
	echo "Usage: $0 <chipyard|firesim> [install_path]"
	echo "  <chipyard|firesim> : Install either Firesim within Chipyard (chipyard) or Standalone (firesim)"
	echo "  [install_path]     : Optional install path (default: ${HOME})"
}

function installBXEConfig() {
    mkdir -p ${BXE_CONFIG_DIR}
    cp managers/* ${BXE_CONFIG_DIR}/.
}

function installChipyard() {
    local INSTALL_PATH=$1
    cd ${HOME}
    git clone https://github.com/ucb-bar/chipyard ${INSTALL_PATH}
    cd ${INSTALL_PATH}
    CHIPYARD_GIT_HASH="$(git rev-parse --short HEAD)"
    CHIPYARD_GIT_ROOT="$(pwd)"
    ./build-setup.sh
    cd sims/firesim
    FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
    cd

    sed -i '/CHIPYARD_HASH=/s/$/'"${CHIPYARD_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    awk -v dir=${CHIPYARD_GIT_ROOT} '{if ($0 ~ /CHIPYARD_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/temp && mv temp ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_ROOT=/s|$|${CHIPYARD_ROOT}/sims/firesim|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIREMARSHAL_ROOT=/s|$|${CHIPYARD_ROOT}/software/firemarshal|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
}

function installFireSim() {
    local INSTALL_PATH=$1
    cd ${HOME}
    git clone https://github.com/firesim/firesim ${INSTALL_PATH}
    cd ${INSTALL_PATH}
    FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
    FIRESIM_GIT_ROOT="$(pwd)"
    ./build-setup.sh
    cd

    sed -i '/CHIPYARD_HASH=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/CHIPYARD_ROOT=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    awk -v dir=${FIRESIM_GIT_ROOT} '{if ($0 ~ /FIRESIM_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/temp && mv temp ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIREMARSHAL_ROOT=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
}

function installProfile() {
    BXE_SED_STRING="source "${BXE_CONFIG_DIR}"/bxe-firesim.sh"
    if ! grep -q "${BXE_SED_STRING}" ${HOME}/.bashrc; then
        sed -i '10a\'"${BXE_SED_STRING}"'\n' ${HOME}/.bashrc
    fi
}


if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Incorrect number of arguments."
    usage
	exit 1
fi

ARG_INSTALLER=$1
ARG_INSTALL_PATH=${2:-${ARG_INSTALLER}}

if [ -d ${ARG_INSTALL_PATH}]; then
    echo "Directory exists, cannot override existing direcotry: ${ARG_INSTALL_PATH}"
    exit 1
fi

case "$ARG_INSTALLER" in
    "chipyard")
        installBXEConfig
        installChipyard(${ARG_INSTALL_PATH})
        ;;

    "firesim")
        installBXEConfig
        installFireSim(${ARG_INSTALL_PATH})
        ;;

    *)
        echo "Invalid installer: ${ARG_INSTALLER}"
        usage
        exit 1
        ;;
esac

installProfile
