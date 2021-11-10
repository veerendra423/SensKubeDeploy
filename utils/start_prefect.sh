#/bin/bash

if [ -z "$1" ]; then
   echo Please provide cluster info
   exit 1
fi
cluster=$1

if [ -z "$2" ]; then
   echo Please provide subdomain info
   exit 1
fi
subdomain=$2

if [ -z "$3" ]; then
   echo Please provide domain info
   exit 1
fi
domain=$3

if [ -z "$4" ]; then
   clientid=ebfbca4c-4f3d-4527-a8b0-50fe978718cf
else
   clientid=$4
fi

echo Installing Prefect server
helm list | grep "^prefect-server" > /dev/null
if [ $? -eq 0 ]; then
   echo prefect-server already installed
   exit 0
fi


apolloname=svr-$cluster.$subdomain.$domain
uiname=ui-$cluster.$subdomain.$domain

echo "
#jobs:
#  createTenant:
#    enabled: true

postgresql:
   master:
      nodeSelector: { sensctrlmode: enabled }
   slave:
      nodeSelector: { sensctrlmode: enabled }
hasura:
   nodeSelector: { sensctrlmode: enabled }
graphql:
   nodeSelector: { sensctrlmode: enabled }
towel:
   nodeSelector: { sensctrlmode: enabled }
apollo:
   service:
      type: ClusterIP
   nodeSelector: { sensctrlmode: enabled }
   ingress:
      enabled: true
      annotations:
         kubernetes.io/ingress.class: nginx
         cert-manager.io/cluster-issuer: letsencrypt
         #nginx.ingress.kubernetes.io/rewrite-target: /
      hosts:
        - $apolloname
      path: /
      tls: 
        - secretName: prefecthq-apollo-general-tls
          hosts:
           - $apolloname
ui:
   apolloApiUrl: https://$apolloname/graphql
#   image:
#      name: sensoriant.azurecr.io/priv-comp/prefect_image
#      tag: VERSION_1_2_4
#      pullSecrets:
#        - name: sens-reg-cred 
   service:
      type: ClusterIP
   nodeSelector: { sensctrlmode: enabled }
   ingress:
      enabled: true
      annotations:
         kubernetes.io/ingress.class: nginx
         cert-manager.io/cluster-issuer: letsencrypt
         #nginx.ingress.kubernetes.io/use-regex: "true"
      hosts:
        - $uiname
      path: /
      tls: 
        - secretName: prefecthq-ui-general-tls
          hosts:
           - $uiname
" > ../install-tmp/prefvals.yaml

helm repo add prefecthq https://prefecthq.github.io/server/
helm repo update
helm install --version 2021.04.06 prefect-server prefecthq/prefect-server -f ../install-tmp/prefvals.yaml

ppod=`kubectl get pods | awk '{print $1}' | grep "^prefect-server*-apollo-*"`
echo $ppod
echo -n Waiting for prefect apollo to start...
while [[ $(kubectl get pods $ppod -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
do
   echo -n ".."
   sleep 10
   if [ -z "$ppod" ]; then
      ppod=`kubectl get pods | awk '{print $1}' | grep "^prefect-server*-apollo-*"`
   fi
done
echo ""
ppod=`kubectl get pods | awk '{print $1}' | grep "^prefect-server*-ui-*"`
echo $ppod
echo -n Waiting for prefect ui to start...
while [[ $(kubectl get pods $ppod -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
do
   echo -n ".."
   sleep 5
   if [ -z "$ppod" ]; then
      ppod=`kubectl get pods | awk '{print $1}' | grep "^prefect-server*-ui-*"`
   fi
done
echo ""

echo -n Waiting for all prefect pods to get to RUNNING...
while true;
do
  n=$(kubectl get pods  -l='app.kubernetes.io/instance=prefect-server'  -o json | jq '.items[].status.containerStatuses[].started' | grep -v true | wc -l)
# n=$(kubectl get pods --all-namespaces -l='app.kubernetes.io/instance=prefect-server' --field-selector=status.phase='!Running' 2>&1 | grep -v "No resources found" | wc -l)
  if [ $n == "0" ]; then
        echo All prefect pods up now
	sleep 10
	break
  else
        echo -n ".."
	sleep 10
        continue
  fi 
done

#kubectl set env deployment/prefect-server-ui VUE_APP_CLIENT_ID=$clientid VUE_APP_API_URL=$uiname

echo -n Waiting for prefect certificates to be ready...
while true;
do
   #kubectl get certificates | grep -v READY | awk '{print $2}' | grep False
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
