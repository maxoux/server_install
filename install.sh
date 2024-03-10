#/bin/bash

FLAG_UPDATE=1
FLAG_BASHRC=1
FLAG_DOCKER=1
FLAG_BTOP=1
FLAG_NODE=1
FLAG_FAIL2BAN=1
FLAG_GPU=1
FLAG_GPU_DOCKER_TOOLKIT=1
FLAG_ZFS=1

FLAG_CLEANUP=1

USER=maxoux
INSTALL_REPO=https://github.com/maxoux/server_install
REPO_DIR=repo
WORK_DIR=$(mktemp -d)
PREV_DIR=$(pwd)


announce () {
  echo "\n\n\n"
  echo "----------------------------------------------------"
  echo $*;
  echo "----------------------------------------------------"
}

# Check root
if [ "$(id -u)" -ne 0 ]; then echo "Please run as root." >&2; exit 1; fi

echo Working Directory: $WORK_DIR
cd $WORK_DIR

if [ -n "$FLAG_UPDATE" ]; then
  announce Updating...
  apt-get update -y && apt-get dist-upgrade -y && apt-get upgrade -y
fi

# Default installs
announce Installing basic utils
apt-get -y install git wget curl tree htop ca-certificates make openssh-server sudo

announce Cloning Repository
git clone $INSTALL_REPO $REPO_DIR

announce Set up $USER as sudoer
usermod -aG sudo maxoux

# SSH
announce Setting up SSH keys
cat public_keys/* > /home/$USER/.ssh/authorized_keys

# Bashrc
if [ -n "$FLAG_BASHRC" ]; then
  announce Installing bashrc
  mv $REPO_DIR/.bashrc /home/$USER/
fi

# Docker
if [ -n "$FLAG_DOCKER" ]; then
  announce Installing Docker
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  announce Enabling docker for $USER
  usermod -aG docker maxoux
fi

# Btop
BTOP_URL=git@github.com:aristocratos/btop.git
if [ -n "$FLAG_BTOP" ]; then
  announce Installing Btop
  git clone $BTOP_URL
  cd btop
  make
  make install
fi

# Nodejs
if [ -n "$FLAG_NODE" ]; then
  announce Install Node.JS
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - &&\
  sudo apt-get install -y nodejs
  announce Install NVM
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  nvm install 20
  nvm use 20
fi

# fail2ban
if [ -n "$FLAG_FAIL2BAN" ]; then
  announce Installing Fail2Ban
  apt-get install -y fail2ban
  systemctl start fail2ban
  systemctl enable fail2ban
fi

# ZFS
if [ -n "$FLAG_ZFS" ]; then
  announce Install ZFS Drivers
  apt-get install -y linux-headers-amd64 zfsutils-linux zfs-dkms zfs-zed
  zpool import storage -f
fi

# Nvidia driver
if [ -n "$FLAG_GPU" ]; then
  announce Install GPU drivers
  apt-get install -y nvidia-driver

  if [ -n "$FLAG_GPU_DOCKER_TOOLKIT" ]; then
    announce Install GPU Docker Toolkit
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
  fi
fi

# Cleanup
announce Cleanup
cd $PREV_DIR
if [ -n "$FLAG_DOCKER" ]; then
  rm -rf $WORK_DIR
fi