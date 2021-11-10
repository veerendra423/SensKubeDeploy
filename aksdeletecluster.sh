#!/bin/bash

if [ -z "$1" ]; then
   echo please provide your name to be used as suffix
   exit 1
fi

if [ -z "$2" ]; then
   echo please provide your resource group
   exit 1
fi
mkdir -p install-tmp
echo "## Custom values" > install-tmp/del.env
kubectl get configmap customcfg -o json | jq  -r '.data."custom.env"' >> install-tmp/del.env 2> /dev/null
source install-tmp/del.env

if [ -z "$CLUSTER" ];then
  cluster=`kubectl config current-context | cut -d "-" -f 2`
else
  cluster=$CLUSTER
fi
cloudprovider=`kubectl config current-context | cut -d "-" -f 1`
if [ -z "$SUBDOMAIN" ];then
  subdomain=devel
else
  subdomain=$SUBDOMAIN
fi
if [ -z "$DOMAIN" ];then
  domain=sensoriant.net
else
  domain=$DOMAIN
fi


un=$1
resg=$2

if [ "$cluster" != "$un" ]; then
   echo "Please switch to the cluster you want to delete, and retry"
   exit 1
fi

while true; do
   read -p "Are you sure you want to delete cluster aks-$un?" yn
   case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "aborting ... "; exit 1;;
          * ) echo "Please answer yes or no.";;
   esac
done

az aks delete -n aks-$un -g $resg --yes


az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n api-$cluster -y
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n ui-$cluster -y
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n svr-$cluster -y
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n auth-$cluster -y

if [ "$cloudprovider" != "aks" ]; then
   az network dns record-set a delete \
     -g sensdns \
     -z $subdomain.$domain \
     -n rls-$cluster -y
fi

