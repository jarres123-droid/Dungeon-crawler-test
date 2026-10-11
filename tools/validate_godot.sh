#!/usr/bin/env bash
set -uo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-}"
if [[ -z "${godot_bin}" ]]; then
  if [[ -x "${ROOT_DIR}/.tools/godot/godot" ]]; then
    godot_bin="${ROOT_DIR}/.tools/godot/godot"
  elif command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then
    godot_bin="$(command -v godot4)"
  else
    echo "SETUP ERROR: no Godot executable found; run tools/setup_godot.sh first." >&2
    exit 2
  fi
fi

status=0
echo "== Godot version =="
"${godot_bin}" --version || exit 2

echo "== Resource import =="
if ! "${godot_bin}" --headless --path "${ROOT_DIR}" --import; then
  echo "SETUP ERROR: Godot could not finish importing project resources." >&2
  status=2
fi

echo "== Project and main-scene load =="
if ! "${godot_bin}" --headless --path "${ROOT_DIR}" --editor --quit; then
  echo "PROJECT ERROR: project.godot did not open successfully." >&2
  [[ ${status} -eq 0 ]] && status=1
fi

# Running the configured main scene briefly forces Godot to resolve its external
# scripts/resources and catches broken UID/path references that parsing alone cannot.
if ! "${godot_bin}" --headless --path "${ROOT_DIR}" --quit-after 3; then
  echo "PROJECT ERROR: the main scene or one of its resource references failed to load." >&2
  [[ ${status} -eq 0 ]] && status=1
fi

echo "== GDScript parse checks =="
while IFS= read -r -d '' script; do
  relative="${script#${ROOT_DIR}/}"
  echo "Checking ${relative}"
  if ! "${godot_bin}" --headless --path "${ROOT_DIR}" --check-only --script "${script}"; then
    echo "PROJECT ERROR: GDScript validation failed for ${relative}." >&2
    [[ ${status} -eq 0 ]] && status=1
  fi
done < <(find "${ROOT_DIR}" -path "${ROOT_DIR}/.godot" -prune -o -name '*.gd' -type f -print0 | sort -z)

exit "${status}"
