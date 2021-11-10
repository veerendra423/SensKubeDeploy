#!/bin/bash

kubectl get configmaps | grep safectlconf > /dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "Safectl config information not available"
   exit 1
fi

sf=$(kubectl get configmap safectlconf -o json | jq -r '.data.SAFECTLCONFIG' 2> /dev/null)

if [ -z "$sf" ]; then
   echo "Safectl config information not available"
   exit 1
else
   echo "Safectl helper config is: $sf" 
fi	
