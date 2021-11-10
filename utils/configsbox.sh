#!/bin/bash 

source ../install-tmp/cluster_info.env

# get sandbox ip
#sboxes=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}')
sboxip=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*].status.addresses[?(@.type=="InternalIP")]}{.address}{end}')

if [ ! -z "$SCONE_SMALL_BASE_IMAGENAME" ]; then
   baseimagename=prefetchedimage
   kubectl get pods | grep "^$baseimagename" >> /dev/null 2>&1
   if [ $? -ne 0 ]; then
     kubectl run  $baseimagename --image=$SCONE_SMALL_BASE_IMAGENAME:$SCONE_SMALL_BASE_TAG --restart=Never --overrides='{ "apiVersion": "v1", "spec": { "imagePullSecrets": [{"name": "sens-reg-cred"}], "nodeSelector": { "senssspmode": "enabled" } } }' -- echo hello 
     echo -n Waiting for base image to be prefetched...
     while [[ $(kubectl get pods $baseimagename -o 'jsonpath={..status.conditions[?(@.type=="Ready")].reason}') != "PodCompleted" ]]; 
     do
        echo -n ".."
        sleep 5
     done
     echo ""
   fi
fi

#Start an ssh pod
kubectl run  ourssh --image=mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11 --restart=Never --overrides='{ "apiVersion": "v1", "spec": { "nodeSelector": { "sensctrlmode": "enabled" } } }' -- sleep 3600
### wait for it to start
echo -n Waiting for ssh pod to start...
while [[ $(kubectl get pods ourssh -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; 
do
   echo -n ".."
   sleep 5
done
echo ""
### install openssh client on ssh pod
kubectl exec ourssh -- bash -c "apt-get update && apt-get install openssh-client -y" > /dev/null

set -e 
### copy the required files to the ssh pod
kubectl cp ./cm-data/nodes-ssh/id_rsa $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/id_rsa
kubectl cp ./sgx_scripts.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/sgx_scripts.sh
kubectl cp ./nodessh.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/nodessh.sh
kubectl cp ./nodescp.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/nodescp.sh
kubectl cp ./cm-data/reg-certs/tls.crt $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/tls.crt
kubectl cp ./reg_cert.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/reg_cert.sh
kubectl cp ./set_sboxreg.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/set_sboxreg.sh
kubectl cp ./setcron.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/setcron.sh
kubectl cp ./purgeimages.sh $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/purgeimages.sh
kubectl cp ../install-tmp/cluster_info.env $(kubectl get pod -l run=ourssh -o jsonpath='{.items[0].metadata.name}'):/cluster_info.env

### set appropriate file permissions
kubectl exec ourssh -- bash -c "chmod 0600 id_rsa"
kubectl exec ourssh -- bash -c "chmod +x *.sh"

# install the SGX kernel modules on the cluster nodes
echo Make sure you install sgx kernel modules on all the ssp nodes
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip cluster_info.env"
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip sgx_scripts.sh"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'sudo ./sgx_scripts.sh'"

# set cron job to delete docker cache images
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip purgeimages.sh"
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip setcron.sh"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'sudo ./setcron.sh'"

# install registry certs
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip set_sboxreg.sh"
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip tls.crt"
kubectl exec ourssh -- bash -c "./nodescp.sh $sboxip reg_cert.sh"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'sudo ./reg_cert.sh'"

# install sboxregistry ip in /etc/hosts
regip=`kubectl get pods -o wide | grep ssp-reg | awk '{print $6}'`
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'sudo ./set_sboxreg.sh $regip'"

# create the keys directory for upload policies
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algoinput1'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algooutput1'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algoinput2'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algooutput2'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algoinput3'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algooutput3'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algoinput4'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/algooutput4'"
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/datasets'"

#### DEBUG stuff - NOT for production
kubectl exec ourssh -- bash -c "./nodessh.sh $sboxip 'mkdir -p /home/$SENSNODE_USERNAME/laslogs'"
### end DEBUG
set +e 

# delete the ssh pod
kubectl delete pod ourssh
