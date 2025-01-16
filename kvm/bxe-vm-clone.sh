#!/bin/bash

set -e
set -x

function displayUsage() {
	echo -e "\nUsage: sudo $0 original_vm new_vm \n"
}

function checkSudo() {
	# display usage if the script is not run as root user
	if [[ "$EUID" -ne 0 ]]; then
		echo "This script must be run with super-user privileges."
		displayUsage
		exit 1
	fi
}

function cloneVM () {
	local ORIG_VM=$1
	local NEW_VM=$2

	echo "Cloning VM ${ORIG_VM} to ${NEW_VM}..."
	virt-clone --original $ORIG_VM --name $NEW_VM --auto-clone
	echo "${NEW_VM} Clone complete."
}

function sysPrep () {
	local VM_NAME=$1
	local NEW_HOST_NAME=$2

	echo "Performing System Preperation on ${VM_NAME}..."
	echo "VM Hostname: ${NEW_HOST_NAME}"
	virt-sysprep -d $VM_NAME --operations user-account,defaults --hostname $NEW_HOST_NAME --keep-user-accounts bxeuser --firstboot-command 'dpkg-reconfigure openssh-server && ufw enable ssh'
	echo "System Preperation for ${VM_NAME} complete."
}

checkSudo

# if not exactly 2 arguments supplied, display usage
if [ "$#" -ne 2 ]; then
	echo "Incorrect number of arguments."
	displayUsage
	exit 1
fi

ARG_ORIGINAL_VM=$1
ARG_NEW_VM=$2
ARG_NEW_HOST_NAME=$ARG_NEW_VM

cloneVM $ARG_ORIGINAL_VM $ARG_NEW_VM
sysPrep $ARG_NEW_VM $ARG_NEW_HOST_NAME
