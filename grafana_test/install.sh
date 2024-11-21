#!/bin/bash
#--------------------------------------------------------------------
# Скрипт для встановлення Grafana Server на Ubuntu (22.04, 24.04) з дашбордом
#--------------------------------------------------------------------

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Установка Grafana...${NC}"
# Версія Grafana
GRAFANA_VERSION="6.4.3"
# Встановлення необхідних залежностей
apt-get install -y apt-transport-https software-properties-common wget curl
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y adduser libfontconfig1 musl

# Завантаження та встановлення Grafana
wget https://dl.grafana.com/oss/release/grafana_6.4.3_amd64.deb
dpkg -i grafana_6.4.3_amd64.deb

# Додавання Grafana до PATH
echo "export PATH=/usr/share/grafana/bin:\$PATH" >> /etc/profile

# Перезавантаження та запуск сервісу Grafana
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

rm -rf grafana_6.4.3_amd64.deb

echo -e "${GREEN}Grafana установлена ​​с дашбордом!${NC}"
echo -e "${YELLOW}Перейдите к Grafana, чтобы проверить дашборд по адресу: http://${PROMETHEUS_IP}:3000${NC}"
