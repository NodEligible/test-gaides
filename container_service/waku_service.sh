#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Шлях для встановлення
INSTALL_DIR="/root/waku_service"
SERVICE_NAME="waku-container"

echo -e "${YELLOW}📁 Создание папки $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR"

# Шлях до файлу логування
LOG_FILE="$HOME/waku_service/monitor.log"

# Створюємо директорію, якщо її немає
mkdir -p "$(dirname "$LOG_FILE")"

# Створюємо файл логування, якщо він не існує
touch "$LOG_FILE"

# Надаємо права на запис у файл
chmod 644 "$LOG_FILE"

# Шлях до файлу docker-compose
COMPOSE_FILE="$HOME/nwaku-compose/docker-compose.yml"

# Створення скрипта моніторингу контейнерів
echo -e "${YELLOW}📝 Создание файла мониторинга...${NC}"
cat <<EOF > "$INSTALL_DIR/monitor.sh"
#!/bin/bash

# Кольорові змінні
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Лог-файл
LOG_FILE="$HOME/waku_service/monitor.log"

# Масив контейнерів, які потрібно моніторити
containers=("nwaku-compose-grafana-1" "nwaku-compose-waku-frontend-1" "nwaku-compose-prometheus-1" "nwaku-compose-nwaku-1" "nwaku-compose-postgres-exporter-1" "nwaku-compose-postgres-1")

while true; do
    restart_needed=false

    for container in "\${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^\$container\$"; then
            echo -e "\$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') ⛔️ ${RED} Контейнер${NC} \$container ${RED}не работает!${NC}" | tee -a "$LOG_FILE"
            restart_needed=true
        fi
    done
    if [ "\$restart_needed" = true ]; then
        docker compose -f "$COMPOSE_FILE" down
    echo -e "\$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') ⏳ ${YELLOW} Перезапускаем все контейнеры...${NC}" | tee -a "$LOG_FILE"   
    sleep 40
    docker compose -f "$COMPOSE_FILE" up -d
    echo -e "\$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') 🔎 ${YELLOW} Контейнеры${NC} Waku ${YELLOW}подняты, следующая проверка через 10 минут.${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "\$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') ✅ ${GREEN} Все контейнеры${NC} Waku ${GREEN}работают корректно.${NC}" | tee -a "$LOG_FILE"
    fi
    sleep 10m
done
EOF

# Робимо скрипт виконуваним
chmod +x "$INSTALL_DIR/monitor.sh"

# Створення systemd-сервісу
echo -e "${YELLOW}📝 Создание systemd-сервиса...${NC}"
cat <<EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Мониторинг контейнеров Waku
After=docker.service
Requires=docker.service

[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/bin/bash /root/waku_service/monitor.sh
Restart=always
User=root
StandardOutput=append:/root/waku_service/service.log
StandardError=append:/root/waku_service/service.log

[Install]
WantedBy=multi-user.target
EOF

# Оновлення systemd
echo -e "${YELLOW}🔄 Обновление systemd...${NC}"
systemctl daemon-reload

# Додавання в автозапуск
echo -e "${YELLOW}🔧 Включение сервиса...${NC}"
systemctl enable "$SERVICE_NAME.service"

# Запуск сервісу
echo -e "${YELLOW}🚀 Запуск сервиса...${NC}"
systemctl start "$SERVICE_NAME.service"

echo -e "${GREEN}✅ Установка завершена!${NC}"
