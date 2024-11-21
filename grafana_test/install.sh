#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PROMETHEUS_VERSION="2.51.1"
GRAFANA_VERSION="6.4.3"

PROMETHEUS_IP=$(hostname -I | awk '{print $1}')
PROMETHEUS_URL="http://${PROMETHEUS_IP}:19980"

echo -e "${YELLOW}Автоматически определен IP-адрес сервера: ${PROMETHEUS_IP}${NC}"
echo -e "${YELLOW}Prometheus URL: ${PROMETHEUS_URL}${NC}"

echo -e "${YELLOW}Установка Grafana...${NC}"
sudo apt-get update
sudo apt-get install -y apt-transport-https software-properties-common wget curl
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
apt-get install -y adduser libfontconfig1 musl

wget https://dl.grafana.com/oss/release/grafana_6.4.3_amd64.deb
dpkg -i grafana_6.4.3_amd64.deb

mkdir -p /etc/grafana/provisioning/datasources/
cat <<EOF > /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: ${PROMETHEUS_URL}
EOF

mkdir -p /etc/grafana/provisioning/dashboards/
cat <<EOF > /etc/grafana/provisioning/dashboards/dashboard.yaml
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/dashboards
EOF

mkdir -p /etc/grafana/dashboards/
curl -o /etc/grafana/dashboards/dashboard.json https://raw.githubusercontent.com/NodEligible/monitoring/refs/heads/main/dashboard/settings.json

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
rm -rf grafana_6.4.3_amd64.deb

echo -e "${GREEN}Grafana успешно установлена!${NC}"
echo -e "${YELLOW}Grafana доступна по адресу: http://${PROMETHEUS_IP}:3000 Login:admin  Password:admin${NC}"
echo -e "${YELLOW}Prometheus доступен по адресу: http://${PROMETHEUS_IP}:19980/targets?search=${NC}"
