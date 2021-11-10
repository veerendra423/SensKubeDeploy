#!/bin/bash
if [ -z "$1" ];then
  cluster=`kubectl config current-context | cut -d "-" -f 2`
else
  cluster=$1
fi
cloudprovider=`kubectl config current-context | cut -d "-" -f 1`
if [ -z "$2" ];then
  subdomain=devel
else
  subdomain=$2
fi
if [ -z "$3" ];then
  domain=sensoriant.net
else
  domain=$3
fi
ingressIp=`kubectl get svc nginx-ingress-ingress-nginx-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}"`
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n api-$cluster -y
az network dns record-set a add-record \
  -g sensdns \
  -z $subdomain.$domain \
  -n api-$cluster \
  -a $ingressIp \
  --ttl 60
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n ui-$cluster -y
az network dns record-set a add-record \
  -g sensdns \
  -z $subdomain.$domain \
  -n ui-$cluster \
  -a $ingressIp \
  --ttl 60
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n svr-$cluster -y
az network dns record-set a add-record \
  -g sensdns \
  -z $subdomain.$domain \
  -n svr-$cluster \
  -a $ingressIp \
  --ttl 60
az network dns record-set a delete \
  -g sensdns \
  -z $subdomain.$domain \
  -n auth-$cluster -y
az network dns record-set a add-record \
  -g sensdns \
  -z $subdomain.$domain \
  -n auth-$cluster \
  -a $ingressIp \
  --ttl 60

echo "Registered api-$cluster.$subdomain.$domain with IP address $ingressIp"
echo "Registered ui-$cluster.$subdomain.$domain with IP address $ingressIp"
echo "Registered svr-$cluster.$subdomain.$domain with IP address $ingressIp"
echo "Registered auth-$cluster.$subdomain.$domain with IP address $ingressIp"
if [ "$cloudprovider" != "aks" ]; then
   az network dns record-set a delete \
     -g sensdns \
     -z $subdomain.$domain \
     -n rls-$cluster -y
   az network dns record-set a add-record \
     -g sensdns \
     -z $subdomain.$domain \
     -n rls-$cluster \
     -a $ingressIp \
     --ttl 60
echo "Registered rls-$cluster.$subdomain.$domain with IP address $ingressIp"
fi

echo Waiting for DNS to propagate
sleep 60
echo Done waiting ...
