#!/bin/bash
[ -z "${WORKING_DIR}" ] && WORKING_DIR='/app'
[ -z "${DATA_SOURCE}" ] && DATA_SOURCE="${WORKING_DIR}/worlds"
[ -z "${OUTPUT_DIR}" ] && OUTPUT_DIR="${WORKING_DIR}/map"
[ -z "${TEXTURE_DIR}" ] && TEXTURE_DIR="${WORKING_DIR}/textures"

for MKDIR in "${WORKING_DIR}" "${DATA_SOURCE}" "${OUTPUT_DIR}" "${TEXTURE_DIR}" ; do
  { [ -d "${MKDIR}" ] || mkdir -p "${MKDIR}" ; } >>/dev/null 2>&1
  chown bukkit: "${MKDIR}"
done

[ -n "${TEXTURE_S3_SOURCE}" ] && aws_s3_sync "${TEXTURE_S3_SOURCE}"

cd "${WORKING_DIR}"
touch .backup_in_progress

# If we are pulling from S3 as a datasource, then we try to get clean backups of each world
if [ -n "${S3_SOURCE_BUCKET}" ] ; then
  [ -z "${S3_SOURCE_PATH}" ] && S3_SOURCE_PATH=/
  # Iterate over all known subdirectories in s3
  for WORLD in $(aws s3 ls "${S3_SOURCE_BUCKET}/${S3_SOURCE_PATH}/" | awk '{print $NF}') ; do

    CONF_FILE="${S3_SOURCE_PATH}/${WORLD}overviewer_config.json"

    # Check if the world has been configured
    echo "Checking to see if world ${CONF_FILE} exists"
    if aws s3api head-object --bucket "${S3_SOURCE_BUCKET}" --key "${CONF_FILE}" ; then

      # World is configured. Check for a backup-in-progress
      while aws s3api head-object --bucket "${S3_SOURCE_BUCKET}" --key "${S3_SOURCE_PATH}/${WORLD}/.backup_in_progress" ; do
        echo "backup in progress for world ${WORLD}. Delaying sync"
        sleep 15
      done

      echo "Pulling down world ${WORLD}"

      # Flag this as backup-in-progress
      aws s3api put-object --bucket "${S3_SOURCE_BUCKET}" --key "${S3_SOURCE_PATH}/${WORLD}/.backup_in_progress" --body .backup_in_progress

      # Sync the dir down
      aws s3 sync "s3://${S3_SOURCE_BUCKET}/${S3_SOURCE_PATH}/${WORLD}" "${WORKING_DIR}/worlds/${WORLD}"

      # If for some reason the backup lockfile goes missing during sync, we must assume a shutdown was called and therefore our sync was inconsistent
      if ! aws s3api head-object --bucket "${S3_SOURCE_BUCKET}" --key "${S3_SOURCE_PATH}/${WORLD}/.backup_in_progress" ; then
        echo ".backup_in_progress went missing in world ${WORLD} during backup. Going to re-sync in case an emergency shutdown occurred"
        # Sync again, with enthusiasm
        aws s3 sync --exact-timestamps --delete "${S3_SOURCE_BUCKET}/${S3_SOURCE_PATH}/${WORLD}" "${WORKING_DIR}/worlds/${WORLD}"
      fi
      # Remove the lockfile. We don't care if it fails to delete.
      aws s3api delete-object --bucket "${S3_SOURCE_BUCKET}" --key "${S3_SOURCE_PATH}/${WORLD}/.backup_in_progress" || true
    fi
  done
fi

overviewer.py --quiet --config /app/overviewer_config.py

if [ -n "${S3_TARGET_BUCKET}" ] ; then
  [ -z "${S3_TARGET_PATH}" ] && S3_TARGET_PATH=/
fi
