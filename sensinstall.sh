#!/bin/bash

mkdir -p ./install-tmp

pushd ./utils >> /dev/null
./genclusterinfo.sh
popd >> /dev/null
source ./install-tmp/cluster_info.env

# Rebuild sens.env
if ! test -f "./install-tmp/staging.env"; then
   echo staging.env not present
   exit 1
fi

if ! test -f "./install-tmp/default-creds.env"; then
   echo default-creds.env not present
   exit 1
fi

cloudprovider=$(kubectl config current-context | cut -d "-" -f 1)
if [ $cloudprovider == "aks" ]; then
    echo SENSORIANT_PLATFORM_PROVIDER="AZURE" > install-tmp/sens.env
else
    echo SENSORIANT_PLATFORM_PROVIDER="GOOGLE" > install-tmp/sens.env
    echo "## SKIF values" >> install-tmp/sens.env
    kubectl get configmap skifmap -o json | jq -r '.data.skif' | grep "^SKIF_" >> install-tmp/sens.env 2> /dev/null
fi

echo "## Custom values" >> install-tmp/sens.env
kubectl get configmap customcfg -o json | jq  -r '.data."custom.env"' >> install-tmp/sens.env 2> /dev/null

if ! test -f "./config/overrides.custom.env"; then
   echo "## No Override cluster custom values"  >> install-tmp/sens.env
else
   echo "## Override cluster custom values if needed"  >> install-tmp/sens.env
   cat config/overrides.custom.env >> install-tmp/sens.env
fi

echo "## Default-creds.env" >> install-tmp/sens.env
cat install-tmp/default-creds.env >> install-tmp/sens.env

echo "## Staging.env" >> install-tmp/sens.env
cat install-tmp/staging.env >> install-tmp/sens.env
echo "## Kubernetes specific values" >> install-tmp/sens.env
cat config/kubelocal.env >> install-tmp/sens.env

echo "## Developer env information" >> install-tmp/sens.env
cat config/dev.env >> install-tmp/sens.env

if ! test -f "./config/overrides.env"; then
   echo "## No Override values"  >> install-tmp/sens.env
else
   echo "## Override values" >> install-tmp/sens.env
   cat config/overrides.env >> install-tmp/sens.env
fi
echo "## Cluster information" >> install-tmp/sens.env
cat install-tmp/cluster_info.env >> install-tmp/sens.env

if test -f "./config/overrides.env"; then
   echo "Using the following overrides"
   cat config/overrides.env
fi
# Done rebuilding sens.env

source ./install-tmp/sens.env

ev=(
   CLUSTER
   SUBDOMAIN
   DOMAIN
   SENSCR_NAME
   SENSCR_USER
   SENSCR_PASSWD
   SENSCR_IMGREPO_NAME
   SENSCR_HELMREPO_NAME
   SENS_ALGO_DREG
   SENS_ALGO_USER
   SENS_ALGO_PASSWD
   SENS_ALGO_DCRED
   SENS_ALGO_DREG_AZURE_TOKEN
   SENSINT_STORAGE_PROVIDER
   SENSINT_BUCKET_NAME
   SENSINT_STORAGE_CREDS
   INPBUCKET_STORAGE_PROVIDER
   INPBUCKET_NAME
   INPBUCKET_STORAGE_CREDS
   OUTBUCKET_STORAGE_PROVIDER
   OUTBUCKET_NAME
   OUTBUCKET_STORAGE_CREDS
   SENS_TRUST_DOMAIN
   SENSOAUTH_CLIENT_ID
   SENSOAUTH_CLIENT_SECRET
   SENSOAUTH_TENANT_ID
   SENSOAUTH_COOKIE_SECRET
)   
for x in ${ev[@]}; do
    if [ -z "${!x}" ]; then
       echo $x not defined
       exit 1
    fi
done

kubectl get pods | grep "^$SENSSCHARTS_DEPLOY_NAME-" >> /dev/null
if [ $? -eq 0 ]; then
   echo "Previous instance still running"
   exit 1
fi

# provide access to the sensoriant registry
kubectl create secret docker-registry sens-reg-cred \
	--docker-server=$SENSCR_NAME \
	--docker-username=$SENSCR_USER \
	--docker-password=$SENSCR_PASSWD

# Create the config maps needed for various components
echo Creating configuation objects
## configmap for internal storage creds
echo $SENSINT_GCS_CREDENTIALS | jq . > ./install-tmp/gcscred
kubectl create configmap api-cfg \
	--from-file=Sensoriant-gcs-data-bucket-ServiceAcct.json=./install-tmp/gcscred \
	--from-file=privatekey_sandbox.key=utils/cm-data/apicreds/privatekey_sandbox.key
kubectl create configmap gcs-cfg \
	--from-file=gcs-cred.json=./install-tmp/gcscred 
echo $INPBUCKET_GCS_CREDENTIALS | jq . > ./install-tmp/gcscred
kubectl create configmap igcs-cfg \
	--from-file=Sensoriant-gcs-data-bucket-ServiceAcct.json=./install-tmp/gcscred 
echo $OUTBUCKET_GCS_CREDENTIALS | jq . > ./install-tmp/gcscred
kubectl create configmap ogcs-cfg \
	--from-file=Sensoriant-gcs-data-bucket-ServiceAcct.json=./install-tmp/gcscred 
## configmap for mariadb
kubectl create configmap mdb-cfg --from-file=utils/cm-data/mdb/
## configmap for registry certs
kubectl create configmap cert-cfg --from-file=utils/cm-data/reg-certs/tls.crt
## configmaps needed for cas audit logs
kubectl create configmap cas-cas --from-file=./utils/cm-data/cas/cas.toml
kubectl create configmap cas-aud --from-file=./utils/cm-data/cas/cas-default-owner-config.toml

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

# Install the ingress controller
echo Installing ingress controller 
helm list | awk '{print $1}' | grep -w nginx-ingress > /dev/null
if [ $? -eq 0 ]; then
   echo nginx-ingress already installed
else
   ## install nginx ingress
   echo installing helm
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   helm install --version 3.29.0 nginx-ingress ingress-nginx/ingress-nginx --namespace default --set controller.replicaCount=1 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.nodeSelector.sensctrlmode=enabled
  nsvc=nginx-ingress-ingress-nginx-controller
  niip=""
  echo -n Waiting for nginx-ingress to get external ip addr...
  while [ -z $niip ]; 
  do
     echo -n ".."
     sleep 5
     niip=$(kubectl get svc $nsvc --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  done
  echo ""
   ## install cluster issuer
   helm repo add jetstack https://charts.jetstack.io
   helm repo update

   helm install --version v1.3.1 cert-manager jetstack/cert-manager   --namespace default   --set installCRDs=true   --set nodeSelector."kubernetes\.io/os"=linux   --set webhook.nodeSelector."kubernetes\.io/os"=linux   --set cainjector.nodeSelector."kubernetes\.io/os"=linux --set nodeSelector.sensctrlmode=enabled --set webhook.nodeSelector.sensctrlmode=enabled  --set cainjector.nodeSelector.sensctrlmode=enabled
   ctr=0
   echo -n Waiting for all cert-manager pods to get to RUNNING...
   while true;
   do
     #kubectl get pods | grep cert-manager
     n=$(kubectl get pods  -l='app.kubernetes.io/instance=cert-manager'  -o json | jq '.items[].status.containerStatuses[].started' 2> /dev/null | grep -v true | wc -l)
     if [ $n == "0" ]; then
	       ((ctr++))
	       if [ $ctr -eq 3 ]; then
             break
         else
	         sleep 10
	       fi
     else
           echo -n ".."
           sleep 10
           continue
     fi
   done
   echo ""
   echo applying cluster issuer
   pushd ./utils >> /dev/null
   #kubectl apply -f ./utils/cluster-issuer.yaml
   ./start_clusterissuer.sh
   ./publish_kube_domain.sh $cluster $subdomain $domain
   popd >> /dev/null

fi

pushd ./utils >> /dev/null
./start_prefect.sh $cluster $subdomain $domain
./start_oauth.sh $cluster $subdomain $domain
popd >> /dev/null

# Install the controller components
echo Installing controller and securestream platform components
sbn=$SENSSSP_NODENAME
./utils/genvals.sh ./install-tmp/sens.env $cluster $subdomain $domain
## configmap for pmgr sensenv
kubectl create configmap sens-env --from-file=sens.env=./install-tmp/sens.env

export HELM_EXPERIMENTAL_OCI=1
echo $SENSCR_PASSWD | helm registry login $SENSCR_NAME -u $SENSCR_USER --password-stdin 
helm repo update
helm chart pull $SENSSCHARTS_REPO:$SENSSCHARTS_TAG
helm chart export $SENSSCHARTS_REPO:$SENSSCHARTS_TAG
helm install $SENSSCHARTS_DEPLOY_NAME $SENSSCHARTS_NAME/ --set sensctrl.ctrl-ras.sboxname=$sbn -f ./install-tmp/sensvals.yaml

# wait for registry to be ready
while true;
do
   regpod=`kubectl get pods | awk '{print $1}' | grep ssp-reg`
   if [ ! -z "$regpod" ]; then
      break
   fi
   sleep 5
done

echo registry pod is $regpod
echo -n "Waiting for registry pod ($regpod) to start..."
while [[ $(kubectl get pods $regpod -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
do
   echo -n ".."
   sleep 5
done
echo ""
# update the registry information
echo updating registry information
pushd ./utils >> /dev/null
./configsbox.sh
if [ $? -ne 0 ]; then
   echo Something went wrong configuring sbox
   popd >> /dev/null
   exit 1
fi
popd >> /dev/null

echo -n "Waiting for all $SENSSCHARTS_DEPLOY_NAME pods to get to RUNNING..."
while true;
do
  n=$(kubectl get pods  -l="app.kubernetes.io/instance=$SENSSCHARTS_DEPLOY_NAME"  -o json | jq '.items[].status.containerStatuses[].started' | grep -v true | wc -l)
  if [ $n == "0" ]; then
        echo All pods up now
	break
  else
	echo -n ".."
	sleep 10
        continue
  fi 
done

echo -n Waiting for API certificates to be ready...
while true;
do
   kubectl get certificates -o json | jq -r .items[].status.conditions[0].status | grep False > /dev/null
   if [ $? -ne 0 ]; then
      echo Certificates ready
      break
   else
      echo -n ".."
      sleep 10
      continue
   fi
done

pushd ./utils >> /dev/null
./skifsetstate.sh up
popd >> /dev/null

kubectl create configmap safectlconf --from-literal=SAFECTLCONFIG=$SENS_SAFECTL_HELPER_CONFIG
