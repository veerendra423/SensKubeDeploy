#!/bin/bash

source ./cluster_info.env

mkdir -p /etc/docker/certs.d
mkdir -p /etc/docker/certs.d/sboxregistry:5000
if test -f "/etc/docker/certs.d/sboxregistry:5000/ca.crt"; then
   diff tls.crt /etc/docker/certs.d/sboxregistry:5000/ca.crt
   if [ $? -ne 0 ]; then
      echo installing registry certificates
   else
      echo registry certificates already installed
      exit 0
   fi
fi
cp tls.crt /etc/docker/certs.d/sboxregistry:5000/ca.crt
cp tls.crt /usr/local/share/ca-certificates/sboxregistry.crt
update-ca-certificates

if [ "$KUBERNETES_RUNTIME" == "docker" ]; then
   service docker restart
fi
