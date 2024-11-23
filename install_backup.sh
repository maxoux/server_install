#!/bin/bash

ACTUAL_HOST=panam

declare -A BACKUP_DEST
BACKUP_DEST[yuna]=/storage/backup/borg

echo "Copy backup scripts..."
cp -r ./backup_script ~/

for TARGET in "${!BACKUP_DEST[@]}"; 
do
    echo "Installing ssh keys on ${TARGET[0]}"
    ssh-keygen -f /root/.ssh/${TARGET[0]}_backup -P ""
    ssh-copy-id -i /root/.ssh/${TARGET[0]}_backup backup@${TARGET}.laize.pro

    echo "Writing ssh configuration..."
    echo -e "Host ${TARGET}_backup\n  Hostname ${TARGET[0]}.laize.pro\nUser backup\n  PreferredAuthentications publickey\n  IdentityFile /root/.ssh/${TARGET[0]}_backup" > /root/.ssh/config

    echo "Creating borg repository on ${TARGET}:${BACKUP_DEST[${TARGET}]}/${ACTUAL_HOST}"
    ssh ${TARGET}_backup "BORG_PASSPHRASE=lalilulelo borg init --encryption=repokey ${BACKUP_DEST[${TARGET}]}/${ACTUAL_HOST}" > /dev/null

    echo "Copy backup scripts..."
done