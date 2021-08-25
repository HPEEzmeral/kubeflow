#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
BASEDIR=$(dirname "$0")
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file:///opt/hpe/static/manifests.tar.gz"}

# Check if var is set https://stackoverflow.com/a/13864829 
if [ -z ${USER_AIRGAP_REGISTRY+x} ]; then
    USER_AIRGAP_REGISTRY=$AIRGAP_REGISTRY
    export USER_AIRGAP_REGISTRY
fi

kubectl create ns ${KF_JOBS_NS}
kubectl apply -k ${BASEDIR}/components/image-pull-secret/jobs -n ${KF_JOBS_NS}
kubectl apply -k ${BASEDIR}/components/installer -n ${KF_JOBS_NS}
