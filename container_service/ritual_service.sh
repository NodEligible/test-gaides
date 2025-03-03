#!/bin/bash

# Шлях для встановлення
INSTALL_DIR="/root/ritual_service"
SERVICE_NAME="ritual-container"

echo "📁 Создание папки $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Шлях до файлу docker-compose
COMPOSE_FILE="/root/infernet-container-starter/deploy/docker-compose.yaml"

# Створення скрипта моніторингу контейнерів
echo "📝 Создание файла мониторинга..."
cat <<EOF > "$INSTALL_DIR/monitor.sh"
#!/bin/bash

# Массив контейнеров, которые нужно мониторить
containers=("infernet-node" "deploy-fluentbit-1" "deploy-redis-1")

while true; do
    restart_needed=false

    for container in "\${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^\$container\$"; then
            echo "\$(date): Контейнер \$container не работает!"
            restart_needed=true
        fi
    done

    if [ "\$restart_needed" = true ]; then
        echo "\$(date): Перезапускаем все контейнеры..."
        docker compose -f "$COMPOSE_FILE" restart
    else
        echo "\$(date): Все контейнеры работают корректно."
    fi

    sleep 30
done
EOF

# Робимо скрипт виконуваним
chmod +x "$INSTALL_DIR/monitor.sh"

# Створення systemd-сервісу
echo "📝 Создание systemd-сервиса..."
cat <<EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Мониторинг и перезапуск контейнеров Ritual
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
echo "🔄 Обновление systemd..."
systemctl daemon-reload

# Додавання в автозапуск
echo "🔧 Включение сервиса..."
systemctl enable "$SERVICE_NAME.service"

# Запуск сервісу
echo "🚀 Запуск сервиса..."
systemctl start "$SERVICE_NAME.service"

echo "✅ Успешно установлено!"
