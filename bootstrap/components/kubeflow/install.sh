#!/bin/sh

EXTERNAL_MINIO_SECRET_NAME=kubeflow-external-minio
EXTERNAL_MINIO_SECRET_NAMESPACE=kubeflow-minio

deploy_cert_manager()
{
    process_service_resources common/cert-manager/cert-manager/base
    sleep 40
    process_service_resources common/cert-manager/kubeflow-issuer/base
    while [ -z "$(kubectl get apiservices.apiregistration.k8s.io v1beta1.cert-manager.io --ignore-not-found)" ]; 
        do echo "waiting for webhook apiservice being deployed" && sleep 5;
    done
    kubectl wait --for=condition=Available --timeout=600s apiservice v1beta1.cert-manager.io
}

deploy_istio()
{
    process_service_resources common/${ISTIO_DIR}/istio-crds/base \
                              common/${ISTIO_DIR}/istio-namespace/base \
                              common/${ISTIO_DIR}/istio-install/base
}

deploy_authservices()
{
    if [ -z ${CA_SECRET_NAME} ]; then
        process_service_resources common/oidc-authservice/base \
                                  common/dex/overlays/istio
    else
        process_service_resources common/oidc-authservice/overlays/ca-config \
                                  common/dex/overlays/istio
    fi
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
    process_service_resources apps/pipeline/upstream/cluster-scoped-resources \
                              common/kubeflow-namespace/base \
                              bootstrap/components/image-pull-secret/kubeflow \
                              common/kubeflow-roles/base \
                              common/${ISTIO_DIR}/kubeflow-istio-resources/base

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
    kubectl get crd | grep seldondeployments.machinelearning.seldon.io
    ret=$?
    if [ $ret -eq 0 ]; then
        process_service_resources -c replace contrib/seldon/seldon-core-operator/overlays/application
    else
        process_service_resources -c create contrib/seldon/seldon-core-operator/overlays/application
    fi
    kubectl get crd | grep seldondeployments.machinelearning.seldon.io
}

enable_kf_dashboard_url_in_tenant_ui()
{
    process_service_resources -n ${KF_JOBS_NS} bootstrap/components/hpecpconfig-patch
}

install()
{
    KUBE_CMD="apply"
    process_service_resources -n ${KF_JOBS_NS} bootstrap/components/minio-config
    if [ ${DISABLE_DEX} != true ]; then
        process_service_resources -n ${KF_JOBS_NS} bootstrap/components/dex-secret-ldap
    fi

    MAX_RETRIES=8 deploy_cert_manager

    if [ ${DISABLE_ISTIO} != true ]; then
        deploy_istio
    fi

    if [ ${DISABLE_DEX} != true ]; then
        deploy_authservices
    fi

    deploy_knative

    deploy_cluster_local_gateway

    MAX_RETRIES=8 deploy_kf_services

    if [ ${DISABLE_SELDON} != true ]; then
        while ! deploy_seldon ; do sleep ${RETRY_TIMEOUT} ; done
    fi

    deploy_prism
    enable_kf_dashboard_url_in_tenant_ui
}
