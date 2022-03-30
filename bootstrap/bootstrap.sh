#!/bin/bash

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
#WORKDIR is defined in kf-installer Dockerfile
WORKDIR="/opt/hpe"
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file://$WORKDIR/static/manifests.tar.gz"}
MANIFESTS_MOUNT_PATH=${MANIFESTS_MOUNT_PATH:-"$WORKDIR/manifests"}
INTERNAL_TLS_SECRET_NAME=kf-jobs-cert-secret
OIDC_PROVIDER=${OIDC_PROVIDER:-http://dex.auth.svc.cluster.local:5556/dex}
KF_INSTALLER_IMAGE=${KF_INSTALLER_IMAGE:-gcr.io/mapr-252711/kubeflow/installer}
KF_INSTALLER_IMAGE_TAG=${KF_INSTALLER_IMAGE_TAG:-v1.4.0-gl-2}

export KF_JOBS_NS OIDC_PROVIDER CA_SECRET_KEY CA_SECRET_NAME KF_INSTALLER_IMAGE KF_INSTALLER_IMAGE_TAG
export WORKDIR MANIFESTS_LOCATION MANIFESTS_MOUNT_PATH

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

apply_tls_secrets(){
    if [ -n "${TLS_SECRET_NAME}" ]; then
        echo "*** apply tls secrets from TLS_SECRET_NAME: ${TLS_SECRET_NAME}"
        kubectl get secret ${TLS_SECRET_NAME} -n ${TLS_SECRET_NS} -o yaml \
            | sed "s/name: ${TLS_SECRET_NAME}/name: ${INTERNAL_TLS_SECRET_NAME}/g ; /namespace:/d" \
            | kubectl apply --namespace=${KF_JOBS_NS} -f -
    elif [ -n "${TLS_KEY_LOCATION}" ]; then
        echo "*** apply tls secrets from TLS_KEY_LOCATION: ${TLS_KEY_LOCATION}"
        kubectl create secret tls ${INTERNAL_TLS_SECRET_NAME}\
                --key ${TLS_KEY_LOCATION}\
                --cert ${TLS_CERT_LOCATION}\
                -n ${KF_JOBS_NS}
    fi
}

scale_deployment (){
    kubectl -n $KF_JOBS_NS scale deployment/kf-installer --replicas="$1"
}

get_config_value (){
    echo $(kubectl get -n $KF_JOBS_NS cm/kf-bootstrap-config -o "jsonpath={.data.$1}")
}

set_config_value (){
    kubectl patch -n $KF_JOBS_NS cm/kf-bootstrap-config \
            --type merge -p "{\"data\":{\"$1\":\"$2\"}}"
    echo "Set config: $1 = $2"
}

run_kubeflow_installer(){
    local Command=$1
    if test_env_vars; then
        if ! kubectl get ns ${KF_JOBS_NS} >/dev/null 2>&1 ; then
            kubectl create ns ${KF_JOBS_NS}
        fi

        apply_tls_secrets

        kubectl apply -k ./components/kubeflow -n ${KF_JOBS_NS}

        echo
        set_config_value "running" "true"
        set_config_value "error" "false"
        set_config_value "command" "$Command"

        echo
        scale_deployment 1

        local Retries=20
        local Timeout=3
        printf "\nWaiting for kf-installer to be running"
        while [ ! $(kubectl get pods -n $KF_JOBS_NS -l name=kf-installer -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') = "True" ]
        do
            printf "."
            Retries=$(( Retries - 1 ))
            if [ "$Retries" -le 0 ]; then
                printf "\nFailed waiting for kf-installer to be running.\n\n"
                scale_deployment 0
                exit 1
            fi
            sleep $Timeout
        done
        printf "\n\n"

        local Pod_name=$(kubectl get pods -n $KF_JOBS_NS -l name=kf-installer -o jsonpath='{.items[0].metadata.name}' )
        echo "To fetch pod logs run:"
        echo "kubectl logs -f -n $KF_JOBS_NS $Pod_name"
        echo
        echo "To run bash in the pod run:"
        echo "kubectl exec --stdin --tty -n $KF_JOBS_NS $Pod_name -- /bin/bash"

        Retries=60
        Timeout=20
        printf "\nWaiting for kubeflow to be ${Command}ed"
        while [ $(get_config_value "running") != "false" ] && \
                  [ $(get_config_value "error") != "true" ]
        do
            printf "."
            Retries=$(( Retries - 1 ))
            if [ "$Retries" -le 0 ]; then
                printf "\nFailed waiting for kf-installer to be finished."
                break
            fi
            sleep $Timeout
        done
        printf "\n\n"
        
        local Running=$(get_config_value "running")
        local Error=$(get_config_value "error")
        echo "Command:$Command, Running:$Running, Error:$Error"
        if [ "$Running" = "false" ] && [ "$Error" = "false" ]; then
            echo "kubeflow $Command script finished done"
        else
            echo "kubeflow $Command script failed."
            echo
            echo "************* Logs: $Pod_name *************"
            kubectl logs -n $KF_JOBS_NS $Pod_name
            sleep 5
        fi
        scale_deployment 0
    else
        echo "kubeflow $Command script failed."
        exit 1
    fi
}

is_command_valid(){
    if [ "$1" = "install" ] ||
           [ "$1" = "uninstall" ] ; then
        return 0
    elif [ -z "$1" ]; then
        echo "Kubeflow bootstrap command is empty"
    else
        echo "Undefined kubeflow bootstrap command: $1"
    fi
    return 1
}

#This section used to run run_kubeflow_installer dirrectly from bootstrao.sh script
#example: ./bootstrap.sh install
Command="$1"
if [ -n "${Command:+true}" ] && is_command_valid "$Command"; then
    run_kubeflow_installer "$Command"
fi
