#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
for cmd in podman k3s curl unzip zip; do command -v "$cmd" >/dev/null; done
base=icr.io/appcafe/websphere-traditional:9.0.5.29
tag=localhost/was-lab:jdbc-v2
free_kb=$(df -Pk . | awk 'NR==2 {print $4}')
if (( free_kb < 15728640 )); then
  echo 'Reserve ao menos 15 GiB livres para construir e exportar a imagem.' >&2
  exit 1
fi
if ! podman image exists "$base"; then
  if k3s ctr -n k8s.io images list -q | grep -Fxq "$base"; then
    scratch=$(mktemp -d)
    trap 'rm -f -- "$scratch/base.tar"; rmdir -- "$scratch"' EXIT
    k3s ctr -n k8s.io images export --platform linux/amd64 "$scratch/base.tar" "$base"
    podman load -i "$scratch/base.tar"
  else
    podman pull "$base"
  fi
fi
curl --fail --location --retry 3 --connect-timeout 20 \
  https://jdbc.postgresql.org/download/postgresql-42.7.13.jar -o image/postgresql.jar.part
unzip -t image/postgresql.jar.part >/dev/null
mv image/postgresql.jar.part image/postgresql.jar
sha256sum image/postgresql.jar
# Generate the application from tracked source. No WAR is stored in Git.
war_path="$PWD/image/was-lab.war"
rm -f -- "$war_path"
(cd app/src/main/webapp && zip -q -r "$war_path" .)
unzip -t "$war_path" >/dev/null
podman build --pull=never --format docker -f image/Containerfile -t "$tag" image
podman image inspect "$tag" --format '{{.Id}}'
echo 'BUILD CONCLUIDO: localhost/was-lab:jdbc-v2'
