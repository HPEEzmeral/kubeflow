# INSTALL

## Requirements
- kustomize
- kubectl
- bash

## Steps
- Create secret named **copy-secret** with fields
   - *external-url* - external minio kubernetes service url
   - *kubeflow-url* - kubeflow minio kubernetes service url
   - *kf-access-key* - kubeflow minio **Access key**
   - *kf-secret-key* - kubeflow minio **Password**
   - *external-access-key* - external minio **Access key**
   - *external-secret-key* - external minio **Password**
```
kubectl create secret generic -n kubeflow-jobs copy-secret \
   --from-literal=kf-access-key=minioadmin \
   --from-literal=kf-secret-key=minioadmin \
   --from-literal=external-access-key=minio \
   --from-literal=external-secret-key=minio123 \
   --from-literal=kubeflow-url=http://minio-service.kubeflow.svc.cluster.local:9000 \
   --from-literal=external-url=http://minio-service.minio.svc.cluster.local:9000
```
- Export env variable *COPY_NS* with namespace you would like to operate in (default value - **kubeflow-jobs**)
- Run install.sh

