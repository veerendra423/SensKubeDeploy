#/bin/bash

source ../install-tmp/sens.env

if [ -z "$1" ]; then
   echo Please provide cluster info
   exit 1
fi
cluster=$1

if [ -z "$2" ]; then
   echo Please provide subdomain info
   exit 1
fi
subdomain=$2

if [ -z "$3" ]; then
   echo Please provide domain info
   exit 1
fi
domain=$3

echo Installing Oauth2 proxy
helm list | grep "^oauth2-proxy" > /dev/null
if [ $? -eq 0 ]; then
   echo oauth2-proxy already installed
   exit 0
fi

oauthclientid=$SENSOAUTH_CLIENT_ID
oauthclientsecret=$SENSOAUTH_CLIENT_SECRET
oauthcookiesecret=$SENSOAUTH_COOKIE_SECRET
oauthtenantid=$SENSOAUTH_TENANT_ID
adname=$SENSOAUTH_AD_PRIMARY_DOMAIN

authname=auth-$cluster.$subdomain.$domain

echo "
extraArgs:
  whitelist-domain: .$domain
  cookie-domain: .$domain
  client-id: $oauthclientid
  client-secret: $oauthclientsecret
  cookie-secret: $oauthcookiesecret
  provider: oidc
  scope: openid https://$adname.onmicrosoft.com/$oauthclientid/api.getpost
  oidc-issuer-url: https://$adname.b2clogin.com/$adname.onmicrosoft.com/B2C_1_SS_SIGNIN/v2.0/
  #session-store-type: redis
  #redis-connection-url: redis://10.244.1.111:6379
  insecure-oidc-skip-issuer-verification: true
  oidc-email-claim: oid
  skip-provider-button: true
  email-domain: \"*\"
  reverse-proxy: true
  pass-authorization-header: true
  set-authorization-header: true
  pass-access-token: true
  skip-jwt-bearer-tokens: true
  extra-jwt-issuers: \"https://login.microsoftonline.com/$oauthtenantid/v2.0=$oauthclientid\"
  cookie-samesite: \"lax\"
  cookie-refresh: 1h
  cookie-expire: 168h
  silence-ping-logging: true

extraEnv:
- name: OAUTH2_PROXY_AZURE_TENANT
  value: $oauthtenantid

ingress:
  enabled: true
  path: /
  hosts:
    - $authname
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-buffer-size: \"128k\"
    nginx.ingress.kubernetes.io/proxy-buffers: \"16\"
    nginx.ingress.kubernetes.io/proxy-body-size: 10m
    cert-manager.io/cluster-issuer: letsencrypt
  tls:
    - hosts:
        - $authname
      secretName: oauth2-proxy-https-cert
" > ../install-tmp/oauthvals.yaml

helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
helm install --version 4.1.0 oauth2-proxy oauth2-proxy/oauth2-proxy --values ../install-tmp/oauthvals.yaml

ppod=`kubectl get pods | awk '{print $1}' | grep "^oauth2-proxy-*"`
echo $ppod
echo -n Waiting for oauth2 proxy to start...
while [[ $(kubectl get pods $ppod -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]];
do
   echo -n ".."
   sleep 10
done
echo ""

echo -n Waiting for oauth certificates to be ready...
while true;
do
   #kubectl get certificates | grep -v READY | awk '{print $2}' | grep False
   kubectl get certificates -o json | jq -r .items[].status.conditions[0].status | grep False > /dev/null
   if [ $? -ne 0 ]; then
      echo Certificates ready
      break
   else
      echo -n ".."
      sleep 10
      continue
   fi
done

echo Adding redirect URL on Azure B2C
objid=$(az ad app show --id $SENSOAUTH_CLIENT_ID --query objectId | sed s/\"//g)
authurl="\"https://$authname/oauth2/callback\""
cur_list=$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/applications/$objid" | jq -c ".web.redirectUris | . - [$authurl]")

new_list=$(echo $cur_list | jq ". | . + [$authurl]")
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$objid" --headers 'Content-Type=application/json' --body "{\"web\":{\"redirectUris\":$new_list}}"

