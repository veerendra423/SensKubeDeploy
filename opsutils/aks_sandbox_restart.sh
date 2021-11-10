#!/bin/bash 

un=$(kubectl config current-context | cut -d "-" -f 2)
ssp_np_name=nps$un
echo -n Restarting sandbox..
vname=$(az vmss list -o table | grep ".*-$ssp_np_name-.*" | awk '{print $1}')
resgname=$(az vmss list -o table | grep ".*-$ssp_np_name-.*" | awk '{print $2}')
az vmss restart -n $vname -g $resgname --instance-ids 0
sleep 10
until ! (JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'  && kubectl get nodes -o jsonpath="$JSONPATH" | grep "Ready=False"); do echo -n ".." ; done
echo "..done"

