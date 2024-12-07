#!/bin/bash

logo() {
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash
}

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

cleanup() {
  docker-compose -f $HOME/nwaku-compose/docker-compose.yml down
  # mkdir -p $HOME/nwaku_backups
  # if [ -d "$HOME/nwaku_backups/keystore0.30" ]; then
  #   echo "Бекап уже сделан"
  # else
  #   echo "Делаем бекап ключей"
  #   mkdir -p $HOME/nwaku_backups/keystore0.30
  #   cp $HOME/nwaku-compose/keystore/keystore.json $HOME/nwaku_backups/keystore0.30/keystore.json
  #   rm -rf $HOME/nwaku-compose/keystore/
  # fi
  
  # rm -rf $HOME/nwaku-compose/rln_tree/ 
  cd $HOME/nwaku-compose
  git restore . &>/dev/null
}

update() {
  # Выгружаем переменные с .env в среду выполнения
  source $HOME/nwaku-compose/.env &>/dev/null

  # Удаляем старый .env
  rm -rf $HOME/nwaku-compose/.env
  cd $HOME/nwaku-compose
  git pull origin master
  cp .env.example .env

  if [ -z "$RLN_RELAY_ETH_CLIENT_ADDRESS" ]; then
      echo -e "Введите ваш RPC Sepolia https url. Пример url'a - https://sepolia.infura.io/v3/ТУТ_ВАШ_КЛЮЧ"
      read RLN_RELAY_ETH_CLIENT_ADDRESS
  fi

  if [ -z "$ETH_TESTNET_KEY" ]; then
      echo -e "Введите ваш приватник от ETH кошелека на котором есть как минимум 0.1 ETH в сети Sepolia"
      read ETH_TESTNET_KEY
  fi

  if [ -z "$RLN_RELAY_CRED_PASSWORD" ]; then
      echo -e "Введите(придумайте) пароль который будет использваться для сетапа ноды"
      read RLN_RELAY_CRED_PASSWORD
  fi

  sed -i "s|RLN_RELAY_ETH_CLIENT_ADDRESS=.*|RLN_RELAY_ETH_CLIENT_ADDRESS=$RLN_RELAY_ETH_CLIENT_ADDRESS|" $HOME/nwaku-compose/.env
  sed -i "s|ETH_TESTNET_KEY=.*|ETH_TESTNET_KEY=$ETH_TESTNET_KEY|" $HOME/nwaku-compose/.env
  sed -i "s|RLN_RELAY_CRED_PASSWORD=.*|RLN_RELAY_CRED_PASSWORD=$RLN_RELAY_CRED_PASSWORD|" $HOME/nwaku-compose/.env
  sed -i "s|NWAKU_IMAGE=.*|NWAKU_IMAGE=wakuorg/nwaku:v0.33.1|" $HOME/nwaku-compose/.env


  # Меняем стандартный порт графаны, на случай если кто-то баловался с другими нодами 
  # и она у него висит и занимает порт. Сыграем на опережение=)
  sed -i 's/0\.0\.0\.0:3000:3000/0.0.0.0:3004:3000/g' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/127\.0\.0\.1:4000:4000/0.0.0.0:4044:4000/g' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's|127.0.0.1:8003:8003|127.0.0.1:8333:8003|' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/:5432:5432/:5444:5432/g' $HOME/nwaku-compose/docker-compose.yml

}


docker_compose_up() {
  docker compose -f $HOME/nwaku-compose/docker-compose.yml up -d
}

echo_info() {
  echo -e "${GREEN}Для остановки ноды waku: ${NC}"
  echo -e "${YELLOW}   docker-compose -f $HOME/nwaku-compose/docker-compose.yml down \n ${NC}"
  echo -e "${GREEN}Для запуска ноды и фармера waku: ${NC}"
  echo -e "${YELLOW}   docker-compose -f $HOME/nwaku-compose/docker-compose.yml up -d \n ${NC}"
  echo -e "${GREEN}Для перезагрузки ноды waku: ${NC}"
  echo -e "${YELLOW}   docker-compose -f $HOME/nwaku-compose/docker-compose.yml restart \n ${NC}"
  echo -e "${GREEN}Для проверки логов ноды выполняем команду: ${NC}"
  echo -e "${YELLOW}   docker-compose -f $HOME/nwaku-compose/docker-compose.yml logs -f --tail=100 \n ${NC}"
  ip_address=$(hostname -I | awk '{print $1}') >/dev/null
  echo -e "${GREEN}Для проверки дашборда графаны, перейдите по ссылке: ${NC}"
  echo -e "${YELLOW}   http://$ip_address:3004/d/yns_4vFVk/nwaku-monitoring \n ${NC}"
}

logo
cleanup
update
docker_compose_up
echo_info
echo -e "${GREEN}Обновление завершено!${NC}"
