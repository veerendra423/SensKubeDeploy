#!/bin/bash

source ../install-tmp/sens.env

if [ "$USE_ZEROSSL" == "true" ]; then
   if [ "$USE_ZEROSSL_EXISTING_ACCOUNT" == "true" ]; then
      kubectl apply -f $USE_ZEROSSL_ACCOUNT_SECRET
      kubectl apply -f ./cm-data/cluster-issuers/zerossl-existingAccount.yaml
   else
      # if you are using this, make sure you update the yaml file below to include the proper kid and hmac
      kubectl apply -f ./cm-data/cluster-issuers/zerossl-newAccount.yaml
      # to save the created account secret, use
      # kubectl get secret <secretname> -ojson | \
      #    jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid) | .metadata.creationTimestamp=null' \
      #    > filenameyouwant.yaml
      # filenameyouwant.yaml can be used as USE_ZEROSSL_ACCOUNT_SECRET later for other clusters
   fi
else
   kubectl apply -f ./cm-data/cluster-issuers/letsencrypt-issuer.yaml
fi
