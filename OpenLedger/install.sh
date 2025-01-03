wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip

sudo apt install unzip -y
unzip openledger-node-1.0.0-linux.zip

sudo apt-get install -f -y

sudo apt-get install -y libgbm1
sudo apt-get install -y libasound2

sudo apt-get install -y xvfb

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers

bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/nodejs.sh)


