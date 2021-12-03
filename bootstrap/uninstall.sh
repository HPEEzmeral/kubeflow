#!/bin/sh
set -e

BASEDIR=$(dirname "$0")
KFCTL_HOME=$(cd "${BASEDIR}/../"; pwd)

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

uninstall()
{
    cd "${KFCTL_HOME}/bootstrap/"
    kubectl delete -k ./components/hpecpconfig-patch/
    kubectl delete -k ../manifests/kfdef/kfctl_hcp_istio/base/
    kubectl delete -k ./base/
}

if test_dirs ; then
    uninstall
    echo "kubeflow uninstall script finished done"
    exit 0
else
    echo "kubeflow uninstall script failed."
    exit 1
fi

