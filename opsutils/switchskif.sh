#!/bin/bash

if [ -z "$1" ]; then
   echo Usage: "./switchskif.sh <new-skif-ip>"
   exit 1
fi

curdir=$(basename $PWD)
if [ "$curdir" != "opsutils" ]; then
   echo Make sure you are in the SensKubeDeploy/opsutils directory and try again
   exit 1
fi

pushd .. >> /dev/null
echo Performing sensdelete
./sensdelete.sh
pushd ./utils >> /dev/null
echo Deleting current skif
./skifconfig.sh del
echo Adding new skif
./skifconfig.sh add $1
popd >> /dev/null
echo Performing sensinstall
./sensinstall.sh
popd >> /dev/null
echo Done..

