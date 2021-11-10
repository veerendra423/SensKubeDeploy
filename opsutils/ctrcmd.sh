#!/bin/bash

if [ "$#" -lt 2 ]; then
   echo "Usage: ctrcmd.sh <logs|bash|describe|sh> <container-unique-suffix> [pod-unique-prefix]"
   exit 1
fi

cmd=$1
ctrsuffix=$2
podprefix=$3

a=$(kubectl get pods | awk '/p1-*|p2-*|s1-*/{print $1}')
if [ -z "$podprefix" ]; then
   n=$(kubectl get pods $a -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{" "}{end}{end}' | grep -E ".*$ctrsuffix[ $]" | wc -l)
else
   n=$(kubectl get pods $a -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{" "}{end}{end}' | grep -E ".*$ctrsuffix[ $]" | grep -E "$podprefix.*" | wc -l)
fi
if [ $n -eq 0 ]; then
   echo "No matches for suffix ($ctrsuffix), pod prefix ($podprefix)"
   exit 1
fi
if [ $n -gt 1 ]; then
   echo "Multiple matches for suffix ($ctrsuffix), pod prefix ($podprefix)"
   exit 1
fi
if [ -z "$2" ]; then
   line=$(kubectl get pods $a -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{" "}{end}{end}' | grep -E ".*$ctrsuffix[ $]")
else
   line=$(kubectl get pods $a -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{" "}{range .spec.containers[*]}{.name}{" "}{end}{end}' | grep -E ".*$ctrsuffix[ $]" | grep -E "$podprefix.*")
fi

found=false
for word in $line
do
   ctrname=$(echo $word | grep "$ctrsuffix$")
   if [ $? -eq 0 ]; then
      found=true
      break
   fi
   ctrname=$(echo $word | grep "$ctrsuffix ")
   if [ $? -eq 0 ]; then
      found=true
      break
   fi
done

if [ "$found" == "false" ]; then
   echo "Something went wrong"
   exit 1
fi

podname=$(echo $line | awk '{print $1}')
if [ "$cmd" == "logs" ]; then
   echo Showing logs for Pod: $podname, Container: $ctrname
   kubectl logs -f $podname -c $ctrname
elif [ "$cmd" == "describe" ]; then
   kubectl describe pod $podname 
else
   kubectl exec -it $podname -c $ctrname -- $cmd
fi
