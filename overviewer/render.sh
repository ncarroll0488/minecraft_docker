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

[ -n "${ECS_CONTAINER_METADATA_URI_V4}" ] && {
  FARGATE=1
  TASK="$(curl -s "${ECS_CONTAINER_METADATA_URI_V4}/task")"
  TASK_DEFINITION="$(jq -rc '.Family' <<< "${TASK}")"
  CLUSTER="$(jq -rc '.Cluster' <<< "${TASK}")"
  MY_ARN="$(jq -rc '.TaskARN' <<< "${TASK}")"
  set -e
  set -o pipefail
  MATCHING_TASKS="$(aws --output text ecs list-tasks --cluster "${CLUSTER}" --family "${TASK_DEFINITION}" | awk '/arn:/ {print $NF}')"
  for M in ${MATCHING_TASKS} ; do
    if [ "${M}" == "${MY_ARN}" ] ; then
      continue
    fi
    aws ecs stop-task --cluster "${CLUSTER}" --task "${M}" --reason "Previous task running long. Killed by ${TASK}."
  done
  set +e
  set +o pipefail
}

TEXTURE_BASE_DIR="${WORKSPACE}/textures/"
WORLD_SAVE_DIR="${WORKSPACE}/worlds/${WORLD_NAME}"
MAP_SAVE_DIR="${WORKSPACE}/rendered_maps/${WORLD_NAME}"
CHANGELIST_DIR="${WORKSPACE}/changelists/${WORLD_NAME}"
DAY_OF_MONTH="$(date '+%m')"

mkdir -p "${WORLD_SAVE_DIR}"
mkdir -p "${MAP_SAVE_DIR}"
mkdir -p "${CHANGELIST_DIR}"

# Make sure a backup is not in progress
while aws s3api head-object --bucket "${S3_BUCKET}" --key "${S3_PATH}/.signals/.backup_in_progress" ; do
  echo "A backup appears to be in progress. Delaying"
  sleep 60
done

# Look for an overviewer_config.json in the world path
if aws s3api head-object --bucket "${S3_BUCKET}" --key "${S3_PATH}/.config/overviewer_config.json" ; then
  # We found a config file.
  aws s3 sync --exact-timestamps --exclude ".signals/.last" --delete "s3://${S3_BUCKET}/${S3_PATH}" "${WORLD_SAVE_DIR}"
else
  echo "This world does not have an overviewer_config.json"
  exit 1
fi

if [ -f "${WORLD_SAVE_DIR}/.config/.version" ] ; then
  [ -n "${TEXTURE_VERSION}" ] || TEXTURE_VERSION="$(cat "${WORLD_SAVE_DIR}/.config/.version")"
  TEXTURE_DIR="${TEXTURE_BASE_DIR}/${TEXTURE_VERSION}"
  aws s3 sync --delete "s3://${S3_BUCKET}/textures/${TEXTURE_VERSION}" "${TEXTURE_DIR}"
  export TEXTURE_DIR
fi

export WORLD_NAME
export WORLD_DIR="${WORLD_SAVE_DIR}/world"
export OUTPUT_DIR="${MAP_SAVE_DIR}"
export CONFIG_FILE
export CHANGELIST_DIR

if [ -f "${WORLD_SAVE_DIR}/.signals/.force_s3_sync" ] || [ "${DAY_OF_MONTH}" == "01" ] ; then
  FORCE_S3_SYNC=1
fi

if [ -f "${WORLD_SAVE_DIR}/.signals/.force_render" ] ; then
  FORCE_RENDER=1
fi

if ! [ -f "${WORLD_SAVE_DIR}/.signals/.last" ] ; then
  echo "Unknown last run time. Forcing S3 sync"
  FORCE_S3_SYNC=1
fi

# Everything must succeed or we risk corruption
set -e

if [ -n "${FORCE_RENDER}" ] ; then
  CONFIG_PY='/app/overviewer_config.dev.py'
elif [ -n "${CONFIG_FILE}" ] ; then
  CONFIG_PY='/app/overviewer_config.py'
  aws s3 cp "${CONFIG_FILE}" "${CONFIG_PY}"
fi

if [ -z "${CONFIG_PY}" ] ; then
  CONFIG_PY='/app/overviewer_config.default.py'
fi

export CONFIG_PY

# The --forcerender option forces all renders to regenerate
if [ "${FORCE_RENDER}" == "1" ] || [ -n "${DEV_MODE}" ] ; then
  overviewer.py --config "${CONFIG_PY}" --forcerender
else
  overviewer.py --config "${CONFIG_PY}"
fi

# Generate POIs
overviewer.py --config "${CONFIG_PY}" --genpoi

# If we've set dev mode, are forcing a render, or are forcing an S3 sync
if [ -n "${DEV_MODE}" ] || [ "${FORCE_RENDER}" == "1" ] || [ "${FORCE_S3_SYNC}" == "1" ] ; then
  aws s3 sync --exact-timestamps --delete --acl public-read "${MAP_SAVE_DIR}" "s3://${MAP_BUCKET}/${WORLD_NAME}/"
else
  python3 upload_to_s3.py "${MAP_SAVE_DIR}" "${MAP_BUCKET}" "${WORLD_NAME}/" "${CHANGELIST_DIR}"/*
  aws s3 sync "${MAP_SAVE_DIR}/*.*" "s3://${MAP_BUCKET}/${WORLD_NAME}/"
fi

rm -f "${CHANGELIST_DIR}/changelist.txt" 2>/dev/null
mkdir -p "${WORLD_SAVE_DIR}/.signals"
date "+%s" > "${WORLD_SAVE_DIR}/.signals/.last"
