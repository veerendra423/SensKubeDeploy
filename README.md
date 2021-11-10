# Basic usage
## creating a cluster

akscreatecluster.sh and aksdeletecluster.sh are used to create/delete an azure cluster

gkecreatecluster.sh and gkedeletecluster.sh are used to create/delete an gke cluster

(usage info for the above will be printed if you run any of the above without any parameters)

Note: the values specified in config/custom.env (details of contents later below) are associated with the cluster at cluster creation time

## installing SafeliShare software on the cluster

first choose the software version you want to install and get the required configuration for that version using

```sh
./getsensenv.sh <version tag>` e.g. VERSION_1_3_3-devel
```

note: getsensenv.sh creates a file called staging.env in the install-tmp directory
then install/uninstall using sensinstall.sh and sensdelete.sh

## configuration - customization and overrides

several configuration files are available in the config directory
- custom.env : the contents of this file specify the various container registries and buckets used in deployment and are associated with a cluster at the time of cluster creation. this file is ONLY used at the time of cluster creation
- kubelocal.env : do not change the contents of this file
- skif.env : only used for GKE clusters (details tbd)
- overrides.custom.env : the contents of this file override any custom values associated with the cluster on which the software is being installed
- dev.env: overrides values in staging.env and is only used on clusters wih subdomain "devel"
- overrides.env : the contents of this file override any values specified in staging.env and dev.env

## Certificates
There are three ways to get certificates:
- Using a new zerossl eab account: to use this mode, following is needed:
```sh
USE_ZEROSSL=true
USE_ZEROSSL_EXISTING_ACCOUNT=false
edit the file utils/cm-data/cluster-issuers/zerossl-newAccount.yaml and update the keyKID in the issuer spec and secret in the data part of secret (needs to be base64 encoded)
to use this account on other clusters, follow instructions in utils/start_clusterissuer.sh to create a file and use that as USE_ZEROSSL_ACCOUNT_SECRET
kubectl get secret letsencrypt -ojson | \
       jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid) | .metadata.creationTimestamp=null' \
      > filenameyouwant.yaml
  filenameyouwant.yaml can be used as USE_ZEROSSL_ACCOUNT_SECRET later for other clusters
```
- Using an existing zerossl eab account
```sh
USE_ZEROSSL=true
USE_ZEROSSL_EXISTING_ACCOUNT=true
USE_ZEROSSL_ACCOUNT_SECRET="/mnt/staging/default_zerossl.yaml"
```
- Using letsencrypt
```sh
USE_ZEROSSL=false
USE_ZEROSSL_EXISTING_ACCOUNT=false
```

# Helm charts for Sensoriant components

## All Azure system

This is meant to be a cookbook description -- i.e. it is one path through a complex system.  There are other paths.

There are three major pieces to the SafeliShare architecture

- the control plane (aka controller)
- the data plane (aka the sandbox / platform / enclave)
- the persistent storage

At this point, an all Azure system is being described.  There are other options.

### Glossary

| term | definition |
| ---- | ---------- |
| acr | Azure Container Registry (docker) |
| aks | Azure Kubernetes Service |
| az  | Azure command line interface |
| blobs | an unspecified-format file |
| bucket | a cloud storage container where datasets and other files are pushed / pulled |
| cli | command line interface |
| cluster | a managed set of VMs that contain pods that run containers |
| devOps | device operations |
| jq  | a utility that pretty prints and inspects JSON |
| registry | a docker registry (acr) where encrypted safelets are pushed / pulled |
| repo | Git repository |
| vm  | Virtual Machine |

### Basic idea

At present we have varying levels of privilege that this document describes.

- Administrator -- has complete control over the Azure account.
- DevOps -- has ability to create / install / destroy clusters for users
- Users -- can only access the Safestream API endpoint.  No other access.

### Administrator Tasks

#### Create an Azure login

Admin will create an Azure login with at least the following Administrative Roles:

- Application administrator
- Application developer
- Azure DevOps administrator

That should result in login having at least the following privileges:

- Microsoft.Resources/subscriptions/resourcegroups/read
- Microsoft.ContainerService/managedClusters/agentPools/read
- Microsoft.ContainerService/managedClusters/listClusterUserCredential/action
- Microsoft.ContainerService/managedClusters/write
- Microsoft.ContainerService/managedClusters/agentPools/write
- Microsoft.ContainerService/managedClusters/delete
- Microsoft.Network/dnsZones/A/delete

#### Create an Azure resource group

- Admin will create

#### Create an Azure storage container (aka bucket)

In Azure terms, a storage account contains a storage container with an access key, and the storage container contains blobs.

The storage account name, container name, and access key will be needed from the administrator.

#### Create an Azure docker registry

The acr (docker registry) name and username:password access key will be needed from the administrator.

#### Create an Admin Linux VM to be used by DevOps

- Create a simple Linux VM to be used by DevOps for a given user.
- Create a `DevOps` login on the Admin VM
- Create a /home/DevOps/.ssh folder (if not already there) with o700 permissions
- Create a SensKubeDeploy deploy key on the Admin VM in the same ~/.ssh/ folder `ssh-keygen -t rsa -b 4096 -C "SensKubeDeployKey"`
- Add the associated public key to the SensKubeDeploy git repository. https://docs.github.com/en/developers/overview/managing-deploy-keys
- Get the DevOps person's public key, and append to the .ssh/authorized_keys file on the Admin VM
- Install Azure Command Line Interface (CLI) https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- Install jq `sudo apt-get install jq`
- Clone the SensKubeDeploy repo `git clone git@github.com:sensoriant/SensKubeDeploy.git`

The Admin VM URL will be need to be supplied by the administrator.

At this point, DevOps should be able to complete their tasks.

### DevOps Tasks

#### Log into the Admin Linux VM

- `ssh -i <DevOps person's private key file> DevOps@<vm address>`

#### Enter the SensKubeDeploy folder

- `cd SensKubeDeploy`

#### Log into Azure CLI

- `az login` (follow prompts)

#### List resource group(s)

- `az group list | jq` (will list the whole resource group)
- `az group list | jq .[].name` (will list only the resource group names)

#### List the storage accounts / storage containers

- `az storage account list | jq .[].name` (will list just the storage account names)
- `az storage container list --account-name <account name from above command> | jq .[].name` (list the storage container aka bucket names)

#### List the docker registries

- `az acr list | jq .[].name` (will list the names of the docker registries)

#### Edit the `config/custom.env`

##### Set env variables to use new storage container

- Uncomment and set `AZURE_STORAGE_ACCOUNT` appropriately -- the storage account name from above
- Uncomment and set `GCS_BUCKET_NAME` appropriately -- the storage container name from above
- Uncomment and set `AZURE_STORAGE_ACCESS_KEY` appropriately -- as given from administrator

##### Set the env variables to use the new docker container registry

- Uncomment and set `SENSCLI_DREG` appropriately -- the URI (without scheme) of the registry
- Uncomment and set `SENSCLI_DCRED` apprpriately -- the username:password for the registry

Save the modified config/custom.env file

#### Create Azure Kubernetes cluster

- pick a nickname for your cluster (e.g. your initials)
- `./akscreatecluster.sh <cluster nickname> <resource group name>`

This will create a cluster named `aks-<cluster nickname>`

#### List cluster

- `az aks list | jq` (will list the whole cluster)
- `az aks list | jq .[].name` (will list just the cluster name)

#### Switch to the cluster

- Switch over to your new cluster `./opsutils/switchtocluster.sh <aks | gke> <cluster name> <resource group name>`

#### Set the software environment to use

- `./getsensenv.sh <version tag>` e.g. VERSION_1_3_3-devel

#### Install the software and fire up the pods

- `./sensinstall.sh`

#### Delete cluster (if needed)

- Switch to cluster as above
- Delete the cluster `./aksdeletecluster.sh <cluster nickname> <resource group name>`

At this point, the user can begin using the system

### User tasks

There are five basic user types for the SafeliShare system.

- Safelet provider
- Dataset provider
- Output credentials provider
- Safestream operator
- Output retriever / consumer

A user can be one or more of these user types.

Each separate user neeeds to do the following:

#### Obtain a Linux system (VM or real)

#### Install the SafeliShare CLI on that machine

#### Go into the SafeliShare CLI folder

- `cd <folder>`

At this point, the tasks vary by user type

#### Agree on a session name

In order to make coordination between the five user types (or roles), it will be helpful (but not required) to agree on a "session" name for the shared session that is planned -- where session means the sharing of inputs, outputs, and safelets with the SafeliShare system for Safestream computations.  Thus, all the encrypted secrets, safelets, and datasets will share a common session name -- making them easy to discern from other data in the system.

By default, the session name is set to the user's username on their Linux system

#### Notes on order

While shown below with numbers 1 - 5, there is no required ordering of the three provider tasks.  So steps 1-3 can be run in any order.  They each result in a secret ID.

Step 4 requires that all three of steps 1-3 have completed.  And Step 5 requires step 4 to have completed.

#### Looking for secrets

At any time a user can list the secrets stored in the vault by doing `bin/safectl list secrets`

#### Safelet Provider tasks

A safelet is a docker container in a docker registry (of the user's) that contains an algorithm that is to be run.  The safelet parameters are:

- the entry point (or command) to be run on that container
- the reference image URL for the container (in a local or other non-SafeliShare registry) that is to be encrypted for SafeliShare use.
- the access credentials for the local/non-SafeliShare registry

##### Edit the scripts/1-safelet_provider.sh file

Update the subject file to include the proper parameters.

##### Run the scripts/1-safelet_provider.sh script

- `./scripts/1-safelet_provider.sh <session name>`

The script will then perform the following tasks:

- Create an Owner Key (symmetric) to be used to encrypt the safelet
- Encrypt the safelet with the owner key
- Push the encrypted safelet to the SafeliShare container registry
- Get the SafeliShare platform's public key
- Encrypt the owner key with the SafeliShare platform's public key
- Push the encrypted symmetric key to the SafeliShare Secrets vault.
- Pushing to the Secrets vault will return a Secret ID.

At this point, the Safelet is fully encrypted and in the SafeliShare registry.  The decryption key for the Safelet has been encrypted with the SafeliShare platform's public key -- and can only be decrypted inside the SafeliShare enclave.

The Safelet Provider can now supply the received Secret ID to the Safestream Operator user.

#### Dataset Provider tasks

A dataset is a folder of datafiles (can be nested).  The dataset parameters are:

- the root folder path of the dataset

##### Edit the scripts/2-data_provider.sh file

Update the subject file to include the proper parameters.

##### Run the scripts/2-data_provider.sh script

- `./scripts/2-data_provider.sh <session name>`

The script will then perform the following tasks:

- Create an Owner Key (symmetric) to be used to encrypt the dataset
- Encrypt the dataset with the owner key
- Push the encrypted dataset to the SafeliShare storage container
- Get the SafeliShare platform's public key
- Encrypt the owner key with the SafeliShare platform's public key
- Push the encrypted symmetric key to the SafeliShare Secrets vault.
- Pushing to the Secrets vault will return a Secret ID.

At this point, the Dataset is fully encrypted and in the SafeliShare storage container.  The decryption key for the Dataset has been encrypted with the SafeliShare platform's public key -- and can only be decrypted inside the SafeliShare enclave.

The Dataset Provider can now supply the received Secret ID to the Safestream Operator user.

#### Output Credentials Provider tasks

The result of running a Safestream is an output dataset.  The Output Credentials Provider provides the credentials needed to encrypt the output dataset such that only the intended recipient will be able to read the output dataset.

##### Run the scripts/3-outputprovider_pushoutpoutkey.sh script

- `./scripts/3-outputprovider_pushoutputkey.sh <session name>`

The script will then perform the following tasks:

- Create an Owner Key (symmetric) to be used to encrypt the output dataset (when it exists)
- Get the SafeliShare platform's public key
- Encrypt the owner key with the SafeliShare platform's public key
- Push the encrypted symmetric key to the SafeliShare Secrets vault.
- Pushing to the Secrets vault will return a Secret ID.

At this point, the output dataset's owner key has been encrypted with the SafeliShare platform's public key -- and can only be decrypted inside the SafeliShare enclave.

The Output Credentials Provider can now supply the received Secret ID to the Safestream Operator user.

#### Safestream Operator tasks

Once the Stream Operator has the three SafeliShare Secret IDs (from the three providers), the Safestream is ready to be run.

##### Edit the scripts/4-safestream_operator.sh file

Update the subject file to include the three Secret IDs.

##### Run the scripts/scripts/4-safestream_operator.sh script

- `./scripts/scripts/4-safestream_operator.sh <session name>`

The script will then perform the following tasks inside the SafeliShare platform's enclave:

- Download the three SafeiShare secrets from the vault -- into the platform.
- Decrypt the three secrets using the platform's private key (now the secrets are in the clear -- inside the enclave)
- Download the input dataset
- Decrypt the input dataset using the appropriate secret (now the dataset is in the clear -- inside the enclave)
- Download the safelet
- Decrypt the safelet using the appropriate secret (now the saflet is in the clear -- inside the enclave)
- Run the safelet on the input dataset, creating the output dataset (in the clear -- inside the enclave)
- Encrypt the output dataset using the appropriate secret's symmetric key.
- Push the encrypted output dataset to the SafeliShare storage container
- Encrypt the output dataset's encryption key with the supplied output recipient's public key
- Push the encrypted decryption key to the SafeiShare Secrets Vault
- Pushing to the Secrets vault will return a Secret ID.

At this point, the encrypted output dataset is in the SafeliShare Storage Container.  And the associated encrypted decryption key is in the Secrets vault.

Note:  This script is asynchronous -- where it is very important to note that the script will return almost immediately after starting it.  That does not mean that the above tasks are all complete.  

It is incumbent upon the user to monitor the pipeline progress (using `bin/safectl list safestreams`) to determine when the safestream either completes successfully, or fails.  Once the safestream has completed successfully, the resulting secret can be found by doing `bin/safectl list secrets` and looking for the appropriate dataset secret associated with the session name started.

The Safestream Opertor can now supply the received Secret Name to the Output Retriever / Consumer user.

#### Output Retriever / Consumer user tasks

The Output Retriever's parameters are:

- The name of the Secret in the Secret Vault

##### Edit the scripts/5-outputconsumer_pulloutput.sh file

Update the subject file to include the proper parameters.

##### Run the 5-outputconsumer_pulloutput.sh script

- `./scripts/5-outputconsumer_pulloutput.sh <session name>`

The script will then perform the following tasks:

- Download the secret from the Secret vault
- Decrypt the downloaded secret using the Output recipient's private key
- Download the output dataset from the SafeiShare Storage container
- Decrypt the downloaded dataset with the decrypted decryption key.

At this point, the output dataset is now fully decrypted and on the Output Recipient's local machine.









