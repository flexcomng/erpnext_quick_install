#!/bin/bash

# Get the directory where this script is located
# Helps if you run the script from abnormal location like frappe-bench
helper_scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
erpnext_quick_install="$(dirname "$helper_scripts")"

d="${helper_scripts}"
while [[ "$d" != "/" ]]; do
    if [[ -f "$d/.env" ]]; then
        source "$d/.env"
        break
    fi
    if [[ "$d" == "$erpnext_quick_install" ]]; then
        break
    fi
    d="$(dirname "$d")"
done

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Prompt for site name
if [ -n "$SITE_NAME" ]; then
    site_name="$SITE_NAME"
    echo -e "${YELLOW}Site name set from .env: $site_name${NC}"
else
    read -p "Enter the site name (FQDN): " site_name
fi

# Prompt for email address
if [ -n "$EMAIL_ADDRESS" ]; then
    email_address="$EMAIL_ADDRESS"
    echo -e "${YELLOW}Email address set from .env: $email_address${NC}"
else
    read -p "Enter your email address: " email_address
fi

# Install Certbot if not present
if ! command -v certbot >/dev/null 2>&1; then
    echo -e "${YELLOW}Certbot not found. Installing certbot...${NC}"
    sudo apt install snapd -y
    sudo snap install core
    sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi

# Run certbot
if ! sudo certbot --nginx --non-interactive --agree-tos --email "$email_address" -d "$site_name"; then
    echo -e "${RED}SSL certificate installation failed. Please check your DNS and try again.${NC}"
    exit 1
else
    echo -e "${GREEN}SSL certificate installed successfully!${NC}"
fi 