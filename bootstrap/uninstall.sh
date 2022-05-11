#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
BASEDIR=$(dirname "$0")
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file:///opt/hpe/static/manifests.tar.gz"}
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$https_proxy
NO_PROXY=$no_proxy

export HTTP_PROXY HTTPS_PROXY NO_PROXY

KF_JOBS_NS=${KF_JOBS_NS} kubectl apply -k ${BASEDIR}/components/uninstaller -n ${KF_JOBS_NS}

printf "\nWaiting for kubeflow to be undeployed...\n\n"
if kubectl wait --for=condition=complete job kf-uninstaller -n ${KF_JOBS_NS} --timeout=15m; then
    KF_JOBS_NS=${KF_JOBS_NS} kubectl delete -k ${BASEDIR}/components/uninstaller -n ${KF_JOBS_NS}
    kubectl delete ns ${KF_JOBS_NS}
else
    echo "Error undeploying kubeflow"
fi
