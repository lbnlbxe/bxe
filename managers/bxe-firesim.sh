export FIRESIM_HASH=main
export CHIPYARD_HASH=main

### Added FireSim and Chipyard Locations
export CHIPYARD_ROOT=${HOME}/chipyard
export FIRESIM_ROOT=${CHIPYARD_ROOT}/sims/firesim
export FIREMARSHAL_ROOT=${CHIPYARD_ROOT}/software/firemarshal
export CONDA_ROOT=${HOME}/.conda

### Added Xilinx Tools  
source /tools/source-vitis-2023.1.sh  

### Added SSH Agent  
ssh-agent -s > ${HOME}/.ssh/AGENT_VARS
source ${HOME}/.ssh/AGENT_VARS &> /dev/null
ssh-add ${HOME}/.ssh/firesim.pem &> /dev/null

