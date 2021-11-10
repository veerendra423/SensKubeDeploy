# Create the pod

curdir=$(basename $PWD)
if [ "$curdir" != "opsutils" ]; then
   echo Make sure you are in the SensKubeDeploy/opsutils directory and try again
   exit 1
fi

LABEL=aks-ssh

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aksssh-jumpbox
  labels:
     run: $LABEL
spec:
  containers:
  - name: aks-ssh 
    image: mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
    command:
    - 'bash'
    - '-c'
    - 'while true; do sleep 5; done'
EOF

kubectl cp ../utils/cm-data/nodes-ssh/id_rsa $(kubectl get pod -l run=$LABEL -o jsonpath='{.items[0].metadata.name}'):/id_rsa
kubectl exec -it  aksssh-jumpbox -- bash -c " \
chmod 0400 /id_rsa \
"
kubectl get nodes -o wide
kubectl exec -it $(kubectl get pod -l run=$LABEL -o jsonpath='{.items[0].metadata.name}') -- ssh -i /id_rsa azureuser@$(kubectl get nodes | grep aks-nps |  awk  '{print $1}')

