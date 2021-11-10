if [ -z $1 ] ; then
  echo "Please provide Resource group name" && exit 1;
fi

if [ -z $2 ] ; then
  echo "Please provide security group name!" && exit 2;
fi

if [ -z $3 ] ; then
  echo "Please Provide Security Rule Name!" && exit 3;
fi

if [ -z $4 ] ; then
  echo "Please provide ip address list!" && exit 4;
fi

az network nsg rule update -g $1 --nsg-name $2 -n $3 --destination-address-prefix $4

#az network nsg rule update -g sens-azure-controller-resource-group-test-ccf --nsg-name sens-network-security-group-ccf -n open-port-3091 --destination-address-prefixes 20.102.58.76 173.48.112.27
