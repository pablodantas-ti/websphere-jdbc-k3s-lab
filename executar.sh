#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
[[ $(id -u) == 0 ]] || { echo 'Execute como root no servidor do laboratorio.' >&2; exit 1; }
for cmd in podman k3s curl unzip zip openssl; do command -v "$cmd" >/dev/null; done
for script in scripts/*.sh database/*.sh image/*.sh; do bash -n "$script"; done
k3s kubectl create namespace websphere --dry-run=client -o yaml | k3s kubectl apply -f -
bash database/01-banco.sh
bash scripts/01-build.sh
bash scripts/02-deploy.sh
bash scripts/03-validar.sh
