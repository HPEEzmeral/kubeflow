# kubectl_hcp_istio kustomization

## Requirements

Version of `kubectl` should be 1.14 or higher.

## Variables

* `AIRGAP_REGISTRY` - address of docker registry for airgapped env, e.g. `localhost:5000/` (Trailing slash is needed). If env is not airgapped, set empty string as value;

* `MANIFEST_REPO_URI` - Required. The default value for the variable is file:///opt/mapr/manifests.tar.gz

## Using like kustomization base

Feel free to use the overlay in the new kustomizations.

```yaml
kind: Kustomization
bases:
- path/to/dir/kfctl_hcp_istio/overlays/manifest-uri/
```

## Apply

Make sure you have the variable `MANIFEST_REPO_URI` set before use, or add export for it.

Example:
```bash
MANIFEST_REPO_URI=file:///opt/mapr/manifests.tar.gz kubectl apply -k ./
```

## Debug

To see kustomization result use command:

```bash
kubectl kustomize ./
```