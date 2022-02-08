#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
BASEDIR=$(dirname "$0")
COMMON_INSTALL=${BASEDIR}/components/common-install
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file:///opt/hpe/static/manifests.tar.gz"}
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$https_proxy
NO_PROXY=$no_proxy

export HTTP_PROXY HTTPS_PROXY NO_PROXY KF_JOBS_NS

# clean previously copied entrypoint.sh + job.yaml                                                                                                                                                     
    if [ -f ${COMMON_INSTALL}/entrypoint.sh ]; then
        rm ${COMMON_INSTALL}/entrypoint.sh
    fi

    if [ -f ${COMMON_INSTALL}/job.yaml ]; then
        rm ${COMMON_INSTALL}/job.yaml
    fi

# copying entrypoint.sh + job.yaml from uninstall folder
cp ${COMMON_INSTALL}/uninstall/entrypoint.sh ${COMMON_INSTALL}/
cp ${COMMON_INSTALL}/uninstall/job.yaml ${COMMON_INSTALL}/

if  ! kubectl get ns ${KF_JOBS_NS} 1> /dev/null ; then
    kubectl create ns ${KF_JOBS_NS}
fi

if kubectl get job -n ${KF_JOBS_NS} kf-installer 1> /dev/null ;  then
    kubectl delete job -n ${KF_JOBS_NS} kf-installer
fi

kubectl apply -k ${COMMON_INSTALL} -n ${KF_JOBS_NS}

printf "\nWaiting for kubeflow to be undeployed...\n\n"
if kubectl wait --for=condition=complete job kf-uninstaller -n ${KF_JOBS_NS} --timeout=15m; then
    kubectl delete -k ${COMMON_INSTALL} -n ${KF_JOBS_NS}
else
    echo "Error undeploying kubeflow"
fi
kubectl delete ns ${KF_JOBS_NS}
