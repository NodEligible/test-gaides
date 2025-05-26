#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m'

echo -e "${YELLOW}⚙️ Запрос данных для регистрации узла...${NC}"

PROMETHEUS_API="http://109.199.101.181:5001/register"
NODE_PORT=9100
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}👤 Введите ваш никнейм (будет job_name):${NC}"
read -p "➜ " USER

echo -e "${BLUE}📝 Придумайте название сервера (instance):${NC}"
read -p "➜ " SERVER_NAME

echo -e "${BLUE}🛡️ Введите ваш Discord ID:${NC}"
read -p "➜ " DISCORD_ID

RESPONSE=$(curl -s -X POST "$PROMETHEUS_API" \
  -H "Content-Type: application/json" \
  -d "{\"ip\": \"$IP\", \"port\": $NODE_PORT, \"user\": \"$USER\", \"server_name\": \"$SERVER_NAME\", \"discord_id\": \"${DISCORD_ID}\"}")

if echo "$RESPONSE" | grep -q "Registered\|Updated"; then
    MESSAGE=$(echo "$RESPONSE" | grep -oP '"message"\s*:\s*"\K[^"]+')
    USERNAME=$(echo "$RESPONSE" | grep -oP '"user"\s*:\s*"\K[^"]+')

    echo -e "${GREEN}✅ Регистрация прошла успешно!${NC}"
    echo -e "👤 ${BLUE}Пользователь:${NC} ${GREEN}$USERNAME${NC}"
    echo -e "📬 ${BLUE}Сообщение:${NC} $MESSAGE"
else
    echo -e "${RED}❌ Ошибка: вы не в белом списке или используете недопустимое имя. Ответ: $RESPONSE${NC}"
    exit 1
fi


#--------------------------------------------------------------------------------------------------------------
NODE_EXPORTER_VERSION="1.7.0"

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
cd node_exporter-$NODE_EXPORTER_VERSION.linux-amd64

mv node_exporter /usr/bin/
rm -rf /tmp/node_exporter*

useradd -rs /bin/false node_exporter
chown node_exporter:node_exporter /usr/bin/node_exporter


cat <<EOF> /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target
 
[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

echo -e "${GREEN}Установка завершена!${NC}" 
