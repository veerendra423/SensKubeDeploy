#!/bin/bash

source ./cluster_info.env

ssh  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa $SENSNODE_USERNAME@$1 $2 2> /dev/null
