#!/usr/bin/env bash

# Enhanced ERPNext Installation Script

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display error messages
error_exit() {
    echo -e "\033[0;31mError: $1\033[0m" >&2
    exit 1
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    error_exit "Please run this script as root or with sudo privileges."
fi

# Variables for colored output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to detect OS and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    else
        error_exit "Cannot detect the operating system."
    fi
}

# Function to check if the OS is supported
check_os() {
    SUPPORTED_OS=("ubuntu" "debian")
    SUPPORTED_UBUNTU_VERSIONS=("20.04" "22.04" "24.04")
    SUPPORTED_DEBIAN_VERSIONS=("10" "11" "12")

    detect_os

    if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${OS_NAME} " ]]; then
        error_exit "Your OS ($OS_NAME) is not supported."
    fi

    if [ "$OS_NAME" == "ubuntu" ] && [[ ! " ${SUPPORTED_UBUNTU_VERSIONS[@]} " =~ " ${OS_VERSION} " ]]; then
        error_exit "Your Ubuntu version ($OS_VERSION) is not supported."
    fi

    if [ "$OS_NAME" == "debian" ] && [[ ! " ${SUPPORTED_DEBIAN_VERSIONS[@]} " =~ " ${OS_VERSION} " ]]; then
        error_exit "Your Debian version ($OS_VERSION) is not supported."
    fi
}

# Function to ask for input twice (for passwords)
ask_twice() {
    local prompt="$1"
    local val1 val2

    while true; do
        read -srp "$prompt: " val1
        echo >&2
        read -srp "Confirm: " val2
        echo >&2
        if [ "$val1" = "$val2" ]; then
            echo "$val1"
            break
        else
            echo -e "${RED}Inputs do not match. Please try again.${NC}" >&2
        fi
    done
}

# Welcome message
echo -e "${LIGHT_BLUE}Welcome to the ERPNext Installer...${NC}\n"
sleep 1

# Check OS compatibility
check_os

# Prompt user for ERPNext version
echo -e "${YELLOW}Please select the ERPNext version to install:${NC}"
PS3="Enter the number corresponding to your choice: "
options=("Version 13" "Version 14" "Version 15" "Quit")
select opt in "${options[@]}"; do
    case $REPLY in
        1) bench_version="version-13"; break;;
        2) bench_version="version-14"; break;;
        3) bench_version="version-15"; break;;
        4) exit 0;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}";;
    esac
done

echo -e "${GREEN}You have selected $opt for installation.${NC}\n"

# Confirm installation
while true; do
    read -rp "Do you wish to continue? (yes/no): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) echo -e "${RED}Installation aborted by user.${NC}"; exit;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

# Additional OS compatibility checks for Version 15
if [ "$bench_version" == "version-15" ]; then
    if [ "$OS_NAME" == "ubuntu" ] && (( $(echo "$OS_VERSION < 22.04" | bc -l) )); then
        error_exit "Version 15 requires at least Ubuntu 22.04."
    fi
    if [ "$OS_NAME" == "debian" ] && (( $(echo "$OS_VERSION < 12" | bc -l) )); then
        error_exit "Version 15 requires at least Debian 12."
    fi
fi

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update -qq
apt-get upgrade -y -qq
echo -e "${GREEN}System packages updated.${NC}\n"

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt-get install -y -qq software-properties-common curl git

# Install Python 3.10 or higher if necessary
PYTHON_MIN_VERSION="3.10"
PYTHON_CURRENT_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

if [ "$(printf '%s\n' "$PYTHON_MIN_VERSION" "$PYTHON_CURRENT_VERSION" | sort -V | head -n1)" != "$PYTHON_MIN_VERSION" ]; then
    echo -e "${YELLOW}Installing Python $PYTHON_MIN_VERSION...${NC}"
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update -qq
    apt-get install -y -qq python3.10 python3.10-venv python3.10-dev
    ln -sf /usr/bin/python3.10 /usr/local/bin/python3
    ln -sf /usr/bin/python3.10 /usr/bin/python3
fi

# Ensure pip is installed
echo -e "${YELLOW}Ensuring pip is installed...${NC}"
apt-get install -y -qq python3-pip
pip3 install --upgrade pip

# Install Redis and other dependencies
echo -e "${YELLOW}Installing Redis and other dependencies...${NC}"
apt-get install -y -qq redis-server

# Install wkhtmltopdf
echo -e "${YELLOW}Installing wkhtmltopdf...${NC}"
apt-get install -y -qq xfonts-75dpi xfonts-base libxrender1
wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.${OS_NAME}${OS_VERSION}_amd64.deb
apt-get install -y -qq ./wkhtmltox_0.12.6-1.${OS_NAME}${OS_VERSION}_amd64.deb
rm wkhtmltox_0.12.6-1.${OS_NAME}${OS_VERSION}_amd64.deb

# Install MariaDB
echo -e "${YELLOW}Installing MariaDB...${NC}"
apt-get install -y -qq mariadb-server mariadb-client

# Secure MariaDB installation
echo -e "${YELLOW}Securing MariaDB...${NC}"
sql_root_password=$(ask_twice "Enter a password for the MariaDB root user")
mysql -e "UPDATE mysql.user SET Password=PASSWORD('$sql_root_password') WHERE User='root'"
mysql -e "DELETE FROM mysql.user WHERE User=''"
mysql -e "DROP DATABASE IF EXISTS test"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -e "FLUSH PRIVILEGES"

# Configure MariaDB for Frappe
echo -e "${YELLOW}Configuring MariaDB for Frappe...${NC}"
cat <<EOF > /etc/mysql/conf.d/frappe.cnf
[mysqld]
innodb-file-format=barracuda
innodb-file-per-table=1
innodb-large-prefix=1
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

systemctl restart mariadb

# Install NVM and Node.js
echo -e "${YELLOW}Installing Node.js via NVM...${NC}"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

if [ "$bench_version" == "version-15" ]; then
    nvm install 18
    nvm alias default 18
else
    nvm install 16
    nvm alias default 16
fi

# Install yarn
echo -e "${YELLOW}Installing yarn...${NC}"
npm install -g yarn

# Install Bench
echo -e "${YELLOW}Installing Frappe Bench...${NC}"
pip3 install frappe-bench

# Initialize Bench
echo -e "${YELLOW}Initializing Bench...${NC}"
mkdir -p /opt/bench
cd /opt/bench
bench init --frappe-branch $bench_version frappe-bench

# Create new site
cd frappe-bench
site_name=""
while [ -z "$site_name" ]; do
    read -rp "Enter the site name (FQDN recommended): " site_name
done

admin_password=$(ask_twice "Enter the Administrator password")

echo -e "${YELLOW}Creating new site...${NC}"
bench new-site $site_name --admin-password "$admin_password" --mariadb-root-password "$sql_root_password" --no-mariadb-socket

# Install ERPNext
echo -e "${YELLOW}Installing ERPNext...${NC}"
bench get-app erpnext --branch $bench_version
bench --site $site_name install-app erpnext

# Setup production environment
echo -e "${YELLOW}Setting up production environment...${NC}"
bench setup production --yes

# Enable scheduler
bench --site $site_name enable-scheduler

# Optionally install HRMS
read -rp "Would you like to install HRMS? (yes/no): " install_hrms
if [[ "$install_hrms" =~ ^[Yy] ]]; then
    echo -e "${YELLOW}Installing HRMS...${NC}"
    bench get-app hrms --branch $bench_version
    bench --site $site_name install-app hrms
fi

# Optionally setup SSL
read -rp "Would you like to setup SSL? (yes/no): " setup_ssl
if [[ "$setup_ssl" =~ ^[Yy] ]]; then
    read -rp "Enter your email address for SSL certificate: " email_address
    apt-get install -y -qq certbot
    bench setup lets-encrypt $site_name --email $email_address
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "You can access your ERPNext site at: http://$site_name or http://<server-ip>"

