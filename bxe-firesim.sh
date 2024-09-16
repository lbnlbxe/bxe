export FIRESIM_HASH=1.20.1
export CHIPYARD_HASH=7eb2cc1

### Added FireSim and Chipyard Locations
export FIRESIM_ROOT=${HOME}/firesim
export CHIPYARD_ROOT=${FIRESIM_ROOT}/target-design/chipyard
export FIREMARSHAL_ROOT=${CHIPYARD_ROOT}/software/firemarshal
export FIRESIM_CONDA_ROOT=${HOME}/.conda

### Added Xilinx Tools  
source /tools/source-vitis-2023.1.sh  

### Added SSH Agent  
ssh-agent -s > ${HOME}/.ssh/AGENT_VARS
source ${HOME}/.ssh/AGENT_VARS &> /dev/null
ssh-add ${HOME}/.ssh/firesim.pem &> /dev/null

