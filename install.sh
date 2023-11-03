#!/bin/bash

# Define colors if needed for the echo statements
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ask_twice() {
    local prompt="$1"
    local secret="$2"
    local val1 val2

    while true; do
        if [ "$secret" = "true" ]; then

            read -rsp "$prompt: " val1

            echo >&2
        else
            read -rp "$prompt: " val1
            echo >&2
        fi
        
        if [ "$secret" = "true" ]; then
            read -rsp "Confirm password: " val2
            echo >&2
        else
            read -rp "Confirm password: " val2
            echo >&2
        fi

        if [ "$val1" = "$val2" ]; then
            printf "${GREEN}Password confirmed${NC}" >&2
            echo "$val1"
            break
        else
            printf "${RED}Inputs do not match. Please try again${NC}\n" >&2
            echo -e "\n"
        fi
    done
}
# Function to check and install Ansible
install_ansible() {
    if ! command -v ansible-playbook >/dev/null; then
        echo "Ansible is not installed. Installing Ansible..."

        # Update package lists
        sudo apt update

        # Install software-properties-common if not already installed
        sudo apt install -y software-properties-common

        # Add Ansible PPA (Personal Package Archive) and install Ansible
        sudo apt-add-repository --yes --update ppa:ansible/ansible
        sudo apt install -y ansible

        echo "Ansible installation complete."
    else
        echo "Ansible is already installed."
    fi
}
# Collect SQL root password and set environment variable
echo -e "${YELLOW}Now let's set some important parameters...${NC}"
sleep 1
echo -e "${YELLOW}We will need your required SQL root password${NC}"
sleep 1
sqlpasswrd=$(ask_twice "What is your required SQL root password" "true")
export MARIADB_ROOT_PASSWORD="$sqlpasswrd" # Use the collected password here

# Function to run the Ansible playbook
run_playbook() {
    # Execute the playbook
    echo "Running Ansible playbook..."
    ansible-playbook playbooks/main.yml
}

# Check if Ansible is installed and install if not
install_ansible

# Run the playbook
run_playbook