#!/bin/sh
set -e

. /mnt/entrypoint/process_service_resources.sh

EXTERNAL_MINIO_SECRET_NAME=kubeflow-external-minio
EXTERNAL_MINIO_SECRET_NAMESPACE=kubeflow-minio
KUBE_CMD="apply"

DISABLE_DEX=${DISABLE_DEX:-false}
DISABLE_SELDON=${DISABLE_SELDON:-false}

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

    return ${ret_val}
}

deploy_cert_manager()
{
    process_service_resources common/cert-manager/cert-manager/base \
                              common/cert-manager/kubeflow-issuer/base
}

deploy_istio()
{
    process_service_resources common/${ISTIO_DIR}/istio-crds/base \
                              common/${ISTIO_DIR}/istio-namespace/base \
                              common/${ISTIO_DIR}/istio-install/base
}

deploy_authservices()
{
    process_service_resources common/oidc-authservice/base \
                              common/dex/overlays/istio
}

deploy_knative()
{
    process_service_resources common/knative/knative-serving/overlays/patches \
                              common/knative/knative-eventing/overlays/image-pull-secret \
                              bootstrap/components/image-pull-secret/knative-eventing
}

deploy_cluster_local_gateway()
{
    process_service_resources common/${ISTIO_DIR}/cluster-local-gateway/base
}

deploy_prism()
{
    process_service_resources apps/prism/overlays/image-pull-secret \
                              bootstrap/components/image-pull-secret/prism
}

deploy_kf_services()
{
    process_service_resources common/kubeflow-namespace/base \
                              bootstrap/components/image-pull-secret/kubeflow \
                              common/kubeflow-roles/base \
                              common/${ISTIO_DIR}/kubeflow-istio-resources/base  \
                              apps/pipeline/upstream/cluster-scoped-resources

    kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
    process_service_resources apps/pipeline/upstream/overlays/image-pull-secret

    process_service_resources apps/pipeline/upstream/third-party/minio/overlays/ldap \
                              apps/pipeline/upstream/third-party/minio/options/istio \
                              apps/pipeline/upstream/third-party/minio-console/base

    process_service_resources apps/kfserving/upstream/overlays/kubeflow \
                              apps/katib/upstream/installs/katib-with-kubeflow

    if [ ${DISABLE_NOTEBOOKSERVERS_LINK} = false ]; then
        process_service_resources apps/centraldashboard/upstream/overlays/istio
    else
	process_service_resources apps/centraldashboard/upstream/overlays/disableNotebookServers
    fi

    process_service_resources apps/admission-webhook/upstream/overlays/cert-manager
    process_service_resources apps/jupyter/jupyter-web-app/upstream/overlays/istio \
                              apps/jupyter/notebook-controller/upstream/overlays/kubeflow
    process_service_resources apps/profiles/upstream/overlays/kubeflow
    process_service_resources apps/volumes-web-app/upstream/overlays/istio
    process_service_resources apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow \
                              apps/tensorboard/tensorboards-web-app/upstream/overlays/istio
    process_service_resources apps/training-operator/upstream/overlays/kubeflow \
                              apps/mpi-job/upstream/overlays/kubeflow
    process_service_resources common/user-namespace/base
    process_service_resources contrib/application/application-crds/base
}

deploy_seldon()
{
    echo "test if seldon is already installed"
    kubectl get crd | grep seldondeployments.machinelearning.seldon.io ; \
    ret=$? ; \
    if [ ${ret} -eq 0 ]; then
        KUBE_CMD="replace" process_service_resources contrib/seldon/seldon-core-operator/overlays/application
    else
        KUBE_CMD="create" process_service_resources contrib/seldon/seldon-core-operator/overlays/application
    fi
    kubectl get crd | grep seldondeployments.machinelearning.seldon.io
}

enable_kf_dashboard_url_in_tenant_ui()
{
    KUBE_NAMESPACE=${KF_JOBS_NS} process_service_resources bootstrap/components/hpecpconfig-patch
}

install()
{
    deploy_cert_manager

    if [ ${DISABLE_ISTIO} != true ]; then
        deploy_istio
    fi


    if [ ${DISABLE_DEX} != true  ]; then
	deploy_authservices
    fi
    
    deploy_knative
    deploy_cluster_local_gateway
    MAX_RETRIES=8 && deploy_kf_services

    if [ ${DISABLE_SELDON} != true ]; then
        while ! deploy_seldon ; do sleep ${RETRY_TIMEOUT} ; done
    fi

    deploy_prism
    enable_kf_dashboard_url_in_tenant_ui
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

    KUBE_NAMESPACE=${KF_JOBS_NS} process_service_resources bootstrap/components/minio-config \
                                                           bootstrap/components/dex-secret-ldap

    install
    echo "kubeflow install script finished done"
    exit 0
else
    echo "kubeflow install script failed."
    exit 1
fi
