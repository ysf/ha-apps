# ysf Home Assistant Apps

Home Assistant → Einstellungen → Apps → App-Store → ⋮ → Repositories → `https://github.com/ysf/ha-apps`.

## Gatus

Statusseite aller ysf-Dienste. Die Konfiguration liegt in ysf/ops (`status/gatus.yaml`) und wird alle 10 Minuten geholt.

- `github_token`: Fine-grained Token, nur ysf/ops, nur „Contents: Read“.
- `role_id`, `secret_id`: AppRole `status` in OpenBao (ysf/ops `status.yml`), darf nur `bao_paths` lesen. Jedes Feld dort steht in der Konfiguration als `${FELD}` in Großbuchstaben bereit.
- `env`: zusätzliche Zeilen `NAME=wert`, gehen vor (meist leer).

Läuft im Host-Netz auf Port 80, im Tailnet unter `http://status.int.ysf.sh` (ysf/ops README „Status“).
