# kubeflow manifest kustomization

## Requirements

Version of `kubectl` should be 1.14 or higher.

Configured git SSH keys.

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value; 

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
