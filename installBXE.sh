#!/bin/bash

set -e
set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

export BXE_CONFIG_DIR=${HOME}/.bxe
# Detect conda location - prefer system conda if available
if [ -d "/opt/conda" ]; then
    export CONDA_ROOT="/opt/conda"
else
    export CONDA_ROOT="${HOME}/.conda"
fi
export BASE_CHIPYARD_BLD_ARGS=""
export CONTAINER_CHIPYARD_BLD_ARGS="--skip 9 --skip 11"

function displayUsage() {
	echo "Usage: $0 <chipyard|firesim|bxe> [install_path]"
	echo "  <chipyard|firesim|bxe> : Install one of the following"
	echo "                           - Firesim within Chipyard (chipyard)"
	echo "                           - Standalone (firesim)"
	echo "                           - BXE FireSim Configs (bxe)"
	echo "                             *Requires Firesim install_path*"
	echo "  [install_path]         : Optional install path"
	echo "                           (default: ${HOME})"
}

function installBXEConfig() {
	echo -e "${BLUE}==>${NC} Installing BXE configuration..."
	SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
	mkdir -p ${BXE_CONFIG_DIR}
	if [ -f ${BXE_CONFIG_DIR}/bxe-firesim.sh ]; then
		DATE_TIME=$(date +"%Y%m%d_%H%M%S")
		echo -e "${YELLOW}  Backing up existing configuration${NC}"
		mv ${BXE_CONFIG_DIR}/bxe-firesim.sh ${BXE_CONFIG_DIR}/bxe-firesim-${DATE_TIME}.sh
	fi
	cp ${SCRIPT_DIR}/managers/* ${BXE_CONFIG_DIR}/.
	echo -e "${GREEN}  ✓ BXE configuration installed${NC}"

	# Replace placeholder {{HOME}} with actual home directory in config_build.yaml
	if [ -f "${BXE_CONFIG_DIR}/config_build.yaml" ]; then
		sed -i "s|{{HOME}}|${HOME}|g" "${BXE_CONFIG_DIR}/config_build.yaml"
	fi
}

function installProfile() {
	echo -e "${BLUE}==>${NC} Installing profile configuration..."
	BXE_SED_STRING="source "${BXE_CONFIG_DIR}"/bxe-firesim.sh"
	if ! grep -q "${BXE_SED_STRING}" ${HOME}/.bashrc; then
		sed -i '10a\'"${BXE_SED_STRING}"'\n' ${HOME}/.bashrc
		echo -e "${GREEN}  ✓ Profile configured${NC}"
	else
		echo -e "${YELLOW}  Profile already configured${NC}"
	fi
}

function installBXEFireSim() {
	echo -e "${BLUE}==>${NC} Installing BXE FireSim configurations..."
	local FIRESIM_DIR=$1
	cp ${BXE_CONFIG_DIR}/*.yaml ${FIRESIM_DIR}/deploy/.
	echo -e "${GREEN}  ✓ BXE FireSim configurations installed${NC}"
}

function installChipyard() {
	local INSTALL_PATH=$1
	cd ${HOME}

    echo -e "${BLUE}==>${NC} Cloning Chipyard repository..."
	git clone https://github.com/ucb-bar/chipyard ${INSTALL_PATH}
	cd ${INSTALL_PATH}

	CHIPYARD_GIT_HASH="$(git rev-parse --short HEAD)"
	CHIPYARD_GIT_ROOT="$(pwd)"
    echo -e "${GREEN}  ✓ Chipyard cloned at: ${CHIPYARD_GIT_ROOT}${NC}"
    echo -e "${GREEN}  ✓ Chipyard commit: ${CHIPYARD_GIT_HASH}${NC}"

	if [ -z "${BXE_CONTAINER}" ] ; then
		echo -e "${BLUE}==>${NC} Building Chipyard natively..."
		./build-setup.sh ${BASE_CHIPYARD_BLD_ARGS} || :
	else
		echo -e "${BLUE}==>${NC} Building Chipyard for a container..."
		./build-setup.sh ${BASE_CHIPYARD_BLD_ARGS} ${CONTAINER_CHIPYARD_BLD_ARGS} || :
	fi

	cd sims/firesim
	FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
	FIRESIM_GIT_ROOT="$(pwd)"
	echo -e "${GREEN}  ✓ FireSim location: ${FIRESIM_GIT_ROOT}${NC}"
    echo -e "${GREEN}  ✓ FireSim commit: ${FIRESIM_GIT_HASH}${NC}"

    cd ${HOME}

    sed -i '/CHIPYARD_HASH=/s/$/'"${CHIPYARD_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    awk -v dir=${CHIPYARD_GIT_ROOT} '{if ($0 ~ /CHIPYARD_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/temp && mv ${BXE_CONFIG_DIR}/temp ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_ROOT=/s|$|${CHIPYARD_ROOT}/sims/firesim|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIREMARSHAL_ROOT=/s|$|${CHIPYARD_ROOT}/software/firemarshal|' ${BXE_CONFIG_DIR}/bxe-firesim.sh

	installBXEFireSim ${FIRESIM_GIT_ROOT}
}

function installFireSim() {
    local INSTALL_PATH=$1
    cd ${HOME}

    echo -e "${BLUE}==>${NC} Cloning FireSim repository..."
    git clone https://github.com/firesim/firesim ${INSTALL_PATH}
    cd ${INSTALL_PATH}

    FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
    FIRESIM_GIT_ROOT="$(pwd)"

    echo -e "${GREEN}  ✓ FireSim cloned at: ${FIRESIM_GIT_ROOT}${NC}"
    echo -e "${GREEN}  ✓ FireSim commit: ${FIRESIM_GIT_HASH}${NC}"

    echo -e "${BLUE}==>${NC} Running build setup..."
    ./build-setup.sh

    cd ${HOME}

    # Update BXE configuration (standalone FireSim - no Chipyard)
    sed -i '/CHIPYARD_HASH=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/CHIPYARD_ROOT=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    awk -v dir=${FIRESIM_GIT_ROOT} '{if ($0 ~ /FIRESIM_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/temp && mv ${BXE_CONFIG_DIR}/temp ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i '/FIREMARSHAL_ROOT=/d' ${BXE_CONFIG_DIR}/bxe-firesim.sh
    sed -i "s|^export CONDA_ROOT=.*|export CONDA_ROOT=${CONDA_ROOT}|" ${BXE_CONFIG_DIR}/bxe-firesim.sh

	installBXEFireSim ${FIRESIM_GIT_ROOT}
}

function checkDirectory() {
	if [ -d ${ARG_INSTALL_PATH} ]; then
		echo -e "${RED}Error: Directory exists, cannot override existing directory: ${ARG_INSTALL_PATH}${NC}"
		exit 1
	fi
}

function checkSSHKey() {
	echo -e "${BLUE}==>${NC} Checking SSH key..."
	if [ ! -f "${HOME}/.ssh/firesim.pem" ]; then
		echo -e "${YELLOW}  SSH key not found, regenerating...${NC}"
		SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
		${SCRIPT_DIR}/regenSSHKey.sh
	else
		echo -e "${GREEN}  ✓ SSH key already exists${NC}"
	fi

	echo -e "${BLUE}==>${NC} FireSim Public Key:"
	echo -e "${YELLOW}$(cat ${HOME}/.ssh/firesim.pem.pub)${NC}"
	echo ""
	echo -e "${YELLOW}Please send the public key above to the admin to ensure it exists on the FireSim runner machines.${NC}"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Incorrect number of arguments."
	displayUsage
	exit 1
fi

ARG_INSTALL_PATH=${2:-${ARG_INSTALLER}}
ARG_INSTALLER=$1

case "$ARG_INSTALLER" in
	"chipyard")
		checkDirectory
		installBXEConfig
		installChipyard ${ARG_INSTALL_PATH}
		;;

	"firesim")
		checkDirectory
		installBXEConfig
		installFireSim ${ARG_INSTALL_PATH}
		;;

	"bxe")
		if [ ! -d ${ARG_INSTALL_PATH}/deploy ]; then
			echo "Provided FireSim path does not exist: ${ARG_INSTALL_PATH}/deploy"
			displayUsage
			exit 1
		fi
		# Prompt to reset BXE configuration
		read -r -p "Would you like to reset the BXE configuration before proceeding? (y/[n]) " answer
		if [[ "$answer" =~ ^[Yy]$ ]]; then
    		installBXEConfig
		fi
		installBXEFireSim ${ARG_INSTALL_PATH}
		;;

	*)
		echo "Invalid installer: ${ARG_INSTALLER}"
		displayUsage
		exit 1
		;;
esac

installProfile

checkSSHKey

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}BXE Install Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

exit 0
