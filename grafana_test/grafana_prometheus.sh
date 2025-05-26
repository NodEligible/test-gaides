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

cat <<EOF | sudo tee /etc/prometheus/prometheus.yml > /dev/null
global:
  scrape_interval: 20s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:19980"]

  - job_name: "node_exporters"
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

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

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

echo -e "${YELLOW}Устанавливаем register_api.py...${NC}"
sudo tee /opt/prometheus-autoreg/register_api.py > /dev/null << 'EOF'
from flask import Flask, request, jsonify
import yaml
import os
import subprocess
import json

app = Flask(__name__)

PROMETHEUS_CONFIG = "/etc/prometheus/prometheus.yml"
ALLOWED_USERS_FILE = "/opt/prometheus-autoreg/allowed_users.json"
DEFAULT_SCRAPE_INTERVAL = "15s"
TARGET_PORT = 9100

def load_config():
    with open(PROMETHEUS_CONFIG, "r") as f:
        return yaml.safe_load(f)

def save_config(config):
    with open(PROMETHEUS_CONFIG, "w") as f:
        yaml.dump(config, f, default_flow_style=False)

def restart_prometheus():
    subprocess.run(["systemctl", "restart", "prometheus"])

def get_allowed_users():
    if not os.path.exists(ALLOWED_USERS_FILE):
        return {}
    with open(ALLOWED_USERS_FILE, "r") as f:
        return json.load(f)

@app.route("/register", methods=["POST"])
def register():
    data = request.json
    ip = data.get("ip")
    port = data.get("port", TARGET_PORT)
    user = data.get("user")  # job_name
    server_name = data.get("server_name")
    discord_id = data.get("discord_id")

    if not ip or not user or not server_name or not discord_id:
        return jsonify({"error": "Missing fields (ip, user, server_name, discord_id)"}), 400

    allowed_users = get_allowed_users()
    discord_id_str = str(discord_id)

    # перевірка доступу
    if discord_id_str not in allowed_users:
        return jsonify({"error": f"⛔ Discord ID {discord_id} не має доступу"}), 403

    allowed_name = allowed_users[discord_id_str]
    if allowed_name != user:
        return jsonify({"error": f"⛔ Вам дозволено реєструватися лише як '{allowed_name}', а не '{user}'"}), 403

    target = f"{ip}:{port}"

    config = load_config()
    jobs = config.get("scrape_configs", [])

    user_job = next((job for job in jobs if job.get("job_name") == user), None)
    if not user_job:
        user_job = {
            "job_name": user,
            "scrape_interval": DEFAULT_SCRAPE_INTERVAL,
            "static_configs": []
        }
        jobs.append(user_job)

    static_configs = user_job.get("static_configs", [])

    for entry in static_configs:
        if entry.get("labels", {}).get("instance") == server_name and target not in entry.get("targets", []):
            return jsonify({"error": f"Server name '{server_name}' already used for another IP"}), 400

    for entry in static_configs:
        if target in entry.get("targets", []):
            entry["labels"]["instance"] = server_name
            save_config(config)
            restart_prometheus()
            return jsonify({
                "message": f"Updated {target} with new name '{server_name}'",
                "user": user,
                "welcome": f"Ласкаво просимо, {user}!"
            }), 200

    static_configs.append({
        "targets": [target],
        "labels": {
            "instance": server_name
        }
    })

    user_job["static_configs"] = static_configs
    config["scrape_configs"] = jobs
    save_config(config)
    restart_prometheus()

    return jsonify({
        "message": f"Registered {target} under job '{user}' as '{server_name}'",
        "user": user,
        "welcome": f"Ласкаво просимо, {user}!"
    }), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)

EOF

echo -e "${YELLOW}Создаем systemd сервис...${NC}"
sudo tee /etc/systemd/system/autoreg-api.service > /dev/null << EOF
[Unit]
Description=Prometheus Auto Registration API
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/prometheus-autoreg/register_api.py
WorkingDirectory=/opt/prometheus-autoreg
Restart=always
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

#---------------------------------------------------------------------------------------------------------------------------------------------

echo -e "${YELLOW}Создаем список Discord ID${NC}"
sudo mkdir -p /opt/prometheus-autoreg
cat <<EOF | sudo tee /opt/prometheus-autoreg/allowed_users.json > /dev/null
{}
EOF

echo -e "${YELLOW}Перезапуск systemd и запуск API...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

sleep 4

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable autoreg-api
sudo systemctl restart autoreg-api

sleep 4

sudo systemctl restart prometheus

echo -e "${GREEN}Grafana успешно установлена!${NC}"
echo -e "${YELLOW}Grafana доступна по адресу: http://${PROMETHEUS_IP}:3000 Login:${NC}admin  ${YELLOW}Password:${NC}admin"
echo -e "${YELLOW}Prometheus доступен по адресу: http://${PROMETHEUS_IP}:19980/targets?search=${NC}"
