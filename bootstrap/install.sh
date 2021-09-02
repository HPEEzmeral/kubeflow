#!/bin/sh
set -e

BASEDIR=$(dirname "$0")
KFCTL_HOME=$(cd "${BASEDIR}/../"; pwd)
DISABLE_NOTEBOOKSERVERS_LINK=${DISABLE_NOTEBOOKSERVERS_LINK:-true}

# Check if var is set https://stackoverflow.com/a/13864829 
if [ -z ${USER_AIRGAP_REGISTRY+x} ]; then
    USER_AIRGAP_REGISTRY=$AIRGAP_REGISTRY
    export USER_AIRGAP_REGISTRY
fi

test_dirs()
{
    if [ -d "${KFCTL_HOME}/manifests/kfdef/kfctl_hcp_istio/base/" ] ; then
        return 0
    else
        echo "${KFCTL_HOME}/manifests/kfdef/kfctl_hcp_istio/base/ not found.
 Try to pull submodule manifests first. (https://git-scm.com/book/en/v2/Git-Tools-Submodules)"
        return 1
    fi
}

install()
{
    cd "${KFCTL_HOME}/bootstrap/"
    kubectl apply -k ./base/
    kubectl apply -k ./components/dex-secret-ldap/
    if [ ${DISABLE_NOTEBOOKSERVERS_LINK} = false ] ;
    then
      kubectl apply -k ../manifests/kfdef/kfctl_hcp_istio/base/
    elif [ ${DISABLE_NOTEBOOKSERVERS_LINK} = true ] ;
    then
      kubectl apply -k ../manifests/kfdef/kfctl_hcp_istio/overlays/disableNotebookServers/
    fi
    kubectl apply -k ./components/hpecpconfig-patch/
}

if test_dirs ; then
    install
    echo "kubeflow install script finished done"
    exit 0
else
    echo "kubeflow install script failed."
    exit 1
fi

