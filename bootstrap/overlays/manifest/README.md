# kubeflow manifest kustomization

## Requirements

Version of `kubectl` should be 1.14 or higher.

Configured git SSH keys.

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value; 

## Pre setup

This kustomization uses base form git submodule. Make sure that $private-kfctl/.gitmodules points to:
```
url = git@github.com:mapr/private-manifests.git`
branch = v1.2.0-mapr-branch 
```
or newer where are the directory `$(private-manifests)/manifests/kfdef/kfctl_hcp_istio/base/` exists.

Before using this kustomization make sure the directory exists and is not empty.
```bash
test -d $(private-kfctl-home)/manifests/kfdef/kfctl_hcp_istio/base/ && echo true || echo false
```
where `$private-kfctl-home` - repos home directory.

If `$(private-kfctl-home)/manifests/` is empty pull submodule first.
[Git Tools - Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

## Install

Set env variables if needed, and run command `kubectl apply -k ./`

Example of command:

```bash
AIRGAP_REGISTRY=localhost:5000/ kubectl apply -k ./
```

## Debug

Use `kubectl kustomize ./` to see kustomization result.

example:
```bash
AIRGAP_REGISTRY=localhost:5000/ kubectl kustomize ./
```