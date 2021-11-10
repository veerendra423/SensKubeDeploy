#!/bin/bash

source ./cluster_info.env

grep "purgeimages.sh" /etc/crontab > /dev/null
cat /etc/crontab | grep -v purgeimages > ct
mv ct /etc/crontab
echo "*/5 * * * * $SENSNODE_USERNAME /home/$SENSNODE_USERNAME/purgeimages.sh" >> /etc/crontab
