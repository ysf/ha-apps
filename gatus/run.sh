#!/bin/sh
# Holt die Gatus-Konfiguration aus GitHub (Option config: owner/repo/pfad, Token nur mit Lesezugriff) und die Werte für
# ${NAME} darin aus OpenBao (AppRole mit Leserecht nur auf bao_paths, alle Felder als Großbuchstaben), setzt sie ein
# und schreibt /data/gatus.yaml. Alle 10 Minuten neu; Gatus lädt Änderungen selbst (skip-invalid-config-update).
# Option env: zusätzliche Zeilen NAME=wert (gehen vor). Im Protokoll nur Namen, nie Werte
set -eu
o=/data/options.json
opt() { jq -r "$1 // empty" "$o"; }
tok=$(opt .github_token)
ziel=$(opt .config)
url="https://api.github.com/repos/$(echo "$ziel" | cut -d/ -f1-2)/contents/$(echo "$ziel" | cut -d/ -f3-)"
bao=$(opt .bao_addr)
dns=$(opt .dns)

# OpenBao im Tailnet: Name über CoreDNS auflösen (das Gerät selbst kennt int.ysf.sh nicht unbedingt)
bao_resolve=
if [ -n "$bao" ] && [ -n "$dns" ]; then
  host=$(echo "$bao" | sed -E 's#^https?://([^/:]+).*#\1#')
  ip=$(nslookup "$host" "$dns" 2>/dev/null | awk '/^Address/ && !/#/ {print $2}' | tail -1)
  [ -n "$ip" ] && bao_resolve="--resolve $host:443:$ip"
fi

werte() {
  : > /tmp/werte
  if [ -n "$bao" ] && [ -n "$(opt .role_id)" ]; then
    t=$(jq -n --arg r "$(opt .role_id)" --arg s "$(opt .secret_id)" '{role_id:$r, secret_id:$s}' |
      curl -sf -m 15 $bao_resolve -X POST --data @- "$bao/v1/auth/approle/login" | jq -r .auth.client_token) || return 1
    for p in $(jq -r '.bao_paths[]' "$o"); do
      curl -sf -m 15 $bao_resolve -H "X-Vault-Token: $t" "$bao/v1/secrets/data/$p" |
        jq -r '.data.data | to_entries[] | "\(.key | ascii_upcase)=\(.value)"' >> /tmp/werte || return 1
    done
  fi
  jq -r '.env // [] | .[]' "$o" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[=:][[:space:]]*/\1=/' |
    awk -F= '{ $1 = toupper($1); print }' OFS== >> /tmp/werte
}

holen() {
  curl -sfL -m 30 -H "Authorization: Bearer $tok" -H 'Accept: application/vnd.github.raw' "$url" -o /tmp/roh &&
    [ -s /tmp/roh ] || { echo "Konfiguration $ziel nicht ladbar" >&2; return 1; }
  werte || { echo "Werte aus OpenBao nicht ladbar" >&2; return 1; }
  # ${NAME} ersetzen, spätere Zeilen (env) gehen vor; im Protokoll nur die Namen
  jq -Rn --rawfile c /tmp/roh '[inputs | capture("^(?<k>[A-Z_][A-Z0-9_]*)=(?<v>.*)$")] | reduce .[] as $e ({}; .[$e.k] = $e.v) as $m
    | $c | gsub("\\$\\{(?<k>[A-Z_][A-Z0-9_]*)\\}"; ($m[.k] // ("${" + .k + "}")))' --raw-output < /tmp/werte > /data/gatus.neu
  namen=$(cut -d= -f1 /tmp/werte | sort -u | tr '\n' ' ')
  rm -f /tmp/roh /tmp/werte
  [ -s /data/gatus.neu ] || return 1
  cmp -s /data/gatus.neu /data/gatus.yaml && rm -f /data/gatus.neu && return 0
  mv /data/gatus.neu /data/gatus.yaml && echo "Konfiguration neu, Werte: ${namen:-keine}" >&2
}
holen || [ -s /data/gatus.yaml ] || { echo "Keine Konfiguration, Abbruch" >&2; exit 1; }
(while sleep 600; do holen || echo "Konfiguration nicht aktualisiert, alte bleibt" >&2; done) &

export GATUS_CONFIG_PATH=/data/gatus.yaml
exec gatus
