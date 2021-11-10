#!/bin/bash

if [ -z "$1" ]; then
   echo please provide your name to be used as suffix
   exit 1
fi

un=g$1
while true; do
	read -p "Are you sure you want to delete cluster gke-$un?(y/n) " yn
   case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "aborting ... "; exit 1;;
          * ) echo "Please answer yes or no.";;
   esac
done

mkdir -p install-tmp
echo "## Custom values" > install-tmp/del.env
kubectl get configmap customcfg -o json | jq  -r '.data."custom.env"' >> install-tmp/del.env 2> /dev/null
source install-tmp/del.env

if [ -z "$CLUSTER" ];then
  cluster=`kubectl config current-context | cut -d "-" -f 2`
else
  cluster=$CLUSTER
fi
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

if [ "$cluster" != "$un" ]; then
   echo "Please switch to the cluster you want to delete, and retry"
   exit 1
fi

ssp_np_name=nps$un
ctrl_np_name=npc$un

# configure SKIF
echo -n Deleting SKIF..
pushd ./utils >> /dev/null
./skifconfig.sh del 
popd >> /dev/null
echo ...done

gcloud container node-pools delete --cluster gke-$un $ctrl_np_name --quiet
gcloud container node-pools delete --cluster gke-$un $ssp_np_name --quiet
gcloud container clusters delete gke-$un --quiet
kubectl config delete-context gke-$un

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
  -n rls-$cluster -y


