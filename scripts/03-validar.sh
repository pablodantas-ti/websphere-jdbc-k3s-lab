#!/bin/bash
set -euo pipefail
umask 077
k3s kubectl get pods,pvc -n websphere
k3s kubectl exec -n websphere deployment/postgres-lab -- \
  psql -U labadmin -d labdb -v ON_ERROR_STOP=1 -c 'SELECT * FROM lab.produtos ORDER BY id;'
scratch=$(mktemp -d)
forward_pid=''
cleanup() {
  if [[ -n "$forward_pid" ]]; then kill "$forward_pid" 2>/dev/null || true; wait "$forward_pid" 2>/dev/null || true; fi
  rm -f -- "$scratch/forward.log" "$scratch/result.html"
  rmdir -- "$scratch"
}
trap cleanup EXIT
k3s kubectl port-forward -n websphere deployment/was :9443 --address=127.0.0.1 > "$scratch/forward.log" 2>&1 &
forward_pid=$!
port=''
for attempt in $(seq 1 30); do
  port=$(awk '/Forwarding from 127.0.0.1:/ {split($3,a,":"); print a[2]; exit}' "$scratch/forward.log")
  [[ -n "$port" ]] && break
  if ! kill -0 "$forward_pid" 2>/dev/null; then cat "$scratch/forward.log"; exit 1; fi
  sleep 1
done
test -n "$port"
# -k is limited to the local forwarded lab endpoint with its self-signed certificate.
request_started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
status=$(curl -k -sS -H 'Host: localhost:9443' --connect-timeout 10 --max-time 90 -o "$scratch/result.html" \
  -w '%{http_code}' "https://127.0.0.1:$port/was-lab/jdbc.jsp")
if [[ "$status" != 200 ]] || ! grep -q 'Curso WebSphere' "$scratch/result.html"; then
  echo "CONSULTA FALHOU: HTTP $status. Resposta HTTP (primeiras 40 linhas):"
  head -40 "$scratch/result.html"
  echo 'Logs desde o inicio desta requisicao:'
  k3s kubectl logs -n websphere deployment/was --since-time="$request_started" --tail=200
  exit 1
fi
echo 'LAB_JDBC_OK: aplicacao respondeu HTTP 200 e consultou os produtos no PostgreSQL.'
k3s kubectl logs -n websphere deployment/was --since=3m | grep 'WASLAB JDBC' || true
