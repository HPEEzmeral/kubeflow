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

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value;

* `MANIFESTS_IMAGE_TAG` - used to specify manifests image tag, default value `v1.2.0-latest`;

* `MANIFEST_REPO_URI` - optional. Used to load manifests from specific repository archive. The default value for the variable is `file:///opt/mapr/manifests.tar.gz`;

list of all specific used variables you can find in README file of each kustomization directory.

## Install

Set env variables if needed.

In order to install kubeflow with istio-1.9 set variable `MANIFESTS_IMAGE_TAG=v1.2.0-istio1.9`

> Note: In current branch `MANIFESTS_IMAGE_TAG=v1.2.0-istio1.9` used by default.

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
