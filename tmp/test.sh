#!/bin/bash

#cur_ports="29582 26044 25001 25002"
#echo $cur_ports | sed "s/[^ ]29582[$ ]/ /g" | sed "s/[^ ]26044[$ ]/ /g"
#new_ports=$(echo $cur_ports | sed "s/[^ ]29582[$ ]/ /g" | sed "s/[^ ]26044[$ ]/ /g")
#echo $new_ports
port1=28100
port2=27106
az network nsg rule show --resource-group sens-azure-controller-resource-group-test-ccf --nsg-name sens-network-security-group-ccf --name skif_access_rule  | jq -r '.destinationPortRanges'
az network nsg rule show --resource-group sens-azure-controller-resource-group-test-ccf --nsg-name sens-network-security-group-ccf --name skif_access_rule  | jq -r '.destinationPortRanges|join(" ")'
az network nsg rule show --resource-group sens-azure-controller-resource-group-test-ccf --nsg-name sens-network-security-group-ccf --name skif_access_rule  | jq -r --arg port1 "$port1" --arg port2 "$port2" '.destinationPortRanges | del(.[] | select(. == $port1 or . == $port2)) | join(" ")'
