#!/bin/bash

if [ -z "$1" ]; then
   echo "Usage: ./switchtocluster.sh cluster"
   echo "Example: ./switchtocluster.sh aks-luke1"
   exit 1
fi

cloudprovider=$(echo $1 | cut -d "-" -f 1)
if [ "$cloudprovider" == "aks" ]; then
   az aks list -o table | grep "^$1 " > /dev/null 2>&1
   if [ $? -eq 0 ]; then
      resg=$(az aks list -o table | grep "^$1 " | awk '{print $3}')
   else
      echo Unknown cluster $1
      exit 1
   fi

   set -e
   az aks get-credentials --resource-group $resg --name $1 --overwrite-existing
   kubectl config use-context $1
   set +e
   exit 0
fi

set -e
gkeproject=kube-project-305817
gkesvcaccount=852157164149-compute@developer.gserviceaccount.com
gkekeyfile=/mnt/staging/gkecreds/852157164149-compute@developer.gserviceaccount.com.json
gcloud auth activate-service-account $gkesvcaccount --key-file $gkekeyfile
gcloud config set project $gkeproject
gcloud config set compute/region us-east4
gcloud config set compute/zone us-east4-a
set +e
gcloud container clusters get-credentials $1
if [ $? -ne 0 ]; then
   echo Something wrong, cannot switch to cluster
   exit 1
fi

current_context=$(kubectl config current-context)
kubectl config delete-context $1 > /dev/null 2>&1
kubectl config rename-context $current_context $1 > /dev/null 2>&1
