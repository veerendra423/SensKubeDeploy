#!/bin/bash

source ./cluster_info.env

scp  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa $2 $SENSNODE_USERNAME@$1:$2 2> /dev/null
