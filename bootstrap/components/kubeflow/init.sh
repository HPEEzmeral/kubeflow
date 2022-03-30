#!/bin/sh

#NOTE: after modifying this file, you need to update the addon image

echo "Start kubeflow-install init.sh script."

echo "KF_JOBS_NS: ${KF_JOBS_NS}"
echo "MANIFESTS_LOCATION: ${MANIFESTS_LOCATION}"
echo "MANIFESTS_MOUNT_PATH: ${MANIFESTS_MOUNT_PATH}"

if [ -r /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt ]; then
    update-ca-certificates
    ca_cert_options="--cacert /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt"
fi

if curl ${ca_cert_options} -Lo manifests.tar.gz ${MANIFESTS_LOCATION}; then
    printf "\nManifests get successfully from ${MANIFESTS_LOCATION}\n\n"
else
    printf "\nManifests get failed from ${MANIFESTS_LOCATION}\n\n"
fi

if tar -xf manifests.tar.gz -C ${MANIFESTS_MOUNT_PATH} --strip-components 1; then
    printf "\nManifests extracted successfully to ${MANIFESTS_MOUNT_PATH}\n\n"
else
    printf "\nManifests extracted failed\n\n"
    exit 1
fi

echo "kubeflow-install init.sh finished."
