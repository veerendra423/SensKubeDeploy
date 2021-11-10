#!/bin/bash

if [ "$#" -lt 2 ]; then
   echo "Usage: ./akscreatecluster.sh suffix resource-group [singlenode]"
   exit 1
fi

if [ -z "$1" ]; then
   echo please provide your name to be used as suffix
   exit 1
fi

if [ -z "$2" ]; then
   echo please provide your resource group
   exit 1
fi

un=$1
resg=$2

n=`az aks list -o table | grep aks-$un | wc -l`
if [ $n == "0" ]; then
	echo Ok to create new cluster
else
	echo aks cluster already exists 
	exit 1
fi

while true; do
   read -p "Are you sure you want to create a new cluster?" yn
   case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "aborting ... "; exit 1;;
          * ) echo "Please answer yes or no.";;
   esac
done

singlenode=false
ctrl_labels="sensctrlmode=enabled senssspmode=disabled"
ssp_np_name=nps$un
ctrl_np_name=npc$un
ctrl_machinetype=Standard_DC2s_v2
#sbox_machinetype=Standard_DC8_v2
sbox_machinetype=Standard_DC4s_v2
if [ ! -z "$3" ]; then
   if [ "$3" = "singlenode" ]; then
      singlenode=true
      ssp_np_name=$ctrl_np_name
      ctrl_labels="sensctrlmode=enabled senssspmode=enabled"
      #ctrl_machinetype=$sbox_machinetype
      ctrl_machinetype=Standard_DC8_v2
   fi
fi

# Create an AKS cluster
echo Creating a new cluster
set -e
az aks create \
	-n aks-$un \
	-g $resg \
	-c 1 \
	-s $ctrl_machinetype \
	--enable-managed-identity \
	--nodepool-name $ctrl_np_name \
	--nodepool-labels $ctrl_labels \
        --kubernetes-version "1.19.13" \
	--ssh-key-value ./utils/cm-data/nodes-ssh/id_rsa.pub 

if [ "$singlenode" != "true" ]; then
   echo Adding sandbox node
   az aks nodepool add \
	--cluster-name aks-$un \
	-g $resg \
	-c 1 \
	--labels sensctrlmode=disabled senssspmode=enabled \
	-s $sbox_machinetype \
        --kubernetes-version "1.19.13" \
	-n $ssp_np_name
fi

# get access to the new cluster
echo Getting credentials for the new cluster
az aks get-credentials --resource-group $resg --name aks-$un --overwrite-existing
set +e

echo Recording custom configuration for this cluster
if ! test -f "$PWD/config/custom.env"; then
   echo "#Custom cluster environment empty" > $PWD/config/custom.env
fi

kubectl create configmap customcfg --from-file=$PWD/config/custom.env

mkdir -p install-tmp
pushd ./utils >> /dev/null
./genclusterinfo.sh
if [ $? -ne 0 ]; then
   echo genclusterinfo failed
   popd >> /dev/null
   exit 1
fi
./configsbox.sh
if [ $? -ne 0 ]; then
   echo configsbox failed
   popd >> /dev/null
   exit 1
fi
popd >> /dev/null

c=$(kubectl get nodes -o wide --selector=senssspmode=enabled | tail -1 | awk -F "   +" '{print $10}' | grep containerd)
if [ $? -eq 0 ]; then
   echo -n Restarting sandbox to init certs for containerd runtime...
   vname=$(az vmss list -o table | grep ".*-$ssp_np_name-.*" | awk '{print $1}')
   resgname=$(az vmss list -o table | grep ".*-$ssp_np_name-.*" | awk '{print $2}')
   az vmss restart -n $vname -g $resgname --instance-ids 0
   sleep 10
   until ! (JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'  && kubectl get nodes -o jsonpath="$JSONPATH" | grep "Ready=False"); do echo -n ".." ; done
fi

echo Done...
