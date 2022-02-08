#!/bin/sh

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
MANIFESTS_DIR=manifests
CURRENT_DIR=$(pwd)

DISABLE_ISTIO=${DISABLE_ISTIO:-false}
DISABLE_NOTEBOOKSERVERS_LINK=${DISABLE_NOTEBOOKSERVERS_LINK:-false}
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file://${CURRENT_DIR}/static/manifests.tar.gz"}
ISTIO_DIR=${ISTIO_DIR:-istio-1-9}

MAX_RETRIES=
RETRY_TIMEOUT=8
KUBE_NAMESPACE=
TIMEOUT=

process_service_resources()
{
    local namespace=
    if [ -n "${KUBE_NAMESPACE}" ]; then
	namespace="-n ${KUBE_NAMESPACE}"
    fi

    local cur_retries=

    for man in ${@}; do
        cur_retries=0 ;
        printf "\n*** Trying to ${KUBE_CMD} ${man}... ***\n\n" ;
        while ! ./kustomize build ${MANIFESTS_DIR}/${man} | kubectl ${KUBE_CMD} -f - ${namespace} ; do
            echo "Try ${cur_retries}/${MAX_RETRIES}"
            cur_retries=$((cur_retries+1));
            if (( MAX_RETRIES > 0 && cur_retries > MAX_RETRIES )); then
                printf "\n*** ${man} ${KUBE_CMD} failed ***\n\n"
                if [ ${KUBE_CMD} = "delete" ]; then
                    break 1
                else
                    exit 1
                fi
            fi;
            sleep ${RETRY_TIMEOUT};
            printf "\n***Retrying to ${KUBE_CMD} ${man}... ***\n\n"
        done;
    done
}

namespace_exists()
{
    local namespace=$1 
    kubectl get ns ${namespace} 1> /dev/null
    return $?
}
