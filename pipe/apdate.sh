
#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Обновление PIPE...${NC}"

echo -e "${YELLOW}🛑 Остановка сервиса PIPE...${NC}"
sudo systemctl stop pop
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Сервис PIPE остановлен!${NC}"
else
    echo -e "${RED}❌ Ошибка при остановке сервиса PIPE!${NC}"
fi

sudo sed -i '/^ExecStart=/ { /--enable-80-443/! s/$/ --enable-80-443/ }' /etc/systemd/system/pop.service

echo -e "${YELLOW}📥 Загрузка новой версии POP...${NC}"
sudo wget -O $HOME/opt/dcdn/pop "https://dl.pipecdn.app/v0.2.8/pop"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ POP успешно загружен!${NC}"
else
    echo -e "${RED}❌ Ошибка при загрузке POP!${NC}"
    exit 1
fi

echo -e "${YELLOW}🛠️ Установка прав доступа...${NC}"
chmod +x $HOME/opt/dcdn/pop
sudo ln -s $HOME/opt/dcdn/pop /usr/local/bin/pop -f
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Права доступа установлены!${NC}"
else
    echo -e "${RED}❌ Ошибка при установке прав доступа!${NC}"
fi

echo -e "${YELLOW}🔄 Обновление POP...${NC}"
$HOME/opt/dcdn/pop --refresh
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Обновление POP завершено!${NC}"
else
    echo -e "${RED}❌ Ошибка при обновлении POP!${NC}"
fi

echo -e "${YELLOW}🚀 Запуск сервиса PIPE...${NC}"
sudo systemctl start pop
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Сервис PIPE успешно запущен!${NC}"
else
    echo -e "${RED}❌ Ошибка при запуске сервиса PIPE!${NC}"
fi

echo -e "${GREEN}🚀 Обновление PIPE завершено!${NC}"
