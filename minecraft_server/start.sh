#!/bin/bash
set -e
set -m

cleanup () {
  # A Blocking exclusive lock on the backup-in-progress flock file, so any existing job can finish
  python3 "${SERVER_DIR}/rcon.py" 'localhost' "${RCON_PORT}" "${RCON_PASSWORD_FILE}" << EOF
say Server is shutting down. Changes beyond this point may not be saved.
EOF
  flock -x "${SERVER_DIR}/.local_backup_in_progress" true
  "${SERVER_DIR}/backup.sh"
  aws s3api delete-object --key "worlds/${WORLD}/.signals/.running" --bucket "${WORLD_BUCKET}"
  kill -TERM ${PID}
}

# Default to using 80% of max mem for Xmx
[ -z "${MEMPCT}" ] && MEMPCT=80
MEM_MAX=$(("$(awk '/MemTotal/ {print $(NF-1)}' /proc/meminfo)" * "${MEMPCT}" / 100))

[ -z "${LISTEN_PORT}" ] && LISTEN_PORT='25565'

[ -z "${RCON_PORT}" ] && RCON_PORT='25575'

[ -z "${SERVER_DIR}" ] && SERVER_DIR='/app'
cd "${SERVER_DIR}"

[ -z "${RCON_PASSWORD}" ] && RCON_PASSWORD="$(head -c 32 /dev/urandom | xxd -p -c 32)"
export RCON_PASSWORD_FILE="${SERVER_DIR}/.rcon_pass"
echo -n "${RCON_PASSWORD}" > "${RCON_PASSWORD_FILE}"

export -p | grep -E ' (SERVER_DIR|WORLD|WORLD_BUCKET|SERVER_USER|JAR_FILE|RCON_PASSWORD_FILE|RCON_PORT|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID)=' > /.mc_env

[ -n "${WORLD}" ] || {
  WORLD='world' 
  echo "Warning - world not set. Using 'world' as world name"
}

[ -n "${WORLD_BUCKET}" ] || {
  echo "Bucket not set. Aborting"
  exit 1
}

[ -z "${SERVER_USER}" ] && SERVER_USER='bukkit'

[ "${SERVER_USER}" == "root" ] && {
  echo "Specify a non-root SERVER_USER"
}

# Make sure this dir doesn't exist
[ -e "${SERVER_DIR}/world" ] && {
  echo "File or directory '${SERVER_DIR}/world' already exists"
  exit 1
}

# Create a home for the world files
mkdir world

# Make sure the bucket exists
for BUCKET in "${WORLD_BUCKET}" ; do
  if ! aws s3api head-bucket --bucket "${BUCKET}" >>/dev/null ; then
    echo "Bucket '${BUCKET}' does not seem to exist or is inaccessible."
    exit 1
  fi
done

if aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.signals/.backup_in_progress" >>/dev/null ; then
  echo 'Backup of '"${WORLD}"' did not finish completely. Data could be inconsistent. Abort!'
  exit 1
fi

until ! aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.signals/.running" >>/dev/null ; do
  echo "Remote bucket has a server that is already running or did not stop clean. Delaying startup 30 seconds."
  sleep 30
done

# If the remote world exists, pull it down. Otherwise start a new one
if aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/server.properties" ; then
  echo "World "${WORLD}" appears to exist in remote bucket. Pulling down"
  aws s3 sync --exact-timestamps --exclude "logs/*" --exclude "crash-reports/*" --delete "s3://${WORLD_BUCKET}/worlds/${WORLD}" "${SERVER_DIR}/world" >>/dev/null
else
  echo "No world "${WORLD}" present in remote bucket. Starting a new one"
  # Automatically accept the EULA
  echo 'eula=true' > 'world/eula.txt'
fi

# Signal directory, which may not yet exist
mkdir -p "${SERVER_DIR}/world/.signals"

mkdir jars
SERVER_JAR="jars/server.jar"
echo "Fetching server far from ${JAR_FILE}"
if grep -qE "^http(s)?://" <<< "${JAR_FILE}" ; then
  wget "${JAR_FILE}" -O "${SERVER_JAR}"
elif grep -qE "^s3://" <<< "${JAR_FILE}" ; then
  aws s3 cp "${JAR_FILE}" "${SERVER_JAR}"
else
  echo "Error - Jarfile must be sourced from S3 or HTTP(S)"
  exit 1
fi
SERVER_JAR="$(realpath "${SERVER_JAR}")"

crond -b

if [ -f "${SERVER_DIR}/world/server.properties" ] ; then
  sed -i -e '/^(server-port|rcon\.port.*|broadcast-rcon-to-ops|enable-rcon|rcon\.password)=/d' "${SERVER_DIR}/world/server.properties"
fi

echo "server-port=${LISTEN_PORT}
rcon.port=${RCON_PORT}
broadcast-rcon-to-ops=true
enable-rcon=true
rcon.password=${RCON_PASSWORD}" >> "${SERVER_DIR}/world/server.properties"

chown -R "${SERVER_USER}:" "${SERVER_DIR}"

cd 'world'
touch "${SERVER_DIR}/world/.signals/.running"
aws s3api put-object --body "${SERVER_DIR}/world/.signals/.running" --key "worlds/${WORLD}/.signals/.running" --bucket "${WORLD_BUCKET}"

nohup sudo -u "${SERVER_USER}" java "-Xmx${MEM_MAX}K" "-Xms1024M" -jar "${SERVER_JAR}" &
PID="${!}"

until netstat -lntp | grep "${RCON_PORT}" ; do
  echo "Waiting for server startup"
  sleep 1
done

trap cleanup SIGTERM
trap cleanup SIGINT
trap cleanup SIGHUP

wait "${PID}"
