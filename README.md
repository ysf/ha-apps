# ysf Home Assistant Apps

Home Assistant → Einstellungen → Apps → App-Store → ⋮ → Repositories → `https://github.com/ysf/ha-apps`.

## Gatus

Statusseite aller ysf-Dienste. Die Konfiguration liegt in ysf/ops (`status/gatus.yaml`) und wird alle 10 Minuten geholt.

- `github_token`: Fine-grained Token, nur ysf/ops, nur „Contents: Read“.
- `env`: Zeilen `NAME=wert` für Geheimnisse in der Konfiguration (`${NAME}`), z. B. `NTFY_TOPIC=…`, `PUSH_YSFT=…`.

Läuft im Host-Netz auf Port 80, im Tailnet unter `http://status.int.ysf.sh` (ysf/ops README „Status“).
