#!/bin/bash

# set -e
# set -x

export BXE_CONFIG_DIR=${HOME}/.bxe
export CONDA_ROOT=${HOME}/.conda
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
	SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
	mkdir -p ${BXE_CONFIG_DIR}
	if [ -f ${BXE_CONFIG_DIR}/bxe-firesim.sh ]; then
		DATE_TIME=$(date +"%Y%m%d_%H%M%S")
		mv ${BXE_CONFIG_DIR}/bxe-firesim.sh ${BXE_CONFIG_DIR}/bxe-firesim-${DATE_TIME}.sh
	fi
	cp ${SCRIPT_DIR}/managers/* ${BXE_CONFIG_DIR}/.

	# Replace placeholder {{HOME}} with actual home directory in config_build.yaml
	if [ -f "${BXE_CONFIG_DIR}/config_build.yaml" ]; then
		sed -i "s|{{HOME}}|${HOME}|g" "${BXE_CONFIG_DIR}/config_build.yaml"
	fi
}

function installProfile() {
	BXE_SED_STRING="source "${BXE_CONFIG_DIR}"/bxe-firesim.sh"
	if ! grep -q "${BXE_SED_STRING}" ${HOME}/.bashrc; then
		sed -i '10a\'"${BXE_SED_STRING}"'\n' ${HOME}/.bashrc
	fi
}

function installBXEFireSim() {
	local FIRESIM_DIR=$1
	cp ${BXE_CONFIG_DIR}/*.yaml ${FIRESIM_DIR}/deploy/.
}

function installChipyard() {
	local INSTALL_PATH=$1
	cd ${HOME}
	git clone https://github.com/ucb-bar/chipyard ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	CHIPYARD_GIT_HASH="$(git rev-parse --short HEAD)"
	CHIPYARD_GIT_ROOT="$(pwd)"
	if [ -z "${BXE_CONTAINER}" ] ; then
		echo "[INFO] Building Chipyard natively."
		./build-setup.sh ${BASE_CHIPYARD_BLD_ARGS} || :
	else
		echo "[INFO] Building Chipyard for a container."
		./build-setup.sh ${BASE_CHIPYARD_BLD_ARGS} ${CONTAINER_CHIPYARD_BLD_ARGS} || :
	fi

	cd sims/firesim
	FIRESIM_GIT_HASH="$(git rev-parse --short HEAD)"
	FIRESIM_GIT_ROOT="$(pwd)"
	cd

	sed -i '/CHIPYARD_HASH=/s/$/'"${CHIPYARD_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
	awk -v dir=${CHIPYARD_GIT_ROOT} '{if ($0 ~ /CHIPYARD_ROOT=/) $0 = $0 dir; print}' ${BXE_CONFIG_DIR}/bxe-firesim.sh > ${BXE_CONFIG_DIR}/temp && mv temp ${BXE_CONFIG_DIR}/bxe-firesim.sh
	sed -i '/FIRESIM_HASH=/s/$/'"${FIRESIM_GIT_HASH}"'/' ${BXE_CONFIG_DIR}/bxe-firesim.sh
	sed -i '/FIRESIM_ROOT=/s|$|${CHIPYARD_ROOT}/sims/firesim|' ${BXE_CONFIG_DIR}/bxe-firesim.sh
	sed -i '/FIREMARSHAL_ROOT=/s|$|${CHIPYARD_ROOT}/software/firemarshal|' ${BXE_CONFIG_DIR}/bxe-firesim.sh

	installBXEFireSim ${FIRESIM_GIT_ROOT}
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

	installBXEFireSim ${FIRESIM_GIT_ROOT}
}

function checkDirectory() {
	if [ -d ${ARG_INSTALL_PATH} ]; then
		echo "Directory exists, cannot override existing direcotry: ${ARG_INSTALL_PATH}"
		exit 1
	fi
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	echo "Incorrect number of arguments."
	displayUsage
	exit 1
fi

ARG_INSTALLER=$1
ARG_INSTALL_PATH=${2:-${ARG_INSTALLER}}

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
		installBXEFireSim ${ARG_INSTALL_PATH}
		;;

	*)
		echo "Invalid installer: ${ARG_INSTALLER}"
		displayUsage
		exit 1
		;;
esac

installProfile

echo "BXE Install Complete!"

exit 0
