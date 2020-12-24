#!/bin/bash
set -e
set -m

cleanup () {
  # A Blocking exclusive lock on the backup-in-progress flock file, so any existing job can finish
  flock -x "${SERVER_DIR}/world/.backup_in_progress" "${SERVER_DIR}/backup.sh"
  python3 "${SERVER_DIR}/rcon.py" 'localhost' "${RCON_PORT}" "${RCON_PASSWORD_FILE}" << EOF
say Server is shutting down in <15 seconds. Any changes beyond this point will not be saved
EOF
  sleep 15
  aws s3api delete-object --key "worlds/${WORLD}/.running" --bucket "${WORLD_BUCKET}"
  kill -TERM ${PID}
}

echo -e "\n\nCPUs: $(nproc)\n\nMemory:"
cat /proc/meminfo

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

export -p | grep -E ' (SERVER_DIR|WORLD|WORLD_BUCKET|SERVER_USER|JAR_BUCKET|JAR_FILE|RCON_PASSWORD_FILE|RCON_PORT)=' > /.mc_env

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

[ -z "${JAR_BUCKET}" ] || [ -z "${JAR_FILE}" ] && {
  echo "Jar config incomplete - specify a JAR_FILE and JAR_BUCKET"
  exit 1
}

# Make sure this dir doesn't exist
[ -e "${SERVER_DIR}/world" ] && {
  echo "File or directory '${SERVER_DIR}/world' already exists"
  exit 1
}

# Create a home for the world files
mkdir world

# Make sure the bucket exists
for BUCKET in "${WORLD_BUCKET}" "${JAR_BUCKET}" ; do
  if ! aws s3api head-bucket --bucket "${BUCKET}" >>/dev/null ; then
    echo "Bucket '${BUCKET}' does not seem to exist or is inaccessible."
    exit 1
  fi
done

if aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.backup_in_progress" >>/dev/null ; then
  echo 'Backup of '"${WORLD}"' did not finish completely. Data could be inconsistent. Abort!'
  exit 1
fi

until ! aws s3api head-object --bucket "${WORLD_BUCKET}" --key "worlds/${WORLD}/.running" >>/dev/null ; do
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

mkdir jars
aws s3 cp "s3://${JAR_BUCKET}/${JAR_FILE}" "jars/${JAR_FILE}"

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
touch .running
aws s3api put-object --body .running --key "worlds/${WORLD}/.running" --bucket "${WORLD_BUCKET}"

nohup sudo -u "${SERVER_USER}" java "-Xmx${MEM_MAX}K" "-Xms1024M" -jar "../jars/${JAR_FILE}" &
PID="${!}"

until netstat -lntp | grep "${RCON_PORT}" ; do
  echo "Waiting for server startup"
  sleep 1
done

trap cleanup SIGTERM
trap cleanup SIGINT
trap cleanup SIGHUP

wait "${PID}"
