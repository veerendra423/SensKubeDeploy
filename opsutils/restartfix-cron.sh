#!/bin/bash
  
pushd $HOME/SensKubeDeploy >> /dev/null
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#echo "" >> ./restarts_info
#echo "##########" >> ./restarts_info
#echo checking at $(date) >> ./restarts_info
pmgrpod=$(kubectl get pods | grep "^s1-ctrl-pmgr-" | awk '{print $1}')
#echo pmgr pod is $pmgrpod >> ./restarts_info
kubectl logs $pmgrpod | grep "\"register" | grep "status\": false"
if [ $? -eq 0 ]; then
   echo Restarted at $(date) >> ./restarts_info
   ./sensdelete.sh
   ./sensinstall.sh
#else
#   echo All good >> ./restarts_info
fi
popd >> /dev/null
