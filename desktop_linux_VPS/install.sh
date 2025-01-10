#!/bin/bash

# Определение цветовых кодов
INFO='\033[0;36m'  # Циан
BANNER='\033[0;35m' # Магента
WARNING='\033[0;33m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
NC='\033[0m' # Без цвета

# Запрос имени пользователя и пароля
while true; do
    read -p "Введите имя пользователя для удалённого доступа: " USER
    if [[ "$USER" == "root" ]]; then
        echo -e "${ERROR}Ошибка: 'root' нельзя использовать как имя пользователя. Выберите другое имя.${NC}"
    elif [[ "$USER" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}Ошибка: Имя пользователя содержит запрещённые символы. Разрешены только буквенно-цифровые символы.${NC}"
    else
        break
    fi
done

while true; do
    read -sp "Введите пароль для $USER: " PASSWORD
    echo
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}Ошибка: Пароль содержит запрещённые символы. Разрешены только буквенно-цифровые символы.${NC}"
    else
        break
    fi
done

echo -e "${INFO}Обновление списка пакетов...${NC}"
sudo apt update

echo -e "${INFO}Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

echo -e "${INFO}Установка XFCE рабочего окружения для низкого потребления ресурсов...${NC}"
sudo apt install -y xfce4 xfce4-goodies

echo -e "${INFO}Установка XRDP для удалённого рабочего стола...${NC}"
sudo apt install -y xrdp

echo -e "${INFO}Добавление пользователя $USER с указанным паролем...${NC}"
sudo useradd -m -s /bin/bash $USER
echo "$USER:$PASSWORD" | sudo chpasswd

echo -e "${INFO}Добавление $USER в группу sudo...${NC}"
sudo usermod -aG sudo $USER

echo -e "${INFO}Настройка XRDP для использования XFCE...${NC}"
echo "xfce4-session" > ~/.xsession

echo -e "${INFO}Изменение startwm.sh для запуска XFCE...${NC}"
sudo sed -i '/test -x \/etc\/X11\/Xsession && exec \/etc\/X11\/Xsession/,+1c\startxfce4' "/etc/xrdp/startwm.sh"

echo -e "${INFO}Настройка XRDP для использования низкой глубины цвета...${NC}"
sudo sed -i '/^#xserverbpp=24/s/^#//; s/xserverbpp=24/xserverbpp=16/' /etc/xrdp/xrdp.ini
echo -e "${SUCCESS}Конфигурация XRDP обновлена для использования глубины цвета 16.${NC}"

echo -e "${INFO}Установка максимального разрешения 1280x720...${NC}"
sudo sed -i '/^max_bpp=/s/=.*/=16/' /etc/xrdp/xrdp.ini
sudo sed -i '/^xres=/s/=.*/=1280/' /etc/xrdp/xrdp.ini
sudo sed -i '/^yres=/s/=.*/=720/' /etc/xrdp/xrdp.ini

grep -q '^max_bpp=' /etc/xrdp/xrdp.ini || echo 'max_bpp=16' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null
grep -q '^xres=' /etc/xrdp/xrdp.ini || echo 'xres=1280' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null
grep -q '^yres=' /etc/xrdp/xrdp.ini || echo 'yres=720' | sudo tee -a /etc/xrdp/xrdp.ini > /dev/null

echo -e "${SUCCESS}Разрешение ограничено до 1280x720.${NC}"

echo -e "${INFO}Перезапуск службы XRDP...${NC}"
sudo systemctl restart xrdp

echo -e "${INFO}Включение XRDP при загрузке...${NC}"
sudo systemctl enable xrdp

sudo apt install -y wget gnupg

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -

echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

sudo apt update

sudo apt install -y google-chrome-stable

if command -v ufw >/dev/null; then
    echo -e "${INFO}UFW установлен. Проверка статуса...${NC}"
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "${INFO}UFW включён. Добавление правила для порта 3389...${NC}"
        sudo ufw allow 3389/tcp
        echo -e "${SUCCESS}Порт 3389 разрешён через UFW.${NC}"
    else
        echo -e "${WARNING}UFW установлен, но не включён. Правило пропущено.${NC}"
    fi
else
    echo -e "${INFO}UFW не установлен. Пропуск настройки брандмауэра.${NC}"
fi

echo -e "${SUCCESS}Установка завершена. XFCE, XRDP и браузер Chrome установлены.${NC}"
echo -e "${INFO}Теперь вы можете подключаться по RDP с пользователем $USER.${NC}"
