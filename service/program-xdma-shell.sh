#!/bin/bash

BDF_LOCATION=$(/opt/xilinx/xrt/bin/xbmgmt examine | grep -E -o "[[:xdigit:]]{4}\:[[:xdigit:]]{2}\:[[:xdigit:]]{2}\.[[:xdigit:]]")
BDF_PATH=/lib/firmware/xilinx/12c8fafb0632499db1c0c6676271b8a6/partition.xsabin

/opt/xilinx/xrt/bin/xbmgmt program --device $BDF_LOCATION --shell $BDF_PATH

