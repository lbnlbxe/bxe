export BXE_CONFIG_DIR=${HOME}/.bxe

export FIRESIM_HASH=
export CHIPYARD_HASH=

### Added FireSim and Chipyard Locations
export CHIPYARD_ROOT=
export FIRESIM_ROOT=
export FIREMARSHAL_ROOT=
export CONDA_ROOT=${HOME}/.conda

### Added Xilinx Tools  
source /tools/source-vitis-2023.1.sh  

### Added SSH Agent  
ssh-agent -s > ${HOME}/.ssh/AGENT_VARS
source ${HOME}/.ssh/AGENT_VARS &> /dev/null
ssh-add ${HOME}/.ssh/firesim.pem &> /dev/null

