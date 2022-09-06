#!/bin/sh

cd $(dirname "$0")

KUSTOMIZE=${KUSTOMIZE:-"${WORKDIR}/kustomize"}
KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
MANIFESTS_DIR=$MANIFESTS_MOUNT_PATH
DISABLE_ISTIO=${DISABLE_ISTIO:-false}
DISABLE_NOTEBOOKSERVERS_LINK=${DISABLE_NOTEBOOKSERVERS_LINK:-true}
DISABLE_DEX=${DISABLE_DEX:-false}
DISABLE_SELDON=${DISABLE_SELDON:-false}
ISTIO_DIR=${ISTIO_DIR:-istio-1-12}

. ${MANIFESTS_DIR}/bootstrap/components/kubeflow/process_service_resources.sh
. ${MANIFESTS_DIR}/bootstrap/components/kubeflow/install.sh
. ${MANIFESTS_DIR}/bootstrap/components/kubeflow/uninstall.sh


get_config_value (){
    echo $(kubectl get -n $KF_JOBS_NS --kubeconfig /opt/hpe/kubeconfig cm/kf-bootstrap-config -o "jsonpath={.data.$1}")
}

set_config_value (){
    kubectl patch -n $KF_JOBS_NS cm/kf-bootstrap-config --kubeconfig /opt/hpe/kubeconfig \
            --type merge -p "{\"data\":{\"$1\":\"$2\"}}"
    echo "Set config: $1 = $2"
}

test_env_vars()
{
    local ret_val=0

    if [ ${DISABLE_NOTEBOOKSERVERS_LINK} != true -a ${DISABLE_NOTEBOOKSERVERS_LINK} != false ]; then
        echo 'DISABLE_NOTEBOOKSERVERS_LINK should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    if [ ${DISABLE_ISTIO} != true -a ${DISABLE_ISTIO} != false ]; then
        echo 'DISABLE_ISTIO should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    if [ ${DISABLE_DEX} != true -a ${DISABLE_DEX} != false ]; then
        echo 'DISABLE_DEX should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    if [ ${DISABLE_SELDON} != true -a ${DISABLE_SELDON} != false ]; then
        echo 'DISABLE_SELDON should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    return $ret_val
}

if test_env_vars; then

    echo "pwd: $(pwd)"
    echo "workdir: $WORKDIR"
    echo "MANIFESTS_MOUNT_PATH $MANIFESTS_MOUNT_PATH"
    Command=$(get_config_value "command")
    echo "Command=$Command"

    if [ ${Command} = install ]; then
        install
    elif [ ${Command} = uninstall ]; then
        uninstall
    elif [ ${Command} = upgrade ]; then
        #dummy upgrade
        echo "call dummy upgrade.sh"
    else
        echo "undefined kubeflow bootstrap command: $Command"
    fi

    echo "kubeflow $Command entrypoint.sh script finished done."
    set_config_value "error" "false"
    set_config_value "running" "false"
    exit 0
else
    echo "kubeflow $Command entrypoint.sh script failed."
    set_config_value "error" "true"
    set_config_value "running" "false"
    exit 1
fi
