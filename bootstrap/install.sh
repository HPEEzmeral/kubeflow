#!/bin/sh
set -e

BASEDIR=$(dirname "$0")
KFCTL_HOME=$(cd "${BASEDIR}/../"; pwd)
MANIFESTS_IMAGE_TAG=${MANIFESTS_IMAGE_TAG:-v1.2.0-istio1.9}

test_dirs()
{
    if [ -d "${KFCTL_HOME}/manifests/kfdef/kfctl_hcp_istio/base/" ] ; then
        return 0
    else
        echo "${KFCTL_HOME}/manifests/kfdef/kfctl_hcp_istio/base/ not found.
Try to pull submodule manifests first. (https://git-scm.com/book/en/v2/Git-Tools-Submodules)
Run `make manifests-update` from repository root dir to update submodule manifests."
        return 1
    fi
}

install()
{
    cd "${KFCTL_HOME}/bootstrap/"
    export MANIFESTS_IMAGE_TAG=$MANIFESTS_IMAGE_TAG
    kubectl apply -k ./base/
    kubectl apply -k ./components/dex-cm-ldap/
    if [ -z ${MANIFEST_REPO_URI} ] ;
    then
      kubectl apply -k ../manifests/kfdef/kfctl_hcp_istio/base/
    else
      kubectl apply -k ../manifests/kfdef/kfctl_hcp_istio/overlays/manifest-uri/
    fi
}

if test_dirs ; then
    install
    echo "kubeflow install script finished done"
    exit 0
else
    echo "kubeflow install script failed."
    exit 1
fi

