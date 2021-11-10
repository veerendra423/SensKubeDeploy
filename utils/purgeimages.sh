#!/bin/bash
  
pushd $HOME >> /dev/null

source ./cluster_info.env

rt="docker"
if [ "$KUBERNETES_RUNTIME" == "docker" ]; then
   im=$(docker images | grep sboxregistry | awk '{print $3}')
else
   im=$(sudo crictl images | grep sboxregistry | awk '{print $3}')
   rt="crictl"
fi

if [ ! -z "$im" ]; then
   $rt rmi $im
fi

popd >> /dev/null
