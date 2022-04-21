#!/bin/sh

PORT="8001"
MAX_RETRIES=5

get_free_port()
#return free/unused network port in range from $1 to $2
{
    PORT=$(comm -23 <(seq ${1:-8001} ${2:-8010}) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort) | head -n 1)
}

delete_cert_manager()
{
    if namespace_exists cert-manager ; then 
        process_service_resources common/cert-manager/kubeflow-issuer/base \
				  common/cert-manager/cert-manager/base
    fi
}

delete_istio()
{
    if namespace_exists istio-system ; then
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
    if namespace_exists prism-ns ; then
        process_service_resources bootstrap/components/image-pull-secret/prism
        process_service_resources -t 20s apps/prism/overlays/image-pull-secret
        kubectl patch crd/hpecpmodeldefaults.deployment.hpe.com -p '{"metadata":{"finalizers":[]}}' --type=merge
    fi
}

delete_seldon()
{
    process_service_resources contrib/seldon/seldon-core-operator/overlays/application
} 

delete_kf_services()
{
    process_service_resources contrib/application/application-crds/base \
                              common/user-namespace/base

    process_service_resources apps/mpi-job/upstream/overlays/kubeflow
    
    process_service_resources apps/tensorboard/tensorboards-web-app/upstream/overlays/istio \
                              apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow
    
    process_service_resources apps/volumes-web-app/upstream/overlays/istio

    delete_kubeflow_profiles
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

delete_kubeflow_profiles() {
    printf  "\n******* Started deleting Kubeflow profiles.. *\n\n"
    for profile in $(kubectl get profiles -o name); do
        if [ $(kubectl get $profile -o jsonpath='{.metadata.finalizers}' | grep "profile-finalizer") ]; then
            kubectl delete $profile
        fi;
    done
}

delete_kf_url()
{
    process_service_resources -n ${KF_JOBS_NS} bootstrap/components/hpecpconfig-patch
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
        echo "*      Failed: Namespaces $NAMESPACE not found"
        err=1
    fi

    kubectl get ns --field-selector status.phase=Active | grep "$NAMESPACE" 2> /dev/null
    if [ "$?" = 0 ]; then
        timeout 5s kubectl delete ns "$NAMESPACE" 2>/dev/null
        echo "*      Namespace $NAMESPACE deleted\n"
        sleep 5
    fi

    kubectl get ns "$NAMESPACE" 2> /dev/null
    if [ "$?" = 0 ]; then
        if [ "$err" = 0 ]; then
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

        if [ "$err" = 0 ]; then
            kubectl get ns --field-selector status.phase=Terminating | grep "$NAMESPACE"
            if [ "$?" = 0 ]; then
                printf "*      Send request to delete stucked namespace finalizer.\n"
                kubectl get namespace $NAMESPACE -o json | jq '.spec = {"finalizers":[]}' >temp.json
                curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json  127.0.0.1:$PORT/api/v1/namespaces/$NAMESPACE/finalize >/dev/null
                printf "\n*      Namespace $NAMESPACE was deleted successfully!\n"
            fi
            sleep 2
            kill $PROXY_PID
            echo "*      kubectl proxy with PID: $PROXY_PID terminated"
        fi
    fi

    if [ "$err" = 0 ]; then
        printf "****** force_delete_ns function for namespace $1 DONE\n\n"
    else
        printf "****** force_delete_ns function for namespace $1 FAILED\n\n"
        exit 1
    fi
}

uninstall() {
    KUBE_CMD="delete"
    delete_kf_url

    delete_prism
    sleep 15
    while kubectl get ns prism-ns >/dev/null 2>&1 ; do
        force_delete_ns prism-ns
        delete_prism
    done

    if [ ${DISABLE_SELDON} != true ]; then
        delete_seldon
    fi
    
    delete_kf_services

    if [ ${DISABLE_ISTIO} != true ]; then
        delete_cluster_local_gateway
    fi
    
    delete_knative
    delete_authservices

    if [ ${DISABLE_ISTIO} != true ] ; then
        delete_istio
    fi
    
    delete_cert_manager

    if [ ${DISABLE_DEX} != true ] ; then
        process_service_resources -n ${KF_JOBS_NS} bootstrap/components/dex-secret-ldap
    fi
    process_service_resources -n ${KF_JOBS_NS} bootstrap/components/minio-config
}
