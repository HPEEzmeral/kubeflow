#!/bin/sh

COPY_NS=${COPY_NS:-kubeflow-jobs}

secretPresent=$(kubectl get secrets -n "$COPY_NS" | grep 'copy-secret')

if [ -z "$secretPresent" ]
then
    echo "Please create minio-secret"
else
    AIRGAP_REGISTRY=${AIRGAP_REGISTRY} kustomize build . | kubectl -n ${COPY_NS} apply -f -
fi

