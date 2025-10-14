sudo apt install gawk bison build-essential manpages-dev ca-certificates -y

USERNAME="pipe"

if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}Пользователь${NC} '$USERNAME' ${YELLOW}существует${NC}"
else
    sudo useradd -m -s /bin/bash "$USERNAME"
    echo -e "${GREEN}Пользователь${NC} '$USERNAME' ${GREEN}создан.${NC}"
fi
sudo usermod -aG sudo "$USERNAME"

sudo tee /etc/sysctl.d/99-pipe.conf > /dev/null << "EOL"
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL

sudo sysctl --system &>/dev/null

sudo tee /etc/security/limits.d/pipe.conf > /dev/null << "EOL"
*    hard nofile 65535
*    soft nofile 65535
EOL

sudo mkdir -p /opt/pipe
cd /opt/pipe



# Далі скрипт можна не монтувати
sudo touch "$LOGROTATE_FILE"
sudo chmod 0640 "$LOGROTATE_FILE"
sudo chown popcache:popcache "$LOGROTATE_FILE"

sudo bash -c "cat > $LOGROTATE_FILE << EOL
/opt/popcache/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 popcache popcache
    sharedscripts
    postrotate
        systemctl reload popcache >/dev/null 2>&1 || true
    endscript
}
EOL"
sudo mkdir -p /opt/popcache/logs
sudo chown -R "$USER:$GROUP" /opt/popcache/logs
