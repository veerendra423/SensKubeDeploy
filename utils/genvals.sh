#!/bin/bash

if [ -z "$1" ]; then
   echo Please provide env file
   exit 1
fi

if [ -z "$2" ]; then
   echo Please provide cluster info
   exit 1
fi
cluster=$2

if [ -z "$3" ]; then
   echo Please provide subdomain info
   exit 1
fi
subdomain=$3

if [ -z "$4" ]; then
   echo Please provide domain info
   exit 1
fi
domain=$4

source $1

sbn=$SENSSSP_NODENAME
ctrln=$SENSCTRL_NODENAME
if [ $KUBERNETES_PROVIDER == "aks" ]; then
   enablecaslas=true
   rlsingressenabled=false
else
   enablecaslas=false
   rlsingressenabled=true
fi

apiname=api-$cluster.$subdomain.$domain
apiinternalname="s1-ctrl-api"
rlsname=rls-$cluster.$subdomain.$domain
authname=auth-$cluster.$subdomain.$domain
export PREFECT_API_HOST=prefect-server-apollo

if [ "$USE_OAUTH" == "true" ]; then
api_oauth_annotations="nginx.ingress.kubernetes.io/proxy-buffer-size: \"64k\"
       nginx.ingress.kubernetes.io/proxy-buffers: \"16\"
       nginx.ingress.kubernetes.io/auth-url: \"https://$authname/oauth2/auth\"
       nginx.ingress.kubernetes.io/auth-signin: \"https://$authname/oauth2/start?rd=https://\$host\$request_uri\""
else
api_oauth_annotations="# no oauth annotations"
fi

echo "
sensctrl:
  enabled: true
  ctrl-api:
    checkmdb:
      repository: $SENSUTILS_IMAGENAME
      tag: $SENSUTILS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    ingress:
      annotations:
       cert-manager.io/cluster-issuer: letsencrypt
       $api_oauth_annotations
      hosts:
        - host: $apiname
          paths:
          - path: /
      tls: 
         - hosts:
             - $apiname
           secretName: ctrl-api-general-tls
    apiserver:
      repository: $SECURE_CLOUD_API_IMAGENAME
      tag: $SECURE_CLOUD_API_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SECURE_CLOUD_API_DOCKER_PORT
      env:
        SECURE_CLOUD_API_TAG: $SECURE_CLOUD_API_TAG
        SECURE_CLOUD_API_DOCKER_PORT: $SECURE_CLOUD_API_DOCKER_PORT
        SECURE_CLOUD_API_SERVER_PORT: $SECURE_CLOUD_API_SERVER_PORT
        SECURE_CLOUD_API_GOOGLE_APPLICATION_CREDENTIALS: $SECURE_CLOUD_API_GOOGLE_APPLICATION_CREDENTIALS
        SECURE_CLOUD_API_STORAGE_BUCKET_NAME: ${SENSINT_BUCKET_NAME}
        SECURE_CLOUD_API_SANDBOX_USERNAME: "sensuser"
        SECURE_CLOUD_API_SANDBOX_IDENTITY_FILE: $SECURE_CLOUD_API_SANDBOX_IDENTITY_FILE
        product_version: default
        RELEASE_TAG: $RELEASE_TAG
        MARIADB_SERVER_PORT: $MARIADB_SERVER_PORT
        MYSQL_DATABASE: $MYSQL_DATABASE
        MYSQL_USER: $MYSQL_USER
        MYSQL_PASSWORD: "$MYSQL_PASSWORD"
        SENSPMGR_PORT: $SENSPMGR_PORT
        SECURE_CLOUD_API_AZURE_STORAGE_ACCOUNT: ${SENSINT_AZURE_STORAGE_ACCOUNT}
        SECURE_CLOUD_API_AZURE_STORAGE_ACCESS_KEY: ${SENSINT_AZURE_STORAGE_ACCESS_KEY}
        SENSORIANT_PLATFORM_PROVIDER: $SENSORIANT_PLATFORM_PROVIDER
        SECURE_CLOUD_API_STORAGE_SERVICE: $SENSINT_STORAGE_PROVIDER
        SENSPMGR_PORT: $SENSPMGR_PORT
        SENSSELF_DIGEST: $SECURE_CLOUD_API_DIGEST
        SECURE_CLOUD_API_STORAGE_INTERNAL_PROVIDER: $SENSINT_STORAGE_PROVIDER
        SECURE_CLOUD_API_STORAGE_INTERNAL_BUCKET_NAME: ${SENSINT_BUCKET_NAME}
        SECURE_CLOUD_API_STORAGE_INTERNAL_ACCOUNT: ${SENSINT_AZURE_STORAGE_ACCOUNT}
        SECURE_CLOUD_API_STORAGE_INTERNAL_GOOGLE_CREDENTIALS: "credentials-internal/Sensoriant-gcs-data-bucket-ServiceAcct.json"
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_PROVIDER: $INPBUCKET_STORAGE_PROVIDER
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_BUCKET_NAME: $INPBUCKET_NAME
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_ACCOUNT: $INPBUCKET_AZURE_ACCOUNT
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_GOOGLE_CREDENTIALS: "credentials-input/Sensoriant-gcs-data-bucket-ServiceAcct.json"
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_PROVIDER: $OUTBUCKET_STORAGE_PROVIDER
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_BUCKET_NAME: $OUTBUCKET_NAME
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_ACCOUNT: $OUTBUCKET_AZURE_ACCOUNT
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_GOOGLE_CREDENTIALS: "credentials-output/Sensoriant-gcs-data-bucket-ServiceAcct.json"
        SENS_ALGO_DREG: ${SENS_ALGO_DREG}
        SENS_EXT_IMAGE_DREG: $SENS_SAFECTL_EXTERNAL_REG
        SENSCR_NAME: ${SENSCR_NAME}
        SECURE_CLOUD_API_STORAGE_INTERNAL_AMAZON_CREDENTIALS: $SENSINT_STORAGE_CREDS
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_AMAZON_CREDENTIALS: $INPBUCKET_STORAGE_CREDS
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_AMAZON_CREDENTIALS: $OUTBUCKET_STORAGE_CREDS
        SECURE_CLOUD_API_STORAGE_INTERNAL_AZURE_CREDENTIALS: $SENSINT_STORAGE_CREDS
        SECURE_CLOUD_API_STORAGE_DATASET_INPUT_AZURE_CREDENTIALS: $INPBUCKET_STORAGE_CREDS
        SECURE_CLOUD_API_STORAGE_DATASET_OUTPUT_AZURE_CREDENTIALS: $OUTBUCKET_STORAGE_CREDS
    
    regclient:
      repository: $DOCKER_REGISTRY_API_IMAGENAME
      tag: $DOCKER_REGISTRY_API_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $DOCKER_REGISTRY_API_DOCKER_PORT
      env:
        DOCKER_REGISTRY_API_AZURE_TOKEN: \"$SENS_ALGO_DREG_AZURE_TOKEN\"
        DOCKER_REGISTRY_API_DOCKER_PORT: $DOCKER_REGISTRY_API_DOCKER_PORT
        DOCKER_REGISTRY_API_REGISTRY: "https://${SENS_ALGO_DREG}"
        DOCKER_REGISTRY_API_SERVER_PORT: $DOCKER_REGISTRY_API_DOCKER_PORT

    scli:
      repository: $SENSCLI_IMAGENAME
      tag: ${RELEASE_TAG}
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSCLI_API_DOCKER_PORT
      env:
        GOOGLE_APPLICATION_CREDENTIALS: "/opt/creds/Sensoriant-gcs-data-bucket-ServiceAcct.json"
        SENSCLI_DREG: $SENS_ALGO_DREG
        SENSCLI_DCRED: $SENS_ALGO_DCRED
        SENSCLI_MNT: "/algo"
        SENSCLI_USE_REF: $SENSCLI_USE_REF
        SENSCLI_REF_ALGO_IMAGE: $SENSCLI_REF_ALGO_IMAGE
        SENSCLI_REF_ALGO_CREDS: $SENSCLI_REF_ALGO_CREDS
        SENSSELF_DIGEST: $SENSCLI_DIGEST
        SENSSELF_HOSTALIAS: $SENSCLI_HOSTALIAS

  ctrl-cas:
    enabled: $enablecaslas
    initcont:
      repository: $SENSUTILS_IMAGENAME
      tag: $SENSUTILS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    image:
      repository: $CAS_IMAGENAME
      tag: $CAS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    #wait-for-las tbd

  ctrl-las:
    enabled: $enablecaslas
    image:
      repository: $LAS_IMAGENAME
      tag: $LAS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: 18766

  ctrl-mdb:
    image:
      repository: mariadb
      tag: $MARIADB_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $MARIADB_DOCKER_PORT
      env:
        MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
        MYSQL_DATABASE: $MYSQL_DATABASE
        MYSQL_USER: $MYSQL_USER
        MYSQL_PASSWORD: $MYSQL_PASSWORD

  ctrl-pmgr:
    image:
      repository: $SENSPMGR_IMAGENAME
      tag: $SENSPMGR_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      env:
        USE_PREFECT: $USE_PREFECT
        PREFECT_SERVER_ADDR: $PREFECT_SERVER_ADDR
        PREFECT_API_HOST: $PREFECT_API_HOST
        PREFECT_LOG_LEVEL: $PREFECT_LOG_LEVEL
        SENSPMGR_REGISTRY: "sboxregistry:5000"
        SENSPMGR_HOST: localhost
        SENSPMGR_PORT: $SENSPMGR_PORT
        SENSPMGR_FLOW: SboxKubeFlow
        SENSPMGR_DEBUG: $SENSPMGR_DEBUG
        SENSPMGR_SEND_LOGS_TO_PREFECT: $SENSPMGR_SEND_LOGS_TO_PREFECT
        SENSPMGR_APISERVER_HOSTNAME: $apiinternalname
        SENSLLS_PORT: $SENSLLS_PORT
        SENSPORCH_PORT: $SENSPORCH_PORT
        SENSPMGR_MAX_SBOX_PIPELINES: $SENSPMGR_MAX_SBOX_PIPELINES
        SENSSELF_DIGEST: $SENSPMGR_DIGEST
        GOOGLE_APPLICATION_CREDENTIALS: "/opt/creds/Sensoriant-gcs-data-bucket-ServiceAcct.json"
        SENSPMGR_BUCKET: $SENSINT_BUCKET_NAME
        AZURE_STORAGE_ACCOUNT: $SENSINT_AZURE_STORAGE_ACCOUNT
        AZURE_STORAGE_ACCESS_KEY: $SENSINT_AZURE_STORAGE_ACCESS_KEY
        SENSORIANT_STORAGE_PROVIDER: $SENSINT_STORAGE_PROVIDER
        SENSINT_STORAGE_CREDS: $SENSINT_STORAGE_CREDS

  ctrl-ras:
    checkmdb:
      repository: $SENSUTILS_IMAGENAME
      tag: $SENSUTILS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    checkcas:
      repository: $SENSUTILS_IMAGENAME
      tag: $SENSUTILS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    image:
      repository: $SENSRAS_SERVER_IMAGENAME
      tag: $SENSRAS_SERVER_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: 5010
      env:
        MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
        MYSQL_DATABASE: $MYSQL_DATABASE
        MYSQL_USER: $MYSQL_USER
        MYSQL_PASSWORD: $MYSQL_PASSWORD
        SENSORIANT_SPIRE_TRUST_DOMAIN: $SENSORIANT_SPIRE_TRUST_DOMAIN
        SENSORIANT_SPIRE_SERVER_PORT: $SENSORIANT_SPIRE_SERVER_PORT
        SENSORIANT_SPIRE_SERVER_PLATFORM_MEASUREMENT_WHITELIST: '[]'
        RELEASE_TAG: $RELEASE_TAG
        GCS_BUCKET_NAME: $GCS_BUCKET_NAME
        SENSCLI_DREG: $SENSCLI_DREG
        LOG_LEVEL: "INFO"
        SENSSELF_DIGEST: $SENSRAS_SERVER_DIGEST
        SENSSELF_HOSTALIAS: $SENSRAS_SERVER_HOSTALIAS

  ctrl-rls:
    ingress:
      enabled: $rlsingressenabled
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: letsencrypt
      hosts:
        - host: $rlsname
          paths:
          - path: /
      tls: 
         - hosts:
             - $rlsname
           secretName: ctrl-rls-general-tls
    image:
      repository: $SENSRLS_IMAGENAME
      tag: $SENSRLS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSRLS_MTLS_PORT
      env:
       SENSRLS_MTLS_PORT: $SENSRLS_MTLS_PORT
       SENSRLS_API_PORT: $SENSRLS_API_PORT
       SENSRLS_HOSTNAME: $ctrln
       SENSSELF_DIGEST: $SENSRLS_DIGEST
       CAS_MRENCLAVE: $CAS_MRENCLAVE
    archiver:
      repository: $SENSARCHIVER_IMAGENAME
      tag: $SENSARCHIVER_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSARCHIVER_PORT
      env:
       SENSARCHIVER_HTTP_PORT: $SENSARCHIVER_HTTP_PORT
       SENSARCHIVER_SOURCE_DIRECTORY: $SENSARCHIVER_SOURCE_DIRECTORY
       SENSARCHIVER_TYPE: $SENSINT_STORAGE_PROVIDER
       SENSARCHIVER_INTERVAL: $SENSARCHIVER_INTERVAL
       SENSARCHIVER_DELETE_FILES: $SENSARCHIVER_DELETE_FILES
       SENSARCHIVER_DESTINATION_DIR: $SENSARCHIVER_DESTINATION_DIR
       SENSARCHIVER_IPFSDIR: $SENSARCHIVER_IPFSDIR
       SENSARCHIVER_IPFSIPADDR: $SENSARCHIVER_IPFSIPADDR
       SENSARCHIVER_IPFSPORT: $SENSARCHIVER_IPFSPORT
       #SENSARCHIVER_PREFIX: ".${ctrln}${SENSARCHIVER_PREFIX}"
       SENSARCHIVER_PREFIX: "${SENSARCHIVER_PREFIX}/${ctrln}/"
       SENSARCHIVER_BUCKET_NAME: $SENSINT_BUCKET_NAME
       #SENSARCHIVER_HOSTNAME: $ctrln
       SENSSELF_DIGEST: $SENSARCHIVER_DIGEST
       AZURE_STORAGE_ACCOUNT: $SENSINT_AZURE_STORAGE_ACCOUNT
       AZURE_STORAGE_ACCESS_KEY: $SENSINT_AZURE_STORAGE_ACCESS_KEY
       GOOGLE_APPLICATION_CREDENTIALS: "/opt/creds/Sensoriant-gcs-data-bucket-ServiceAcct.json"
  ctrl-lls:
    image:
      repository: $SENSLLS_IMAGENAME
      tag: $SENSLLS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSLLS_PORT
      env:
       SENSLLS_PORT: $SENSLLS_PORT
       SENSRLS_MTLS_PORT: $SENSRLS_MTLS_PORT
       SENSRLS_API_PORT: $SENSRLS_API_PORT
       SENSLLS_URL: $SENSLLS_URL
       SENSLLS_HOSTNAME: $ctrln
       SENSSELF_DIGEST: $SENSLLS_DIGEST

sensssp:
  enabled: true
  ssp-las:
    enabled: $enablecaslas
    image:
      repository: $LAS_IMAGENAME
      tag: $LAS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: 18766

  ssp-ras:
    # other init images in pod tbd
    initcont:
      repository: $SENSUTILS_IMAGENAME
      tag: $SENSUTILS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
    image:
      repository: $SENSRAS_AGENT_IMAGENAME
      tag: $SENSRAS_AGENT_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      env:
        SENSORIANT_SPIRE_TRUST_DOMAIN: $SENSORIANT_SPIRE_TRUST_DOMAIN
        SENSORIANT_SPIRE_SERVER_PORT: $SENSORIANT_SPIRE_SERVER_PORT
        SENSORIANT_ATTESTATION_DOCKER_PORT: "9005"
        SENSORIANT_PLATFORM_SIGNING_KEY: ""
        SENSORIANT_PLATFORM_PROVIDER: $SENSORIANT_PLATFORM_PROVIDER
        RELEASE_TAG: $RELEASE_TAG
        GCS_BUCKET_NAME: $SENSINT_BUCKET_NAME
        SENSCLI_DREG: $SENS_ALGO_DREG
        LOG_LEVEL: "INFO"
        SENSSELF_DIGEST: $SENSRAS_AGENT_DIGEST
        SENSSELF_HOSTALIAS: $SENSRAS_AGENT_HOSTALIAS

  ssp-senslas:
    image:
      repository: $SENSLAS_IMAGENAME
      tag: $SENSLAS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: 9005

  ssp-lls:
    image:
      repository: $SENSLLS_IMAGENAME
      tag: $SENSLLS_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSLLS_PORT
      env:
       SENSLLS_PORT: $SENSLLS_PORT
       SENSRLS_MTLS_PORT: $SENSRLS_MTLS_PORT
       SENSRLS_API_PORT: $SENSRLS_API_PORT
       SENSLLS_URL: $SENSLLS_URL
       SENSLLS_HOSTNAME: $sbn
       SENSSELF_DIGEST: $SENSLLS_DIGEST

  ssp-orch:
    replicaCount: $SENSPMGR_MAX_SBOX_PIPELINES
    image:
      repository: $SENSPORCH_IMAGENAME
      tag: $SENSPORCH_TAG
      pullPolicy: $SENSIMAGEPULL_POLICY
      containerPort: $SENSPORCH_PORT
      env:
        SENSPMGR_PORT: $SENSPMGR_PORT
        SENSPORCH_PORT: $SENSPORCH_PORT
        USE_PREFECT: $USE_PREFECT
        PREFECT_SERVER_ADDR: $PREFECT_SERVER_ADDR
        PREFECT_API_HOST: $PREFECT_API_HOST
        PREFECT_LOG_LEVEL: $PREFECT_LOG_LEVEL
        SENSPMGR_PROJ: $SENSPMGR_PROJ
        SENSPMGR_FLOW: SboxKubeFlow
        SENSPMGR_SEND_LOGS_TO_PREFECT: $SENSPMGR_SEND_LOGS_TO_PREFECT
        SENSSELF_DIGEST: $SENSPORCH_DIGEST
        SENSSELF_HOSTALIAS: $SENSPORCH_HOSTALIAS
        SENS_PIPELINE_TEMPLATE_DEFAULT: $SENS_PIPELINE_TEMPLATE_DEFAULT
        SENS_PIPELINE_TEMPLATE_KAFKA: $SENS_PIPELINE_TEMPLATE_KAFKA

" > install-tmp/sensvals.yaml
