#!/bin/sh -e

# Prevent execution if this script was only partially downloaded
{
rc='\033[0m'
red='\033[0;31m'

# Check if curl is installed
if ! command -v curl >/dev/null 2>&1; then
    printf "${red}ERROR: curl is not installed. Please install curl to proceed.${rc}\n"
    exit 1
fi

download_url="https://console.icn.global/downloads"
version="v-0-1-2"
server_url="dac.api.icn.global:443"
config_url="https://api.icn.global/services/dac"

while getopts ":ip:u:v:s:c:" option; do
   case $option in
      i)
        install_mode=true;;
      p)
        private_key=$OPTARG;;
      u)
        download_url=$OPTARG;;
      v)
        version=$OPTARG;;
      s)
        server_url=$OPTARG;;
      c)
        config_url=$OPTARG;;
     \?)
        echo "Error: Invalid option"
        exit 1;;
   esac
done

# Check if curl is installed
if ! command -v curl >/dev/null 2>&1; then
    printf "${red}ERROR: curl is not installed. Please install curl to proceed.${rc}\n"
    exit 1
fi

# Check if a private key is provided in start mode
if [ "$install_mode" = false ] && [ -z "$private_key" ]; then
    printf "${red}ERROR: A private key must be provided as a parameter.${rc}\n"
    exit 1
fi

check() {
    exit_code=$1
    message=$2

    if [ "$exit_code" -ne 0 ]; then
        printf "${red}ERROR: %s${rc}\n" "$message"
        exit 1
    fi

    unset exit_code
    unset message
}

find_arch_and_os() {
    case "$(uname -m)" in
        x86_64*|amd64*) arch="amd64" ;;
        arm64*|aarch64*) arch="arm64" ;;
        *) check 1 "Unsupported architecture" ;;
    esac
    case "$(uname -s)" in
        Linux*) os="linux" ;;
        Darwin*) os="darwin" ;;
        *) check 1 "Unsupported OS" ;;
    esac
}

get_url() {
    echo "${download_url}/sla-oracle-node-${os}-${arch}-${version}"
}

find_arch_and_os
check $? "Detecting architecture and OS"

temp_file=$(mktemp)
check $? "Creating the temporary file"

curl -fsL "$(get_url)" -o "$temp_file"
check $? "Downloading sla-oracle-node"

chmod +x "$temp_file"
check $? "Making sla-oracle-node executable"

if [ "$install_mode" = true ]; then
    # Installation logic
    install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    check $? "Creating installation directory at $install_dir"

    mv "$temp_file" "$install_dir/sla-oracle-node"
    check $? "Moving binary to $install_dir"

    if ! echo "$PATH" | grep -q "$install_dir"; then
        echo "Adding $install_dir to your PATH."

        shell_profile=""
        if [ -n "$BASH_VERSION" ]; then
            shell_profile="$HOME/.bashrc"
        elif [ -n "$ZSH_VERSION" ]; then
            shell_profile="$HOME/.zshrc"
        else
            shell_profile="$HOME/.profile"
        fi

        echo "export PATH=\"$install_dir:\$PATH\"" >> "$shell_profile"
        check $? "Updating PATH in $shell_profile"
        
        export PATH="$install_dir:$PATH"
        echo "Updated PATH in $shell_profile. Please restart your terminal or run 'source $shell_profile' to use the updated PATH."
    fi

    echo "Installation complete. You can now run 'sla-oracle-node' from any terminal."
else
    # Start logic
    "$temp_file" -p "$private_key" --dac-client.server-endpoint "$server_url" --external-config.server-endpoint "$config_url"
    check $? "Executing sla-oracle-node"

    rm -f "$temp_file"
    check $? "Deleting the temporary file"
fi
} # End of wrapping
