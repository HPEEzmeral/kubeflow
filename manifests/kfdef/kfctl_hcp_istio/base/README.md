# kubectl_hcp_istio kustomization

## Requirements

Version of `kubectl` should be 1.14 or higher.

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value;

## Using like kustomization base

Feel free to use the base in the new kustomizations.

```yaml
kind: Kustomization
bases:
- path/to/dir/kfctl_hcp_istio/base
```

## Apply

Example:
```bash
AIRGAP_REGISTRY=localhost:5000/ kubectl apply -k ./
```

## Debug

To see kustomization result use command:

```bash
kubectl kustomize ./
```