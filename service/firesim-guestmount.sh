#!/bin/bash

CURRENT_KERNEL="/boot/vmlinuz-$(uname -r)"

if ! [[ $(stat -c "%a" "$CURRENT_KERNEL") == 644 ]] ; then 
  dpkg-statoverride --add --update root root 0644 $CURRENT_KERNEL
else
  echo "$CURRENT_KERNEL is already readable. Guestmount should work."
fi

