#!/bin/bash

export YUNA_REPO='/storage/backup/borg/yuna'
export YUNA_PASS='9PWBtl4w9y4lC2e8L9fIGdUoTdbawDR5nLqGZtOo7ZS0DHpenVaises71U5eGfZg'

export PANAM_REPO='ssh://backup@panam_backup/home/backup/borg/yuna'
export PANAM_PASS='tCraAD412Drkw6gB5k9fj9r25TT7NOUopbmxR99FEb1l6qoy42p7ZXllHciqmcNt'

export FIXE_REPO='ssh://backup@fixe_backup/disk/borg/backup/yuna'
export FIXE_PASS='kAcqwADLA5g0Va7eRNZjUjGLbptejHaX'

echo Stopping Docker...
systemctl stop docker
systemctl stop docker.socket

echo Backup to Local Storage
export BORG_REPO=$YUNA_REPO
export BORG_PASSPHRASE=$YUNA_PASS
. /root/backup_script/borg.sh

echo Backup to Distant Storage
export BORG_REPO=$PANAM_REPO
export BORG_PASSPHRASE=$PANAM_PASS
. /root/backup_script/borg.sh

echo Backup to Distant Storage
export BORG_REPO=$FIXE_REPO
export BORG_PASSPHRASE=$FIXE_PASS
. /root/backup_script/borg.sh

sleep 5
echo Starting up docker socket
systemctl start docker.socket
sleep 5
echo Starting up docker
systemctl start docker

echo "Archive List on Yuna site : "
BORG_PASSPHRASE=$YUNA_PASS borg list $YUNA_REPO
echo ""
echo "Archive list on Panam site : "
BORG_PASSPHRASE=$PANAM_PASS borg list $PANAM_REPO
echo ""
echo "Archive list on Fixe site : "
BORG_PASSPHRASE=$FIXE_PASS borg list $FIXE_REPO