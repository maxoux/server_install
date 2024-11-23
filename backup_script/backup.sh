#!/bin/bash

# Get backup repository list and credentials
. /root/backup_script/credentials.sh

echo Stopping Docker...
systemctl stop docker
systemctl stop docker.socket

for TARGET in "${!BACKUP_DEST[@]}"; 
do
    echo -e "\nBackup to ${TARGET} => ${BACKUP_DEST[${TARGET}]}\n\n"
    export BORG_REPO=${BACKUP_DEST[${TARGET}]}
    export BORG_PASSPHRASE=${BACKUP_KEYS[${TARGET}]}
    . /root/backup_script/borg.sh
done

sleep 5
echo Starting up docker socket
systemctl start docker.socket
sleep 5
echo Starting up docker
systemctl start docker