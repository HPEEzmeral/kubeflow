#!/bin/sh

/usr/bin/mc alias set kf_minio ${kubeflow_minio_url} ${kubeflow_minio_access}  ${kubeflow_minio_access_key}
/usr/bin/mc alias set external_minio $external_minio_url $external_minio_access $external_minio_access_key
/usr/bin/mc mb external_minio/mlpipeline/pipelines
/usr/bin/mc cp --recursive kf_minio/mlpipeline/pipelines/ external_minio/mlpipeline/pipelines/

