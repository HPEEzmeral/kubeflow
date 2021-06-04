#!/bin/bash

kubectl patch -n hpecp hpecpconfig hpecp-global-config --type json -p '
[
  {
    "op": "add",
    "path": "/spec/tenantServiceImports/-",
    "value": {
      "category": "default",
      "importName": "kf-dashboard",
      "targetName": "istio-ingressgateway",
      "targetNamespace": "istio-system",
      "targetPorts": [
        {
          "importName": "http-80",
          "targetName": "http2"
        }
      ]
    }
  }
]
'
