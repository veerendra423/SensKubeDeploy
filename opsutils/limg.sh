#!/bin/bash
kubectl get pods --all-namespaces -o jsonpath="{..image} {..imageID}" |tr -s '[[:space:]]' '\n' |sort |uniq -c | sed 's/.* //' | grep sensoriant


