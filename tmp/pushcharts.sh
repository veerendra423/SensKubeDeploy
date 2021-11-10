#!/bin/bash

export HELM_EXPERIMENTAL_OCI=1
helm registry login sensoriant.azurecr.io -u bb3fd7f0-72e4-4d76-ace4-b17582cc1993 -p 50b77c07-fc54-4c93-bd5b-e1d5aa5e26d1

helm chart save senspcharts/ sensoriant.azurecr.io/helmrepo/senspcharts:0.1.1
helm chart push sensoriant.azurecr.io/helmrepo/senspcharts:0.1.1

helm chart save senscharts/ sensoriant.azurecr.io/helmrepo/senscharts:0.1.0
helm chart push sensoriant.azurecr.io/helmrepo/senscharts:0.1.0


