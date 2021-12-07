#!/bin/bash
set -e
. /.mc_env
[ -z "${RCON_PORT}" ] && RCON_PORT=25575
[ -z "${WORLD_DIR}" ] && WORLD_DIR='/app'
[ -z "${RCON_PASSWORD_FILE}" ] && RCON_PASSWORD_FILE=/dev/null
cd "${WORLD_DIR}"
[ -n "${WORLD}" ] || {
  WORLD='world'
  echo "Warning - world not set. Using 'world' as world name"
}

[ -n "${WORLD_BUCKET}" ] || {
  echo "Bucket not set. Aborting"
  exit 1
}

for BUCKET in "${WORLD_BUCKET}" ; do
  if ! aws s3api head-bucket --bucket "${BUCKET}" ; then
    echo "Bucket '${BUCKET}' does not seem to exist or is inaccessible."
    exit 1
  fi
done

python3 ./rcon.py 'localhost' "${RCON_PORT}" "${RCON_PASSWORD_FILE}" << EOF
say Backing up world data to s3
save-all flush
save-off
EOF
BACKUP_IN_PROGRESS='.local_backup_in_progress'
exec 99>"${BACKUP_IN_PROGRESS}"
flock -n 99 || {
  echo "Could not flock ${BACKUP_IN_PROGRESS}"
  exit 1
}

# .backup_in_progress should not be there. If it exists, something has gone wrong
! aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.signals/.backup_in_progress"
aws s3api put-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.signals/.backup_in_progress" --body "${BACKUP_IN_PROGRESS}"
aws s3 sync \
  --exact-timestamps \
  --delete \
  --exclude "crash-reports/*" \
  --exclude "logs/*" \
  --exclude "nohup.out" \
  --exclude ".config/*" \
  --exclude "server.properties" \
  --exclude ".signals/.backup_in_progress" \
 "world/" "s3://${WORLD_BUCKET}/worlds/${WORLD}/"
aws s3api delete-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.signals/.backup_in_progress"

python3 ./rcon.py 'localhost' "${RCON_PORT}" "${RCON_PASSWORD_FILE}" << EOF
say Backup complete
save-on
EOF
