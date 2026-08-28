#!/usr/bin/env bash
#
# Thin wrapper: the real build script lives with the Godot project at
# desktop-godot/build-deb.sh. Kept here for discoverability / CI.
#
#   ./build-deb.sh [VERSION] [--no-export] [--force-preset] [--keep]
#
# Output: dist/childsplay-modern_<version>_amd64.deb
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$HERE/desktop-godot/build-deb.sh" "$@"
