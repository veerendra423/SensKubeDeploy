#!/bin/bash

source ./config/kubelocal.env

# delete the chart
helm delete ${SENSSCHARTS_DEPLOY_NAME}

## delete safectl config info
kubectl delete configmap safectlconf > /dev/null 2>&1

## configmap for mariadb
kubectl delete configmap mdb-cfg 
## configmap for apiserver
kubectl delete configmap api-cfg
## configmap for gcscred
kubectl delete configmap gcs-cfg 
kubectl delete configmap igcs-cfg 
kubectl delete configmap ogcs-cfg 
## configmap for registry certs
kubectl delete configmap cert-cfg 
## configmap for sens env
kubectl delete configmap sens-env 
## configmaps for cas
kubectl delete configmap cas-cas
kubectl delete configmap cas-aud
##kubectl delete configmap sb-cfg
## configmap for nginx certs
##kubectl delete configmap certs-cfg 

# delete the registry secret
kubectl delete secret sens-reg-cred

### delete any pipeline related stuff if needed
ch=$(helm list | grep -E "^$SENSPCHARTS_DEPLOY_PREFIX([0-9])+ " | awk '{print $1}')
for c in $ch
do
   helm delete $c
done
apc=$(kubectl get configmap | grep -E "^aprep-cfg([0-9])+ " | awk '{print $1}')
for a in $apc
do
   kubectl delete configmap $a
done
poc=$(kubectl get configmap | grep -E "^porch-script([0-9])+ " | awk '{print $1}')
for p in $poc
do
   kubectl delete configmap $p
done
wlc=$(kubectl get configmap | grep -E "^wlog-script([0-9])+ " | awk '{print $1}')
for w in $wlc
do
   kubectl delete configmap $w
done
echo -n "Waiting for all $SENSPCHARTS_DEPLOY_PREFIX[0-9]+ pods to terminate..."
while true;
do
  kubectl get pods | grep -E "^$SENSPCHARTS_DEPLOY_PREFIX([0-9])+-" >> /dev/null
  if [ $? -ne 0 ]; then
     break
  else
     echo -n ".."
     sleep 10
     continue
  fi
done
echo ""

echo -n "Waiting for all $SENSSCHARTS_DEPLOY_NAME pods to terminate..."
while true;
do
  kubectl get pods | grep "^$SENSSCHARTS_DEPLOY_NAME-" >> /dev/null
  if [ $? -ne 0 ]; then
     break
  else
     echo -n ".."
     sleep 10
     continue
  fi
done
echo ""

pushd ./utils >> /dev/null
./skifsetstate.sh down
popd >> /dev/null

