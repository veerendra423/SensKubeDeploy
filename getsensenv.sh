#!/bin/bash

if [ -z "$1" ]; then
   echo "Usage: ./getsensenv.sh <version>"
   exit 1
fi

mkdir -p ./install-tmp

mountpt="/mnt/staging"
dstdir="./install-tmp"
srcev=(
   "default-creds.env"
   "libattestation-python.so"
   "releases/$1/staging.env"
)

dstev=(
   "default-creds.env"
   "libattestation-python.so"
   "staging.env"
)

for x in ${dstev[@]}; do
    rm -f "$dstdir/$x" > /dev/null 2>&1
done

for x in ${srcev[@]}; do
    if ! test -f "$mountpt/$x"; then
       echo File $mountpt/$x does not exist
    else
       cp "$mountpt/$x" $dstdir/.
    fi
done

mv $dstdir/libattestation-python.so ./utils/cm-data/gcloud/.
echo "...Done"
