#!/bin/bash

FLAG_UPDATE=1
# Basic setup like putting me in sudo & setting up ssh keys
FLAG_BASIC=1
FLAG_APT=1
FLAG_BASHRC=1
FLAG_DOCKER=1
FLAG_BTOP=1
FLAG_NODE=1
FLAG_FAIL2BAN=1
# FLAG_GPU=1
# FLAG_GPU_DOCKER_TOOLKIT=1
# FLAG_ZFS=1
FLAG_BACKUP=1
FLAG_BACKUP_INSTALL_SCRIPTS=1
FLAG_BACKUP_INSTALL_SSH=1
FLAG_BACKUP_INIT_BORG_REPO=1
FLAG_BACKUP_INSTALL_CRON=1

# FLAG_CLEANUP=1

ACTUAL_HOST=$(hostname)

USER=maxoux
INSTALL_REPO=https://github.com/maxoux/server_install
REPO_DIR=repo
WORK_DIR=$(mktemp -d)
PREV_DIR=$(pwd)

# Backup vars
declare -A BACKUP_DEST
BACKUP_DEST[yuna]=/storage/backup/borg
BACKUP_DEST[panam]=/home/backup/borg


announce () {
  echo -e "\n\n\n"
  echo "----------------------------------------------------"
  echo $*;
  echo "----------------------------------------------------"
}

# Check root
if [ "$(id -u)" -ne 0 ]; then echo "Please run as root." >&2; exit 1; fi

echo Working Directory: $WORK_DIR
cd $WORK_DIR


if [ -n "$FLAG_BASIC" ]; then
  # Default installs
  announce Installing basic utils
  apt-get update
  apt-get -y install git wget curl tree htop ca-certificates make openssh-server sudo borgbackup

  announce Cloning Repository
fi
git clone $INSTALL_REPO $REPO_DIR

if [ -n "$FLAG_APT" ]; then
  announce Override apt source lists
  cp ./$REPO_DIR/source.list /etc/apt/sources.list
  apt-get update

  if [ -n "$FLAG_UPDATE" ]; then
    announce Updating...
    apt-get update -y && apt-get upgrade -y
  fi
fi

if [ -n "$FLAG_BASIC" ]; then
  announce Set up $USER as sudoer
  /usr/sbin/usermod -aG sudo maxoux

  # SSH
  announce Setting up SSH keys
  mkdir /home/$USER/.ssh
  cat ./$REPO_DIR/public_keys/$ACTUAL_HOST/* > /home/$USER/.ssh/authorized_keys
fi

# Bashrc
if [ -n "$FLAG_BASHRC" ]; then
  echo "Copy backup scripts..."
  cp -r $REPO_DIR/backup_script ~/
  mv $REPO_DIR/.bashrc /home/$USER/
fi

# Nvidia driver
if [ -n "$FLAG_GPU" ]; then
  announce Install GPU drivers
  apt install -y nvidia-kernel-dkms
  apt-get install -y nvidia-driver
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

# Btop
BTOP_URL=https://github.com/aristocratos/btop.git
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
  source /home/$USER/.bashrc
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
  sudo apt install -y linux-headers-amd64
  sudo apt install -y -t stable-backports zfsutils-linux
  zpool import storage -f
fi

# BACKUP
if [ -n "$FLAG_BACKUP" ]; then
  announce "Installing Backup setup..."

  if [ -n "$FLAG_BACKUP_INSTALL_SCRIPTS" ]; then
    echo "Installing backup scripts..."
    cp -r ${WORK_DIR}/${REPO_DIR}/backup_script ~/
  fi


  if [ -n "$FLAG_BACKUP_INSTALL_SSH" ]; then
    echo "purging .ssh/config..."
    echo > ~/.ssh/config
  fi

  for TARGET in "${!BACKUP_DEST[@]}"; 
  do
    REPO_PASSWORD=$(openssl rand -hex 32)

    if [ -n "$FLAG_BACKUP_INSTALL_SSH" ]; then
      echo "Installing ssh keys on ${TARGET[0]}"
      ssh-keygen -f /root/.ssh/${TARGET[0]}_backup -P ""
      ssh-copy-id -i /root/.ssh/${TARGET[0]}_backup backup@${TARGET}.laize.pro
      echo "Writing backup ssh configuration..."
      echo -e "Host ${TARGET}_backup\n  Hostname ${TARGET[0]}.laize.pro\n  User backup\n  PreferredAuthentications publickey\n  IdentityFile /root/.ssh/${TARGET[0]}_backup" >> /root/.ssh/config
    fi

    if [ -n "$FLAG_BACKUP_INIT_BORG_REPO" ]; then
      echo "Creating borg repository on ${TARGET}:${BACKUP_DEST[${TARGET}]}/${ACTUAL_HOST}"
      ssh ${TARGET}_backup "BORG_PASSPHRASE=${REPO_PASSWORD} borg init --encryption=repokey ${BACKUP_DEST[${TARGET}]}/${ACTUAL_HOST}" > /dev/null
      announce "REPOSITORY PASWORD FOR ${TARGET}, KEEP IT => ${REPO_PASSWORD}"
    fi


    if [ -n "$FLAG_BACKUP_INSTALL_SCRIPTS" ]; then
      echo "Adding scripts credentials..."
      echo "BACKUP_DEST[${TARGET}]=ssh://${TARGET}_backup${BACKUP_DEST[${TARGET}]}/${ACTUAL_HOST}" >> ~/backup_script/credentials.sh
      echo "BACKUP_KEYS[${TARGET}]=${REPO_PASSWORD}" >> ~/backup_script/credentials.sh
      echo "" >> ~/backup_script/credentials.sh
      echo "PASWORD FOR ${TARGET}, KEEP IT => ${REPO_PASSWORD}"
    fi


    if [ -n "$FLAG_BACKUP_INSTALL_CRON" ]; then
      command="/root/backup_script/backup.sh >> /var/log/borg.log"
      job="0 4 * * * $command"
      echo "Adding crontab..."
      cat <(fgrep -i -v "$command" <(crontab -l)) <(echo "$job") | crontab -
    fi

    echo Backup setup complete !
  done


fi



# Cleanup
announce Cleanup
cd $PREV_DIR
if [ -n "$FLAG_CLEANUP" ]; then
  rm -rf $WORK_DIR
fi