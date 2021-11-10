#!/bin/bash

if [ "$#" -lt 1 ]; then
   echo "Usage: ./skifconfig.sh add/del skif_ip"
   exit 1
fi

source ../config/skif.env

cluster=`kubectl config current-context`
prov=$(echo $cluster | cut -d "-" -f 1)
if [ "$prov" == "aks" ]; then
   echo "This is an Azure cluster; skipping SKIF setup ..."
   exit 0
fi

if [ "$1" == "add" ]; then
   newcas=true
   if [ -z "$2" ]; then
      echo skif_ip is required for add
      exit 1
   fi
   casip=$2
   az vm list -d -o table | grep $casip
   if [ $? -ne 0 ]; then
      echo SKIF IP does not exist
      exit 1
   fi
elif [ "$1" == "del" ]; then
   newcas=false
   kubectl get configmap skifmap -o json | jq -r '.data.skif' | grep "^SKIF_" > ../install-tmp/skif 2> /dev/null
   source ../install-tmp/skif
   casip=$SKIF_IP
else
   echo "Please specify add/del"
   exit 1
fi

casipuser=$SKIF_USER_NAME
cluster=$(kubectl config current-context)
un=$(echo $cluster | cut -d "-" -f 2)
rlsdom="rls-$un.$SKIF_SUBDOMAIN.sensoriant.net"
sshopts="-i ./cm-data/nodes-ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
sandboxip=$(kubectl get node --selector='senssspmode=enabled' -o wide | tail -1 | awk '{print $7}')

azrulename="skif_access_rule"

azruleresg=$(az vm list -d -o table 2> /dev/null | grep $casip | awk '{print tolower($2)}')
azrulensg=$(echo $azruleresg | sed 's/-azure-controller-resource-group-test-/-network-security-group-/g')
#azruleresg=sens-azure-controller-resource-group-test-ccf
#azrulensg=sens-network-security-group-ccf

updateAzPortsRule()
{
   portadddel=$1
   port1=$2
   port2=$3
   sspip=$4
   az network nsg rule list --resource-group $azruleresg   --nsg-name $azrulensg --query '[].{Name:name}' --output table | grep "^$azrulename"
   if [ $? -eq 0 ]; then
      new_ports=$(az network nsg rule show --resource-group $azruleresg --nsg-name $azrulensg -n $azrulename | jq -r --arg port1 "$port1" --arg port2 "$port2" '.destinationPortRanges | del(.[] | select(. == $port1 or . == $port2)) | join(" ")')
      new_addrs=$(az network nsg rule show --resource-group $azruleresg --nsg-name $azrulensg -n $azrulename | jq -r --arg sspip "$sspip" '.sourceAddressPrefixes | del(.[] | select(. == $sspip)) | join(" ")')
      azcmd=update
      if [ "$portadddel" == "add" ]; then
         #cur_ports=$(az network nsg rule show --resource-group $azruleresg --nsg-name $azrulensg -n $azrulename | jq -r '.destinationPortRanges|join(" ")')
         #cur_addrs=$(az network nsg rule show --resource-group $azruleresg --nsg-name $azrulensg -n $azrulename | jq -r '.sourceAddressPrefixes|join(" ")')
	 azcmdstr=" --source-address-prefixes $new_addrs $sspip --destination-port-ranges $new_ports $port1 $port2 "
      else
	 azcmdstr=" --source-address-prefixes $new_addrs --destination-port-ranges $new_ports "
         if [[ -z "${new_ports// }" ]] || [[ -z "${new_addrs// }" ]]; then
	    azcmd=delete
	    azcmdstr=""
         fi
      fi
   else
      if [ "$portadddel" == "add" ]; then
         azcmd=create
         azcmdstr=" --protocol tcp --priority 899 --access Allow --source-address-prefixes $sspip $casip --destination-port-ranges $port1 $port2 " 
      else
	 echo "Trying to delete a rule that does not exist?"
	 return
      fi
   fi

   echo "Applying access policy: name ($azrulename), command ($azcmd), ports ($port1, $port2), srcip ($sspip)"
   echo "Azure command is: az network nsg rule $azcmd --resource-group $azruleresg --nsg-name $azrulensg --name $azrulename $azcmdstr"
   az network nsg rule $azcmd --resource-group $azruleresg --nsg-name $azrulensg --name $azrulename $azcmdstr
}

if [ $newcas == false ]; then
   # delete the cas instance and exit
   casapiport=$SKIF_CASAPI_PORT
   casattestport=$SKIF_CASATTEST_PORT
   casnet=$SKIF_CASNET
   echo Deleting CAS instance $casattestport on $casip
   ssh $sshopts $casipuser@$casip "cd $casattestport && docker-compose down --remove-orphans"
   ssh $sshopts $casipuser@$casip "rm -rf $casattestport"
   ssh $sshopts $casipuser@$casip "rm -rf $casapiport"
   ssh $sshopts $casipuser@$casip "docker network rm $casnet"
   updateAzPortsRule del $casapiport $casattestport $sandboxip
   kubectl delete configmap skifmap
   exit 0
fi

make_port_dir()
{
checkingport=true
while [ $checkingport == true ]
do
   newport=$(shuf -i $1-$2 -n 1)
   ssh $sshopts $casipuser@$casip ls $newport
   if [ $? -eq 0 ]; then
      continue
   else
      ssh $sshopts $casipuser@$casip mkdir $newport
      checkingport=false
   fi
done
}

# instantiate a new cas for this cluster
make_port_dir 26000 28000
casattestport=$newport
make_port_dir 28000 30000
casapiport=$newport
echo "CAS API Port is: $casapiport"
echo "CAS Attestation Port is: $casattestport"

echo Creating CAS instance $casattestport on $casip
casnet=net_$casattestport
scp $sshopts ./cm-data/cas/cas.toml $casipuser@$casip:$casattestport/cas-availability-config.toml
grep -v "^url = " ./cm-data/cas/cas-default-owner-config.toml > ../install-tmp/cas-default-owner-config-$casattestport.toml
echo "url = \"https://$rlsdom/rls/v1/saveLogScone\"" >> ../install-tmp/cas-default-owner-config-$casattestport.toml
scp $sshopts ../install-tmp/cas-default-owner-config-$casattestport.toml $casipuser@$casip:$casattestport/cas-owner-config-with-audit.toml
cat ../config/skif.env > ../install-tmp/skif
echo "SKIF_CASAPI_PORT=$casapiport" >> ../install-tmp/skif
echo "SKIF_CASATTEST_PORT=$casattestport" >> ../install-tmp/skif
echo "SKIF_CASNET=$casnet" >> ../install-tmp/skif
echo "SKIF_IP=$casip" >> ../install-tmp/skif
echo "GKE_CLUSTER=$cluster" >> ../install-tmp/skif
scp $sshopts ../install-tmp/skif $casipuser@$casip:$casattestport/.env
ssh $sshopts $casipuser@$casip "docker network create $casnet"
cat ./cm-data/cas/docker-compose.yml | sed "s/netxxx/$casnet/g" > ../install-tmp/casdocker-compose.yml
scp $sshopts ../install-tmp/casdocker-compose.yml $casipuser@$casip:$casattestport/docker-compose.yml

#put the necessary info into a cluster config map
kubectl create configmap skifmap --from-file=$PWD/../install-tmp/skif
#use the info during sensinstall and also during deletecluster

updateAzPortsRule add $casapiport $casattestport $sandboxip
