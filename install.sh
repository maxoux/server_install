#/bin/bash

# FLAG_UPDATE=1
# FLAG_BASHRC=1
# FLAG_DOCKER=1
# FLAG_BTOP=1
# FLAG_NODE=1
# FLAG_FAIL2BAN=1
# FLAG_GPU

# FLAG_CLEANUP=1

USER=maxoux
BASHRC_URL=https://raw.githubusercontent.com/maxoux/server_install/main/.bashrc
WORK_DIR=$(mktemp -d)
PREV_DIR=$(pwd)

echo Working Directory: $WORK_DIR
cd $WORK_DIR

announce () {
  echo "\n\n\n"
  echo "----------------------------------------------------"
  echo $*;
  echo "----------------------------------------------------"
}

if [ -n "$FLAG_UPDATE" ]; then
  announce Updating...
  apt-get update -y && apt-get dist-upgrade -y && apt-get upgrade -y
fi

# Default installs
announce Installing basic utils
apt-get -y install git wget curl tree htop ca-certificates make openssh-server

# Bashrc
if [ -n "$FLAG_BASHRC" ]; then
  announce Installing bashrc
  wget $BASHRC_URL
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
  apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
if [ -n "$FLAG_BTOP" ]; then
  announce Installing Fail2Ban
  apt-get install fail2ban
  systemctl start fail2ban
  systemctl enable fail2ban
fi

# Nvidia driver


# Cleanup
announce Cleanup
cd $PREV_DIR
if [ -n "$FLAG_DOCKER" ]; then
  rm -rf $WORK_DIR
fi