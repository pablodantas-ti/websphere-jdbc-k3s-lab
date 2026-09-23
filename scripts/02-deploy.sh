#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
umask 077
tag=localhost/was-lab:jdbc-v2
podman image exists "$tag"
k3s kubectl get secret postgres-lab-auth -n websphere >/dev/null
mkdir -p backups
if k3s kubectl get deployment was -n websphere >/dev/null 2>&1; then
  k3s kubectl get deployment was -n websphere -o yaml > "backups/was-before-$(date +%Y%m%d-%H%M%S).yaml"
fi
scratch=$(mktemp -d)
trap 'rm -f -- "$scratch/password" "$scratch/image.tar"; rmdir -- "$scratch"' EXIT
if ! k3s kubectl get secret was-lab-admin -n websphere >/dev/null 2>&1; then
  read -r -s -p 'Senha de wsadmin (minimo 12 caracteres): ' password
  printf '\n'
  read -r -s -p 'Repita: ' confirmation
  printf '\n'
  if [[ ${#password} -lt 12 || "$password" != "$confirmation" ]]; then
    echo 'Senhas diferentes ou curtas.' >&2
    exit 1
  fi
  printf '%s' "$password" > "$scratch/password"
  unset password confirmation
  k3s kubectl create secret generic was-lab-admin -n websphere --from-file=password="$scratch/password"
fi
podman save --format docker-archive -o "$scratch/image.tar" "$tag"
k3s ctr -n k8s.io images import "$scratch/image.tar"
# Keep the verified runtime fix in an explicit, reproducible ConfigMap.
k3s kubectl create configmap was-lab-runtime-auth-v2 -n websphere \
  --from-file=runtime-auth.py=image/runtime-auth.py --dry-run=client -o yaml | k3s kubectl apply -f -
if k3s kubectl get deployment was -n websphere >/dev/null 2>&1; then
  k3s kubectl patch deployment was -n websphere --type=strategic --patch-file=k8s/was-patch.json
else
  k3s kubectl apply -f k8s/was-deployment.json
fi
k3s kubectl apply -f k8s/was-service.json
k3s kubectl rollout status deployment/was -n websphere --timeout=1800s
k3s kubectl logs -n websphere deployment/was | grep -E 'LAB_AUTH_SECRET_MATCH|LAB_RUNTIME_AUTH_OK'
