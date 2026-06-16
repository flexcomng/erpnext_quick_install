#!/bin/bash

##############################################################################################


DB_PASSWRD=$(openssl rand -base64 10)

# Update package lists
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y nano htop git wget curl build-essential software-properties-common

# Enable UFW firewall
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload


sudo add-apt-repository ppa:deadsnakes/ppa -y    
sudo apt update

# Install Python and development libraries
sudo apt install -y python3.14 python3.14-venv python3-setuptools python3-pip python3.14-distutils python3-dev
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.14

python3 --version
pip3.14 --version

sudo apt install -y libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev libjpeg-dev libcups2-dev libpq-dev libtiff5-dev libmysqlclient-dev pkg-config

# Install other dependencies
sudo apt install -y xvfb libfontconfig wkhtmltopdf nginx supervisor

# Add MariaDB repository
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.6

# Install MariaDB
sudo apt update
sudo apt install -y mariadb-server mariadb-client

# Start and enable the service
sudo systemctl start mariadb
sudo systemctl enable MariaDB

# Create ERPNext database
sudo mysql -u root -p -e "CREATE DATABASE erpnext_db;"
sudo mysql -u root -p -e "CREATE USER 'erpnext'@'localhost' IDENTIFIED BY '$DB_PASSWRD';"
sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON erpnext_db.* TO 'erpnext'@'localhost';"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

# Verify installation
mariadb --version

# Secure Your Database
sudo mariadb-secure-installation

# Install Redis
sudo apt install -y redis-server

# Start and enable
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test it's working
redis-cli ping  # Should return: PONG

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs npm 

# Verify
node --version    
npm --version

# Install Yarn
npm install -g yarn
yarn --version

# Create the frappe user
sudo useradd -m -s /bin/bash frappe

# Add to sudo group
sudo usermod -aG sudo frappe

# Switch to frappe user
sudo su - frappe
cd /home/frappe

# Install Bench CLI
sudo pip3 install frappe-bench

# Verify installation
bench --version

# Navigate to home directory
cd /home/frappe

# Initialize Frappe bench
bench init erpnext-bench --frappe-branch v16

# Navigate to bench directory
cd frappe-bench

# Install Node.js dependencies
npm install

# Set up bench configuration
bench config dns_multitenant on

# Set proper permissions
chmod -R o+rx /home/frappe

# Download ERPNext apps
bench get-app erpnext --branch v16

# Create new site
bench new-site your-domain.com --db-name erpnext_db --db-password $DB_PASSWRD

# Install ERPNext application
bench --site your-domain.com install-app erpnext

bench get-app --branch version-16 hrms
bench --site your-domain.com install-app hrms

bench get-app --branch develop payments
bench --site your-domain.com install-app payments

bench get-app https://github.com/erpchampions/uganda_compliance.git
bench --site your-domain.com install-app uganda_compliance

# Install Caddy or Nginx
sudo apt install -y nginx

# Enable and start services
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Configure supervisor
sudo apt install -y supervisor
sudo systemctl enable supervisor
sudo systemctl start supervisor

# Set up systemd service for bench
sudo tee /etc/systemd/system/frappe-bench.service > /dev/null <<EOF
[Unit]
Description=Frappe Bench
After=network.target

[Service]
Type=forking
User=frappe
Group=frappe
ExecStart=/home/frappe/erpnext-bench/bench start
ExecStop=/home/frappe/erpnext-bench/bench stop
WorkingDirectory=/home/frappe/erpnext-bench
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Frappe service
sudo systemctl enable frappe-bench
sudo systemctl start frappe-bench

# Create Nginx configuration for your site
sudo tee /etc/nginx/sites-available/erpnext > /dev/null <<EOF
upstream erpnext {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://erpnext;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }

    location /assets/ {
        proxy_pass http://erpnext;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/erpnext /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal setup
sudo crontab -e
# Add this line:
0 12 * * * /usr/bin/certbot renew --quiet


# Set up automatic backups
bench config backup --set-to-frappe --with-files --backup-frequency=Daily

# Manual backup
bench backup --with-files

# Enable background worker
bench setup supervisor --supervisor-port 9001

# Configure background jobs
bench --site your-domain.com set-config background_workers 1

# Optimize MariaDB
sudo mysql_secure_installation
sudo mysql_tuner

# Restart all services
bench restart

echo "####################################################"
echo " database username: root"
echo " database password: $DB_PASSWRD"
echo " ERPNext username: admin"
echo " ERPNext password: $ADMIN_PASSWRD"
echo "####################################################"









