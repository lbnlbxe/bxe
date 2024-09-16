#!/bin/bash

BXE_TOOLS_SOURCE="/tools/source-vitis-2022.1.sh"

if [ -z "$XILINX_VIVADO" ]; then source $BXE_TOOLS_SOURCE > /dev/null; fi

LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | sed 's/:$//g')
PYTHONPATH=$(echo "$PYTHONPATH" | sed 's/:$//g')

