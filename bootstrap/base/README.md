# kubeflow operator

## Requirements

Version of `kubectl` should be 1.14 or higher.

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value; 

## Install

Set env variables if needed, and run command `kubectl apply -k ./`

Example of command:

```bash
AIRGAP_REGISTRY=localhost:5000/ kubectl apply -k ./
```

or use `kubectl kustomize ./` to see kustomization result.

## Uninstall

To uninstall kubeflow operator run command:

```bash
kubectl delete ns kubeflow-operator 
```