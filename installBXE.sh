#!/bin/bash

export BXE_CONFIG_DIR=${HOME}/.bxe

function installBXEConfig() {
    mkdir -p ${BXE_CONFIG_DIR}
    cp managers/bxe-firesim.sh ${BXE_CONFIG_DIR}/.
}

function installChipyard() {
    cd ${HOME}
    git clone https://github.com/ucb-bar/chipyard
    cd chipyard
    CHIPYARD_GIT_HASH="$(git rev-parse --short HEAD)"
    CHIPYARD_GIT_ROOT="$(pwd)"
    ./build-setup.sh
    cd sims/firesim
    FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
    cd

    sed -i '/CHIPYARD_HASH=/s/$/'"${CHIPYARD_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    awk -v dir=${CHIPYARD_GIT_ROOT} '{if ($0 ~ /CHIPYARD_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_ROOT=/s|$|${CHIPYARD_ROOT}/sims/firesim|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIREMARSHAL_ROOT=/s|$|${CHIPYARD_ROOT}/software/firemarshal|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
}

function installProfile() {
    BXE_SED_STRING="source "${BXE_CONFIG_DIR}"/bxe-firesim.sh"
    if ! grep -q "${BXE_SED_STRING}" ${HOME}/.bashrc; then
        sed -i '10a\'"${BXE_SED_STRING}"'\n' ${HOME}/.bashrc
    fi
}

installBXEConfig
installChipyard
installProfile
