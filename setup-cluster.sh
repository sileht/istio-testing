#!/bin/bash

set -e
set -o pipefail

kind create cluster --name istio-cluster --config cluster.yaml


# MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# simple L2 config for testing
kubectl apply -f metal-lb-conf.yaml

for port in 80 443; do
    docker exec -d -it istio-cluster-control-plane socat TCP-LISTEN:${port},fork TCP:192.168.42.10:${port}
done

# Dashboard
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.1/aio/deploy/recommended.yaml
#kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default
#token=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 --decode)
#echo $token > dashboard.token
#echo TOKEN: $token

# Cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml

# Istio
istioctl operator init
kubectl create namespace istio-system
# istioctl manifest apply  --set components.policy.enabled=true --set components.sidecarInjector.enabled=true --set values.kiali.enabled=true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: $(echo sileht | base64)
  passphrase: $(echo sileht | base64)
EOF

sleep 2
kubectl apply -f istio-controlplane.yaml
# --set values.global.mtls.enabled=true --set values.global.controlPlaneSecurityEnabled=true

sleep 5
kubectl apply -f app.yaml
kubens sileht
