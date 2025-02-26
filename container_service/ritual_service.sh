#!/bin/bash

# Шлях для встановлення
INSTALL_DIR="/root/ritual_service"
SERVICE_NAME="ritual-container"

echo "📁 Створення папки $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Шлях до файлу docker-compose
COMPOSE_FILE="/root/infernet-container-starter/deploy/docker-compose.yaml"

# Створення скрипта моніторингу контейнерів
echo "📝 Створення файлу моніторингу..."
cat <<EOF > "$INSTALL_DIR/monitor.sh"
#!/bin/bash

# Масив контейнерів, які потрібно моніторити
containers=("infernet-node" "deploy-fluentbit-1" "deploy-redis-1")

while true; do
    restart_needed=false

    for container in "\${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^\$container\$"; then
            echo "\$(date): Контейнер \$container не працює!"
            restart_needed=true
        fi
    done

    if [ "\$restart_needed" = true ]; then
        echo "\$(date): Перезапускаємо всі контейнери..."
        docker compose -f "$COMPOSE_FILE" restart
    else
        echo "\$(date): Всі контейнери працюють коректно."
    fi

    sleep 30
done
EOF

# Робимо скрипт виконуваним
chmod +x "$INSTALL_DIR/monitor.sh"

# Створення systemd-сервісу
echo "📝 Створення systemd-сервісу..."
cat <<EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Моніторинг та перезапуск контейнерів Ritual
After=docker.service
Requires=docker.service

[Service]
ExecStart=$INSTALL_DIR/monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Оновлення systemd
echo "🔄 Оновлення systemd..."
systemctl daemon-reload

# Додавання в автозапуск
echo "🔧 Увімкнення сервісу..."
systemctl enable "$SERVICE_NAME.service"

# Запуск сервісу
echo "🚀 Запуск сервісу..."
systemctl start "$SERVICE_NAME.service"

echo "✅ Успішно встановлено!"
