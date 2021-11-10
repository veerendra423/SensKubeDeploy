#!/bin/bash

mkdir -p ../install-tmp

cloudprovider=$(kubectl config current-context | cut -d "-" -f 1)

if [ $cloudprovider == "aks" ]; then
   sbnx=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*].status.addresses[?(@.type=="Hostname")]}{.address}{end}')
   sbnx1=$(echo $sbnx | sed 's/\(.*\)vmss.*/\1/')
   sbnx2=$(echo $sbnx | sed 's/.*0\(.*\)/\1/')
   if [ -z $sbnx2 ]; then
           sbnx2=0
   fi
   sbn="${sbnx1}vmss_${sbnx2}"
   
   ctrlnx=$(kubectl get nodes --selector=sensctrlmode=enabled -o jsonpath='{range.items[*].status.addresses[?(@.type=="Hostname")]}{.address}{end}')
   ctrlnx1=$(echo $ctrlnx | sed 's/\(.*\)vmss.*/\1/')
   ctrlnx2=$(echo $ctrlnx | sed 's/.*0\(.*\)/\1/')
   if [ -z $ctrlnx2 ]; then
           ctrlnx2=0
   fi
   ctrln="${ctrlnx1}vmss_${ctrlnx2}"

   echo "export SENSNODE_USERNAME=azureuser" > ../install-tmp/cluster_info.env
   echo "export KUBERNETES_PROVIDER=aks" >> ../install-tmp/cluster_info.env
fi

if [ $cloudprovider == "gke" ]; then
   sbn=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*]}{.metadata.name}{end}')
   ctrln=$(kubectl get nodes --selector=sensctrlmode=enabled -o jsonpath='{range.items[*]}{.metadata.name}{end}')
   #userinfo=$(gcloud compute ssh $sbn --command 'whoami' 2> /dev/null)
   echo "export SENSNODE_USERNAME=gkeuser" > ../install-tmp/cluster_info.env
   echo "export KUBERNETES_PROVIDER=gke" >> ../install-tmp/cluster_info.env
fi

echo "export SENSCTRL_NODENAME=$ctrln" >> ../install-tmp/cluster_info.env
echo "export SENSSSP_NODENAME=$sbn" >> ../install-tmp/cluster_info.env

c=$(kubectl get nodes -o wide --selector=senssspmode=enabled | tail -1 | awk -F "   +" '{print $10}' | grep containerd)
if [ $? -eq 0 ]; then
   echo "export KUBERNETES_RUNTIME=containerd" >> ../install-tmp/cluster_info.env
else
   echo "export KUBERNETES_RUNTIME=docker" >> ../install-tmp/cluster_info.env
fi
