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

echo -e "${YELLOW}Открываем порт 19980${NC}"
sudo ufw allow 19980/tcp

echo -e "${YELLOW}Установка Prometheus...${NC}"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

sudo mv prometheus /usr/bin/
sudo mkdir -p /etc/prometheus/data

cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 20s
  
scrape_configs:
  - job_name      : "prometheus"
    static_configs:
      - targets: ["localhost:19980"]

scrape_configs:
  - job_name: 'node_exporters'
    file_sd_configs:
      - files:
        - /opt/prometheus-autoreg/targets/node_exporters.json
        - /opt/prometheus-autoreg/targets/*.json


EOF

sudo useradd -rs /bin/false prometheus
sudo chown prometheus:prometheus /usr/bin/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus

cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /etc/prometheus/data \
  --web.listen-address=":19980"

[Install]
WantedBy=multi-user.target
EOF

if ! systemctl is-active --quiet prometheus; then
  echo -e "${RED}Ошибка при запуске Prometheus! Проверьте логи.${NC}"
  exit 1
fi
echo -e "${GREEN}Prometheus установлен успешно!${NC}"

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

rm -rf grafana_6.4.3_amd64.deb
#---------------------------------------------------------------------------------------------------------------------------------------------
echo -e "${YELLOW}Настройка API...${NC}"
echo -e "${YELLOW}Обновление пакетов...${NC}"
sudo apt update
sudo apt install python3-flask -y

echo -e "${YELLOW}Создаем структуру...${NC}"
sudo mkdir -p /opt/prometheus-autoreg/targets
sudo touch /opt/prometheus-autoreg/targets/node_exporters.json
echo "[]" | sudo tee /opt/prometheus-autoreg/targets/node_exporters.json

echo -e "${YELLOW}Устанавливаем register_api.py...${NC}"
sudo tee /opt/prometheus-autoreg/register_api.py > /dev/null << 'EOF'
from flask import Flask, request, jsonify
import json
import os

app = Flask(__name__)
TARGETS_FILE = "/opt/prometheus-autoreg/targets/node_exporters.json"

def load_targets():
    if not os.path.exists(TARGETS_FILE):
        return []
    with open(TARGETS_FILE, "r") as f:
        return json.load(f)

def save_targets(targets):
    with open(TARGETS_FILE, "w") as f:
        json.dump(targets, f, indent=2)

@app.route("/register", methods=["POST"])
def register():
    data = request.json
    ip = data.get("ip")
    port = data.get("port", 9100)
    user = data.get("user")
    hostname = data.get("hostname")

    if not ip or not user or not hostname:
        return jsonify({"error": "Missing fields (ip, user, hostname)"}), 400

    target_str = f"{ip}:{port}"
    label = f"{user}-{hostname}"
    updated = False

    targets = load_targets()

    for entry in targets:
        if target_str in entry.get("targets", []):
            entry["labels"]["user"] = user
            entry["labels"]["hostname"] = hostname
            entry["labels"]["instance"] = label
            updated = True
            break

    if not updated:
        targets.append({
            "targets": [target_str],
            "labels": {
                "job": "node_exporter",
                "user": user,
                "hostname": hostname,
                "instance": label
            }
        })

    save_targets(targets)

    if updated:
        return jsonify({"message": f"Updated {target_str} with new labels"}), 200
    else:
        return jsonify({"message": f"Registered {target_str} under {label}"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

# Перевірка чи вже запущено
if pgrep -f register_api.py > /dev/null; then
  echo -e "${GREEN}API уже запущено.${NC}"
else
  echo -e "${YELLOW}Запускаем API...${NC}"
  cd /opt/prometheus-autoreg
  nohup python3 register_api.py > api.log 2>&1 &
fi

#---------------------------------------------------------------------------------------------------------------------------------------------

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

sleep 5

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo -e "${GREEN}Grafana успешно установлена!${NC}"
echo -e "${YELLOW}Grafana доступна по адресу: http://${PROMETHEUS_IP}:3000 Login:${NC}admin  ${YELLOW}Password:${NC}admin"
echo -e "${YELLOW}Prometheus доступен по адресу: http://${PROMETHEUS_IP}:19980/targets?search=${NC}"
