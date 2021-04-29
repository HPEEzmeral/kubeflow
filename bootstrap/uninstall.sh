#!/bin/sh
#   Copyright 2021 Hewlett Packard Enterprise Development LP
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
    kubectl delete -k ../manifests/kfdef/kfctl_hcp_istio/base/
    kubectl delete -k ./components/dex-cm-ldap/
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

