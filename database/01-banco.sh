#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
command -v k3s >/dev/null
command -v openssl >/dev/null
k3s kubectl get namespace websphere >/dev/null
if ! k3s kubectl get secret postgres-lab-auth -n websphere >/dev/null 2>&1; then
  if k3s kubectl get pvc postgres-lab-data -n websphere >/dev/null 2>&1; then
    echo 'PVC existente sem Secret. Pare e recupere as credenciais anteriores; nao gere novas senhas.' >&2
    exit 1
  fi
  umask 077
  secret_dir=$(mktemp -d)
  trap 'rm -f -- "$secret_dir/admin-password" "$secret_dir/app-password"; rmdir -- "$secret_dir"' EXIT
  read -r -s -p 'Escolha a senha do usuario waslab (minimo 12 caracteres): ' app_password
  printf '\n'
  read -r -s -p 'Repita a senha: ' app_confirmation
  printf '\n'
  if [[ ${#app_password} -lt 12 || "$app_password" != "$app_confirmation" ]]; then
    echo 'Senhas diferentes ou curtas. Execute novamente.' >&2
    exit 1
  fi
  printf '%s' "$app_password" > "$secret_dir/app-password"
  openssl rand -hex 24 | tr -d '\n' > "$secret_dir/admin-password"
  unset app_password app_confirmation
  k3s kubectl create secret generic postgres-lab-auth -n websphere \
    --from-file=admin-password="$secret_dir/admin-password" \
    --from-file=app-password="$secret_dir/app-password"
else
  echo 'Secret ja existe; mantendo as credenciais anteriores.'
fi
k3s kubectl apply -f postgres.yaml
echo 'Aguardando PostgreSQL. O primeiro download pode demorar.'
k3s kubectl rollout status deployment/postgres-lab -n websphere --timeout=600s
k3s kubectl exec -n websphere deployment/postgres-lab -- sh -c \
  'PGPASSWORD="$APP_PASSWORD" psql -h 127.0.0.1 -U waslab -d labdb -v ON_ERROR_STOP=1 -c "SELECT current_user, current_database(); SELECT * FROM lab.produtos ORDER BY id;"'
