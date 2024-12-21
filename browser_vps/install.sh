#!/bin/bash

# Display the logo (optional)
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Configure locale
sudo locale-gen ru_RU.UTF-8
sudo update-locale

# Open necessary ports
sudo ufw allow 11000/tcp
sudo ufw allow 3000/tcp

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Update and install dependencies
echo -e "${YELLOW}Updating packages...${NC}"
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Packages updated successfully!${NC}"
else
    echo -e "${RED}Failed to update packages!${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker installed successfully!${NC}"
else
    echo -e "${RED}Failed to install Docker!${NC}"
    exit 1
fi

# Get the server's external IP address
SERVER_IP=$(hostname -I | awk '{print $1}')
BROWSER_URL="http://${SERVER_IP}:11000"

echo -e "${YELLOW}Automatically detected server IP address: ${SERVER_IP}${NC}"

# Prompt for username
read -p "Enter a username: " USERNAME

# Prompt for password with confirmation
read -s -p "Enter a password: " PASSWORD
echo
read -s -p "Confirm your password: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Passwords do not match. Please try again.${NC}"
    exit 1
fi

# Save credentials to a file
CREDENTIALS_FILE="$HOME/vps-browser-credentials.json"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "$USERNAME",
  "password": "$PASSWORD"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Check and download the Kasm Firefox Docker image
echo -e "${YELLOW}Downloading the latest Kasm Firefox Docker image...${NC}"
if ! docker pull kasmweb/firefox:latest; then
    echo -e "${RED}Failed to download the Kasm Firefox Docker image.${NC}"
    exit 1
else
    echo -e "${GREEN}Kasm Firefox Docker image downloaded successfully.${NC}"
fi

# Create configuration directory
mkdir -p "$HOME/kasm_firefox/config"

# Container name
container_name="kasm_firefox"

# Launch the container
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Container $container_name already exists. Starting...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Launching the Kasm Firefox container...${NC}"

    docker run -d --name "$container_name" \
        --privileged \
        -e TITLE=KasmFirefox \
        -e DISPLAY=:1 \
        -e PUID=1000 \
        -e PGID=1000 \
        -e CUSTOM_USER="$USERNAME" \
        -e PASSWORD="$PASSWORD" \
        -e LANGUAGE=ru_RU.UTF-8 \
        -v "$HOME/kasm_firefox/config:/config" \
        -p 11000:3000 \
        --shm-size="2gb" \
        --restart unless-stopped \
        kasmweb/firefox:latest

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Kasm Firefox container launched successfully.${NC}"
    else
        echo -e "${RED}Failed to launch the Kasm Firefox container.${NC}"
        exit 1
    fi
fi

# Display information to the user
echo -e "${YELLOW}Open the browser at: ${BROWSER_URL}${NC}"
echo -e "${YELLOW}Username: $USERNAME${NC}"
echo -e "${YELLOW}Use your password to log in.${NC}"
