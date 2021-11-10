#!/bin/bash

if [ "$#" -lt 4 ]; then
   echo 'Usage: ./run_safectl.sh <unique-configprefix> <cluster> <app> <unique-scriptprefix> [subdomain]'
   echo 'Example: ./run_safectl.sh axx aks-pkz helloapp all-g'
   echo The above example runs a safestream for helloapp using all-groups.sh script and the 
   echo axx-safectl.env environment on cluster with api endpoint api-pkz.devel... 
   echo 'Example: ./run_safectl.sh axx aks-pkz helloapp all-g external'
   echo axx-safectl.env environment on cluster with api endpoint api-pkz.external... 
   echo Note: configs and apps must be in '$HOME'/safectl_workspace
   exit 1
fi

replacevar()
{
        rc=`grep "^export $1=" $3`
        if [ -z "$rc" ]; then
                echo export $1=$2 >> $3
        else
                sed "\|^export $1|s|=.*$|=$2|1" $3 > t
                mv t $3
        fi
}

safectlwork=$HOME/safectl_workspace
safectldir=$safectlwork/safectl-current
if ! test -d "$safectldir"; then
   echo Safectl not setup
   exit 1
fi

config=$1
cluster=$2
app=$3
pref=$4
subnet=devel
if [ ! -z "$5" ]; then
   subnet=external
fi

num=$(ls -l $safectldir/Safectl/scripts/${pref}* | wc -l)
if [ "$num" -ne 1 ]; then
   echo Zero or multiple matches for prefix
   exit 1
fi

num=$(ls -l $safectlwork/configs/${config}-safectl.* | wc -l)
if [ "$num" -ne 1 ]; then
   echo Zero or multiple matches for config
   exit 1
fi

if ! test -d "$safectlwork/safelets/$app"; then
   echo Unknown app
   exit 1
fi

prov=$(echo $cluster | cut -d "-" -f 1)
if [ "$prov" == "aks" ]; then
   pr="AZURE"
elif [ "$prov" == "gke" ]; then
   pr="GOOGLE"
else
   echo Unknown cluster provider
   exit 1
fi
clname=$(echo $cluster | cut -d "-" -f 2)
apiname="https://api-$clname.$subnet.sensoriant.net/secure_cloud_api/v1/"
## update the vars
randnum=$(od -vAn -N4 -tu4 < /dev/urandom)
cfile=/tmp/$(echo $randnum | sed 's/^ *//g')
cf=$(ls $safectlwork/configs/${config}-safectl.*)
cp $cf $cfile

replacevar SAFECTL_ROOT_SAFELET_DOCKER_APP_FOLDER $safectlwork/safelets/$app $cfile
replacevar SAFECTL_HELPER_CLUSTER_PROVIDER $pr $cfile
replacevar SAFECTL_ROOT_CLUSTER_API_ENDPOINT $apiname $cfile
replacevar PATH $safectldir/Safectl/bin:$PATH $cfile

source $cfile
mv $cfile mostrecent.env
#rm -f $cfile

cmd=$(ls $safectldir/Safectl/scripts/${pref}*)

echo running $cmd on $clname for $app
#env | grep SAFECTL
$cmd
