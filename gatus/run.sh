#!/bin/sh
# Holt die Gatus-Konfiguration aus einem GitHub-Repo (Option config: owner/repo/pfad, Token nur mit Lesezugriff),
# alle 10 Minuten neu; Gatus lädt Änderungen selbst (skip-invalid-config-update in der Konfiguration).
# Option env: Zeilen NAME=wert, in der Konfiguration als ${NAME} (Geheimnisse bleiben aus dem Repo)
set -eu
o=/data/options.json
tok=$(jq -r .github_token "$o")
ziel=$(jq -r .config "$o")
url="https://api.github.com/repos/$(echo "$ziel" | cut -d/ -f1-2)/contents/$(echo "$ziel" | cut -d/ -f3-)"
# Zeilen NAME=wert (auch „NAME = wert“ oder „NAME: wert“); im Protokoll nur die Namen, nie die Werte
jq -r '.env // [] | .[]' "$o" | tr -d '\r' > /tmp/env
namen=
while IFS= read -r zeile; do
  name=$(printf %s "$zeile" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[=:].*/\1/')
  wert=$(printf %s "$zeile" | sed -E 's/^[^=:]*[=:][[:space:]]*//; s/[[:space:]]+$//')
  [ -n "$zeile" ] && [ "$name" != "$zeile" ] || { [ -z "$zeile" ] || echo "env: Zeile ohne NAME=wert ignoriert" >&2; continue; }
  export "$name=$wert"; namen="$namen $name"
done < /tmp/env
rm -f /tmp/env
echo "env gesetzt:${namen:- (keine)}" >&2

holen() {
  curl -sfL -m 30 -H "Authorization: Bearer $tok" -H 'Accept: application/vnd.github.raw' "$url" -o /data/gatus.neu &&
    [ -s /data/gatus.neu ] && { cmp -s /data/gatus.neu /data/gatus.yaml || mv /data/gatus.neu /data/gatus.yaml; }
}
holen || [ -s /data/gatus.yaml ] || { echo "Konfiguration $ziel nicht ladbar" >&2; exit 1; }
(while sleep 600; do holen || echo "Konfiguration $ziel nicht aktualisiert, alte bleibt" >&2; done) &

export GATUS_CONFIG_PATH=/data/gatus.yaml
exec gatus
