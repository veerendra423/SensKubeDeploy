#!/bin/bash

docker pull sensoriant.azurecr.io/dev/aprep:kube
docker tag sensoriant.azurecr.io/dev/aprep:kube aprep

if ! test -d originalfiles; then
   mkdir originalfiles
   mv run.sh originalfiles
   mv prepare_pipeline.sh originalfiles
   mv start_pipeline.sh originalfiles
   mv upload_policies.sh originalfiles
   mv operator/SensADK/sandbox operator/SensADK/originalsandbox
fi

docker run --rm -v .:/sb aprep bash -c "cp scripts/*.sh /sb; cp scripts/no_kube/*.sh /sb"
docker run --rm -v .:/sb aprep bash -c "cp -R sandox /sb/operator/SensADK""

