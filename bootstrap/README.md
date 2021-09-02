# kubeflow

## Description

These schemes allow you to install / uninstall the `Kubeflow` component separately from the compute components, without using `private-kubernetes/bootstrap` scripts.

## Requirements

Version of `kubectl` should be 1.14 or higher.

## Scenarios:

* install/uninstall the kubeflow component `./overlays/app/` ;

* install/uninstall kubeflow-operator separately `./base/`

* install/uninstall kubeflow kfdef separately `./overlays/kfdef/`

* generate dex config map ldap and configure job `./overlays/dex-cm-ldap/`

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). Determines if docker images, which is used by kubeflow ecosystem (except of images, which are defined in kubeflow pipelines), should be downloaded from airgap docker registry (e.g. in case of connection to Internet couldn't be established). If env is not airgapped, set empty string as value. So all images (except of images, which are defined in kubeflow pipelines) will be pulled from the Internet;

* `USER_AIRGAP_REGISTRY` - address of another docker registry for airgapped env, which user can control, e.g. `localhost:5000/` (Trailing slash is needed). Determines if docker images, which are defined in workflows, which are handled by kubeflow pipelines, should be downloaded from some another airgap docker registry or Internet (e.g. in case of user doesn't control the `AIRGAP_REGISTRY` registry and there is another registry controlled by user, or those images of KFP workflows should be pulled from Internet). If this variable is not set, it will be equal to the value of `AIRGAP_REGISTRY` env variable. If user want to set empty string (in order to pull images, which are defined in pipelines, from the Internet), they need to explicitly set this environment variable with value which should equals empty string.

* `DISABLE_NOTEBOOKSERVERS_LINK` - allow to disable "notebook servers" link in kubeflow dashboard. Set the variable to `true` before install kubeflow. Default value - `false`;

list of specific all used variables you can find in README file of each kustomization directory.

## Install

Set env variables if needed.

To install all the components (kubeflow-operator, kfdef manifests, dex-cm-ldap) run  the command:

```bash
kubectl create -k ./overlays/app/
```

> Note: Do not use `apply` command on `overlays/app/`, it causes skipping of kfdef creation.

or use command:

```bash
kubectl kustomize ./overlays/app/
```

to see kustomization result.

## Uninstall

To uninstall all the components run script `uninstall.sh`, or use next command to uninstall components separately:

```
kubectl delete -k $COMPONENT
```
where `$COMPONENT` is one of available kustomization of overlays, components or base.

> Warning, do not use `kubectl delete -k. /overlays/app/`, this may lead to unsafe / incomplete deletion.
