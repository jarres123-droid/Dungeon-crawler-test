#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TOOLS_DIR="${GODOT_TOOLS_DIR:-${ROOT_DIR}/.tools/godot}"
readonly PROJECT_FILE="${ROOT_DIR}/project.godot"

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "error: project.godot was not found at ${PROJECT_FILE}" >&2
  exit 1
fi

project_version="$(sed -n 's/^config\/features=PackedStringArray("\([0-9][0-9.]*\)".*/\1/p' "${PROJECT_FILE}" | head -n 1)"
if [[ -z "${project_version}" ]]; then
  echo "error: could not determine the Godot version from config/features" >&2
  exit 1
fi

for candidate in "${GODOT_BIN:-}" godot godot4; do
  [[ -n "${candidate}" ]] || continue
  if command -v "${candidate}" >/dev/null 2>&1; then
    installed_version="$("${candidate}" --version)"
    if [[ "${installed_version}" == "${project_version}"* ]]; then
      echo "Godot ${installed_version} is already available at $(command -v "${candidate}")."
      exit 0
    fi
    echo "Ignoring incompatible Godot ${installed_version} at $(command -v "${candidate}")." >&2
  fi
done

# Patch releases do not change config/features, so discover the current stable
# patch instead of guessing that a "4.x-stable" artifact exists.
godot_version="${GODOT_VERSION:-}"
if [[ -z "${godot_version}" ]]; then
  release_json="$(curl --fail --location --retry 3 \
    https://api.github.com/repos/godotengine/godot-builds/releases/latest)"
  release_tag="$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' <<<"${release_json}" | head -n 1)"
  godot_version="${release_tag%-stable}"
fi
readonly GODOT_VERSION="${godot_version}"

if [[ "${GODOT_VERSION}" != "${project_version}"* ]]; then
  echo "error: Godot ${GODOT_VERSION} does not match project feature version ${project_version}." >&2
  echo "Set GODOT_VERSION to a stable ${project_version}.x release." >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) archive_arch="x86_64" ;;
  aarch64|arm64) archive_arch="arm64" ;;
  *) echo "error: unsupported Linux architecture: $(uname -m)" >&2; exit 1 ;;
esac

readonly archive_name="Godot_v${GODOT_VERSION}-stable_linux.${archive_arch}.zip"
readonly download_url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/${archive_name}"
mkdir -p "${TOOLS_DIR}"
archive="${TOOLS_DIR}/${archive_name}"

if [[ -n "${GODOT_ARCHIVE:-}" ]]; then
  cp "${GODOT_ARCHIVE}" "${archive}"
elif [[ ! -f "${archive}" ]]; then
  echo "Downloading ${download_url}"
  curl --fail --location --retry 3 --output "${archive}" "${download_url}"
fi

unzip -q -o "${archive}" -d "${TOOLS_DIR}"
binary="${TOOLS_DIR}/${archive_name%.zip}"
chmod +x "${binary}"
ln -sfn "$(basename "${binary}")" "${TOOLS_DIR}/godot"
echo "Installed $("${TOOLS_DIR}/godot" --version) at ${TOOLS_DIR}/godot."
echo "Run tools/validate_godot.sh to import and validate the project."
