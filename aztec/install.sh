#!/bin/bash
exists()
{
	  command -v "$1" >/dev/null 2>&1
  }
if exists curl; then
	echo ''
else
	  sudo apt update && sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
	    . $HOME/.bash_profile
fi

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Aborting: run as root user!"
    exit 1
fi

echo ""
echo "Enter Ethereum Sepolia RPC URLs."
echo "Example: https://sepolia.infura.io/v3/YOUR_PROJECT_ID,https://rpc.sepolia.org,http://host.docker.internal:8545"
read -p "ETHEREUM_HOSTS: " ETHEREUM_HOSTS

# 2. L1_CONSENSUS_HOST_URLS
echo ""
echo "Enter Ethereum Sepolia Beacon (consensus) RPC URLs."
echo "Example: https://beacon-sepolia.drpc.org,http://host.docker.internal:3500"
read -p "L1_CONSENSUS_HOST_URLS: " L1_CONSENSUS_HOST_URLS

# 3. VALIDATOR_PRIVATE_KEY
echo ""
echo "Enter the private key of your Ethereum wallet that holds Sepolia ETH."
echo "Example: 67387037cfe05140cfd440ed5f015edb63e59c2e9684a9789f779445b0868681 (do NOT share this key with anyone!)"
read -p "VALIDATOR_PRIVATE_KEY: " VALIDATOR_PRIVATE_KEY

# 4. VALIDATOR_ADDRESS
echo ""
echo "Enter the validator Ethereum address (starting with 0x)."
echo "This is the address of the wallet from which you specified the private key on the previous step."
echo "Example: 0xD7775eeeA6cDAF9c95B68539214926e2FF322480"
read -p "VALIDATOR_ADDRESS: " VALIDATOR_ADDRESS
# 4. COINBASE
echo ""
echo "Enter the Ethereum address (starting with 0x) that will receive block rewards."
echo "It is recommended to use an address different from your validator wallet."
echo "Example: 0xD7775eeeA6cDAF9c95B68539214926e2FF322460"
read -p "COINBASE: " COINBASE


P2P_IP="$(curl -s ipinfo.io/ip)"
echo 'export STAKING_ASSET_HANDLER="0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2"' >> ~/.bash_profile #Constant L1 contract address
echo 'export L1_CHAIN_ID="11155111"' >> ~/.bash_profile #Sepolia chainid
echo 'export PRIVATE_KEY="${VALIDATOR_PRIVATE_KEY}"' >> ~/.bash_profile #private key of account with sepolia eth to make transaction
echo 'export ETHEREUM_HOSTS="$ETHEREUM_HOSTS"' >> ~/.bash_profile
echo 'export L1_CONSENSUS_HOST_URLS="$L1_CONSENSUS_HOST_URLS"' >> ~/.bash_profile
echo 'export VALIDATOR_PRIVATE_KEY="$VALIDATOR_PRIVATE_KEY"' >> ~/.bash_profile
echo 'export VALIDATOR_ADDRESS="$VALIDATOR_ADDRESS"' >> ~/.bash_profile
echo 'export COINBASE="$COINBASE"' >> ~/.bash_profile

# Save variables to an environment file
mkdir -p $HOME/.aztec
cat <<EOF > $HOME/.aztec/aztec.env
ETHEREUM_HOSTS="$ETHEREUM_HOSTS"
L1_CONSENSUS_HOST_URLS="$L1_CONSENSUS_HOST_URLS"
VALIDATOR_PRIVATE_KEY="$VALIDATOR_PRIVATE_KEY"
VALIDATOR_ADDRESS="$VALIDATOR_ADDRESS"
COINBASE="$COINBASE"
P2P_IP="$P2P_IP"
EOF

echo ""
echo "вњ… Variables saved to $HOME/.aztec/aztec.env"
sleep 2

#install docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
echo "Adding user '$USER' to docker group..."
#sudo usermod -aG docker "$USER"

#newgrp docker <<EOF
#echo "Now running in a shell where group 'docker' is active"
#echo "Installing Aztec..."
yes | bash -i <(curl -s https://install.aztec.network)
#EOF

echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
aztec-up alpha-testnet
sleep 1
aztec-up latest

echo "[Unit]
Description=Aztec Sequencer Node
After=network.target

[Service]
Type=simple
User=$USER
#EnvironmentFile=$HOME/.aztec/aztec.env
WorkingDirectory=$HOME/.aztec/
ExecStart=$(which aztec) start --node --archiver --sequencer --network alpha-testnet --l1-rpc-urls ${ETHEREUM_HOSTS} --l1-consensus-host-urls ${L1_CONSENSUS_HOST_URLS} --sequencer.validatorPrivateKeys ${VALIDATOR_PRIVATE_KEY} --sequencer.coinbase ${COINBASE} --p2p.p2pIp ${P2P_IP}
Restart=always

[Install]
WantedBy=multi-user.target" > $HOME/aztec.service

sudo mv $HOME/aztec.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart aztec
sudo systemctl enable aztec

echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service aztec status | grep active` =~ "running" ]]; then
  echo -e "Your Aztec node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice aztec status\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your Aztec node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
