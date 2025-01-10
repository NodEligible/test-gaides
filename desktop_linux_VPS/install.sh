#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Проверяем, установлена ли локаль ru_RU.UTF-8
if locale -a | grep -q "ru_RU.utf8"; then
    echo -e "${YELLOW}Локаль ru_RU.UTF-8 уже установлена. Пропускаем установку.${NC}"
else
    echo -e "${YELLOW}Локаль ru_RU.UTF-8 не найдена. Устанавливаем...${NC}"
    sudo locale-gen ru_RU.UTF-8
    sudo update-locale LANG=ru_RU.UTF-8
    echo -e "${GREEN}Локаль ru_RU.UTF-8 успешно установлена.${NC}"
fi

# Запрос имени пользователя и пароля
while true; do
    read -p "Введите имя пользователя для удалённого доступа: " USER
    if [[ "$USER" == "root" ]]; then
        echo -e "${RED}Ошибка: 'root' нельзя использовать как имя пользователя. Выберите другое имя.${NC}"
    elif [[ "$USER" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${RED}Ошибка: Имя пользователя содержит запрещённые символы. Разрешены только буквенно-цифровые символы.${NC}"
    else
        break
    fi
done

while true; do
    read -sp "Введите пароль для $USER: " PASSWORD
    echo
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${RED}Ошибка: Пароль содержит запрещённые символы. Разрешены только буквенно-цифровые символы.${NC}"
    else
        break
    fi
done

echo -e "${YELLOW}Обновление списка пакетов...${NC}"
sudo apt update

echo -e "${YELLOW}Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

echo -e "${YELLOW}Установка XFCE рабочего окружения для низкого потребления ресурсов...${NC}"
sudo apt install -y xfce4 xfce4-goodies

echo -e "${YELLOW}Установка XRDP для удалённого рабочего стола...${NC}"
sudo apt install -y xrdp

echo -e "${YELLOW}Добавление пользователя $USER с указанным паролем...${NC}"
sudo useradd -m -s /bin/bash $USER
echo "$USER:$PASSWORD" | sudo chpasswd

echo -e "${YELLOW}Добавление $USER в группу sudo...${NC}"
sudo usermod -aG sudo $USER

echo -e "${YELLOW}Настройка XRDP для использования XFCE...${NC}"
echo "xfce4-session" > ~/.xsession

echo -e "${YELLOW}Изменение startwm.sh для запуска XFCE...${NC}"
sudo sed -i '/test -x \/etc\/X11\/Xsession && exec \/etc\/X11\/Xsession/,+1c\startxfce4' "/etc/xrdp/startwm.sh"

echo -e "${YELLOW}Настройка XRDP для использования низкой глубины цвета...${NC}"
sudo sed -i '/^#xserverbpp=24/s/^#//; s/xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini
echo -e "${GREEN}Конфигурация XRDP обновлена для использования глубины цвета 16.${NC}"

echo -e "${YELLOW}Установка максимального разрешения 1280x720...${NC}"
sudo sed -i '/^max_bpp=/s/=.*/=16/' /etc/xrdp/xrdp.ini
sudo sed -i '/^xres=/s/=.*/=1280/' /etc/xrdp/xrdp.ini
sudo sed -i '/^yres=/s/=.*/=720/' /etc/xrdp/xrdp.ini

grep -q '^max_bpp=' /etc/xrdp/xrdp.ini || echo 'max_bpp=16' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null
grep -q '^xres=' /etc/xrdp/xrdp.ini || echo 'xres=1280' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null
grep -q '^yres=' /etc/xrdp/xrdp.ini || echo 'yres=720' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null

echo -e "${GREEN}Разрешение ограничено до 1280x720.${NC}"

echo -e "${YELLOW}Перезапуск службы XRDP...${NC}"
sudo systemctl restart xrdp

echo -e "${YELLOW}Включение XRDP при загрузке...${NC}"
sudo systemctl enable xrdp

sudo apt install -y wget gnupg

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -

echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

sudo apt update

sudo apt install -y google-chrome-stable

if command -v ufw >/dev/null; then
    echo -e "${YELLOW}UFW установлен. Проверка статуса...${NC}"
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}UFW включён. Добавление правила для порта 3389...${NC}"
        sudo ufw allow 3389/tcp
        echo -e "${GREEN}Порт 3389 разрешён через UFW.${NC}"
    else
        echo -e "${RED}UFW установлен, но не включён. Правило пропущено.${NC}"
    fi
else
    echo -e "${YELLOW}UFW не установлен. Пропуск настройки брандмауэра.${NC}"
fi

echo -e "${GREEN}Установка завершена. XFCE, XRDP и браузер Chrome установлены.${NC}"
echo -e "${YELLOW}Теперь вы можете подключаться по RDP с пользователем $USER.${NC}"
