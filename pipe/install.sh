#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Обновление пакетов...${NC}"
sudo apt update -y

echo -e "${YELLOW}📥 Установка Main...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Main успешно установлен!${NC}"
else
    echo -e "${RED}❌ Ошибка при установке Main!${NC}"
fi

echo -e "${YELLOW}📥 Установка Ufw...${NC}" 
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Ufw успешно установлено!${NC}"
else
    echo -e "${RED}❌ Ошибка при установке Ufw!${NC}"
fi

echo -e "${YELLOW}🚀 Установка PIPE...${NC}"

echo -e "${YELLOW}📁 Создание резервной директории...${NC}"
mkdir -p $HOME/pipe_backup
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Директория pipe_backup создана!${NC}"
else
    echo -e "${RED}❌ Ошибка при создании директории pipe_backup!${NC}"
fi

if systemctl list-units --type=service | grep -q "dcdnd.service"; then
    echo -e "${YELLOW}📁 Резервное копирование данных...${NC}"
    cp -r $HOME/.permissionless $HOME/pipe_backup
    echo -e "${GREEN}✅ Данные сохранены в pipe_backup${NC}"

    echo -e "${YELLOW}🛑 Остановка и удаление старого сервиса dcdnd...${NC}"
    sudo systemctl stop dcdnd
    sudo systemctl disable dcdnd
    rm -rf /etc/systemd/system/dcdnd.service
    rm -rf $HOME/opt/dcdn
    rm -rf $HOME/.permissionless
    echo -e "${GREEN}✅ Старый сервис удален!${NC}"
fi

echo -e "${YELLOW}🔗 Введите POP URL: ${NC}"
read POP

echo -e "${YELLOW}🔗 Введите адрес кошелька Соланы: ${NC}"
read PUB_KEY

echo -e "${YELLOW}🎟️ Введите реферальный код или нажмите ENTER: ${NC}"
read REF

echo -e "${YELLOW}📁 Создание директории для PIPE...${NC}"
sudo mkdir -p $HOME/opt/dcdn/download_cache
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Директория создана!${NC}"
else
    echo -e "${RED}❌ Ошибка при создании директории!${NC}"
fi

echo -e "${YELLOW}📥 Загрузка POP...${NC}"
sudo wget -O $HOME/opt/dcdn/pop "$POP"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ POP загружен!${NC}"
else
    echo -e "${RED}❌ Ошибка при загрузке POP!${NC}"
fi

echo -e "${YELLOW}🛠️ Установка прав доступа...${NC}"
sudo chmod +x $HOME/opt/dcdn/pop
sudo ln -s $HOME/opt/dcdn/pop /usr/local/bin/pop -f

if [ -n "$REF" ]; then
    echo -e "${YELLOW}📝 Регистрация по реферальному коду...${NC}"
    cd $HOME/opt/dcdn/
    ./pop --signup-by-referral-route $REF
    echo -e "${GREEN}✅ Регистрация завершена!${NC}"
fi

echo -e "${YELLOW}⚙️ Создание systemd сервиса...${NC}"
sudo tee /etc/systemd/system/pop.service > /dev/null << EOF
[Unit]
Description=Pipe POP Node Service
After=network.target
Wants=network-online.target

[Service]
ExecStart=$HOME/opt/dcdn/pop --ram=4 --pubKey $PUB_KEY --max-disk 100 --cache-dir $HOME/opt/dcdn/download_cache
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node
WorkingDirectory=$HOME/opt/dcdn

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}🔄 Перезагрузка systemd...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable pop
sudo systemctl start pop
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Сервис Pipe POP запущен!${NC}"
else
    echo -e "${RED}❌ Ошибка при запуске сервиса!${NC}"
fi

echo -e "${GREEN}🚀 Установка PIPE завершена!${NC}"
