#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

GROUPS=(firesim kvm)

function displayUsage() {
    echo -e "Usage: sudo $0 <username>"
}

function checkRoot() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${RED}Error: this script must be run as root${NC}"
        displayUsage
        exit 1
    fi
}

function validateGroups() {
    local missing=()
    for grp in "${GROUPS[@]}"; do
        if ! getent group "$grp" >/dev/null; then
            missing+=("$grp")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: the following groups do not exist: ${missing[*]}${NC}"
        exit 1
    fi
}

function addUser() {
    local user="$1"
    if id -u "$user" >/dev/null 2>&1; then
        echo -e "${YELLOW}User $user already exists${NC}"
        exit 0
    fi
    adduser "$user"
    usermod -aG "${GROUPS[*]}" "$user"
    echo -e "${GREEN}User $user added and added to groups: ${GROUPS[*]}${NC}"
}

checkRoot
if [[ -z "$1" ]]; then
    displayUsage
    exit 1
fi
USERNAME="$1"
validateGroups
addUser "$USERNAME"
