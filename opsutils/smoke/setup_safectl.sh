#!/bin/bash

if [ "$#" -lt 1 ]; then
   echo 'Usage: ./safectl_setup.sh <release version> | <dev [branch]>'
   echo '(install a released version, or build from git repo branch)'
   echo Install a specific release: ./safectl_setup.sh release VERSION_1_4_0
   echo Build from main branch: ./safectl_setup.sh dev
   echo Build from branch PRIV-xyz: ./safectl_setup.sh dev PRIV-xyz
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
mkdir -p $safectlwork
safectldir=$safectlwork/safectl-current
safectlolddir=$safectlwork/safectl-previous
appsdir=$safectlwork/safelets
confdir=$safectlwork/configs

release=false
dev=false
if [ "$1" == "release" ]; then
   release=true
   if [ -z "$2" ]; then
      echo Please provide a release version
      exit 1
   fi
   relver=$2
elif [ "$1" == "dev" ]; then
   dev=true
else
   echo Please specify release or dev
   exit 1
fi

if test -d "$safectldir"; then
   mkdir -p $safectlolddir
   mv $safectldir ${safectlolddir}/safectl-$(date '+%Y%m%d-%H:%M:%S')
fi

mkdir -p $HOME/.safectl

if [ "$release" == true ]; then
   if ! test -f "/mnt/staging/releases/${relver}/clienttools-${relver}.tar.gz"; then
      echo Release does not exist
      exit 1
   fi
   mkdir $safectldir
   tar xvf /mnt/staging/releases/${relver}/clienttools-${relver}.tar.gz -C $safectldir > /dev/null
   binpath=$safectldir/Safectl/bin/safectl
   cp $safectldir/Safectl/config-example.yaml $HOME/.safectl/config.yaml
else
   if [ -z "$2" ]; then
      git clone git@github.com:sensoriant/Safectl.git $safectldir/Safectl
   else
      git clone -b $2 git@github.com:sensoriant/Safectl.git $safectldir/Safectl
   fi
   pushd $safectldir/Safectl >> /dev/null
   sed -i s/VERSION_1_3_3/VERSION_1_4_0/g Makefile
   make
   popd >> /dev/null
   binpath=$safectldir/Safectl/bin/safectl
   cp $safectldir/Safectl/config-example.yaml $HOME/.safectl/config.yaml
fi

if ! test -d "$appsdir"; then
   cp -R /mnt/staging/safelets $appsdir
fi

mkdir -p $confdir
cp /mnt/staging/reference-configs/*-safectl.env $confdir
if [ ! -z "$relver" ]; then
   for i in $(ls $confdir)
   do
      replacevar SAFECTL_ROOT_IMAGE_REGISTRY_RELEASE_TAG $relver $confdir/$i
   done
fi
