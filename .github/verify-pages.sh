#!/usr/bin/env bash
#
# verify-pages.sh - sanity-check the GitHub Pages deploy workflow and print
# the one-time repo setting needed to turn it on.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

WF=".github/workflows/deploy-pages.yml"
[ -f "$WF" ] || { echo "MISSING: $WF" >&2; exit 1; }

echo "== checking $WF =="

if python3 -c "import yaml" >/dev/null 2>&1; then
  python3 - "$WF" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
trig = doc.get(True) or doc.get("on")            # 'on:' -> YAML boolean key
checks = {
    "valid YAML":                    True,
    "trigger: push to main":         trig["push"]["branches"] == ["main"],
    "trigger: web-canvas/** paths":  any("web-canvas/" in p for p in trig["push"]["paths"]),
    "trigger: workflow_dispatch":    "workflow_dispatch" in trig,
    "permission pages: write":       doc["permissions"]["pages"] == "write",
    "permission id-token: write":    doc["permissions"]["id-token"] == "write",
}
steps = [s for j in doc["jobs"].values() for s in j["steps"]]
uses  = [s.get("uses", "") for s in steps]
checks["uses actions/upload-pages-artifact@v3"] = any("upload-pages-artifact@v3" in u for u in uses)
checks["uses actions/deploy-pages@v4"]          = any("deploy-pages@v4" in u for u in uses)
art = next((s for s in steps if "upload-pages-artifact" in s.get("uses","")), {})
checks["artifact path is ./web-canvas"] = art.get("with", {}).get("path") == "./web-canvas"

ok = True
for name, passed in checks.items():
    print(("  PASS  " if passed else "  FAIL  ") + name)
    ok = ok and passed
sys.exit(0 if ok else 1)
PY
else
  echo "  (python yaml unavailable - structural grep only)"
  need=(
    'branches: \[main\]'
    'web-canvas/\*\*'
    'workflow_dispatch'
    'pages: write'
    'id-token: write'
    'actions/upload-pages-artifact@v3'
    'actions/deploy-pages@v4'
    'path: \./web-canvas'
  )
  ok=1
  for pat in "${need[@]}"; do
    if grep -qE "$pat" "$WF"; then echo "  PASS  $pat"; else echo "  FAIL  $pat"; ok=0; fi
  done
  [ "$ok" = 1 ] || exit 1
fi

cat <<'EOF'

== enable GitHub Pages (one time) ==
1. Push this workflow to the `main` branch of the GitHub repo.
2. On GitHub: Settings -> Pages.
3. Under "Build and deployment" > "Source", choose **GitHub Actions**
   (not "Deploy from a branch").
4. Re-run the workflow: Actions -> "Deploy web-canvas to GitHub Pages" ->
   "Run workflow" (or just push a change under web-canvas/).
5. The site publishes at:
   https://<owner>.github.io/<repo>/       e.g. https://hakarune.github.io/childsplay-modern/
   The live URL also appears on the workflow run's "deploy" job and in
   Settings -> Pages once the first run finishes.
EOF
