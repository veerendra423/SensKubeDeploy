#!/bin/bash

if [ "$#" -lt 2 ]; then
   echo "Usage: ./gkecreatecluster.sh suffix skif-ipaddr [singlenode]"
   exit 1
fi

if [ -z "$1" ]; then
   echo please provide your name to be used as suffix
   exit 1
fi

if [ -z "$2" ]; then
   echo please provide SKIF ip address
   exit 1
fi

un=g$1
skifip=$2

gkeproject=kube-project-305817
gkesvcaccount=852157164149-compute@developer.gserviceaccount.com
gkekeyfile=/mnt/staging/gkecreds/852157164149-compute@developer.gserviceaccount.com.json
#gkelibattestso=./utils/cm-data/gcloud/libattestation-python.so
gkelibattestso=/mnt/staging/libattestation-python.so

set -e
gcloud auth activate-service-account --key-file $gkekeyfile
gcloud config set project $gkeproject
gcloud config set compute/region us-east4
gcloud config set compute/zone us-east4-a
set +e

n=`gcloud container clusters list | grep gke-$un | wc -l`
if [ $n == "0" ]; then
	echo Ok to create new cluster
else
	echo gke cluster already exists 
	exit 1
fi

while true; do
	read -p "Are you sure you want to create a new cluster?(y/n) " yn
   case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo "aborting ... "; exit 1;;
          * ) echo "Please answer yes or no.";;
   esac
done
#

mkdir -p install-tmp
singlenode=false
ctrl_labels="sensctrlmode=enabled,senssspmode=disabled"
ssp_np_name=nps$un
ctrl_np_name=npc$un
ctrl_machinetype=n2-standard-8
ssp_machinetype=n2-standard-16
if [ ! -z "$3" ]; then
   if [ "$3" = "singlenode" ]; then
      singlenode=true
      ssp_np_name=$ctrl_np_name
      ctrl_labels="sensctrlmode=enabled,senssspmode=enabled"
      ctrl_machinetype="n2-standard-16"
   fi
fi

# Create an GKE cluster
set -e
echo Creating a new cluster
	#--release-channel=stable \
#--node-version
gcloud container clusters create gke-$un \
       	--num-nodes=1 \
	--zone=us-east4-a \
	--node-labels=$ctrl_labels \
	--cluster-version=1.19.13 \
        --no-enable-autoupgrade \
	--machine-type=$ctrl_machinetype

echo Adding controller node
	#--metadata-from-file=user-data=./utils/cm-data/gcloud/userconfig \
gcloud container node-pools create $ctrl_np_name \
	--cluster=gke-$un \
       	--num-nodes=1 \
	--zone=us-east4-a \
	--node-labels=$ctrl_labels \
        --no-enable-autoupgrade \
	--machine-type=$ctrl_machinetype \
        --image-type=UBUNTU_CONTAINERD \
	--disk-size=200GB \
	--disk-type=pd-ssd \
	--metadata enable-os-login=true

# Delete default-pool
gcloud container node-pools delete default-pool --cluster=gke-$un --quiet

if [ "$singlenode" != "true" ]; then
   echo Adding sandbox node
   gcloud container node-pools create $ssp_np_name \
	--cluster=gke-$un \
       	--num-nodes=1 \
	--zone=us-east4-a \
	--node-labels=sensctrlmode=disabled,senssspmode=enabled \
        --no-enable-autoupgrade \
	--machine-type=$ssp_machinetype \
        --image-type=UBUNTU_CONTAINERD \
	--disk-size=200GB \
	--disk-type=pd-ssd \
	--metadata enable-os-login=true
fi

sshpubkey="./utils/cm-data/nodes-ssh/id_rsa.pub"
chmod 0600 ./utils/cm-data/nodes-ssh/id_rsa
sshprivkey="--ssh-key-file=./utils/cm-data/nodes-ssh/id_rsa"
gcloud compute os-login ssh-keys add --project $gkeproject --key-file $sshpubkey

# get access to the new cluster
echo getting credentials for the new cluster
gcloud container clusters get-credentials gke-$un
set +e
current_context=$(kubectl config current-context)
kubectl config delete-context gke-$un > /dev/null 2>&1
kubectl config rename-context $current_context gke-$un > /dev/null 2>&1

echo Recording custom configuration for this cluster
if ! test -f "$PWD/config/custom.env"; then
   echo "#Custom cluster environment empty" > $PWD/config/custom.env
fi

kubectl create configmap customcfg --from-file=$PWD/config/custom.env

# configure SKIF
echo -n Creating SKIF..
pushd ./utils >> /dev/null
./skifconfig.sh add $skifip
if [ $? -ne 0 ]; then
   echo skifconfig failed
   popd >> /dev/null
   exit 1
fi
popd >> /dev/null
echo ...done

sbn=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*]}{.metadata.name}{end}')
# Create a gkeuser on the sandbox
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo adduser gkeuser --disabled-password --gecos ''" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo usermod -aG sudo gkeuser" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo mkdir -p /home/gkeuser/.ssh" 2> /dev/null
gcloud compute scp --quiet $sshpubkey $sshprivkey $sbn:. 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo mv id_rsa.pub /home/gkeuser/.ssh/authorized_keys" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo chmod 0600 /home/gkeuser/.ssh/authorized_keys" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo chown gkeuser:gkeuser /home/gkeuser/.ssh/authorized_keys" 2> /dev/null

gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo apt-get update" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo apt-get install -y build-essential make" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo dd if=/dev/zero of=/swapfile bs=1024 count=16048576" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo chmod 600 /swapfile" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo mkswap /swapfile" 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo swapon /swapfile" 2> /dev/null

gcloud compute scp --quiet $gkelibattestso $sshprivkey $sbn:. 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo mv lib* /home/gkeuser/." 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo chmod 777 /home/gkeuser/lib*" 2> /dev/null
gcloud compute scp --quiet utils/cm-data/graphene/graphene-sgx-driver.tar.gz $sshprivkey $sbn:. 2> /dev/null
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo mv graphene* /home/gkeuser/." 2> /dev/null

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

echo Restarting sandbox to init certs for containerd runtime
sbn=$(kubectl get nodes --selector=senssspmode=enabled -o jsonpath='{range.items[*]}{.metadata.name}{end}')
gcloud compute ssh --quiet $sbn $sshprivkey --command="sudo reboot" 2> /dev/null
stat=Ready
echo -n waiting for sandbox reboot..
until [ "$stat" == "NotReady" ]; do 
   sleep 10; 
   stat=$(kubectl get nodes | grep $sbn | awk '{print $2}')
   echo -n "."
done
until [ "$stat" == "Ready" ]; do 
   sleep 10; 
   stat=$(kubectl get nodes | grep $sbn | awk '{print $2}')
   echo -n "."
done
echo ""
echo Done...
