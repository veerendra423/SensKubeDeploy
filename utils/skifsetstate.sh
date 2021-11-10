#!/bin/bash


cluster=`kubectl config current-context`
prov=$(echo $cluster | cut -d "-" -f 1)
if [ "$prov" == "aks" ]; then
   echo SKIF not needed for aks
   exit 0
fi

if [ -z $1 ]; then
   echo "Usage: //skifsetstate.sh up/down"
   exit 1
fi

kubectl get configmap skifmap -o json | jq -r '.data.skif' | grep "^SKIF_" > ../install-tmp/skif 2> /dev/null
source ../install-tmp/skif
casip=$SKIF_IP
casipuser=sensuser
casattestport=$SKIF_CASATTEST_PORT
sshopts="-i ./cm-data/nodes-ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if [ "$1" == "up" ]; then
   echo -n "Starting SKIF..."
   ssh $sshopts $casipuser@$casip "cd $casattestport && docker-compose up -d"
   echo Done
elif [ "$1" == "down" ]; then
   echo -n "Stopping SKIF..."
   ssh $sshopts $casipuser@$casip "cd $casattestport && docker-compose down --remove-orphans"
   echo Done
else
   echo "Please specify up/down"
   exit 1
fi

