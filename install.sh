#/bin/bash

USER=maxoux
BASHRC_URL=

apt-get update -y && apt-get dist-upgrade -y && apt-get upgrade -y

# Default installs
apt-get install git wget curl tree htop
# Bashrc
# Docker
# Zfs
# Btop
# Nodejs
# SSH
# fail2ban
# Nvidia driver