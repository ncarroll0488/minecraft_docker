#!/bin/bash
[ -n "${S3_BUCKET}" ] || {
  echo "No S3_BUCKET"
  exit 1
}

[ -n "${S3_PATH}" ] || {
  S3_PATH=""
}

[ -n "${APP_DIR}" ] || {
  APP_DIR="/app"
}

[ -n "${WORKSPACE}" ] || {
  WORKSPACE="${APP_DIR}/workspace"
}

[ -n "${WORLD_NAME}" ] || {
  echo "Cannot determine WORLD_NAME"
  exit 1
}

[ -n "${MAP_BUCKET}" ] || {
  echo "Cannot determine MAP_BUCKET"
  exit 1
}

TEXTURE_BASE_DIR="${WORKSPACE}/textures/"

WORLD_SAVE_DIR="${WORKSPACE}/worlds/${WORLD_NAME}"

MAP_SAVE_DIR="${WORKSPACE}/rendered_maps/${WORLD_NAME}"
[ -d "${MAP_SAVE_DIR}" ] || FIRST_RUN=1

CHANGELIST_DIR="${WORKSPACE}/changelists/${WORLD_NAME}"

mkdir -p "${WORLD_SAVE_DIR}"
mkdir -p "${MAP_SAVE_DIR}"
mkdir -p "${CHANGELIST_DIR}"

# Look for an overviewer_config.py in the world path
if aws s3api head-object --bucket "${S3_BUCKET}" --key "${S3_PATH}/overviewer_config.py" ; then
  # We found a config file.
  aws s3 sync "s3://${S3_BUCKET}/${S3_PATH}" "${WORLD_SAVE_DIR}"
else
  echo "This world does not have an overviewer_config.py"
  exit 1
fi

if [ -f "${WORLD_SAVE_DIR}/.version" ] ; then
  VERSION="$(cat "${WORLD_SAVE_DIR}/.version")"
  TEXTURE_DIR="${TEXTURE_BASE_DIR}/textures/${VERSION}"
  aws s3 sync "s3://${S3_BUCKET}/textures/${VERSION}" "${TEXTURE_DIR}"
  export TEXTURE_DIR
fi

export WORLD_NAME
export WORLD_DIR="${WORLD_SAVE_DIR}/world"
export OUTPUT_DIR="${MAP_SAVE_DIR}"
export CONFIG_FILE="${WORLD_SAVE_DIR}/overviewer_config.py"
export CHANGELIST_DIR

# Everything must succeed or we risk corruption
set -e

overviewer.py --config /app/overviewer_config.py

if [ -n "${DEV_MODE}" ] || [ "${FIRST_RENDER}" == "1" ] || [ -n "${FORCE_S3_SYNC}" ] ; then
   aws s3 sync --exact-timestamps --delete --acl public-read "${MAP_SAVE_DIR}" "s3://${MAP_BUCKET}/${WORLD_NAME}/"
else
  python3 upload_to_s3.py "${MAP_SAVE_DIR}" "${MAP_BUCKET}" "${WORLD_NAME}/" "${CHANGELIST_DIR}"/*
fi
