#!/bin/bash

#rm ~/.ssh/firesim.pem* ~/.ssh/authorized_keys
ssh-keygen -t ed25519 -C "firesim.pem" -f ~/.ssh/firesim.pem -N ''
cat ~/.ssh/firesim.pem.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

