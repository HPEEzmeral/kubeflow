#!/bin/sh
# set -e

. /mnt/entrypoint/process_service_resources.sh

KUBE_CMD="delete"
PORT="8001"
MAX_RETRIES=5

DISABLE_DEX=${DISABLE_DEX:-false}
DISABLE_SELDON=${DISABLE_SELDON:-false}

get_free_port()
#return free/unused network port in range from $1 to $2
{
    PORT=$(comm -23 <(seq ${1:-8001} ${2:-8010}) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort) | head -n 1)
}

test_env_vars()
{
    local ret_val=0

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

delete_cert_manager()
{
    if namespace_exists cert-manager ; then 
        process_service_resources common/cert-manager/cert-manager/base \
                                  common/cert-manager/kubeflow-issuer/base
    fi
}

delete_istio()
{
    if  namespace_exists istio-system ; then 
        process_service_resources common/${ISTIO_DIR}/istio-install/base \
                                  common/${ISTIO_DIR}/istio-namespace/base \
                                  common/${ISTIO_DIR}/istio-crds/base
    fi
}

delete_authservices()
{
    if namespace_exists auth ; then
        process_service_resources common/dex/overlays/istio \
                                  common/oidc-authservice/base
    fi
}

delete_knative()
{
    if namespace_exists knative-eventing; then
        process_service_resources common/knative/knative-eventing/overlays/image-pull-secret \
                                  bootstrap/components/image-pull-secret/knative-eventing
    fi
    if namespace_exists knative-serving; then    
        process_service_resources common/knative/knative-serving/base
    fi
}

delete_cluster_local_gateway()
{
    process_service_resources common/${ISTIO_DIR}/cluster-local-gateway/base
}

delete_prism()
{
    if namespace_exists prism ; then
        process_service_resources bootstrap/components/image-pull-secret/prism
        ./kustomize build ${MANIFESTS_DIR}/apps/prism/overlays/image-pull-secret | timeout 20s kubectl delete -f -
        kubectl patch crd/hpecpmodeldefaults.deployment.hpe.com -p '{"metadata":{"finalizers":[]}}' --type=merge
    fi
}

delete_seldon()
{
    process_service_resources contrib/seldon/seldon-core-operator/overlays/application
} 

delete_kf_services()
{
    MAINFESTS_DIR=${0}
    process_service_resources contrib/application/application-crds/base \
                              common/user-namespace/base

    process_service_resources apps/xgboost-job/upstream/overlays/kubeflow \
                              apps/mxnet-job/upstream/overlays/kubeflow \
                              apps/mpi-job/upstream/overlays/kubeflow \
                              apps/pytorch-job/upstream/overlays/kubeflow 

    process_service_resources apps/tf-training/upstream/overlays/kubeflow
    
    process_service_resources apps/tensorboard/tensorboards-web-app/upstream/overlays/istio \
                              apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow
    
    process_service_resources apps/volumes-web-app/upstream/overlays/istio
    
    process_service_resources apps/profiles/upstream/overlays/kubeflow

    process_service_resources apps/jupyter/notebook-controller/upstream/overlays/kubeflow \
                              apps/jupyter/jupyter-web-app/upstream/overlays/istio
    
    process_service_resources apps/admission-webhook/upstream/overlays/cert-manager
    process_service_resources apps/centraldashboard/upstream/overlays/istio
    process_service_resources apps/katib/upstream/installs/katib-with-kubeflow
    process_service_resources apps/kfserving/upstream/overlays/kubeflow
    
    process_service_resources apps/pipeline/upstream/third-party/minio-console/base \
                              apps/pipeline/upstream/third-party/minio/options/istio \
                              apps/pipeline/upstream/third-party/minio/overlays/ldap \
                              apps/pipeline/upstream/overlays/image-pull-secret \
                              apps/pipeline/upstream/cluster-scoped-resources
    
    process_service_resources common/${ISTIO_DIR}/kubeflow-istio-resources/base \
                              common/kubeflow-roles/base \
                              common/kubeflow-namespace/base
    return 0
}

delete_kf_url()
{
    KUBE_NAMESPACE=${KF_JOBS_NS} process_service_resources bootstrap/components/hpecpconfig-patch
}

force_delete_ns()
{
    local err=0
    local DELETED=0
    local PORT=8001

    printf "\n****** Started force_delete_ns function for namespace $1\n*\n"
    local NAMESPACE=$1
    if [ -z $NAMESPACE ]; then
        echo "*      Failed: force_delete_ns function takes 1 required argument $1 - NAMESPACE"
        err=1
    fi

    kubectl get ns "$NAMESPACE" 2> /dev/null
    if [ "$?" != 0 ]; then
        echo "*      Failed: Namespaces $NAMESPACE not found\n"
        err=1
    fi

    kubectl get ns --field-selector status.phase=Active | grep "$NAMESPACE" 2> /dev/null
    if [ "$?" == 0 ]; then
        timeout 5s kubectl delete ns "$NAMESPACE" 2>/dev/null
        echo "*      Namespace $NAMESPACE deleted\n"
        sleep 5
    fi

    kubectl get ns "$NAMESPACE" 2> /dev/null
    if [ "$?" == 0 ]; then
        if [ "$err" == 0 ]; then
            get_free_port
            kubectl proxy --port=$PORT &
            local PROXY_PID=$!
            sleep 5
            if [ ! -z "$PROXY_PID" ]; then
                echo "*      Started kubectl proxy with PID: $PROXY_PID ..."
            else
                echo "*      Failed:  kubectl proxy can't be started"
                err=1
            fi
        fi

        if [ "$err" == 0 ]; then
            kubectl get ns --field-selector status.phase=Terminating | grep "$NAMESPACE"
            if [ "$?" == 0 ]; then
                printf "*      Send request to delete stucked namespace finalizer.\n"
                kubectl get namespace $NAMESPACE -o json | jq '.spec = {"finalizers":[]}' >temp.json
                curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json  127.0.0.1:$PORT/api/v1/namespaces/$NAMESPACE/finalize
                printf "*      Namespace $NAMESPACE was deleted successfully!"
            fi
            sleep 2
            kill $PROXY_PID
            echo "*      kubectl proxy with PID: $PROXY_PID terminated"
        fi
    fi

    if [ "$err" == 0 ]; then
        printf "****** force_delete_ns function for namespace $1 DONE\n\n"
    else
        printf "****** force_delete_ns function for namespace $1 FAILED\n\n"
        exit 1
    fi
}

uninstall() {
    delete_kf_url

    printf "\nDeleting prism...\n\n"
    delete_prism
    sleep 10
    echo $(kubectl get ns prism-ns)
    while kubectl get ns prism-ns ; do
        force_delete_ns prism-ns
        printf "\n***                                                                                                                                                                                    
    	Retrying to delete prism ... ***\n\n";
        delete_prism
    done

    if [ ${DISABLE_SELDON} != true ]; then
        delete_seldon
    fi
    
    delete_kf_services
    delete_cluster_local_gateway
    delete_knative
    delete_authservices
    delete_istio
    delete_cert_manager
    KUBE_NAMESPACE="${KF_JOBS_NS}" process_service_resources bootstrap/components/dex-secret-ldap
    KUBE_NAMESPACE="${KF_JOBS_NS}" process_service_resources bootstrap/components/minio-config
}

if test_env_vars; then
    if [ -r /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt ]; then
        update-ca-certificates
        curl --cacert /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt -Lo ${MANIFESTS_DIR}.tar.gz ${MANIFESTS_LOCATION}
    else
        curl -Lo ${MANIFESTS_DIR}.tar.gz ${MANIFESTS_LOCATION}
    fi

    mkdir manifests
    if tar -xf ${MANIFESTS_DIR}.tar.gz -C ${MANIFESTS_DIR} --strip-components 1; then
        printf "\nManifests downloaded successfully to $(pwd)\n\n"
    else
        printf "\nManifests download failed\n\n"
        exit 1
    fi

    uninstall
    echo "kubeflow uninstall script finished done."
    exit 0
else
    echo "kubeflow uninstall script failed."
    exit 1
fi
