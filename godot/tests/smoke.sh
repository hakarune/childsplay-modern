#!/usr/bin/env bash
#
# smoke.sh — headless scene-load smoke for the Godot target.
#
# Imports the project, then loads + instantiates every scene under
# scenes/ (see scene_smoke.gd). Exits non-zero if any scene fails, so it
# works as a pre-commit / CI gate.
#
#   godot/tests/smoke.sh
#   GODOT_BIN=/path/to/godot godot/tests/smoke.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

command -v "$GODOT_BIN" >/dev/null || { echo "smoke: '$GODOT_BIN' not found (set GODOT_BIN)"; exit 127; }

# Noise from the headless renderer / teardown that isn't a scene failure.
# Headless-teardown chatter that isn't a scene failure. Real _ready()
# problems still surface as unfiltered "SCRIPT ERROR:" / "ERROR:" lines.
NOISE='GLES|OpenGL|Vulkan|shader|ANGLE|libGL|swiftshader|TextServer|rasterizer'
NOISE+='|ObjectDB instances were leaked|resources still in use'
NOISE+='|at: cleanup \(core/object/object|at: clear \(core/io/resource'

echo "smoke: importing ($GODOT_BIN) …"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

set +e
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script res://tests/scene_smoke.gd 2>&1 | grep -viE "$NOISE"
rc=${PIPESTATUS[0]}
set -e

echo ""
if [ "$rc" -eq 0 ]; then
  echo "smoke: PASS"
else
  echo "smoke: FAIL ($rc scene(s))"
fi
exit "$rc"
