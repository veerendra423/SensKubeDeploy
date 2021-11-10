#!/bin/bash

a=$(kubectl get pods | awk '/p1-*|p2-*|s1-*/{print $1}')
kubectl get pods $a -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.name}{", "}{end}{end}' |sort
