#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
BASEDIR=$(dirname "$0")
COMMON_INSTALL=${BASEDIR}/components/common-install
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file:///opt/hpe/static/manifests.tar.gz"}
INTERNAL_TLS_SECRET_NAME=kf-jobs-cert-secret
HTTP_PROXY=$http_proxy
HTTPS_PROXY=$https_proxy
NO_PROXY=$no_proxy

export HTTP_PROXY HTTPS_PROXY NO_PROXY KF_JOBS_NS

# Check if var is set https://stackoverflow.com/a/13864829 
if [ -z ${USER_AIRGAP_REGISTRY+x} ]; then
    USER_AIRGAP_REGISTRY=$AIRGAP_REGISTRY
    export USER_AIRGAP_REGISTRY
fi

test_env_vars()
{
    local ret_val=0

    echo ${KF_JOBS_NS} | grep ".*\s.*" && {
        echo 'KF_JOBS_NS should not contain any spaces.'
        ret_val=1
    }

    echo ${TLS_SECRET_NAME} | grep ".*\s.*" && {
        echo 'TLS_SECRET_NAME should not contain any spaces.'
        ret_val=1
    }

    echo ${TLS_SECRET_NS} | grep ".*\s.*" && {
        echo 'TLS_SECRET_NS should not contain any spaces.'
        ret_val=1
    }

    if [ -n "$TLS_SECRET_NAME" ] && [ -n "$TLS_CERT_LOCATION" ]; then
        echo 'TLS_SECRET_NAME and TLS_CERT_LOCATION should not be set at the same time.'
        ret_val=1
    fi

    if [ "${TLS_SECRET_NAME:+true}" != "${TLS_SECRET_NS:+true}" ]; then
        echo 'TLS_SECRET_NAME and TLS_SECRET_NS should either be both set or unset.'
        ret_val=1
    fi

    if [ "${TLS_KEY_LOCATION:+true}" != "${TLS_CERT_LOCATION:+true}" ]; then
        echo 'TLS_KEY_LOCATION and TLS_CERT_LOCATION should either be both set or unset.'
        ret_val=1
    fi

    if ! [ -r $TLS_KEY_LOCATION ]; then
        echo "TLS_KEY_LOCATION either represents an invalid path or the provided file can't be read."
        ret_val=1
    fi

    if ! [ -r $TLS_CERT_LOCATION ]; then
        echo "TLS_CERT_LOCATION either represents an invalid path or the provided file can't be read."
        ret_val=1
    fi

    return $ret_val
}

if test_env_vars; then

    # clean previously copied entrypoint.sh + job.yaml
    if [ -f ${COMMON_INSTALL}/entrypoint.sh ]; then
	rm ${COMMON_INSTALL}/entrypoint.sh
    fi

    if [ -f ${COMMON_INSTALL}/job.yaml ]; then
	rm ${COMMON_INSTALL}/job.yaml
    fi

    # copy entrypoint.sh + job.yaml from uninstall folder
    cp ${COMMON_INSTALL}/install/entrypoint.sh ${COMMON_INSTALL}/
    cp ${COMMON_INSTALL}/install/job.yaml ${COMMON_INSTALL}/

    if kubectl get ns ${KF_JOBS_NS} 1> /dev/null ; then
	kubectl delete ns ${KF_JOBS_NS}
    fi
    kubectl create ns ${KF_JOBS_NS}

    if ! [ -z "${TLS_SECRET_NAME}" ]; then
        kubectl get secret ${TLS_SECRET_NAME} -n ${TLS_SECRET_NS} -o yaml | sed "s/name: ${TLS_SECRET_NAME}/name: ${INTERNAL_TLS_SECRET_NAME}/g ; /namespace:/d" | kubectl apply --namespace=${KF_JOBS_NS} -f -
    elif ! [ -z "${TLS_KEY_LOCATION}" ]; then
        kubectl create secret tls ${INTERNAL_TLS_SECRET_NAME} --key ${TLS_KEY_LOCATION} --cert ${TLS_CERT_LOCATION} -n ${KF_JOBS_NS}
    fi

    kubectl apply -k ${BASEDIR}/components/image-pull-secret/jobs -n ${KF_JOBS_NS}
    kubectl apply -k ${COMMON_INSTALL} -n ${KF_JOBS_NS}
    echo "kubeflow install script finished done"
else
    echo "kubeflow install script failed."
    exit 1
fi
