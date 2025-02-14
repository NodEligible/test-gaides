#!/usr/bin/env bash

set -e
USE_SUDO=0

# Автоматичне підтвердження згоди
WARNING_AGREE="y"
echo "Diagnostic data collection agreement accepted: $WARNING_AGREE"

# Встановлюємо базову директорію
NODEHOME="$(realpath ~/shardeum)"
echo "Base directory set to: $NODEHOME"
mkdir -p "$NODEHOME"

# Перевірка наявності Docker
command -v docker >/dev/null 2>&1 || { echo >&2 "Docker is not installed on this machine but is required to run the shardeum validator. Please install docker before continuing."; exit 1; }

docker-safe() {
  if ! command -v docker &>/dev/null; then
    echo "docker is not installed on this machine"
    exit 1
  fi

  if ! docker "$@"; then
    echo "Trying again with sudo..." >&2
    USE_SUDO=1
    sudo docker "$@"
  fi
}

if [[ $(docker-safe info 2>&1) == *"Cannot connect to the Docker daemon"* ]]; then
    echo "Docker daemon is not running, please start the Docker daemon and try again"
    exit 1
else
    echo "Docker daemon is running"
fi

# Встановлення параметрів
DASHPORT=8180
RUNDASHBOARD="y"
EXTERNALIP="auto"
INTERNALIP="auto"
SHMEXT=9001
SHMINT=10001
PASSWORD="11111111dd!"

# Отримання зовнішнього IP
get_external_ip() {
  external_ip=$(curl -s https://api.ipify.org || echo "localhost")
  echo $external_ip
}

if [ "$EXTERNALIP" == "auto" ]; then
    EXTERNALIP=$(get_external_ip)
fi
INT_IP=$EXTERNALIP
LOCALLANIP=$EXTERNALIP

# Очищення старих контейнерів
OLD_IMAGE="ghcr.io/shardeum/server:latest"
CONTAINER_IDS=$(docker-safe ps -aq --filter "ancestor=$OLD_IMAGE")
if [ -n "$CONTAINER_IDS" ]; then
  set +e
  echo "Stopping and removing deprecated containers: $CONTAINER_IDS"
  docker-safe stop $CONTAINER_IDS 1>/dev/null
  docker-safe rm $CONTAINER_IDS 1>/dev/null
  echo "Containers removed successfully."
  set -e
fi

if docker-safe ps -a --filter "name=shardeum-validator" --format "{{.Names}}" | grep -q "^shardeum-validator$"; then
    echo "Stopping and removing previous instance of shardeum-validator"
    docker-safe stop shardeum-validator 2>/dev/null
    docker-safe rm shardeum-validator 2>/dev/null
fi

# Забезпечення прав доступу до директорії
set +e
mkdir -p ${NODEHOME}
OWNER_UID=$(stat -c '%u' "$NODEHOME")
TARGET_UID=1000

if [ "$OWNER_UID" -ne "$TARGET_UID" ]; then
  echo "Changing ownership of $NODEHOME to UID $TARGET_UID..."
  sudo chown "$TARGET_UID" "$NODEHOME"
fi
set -e

# Завантаження і запуск контейнера
echo "Downloading the shardeum-validator image and starting the validator container"
docker-safe pull ghcr.io/shardeum/shardeum-validator:latest
docker-safe run \
    --name shardeum-validator \
    -p ${DASHPORT}:${DASHPORT} \
    -p ${SHMEXT}:${SHMEXT} \
    -p ${SHMINT}:${SHMINT} \
    -e RUNDASHBOARD=${RUNDASHBOARD} \
    -e DASHPORT=${DASHPORT} \
    -e EXT_IP=${EXTERNALIP} \
    -e INT_IP=${INTERNALIP} \
    -e SERVERIP=${EXTERNALIP} \
    -e LOCALLANIP=${LOCALLANIP} \
    -e SHMEXT=${SHMEXT} \
    -e SHMINT=${SHMINT} \
    -v ${NODEHOME}:/home/node/config \
    --restart=always \
    --detach \
    ghcr.io/shardeum/shardeum-validator 1>/dev/null

echo "Shardeum Validator starting."
echo "Waiting for the container to be available (max 60 seconds).."

timeout=60
elapsed=0

while [ ! -f "${NODEHOME}/set-password.sh" ]; do
  sleep 1
  elapsed=$((elapsed + 1))
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout: set-password.sh not found after 60 seconds."
    exit 1
  fi
done

# Встановлення пароля автоматично
echo "Setting password for the Dashboard automatically."
echo "$PASSWORD" | bash "${NODEHOME}/set-password.sh" >/dev/null 2>&1

echo "Shardeum Validator is now running. You can access the dashboard at https://${EXTERNALIP}:${DASHPORT}/"
echo "If you're running the validator on your local system you can access the dashboard at https://localhost:${DASHPORT}/ instead"
