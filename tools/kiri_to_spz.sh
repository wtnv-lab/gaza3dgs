#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  tools/kiri_to_spz.sh <kiri_share_url> <output_name> [output_root]

Example:
  tools/kiri_to_spz.sh \
    "https://www.kiriengine.app/share/3dgs?taskId=2036241175110746112" \
    baby01

Outputs:
  <output_root>/ply_spz/<output_name>.spz
  <output_root>/ply_spz/cameras/<output_name>.json
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage >&2
    exit 1
fi

require_cmd curl
require_cmd node
require_cmd npm
require_cmd rg
require_cmd xxd

SHARE_URL="$1"
OUTPUT_NAME="$2"
OUTPUT_ROOT="${3:-$(pwd)}"
PLY_SPZ_DIR="${OUTPUT_ROOT%/}/ply_spz"
CAMERA_DIR="${PLY_SPZ_DIR}/cameras"
TOOLS_DIR="${TMPDIR:-/tmp}/kiri-spz-tools"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kiri-work.XXXXXX")"
HTML_PATH="${WORK_DIR}/share.html"
MODEL_PATH="${WORK_DIR}/model.splat"
CAMERA_PATH="${WORK_DIR}/cameras.json"
PLY_PATH="${WORK_DIR}/model.ply"
SPZ_PATH="${WORK_DIR}/model.spz"

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${PLY_SPZ_DIR}" "${CAMERA_DIR}" "${TOOLS_DIR}"

echo "Fetching KIRI share page..."
curl -L --max-time 60 -o "${HTML_PATH}" "${SHARE_URL}"

SPLAT_URL="$(rg -o 'https://[^"<> ]*3DGS\.splat[^"<> ]*' "${HTML_PATH}" | head -n 1 || true)"
CAMERA_URL="$(rg -o 'https://[^"<> ]*cameras\.json[^"<> ]*' "${HTML_PATH}" | head -n 1 || true)"

if [ -z "${SPLAT_URL}" ] || [ -z "${CAMERA_URL}" ]; then
    echo "Failed to extract splatUrl/cameraUrl from: ${SHARE_URL}" >&2
    exit 1
fi

echo "Downloading model and cameras..."
curl -L --max-time 120 -o "${MODEL_PATH}" "${SPLAT_URL}"
curl -L --max-time 120 -o "${CAMERA_PATH}" "${CAMERA_URL}"

if [ ! -x "${TOOLS_DIR}/node_modules/.bin/splat-transform" ] || [ ! -d "${TOOLS_DIR}/node_modules/spz-js" ]; then
    echo "Installing temporary conversion tools..."
    npm install --prefix "${TOOLS_DIR}" @playcanvas/splat-transform spz-js
fi

HEADER="$(xxd -l 16 -ps "${MODEL_PATH}" | tr -d '\n')"
if printf '%s' "${HEADER}" | rg -qi '^706c79'; then
    echo "Detected PlayCanvas compressed PLY payload in .splat file."
    cp "${MODEL_PATH}" "${WORK_DIR}/model.compressed.ply"
    "${TOOLS_DIR}/node_modules/.bin/splat-transform" \
        -w "${WORK_DIR}/model.compressed.ply" \
        "${PLY_PATH}"
else
    echo "Detected standard .splat payload."
    "${TOOLS_DIR}/node_modules/.bin/splat-transform" \
        -w "${MODEL_PATH}" \
        "${PLY_PATH}"
fi

echo "Converting PLY to SPZ..."
MODEL_PLY_PATH="${PLY_PATH}" MODEL_SPZ_PATH="${SPZ_PATH}" node --input-type=module <<'EOF'
import { readFile, writeFile } from "node:fs/promises";
import { loadPly, serializeSpz } from "spz-js";

const plyPath = process.env.MODEL_PLY_PATH;
const spzPath = process.env.MODEL_SPZ_PATH;
const ply = await readFile(plyPath);
const gaussianSplat = loadPly(ply.buffer);
const spz = serializeSpz(gaussianSplat);
await writeFile(spzPath, Buffer.from(spz));
EOF

cp "${SPZ_PATH}" "${PLY_SPZ_DIR}/${OUTPUT_NAME}.spz"
cp "${CAMERA_PATH}" "${CAMERA_DIR}/${OUTPUT_NAME}.json"

echo "Done."
echo "SPZ: ${PLY_SPZ_DIR}/${OUTPUT_NAME}.spz"
echo "Camera: ${CAMERA_DIR}/${OUTPUT_NAME}.json"
