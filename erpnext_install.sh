#!/usr/bin/env bash

set -e

# Setting up colors for echo commands
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Detect the platform (similar to $OSTYPE)
OS="`uname`"
case $OS in
  'Linux')
    OS='Linux'
    if [ -f /etc/redhat-release ] ; then
      DISTRO='CentOS'
    elif [ -f /etc/debian_version ] ; then
      if [ "$(lsb_release -si)" == "Ubuntu" ]; then
        DISTRO='Ubuntu'
      else
        DISTRO='Debian'
      fi
    fi
    ;;
  *) ;;
esac


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
echo -e "${LIGHT_BLUE}Welcome to the ERPNext Installer...${NC}"
sleep 2

#First Let's take you home
cd $(sudo -u $USER echo $HOME)

#Next let's set some important parameters.
#We will need your required SQL root passwords
echo -e "${YELLOW}First let's set some important parameters...${NC}"
sleep 1
echo -e "${YELLOW}We will need your required SQL root password${NC}"
sleep 1
sqlpasswrd=$(ask_twice "What is your required SQL root password" "true")
sleep 1
echo -e "\n"

#Now let's make sure your instance has the most updated packages
echo -e "${YELLOW}Updating system packages...${NC}"
sleep 2
sudo apt update
sudo apt upgrade -y
echo -e "${GREEN}System packages updated.${NC}"
sleep 2

#Now let's install a couple of requirements: git, curl and pip
echo -e "${YELLOW}Installing preliminary package requirements${NC}"
sleep 3
sudo apt -qq install software-properties-common git curl -y

#Next we'll install the python environment manager...
echo -e "${YELLOW}Installing python environment manager and other requirements...${NC}"
sleep 2

# Install Python 3.10 if not already installed or version is less than 3.10
py_version=$(python3 --version 2>&1 | awk '{print $2}')
py_major=$(echo "$py_version" | cut -d '.' -f 1)
py_minor=$(echo "$py_version" | cut -d '.' -f 2)

if [ -z "$py_version" ] || [ "$py_major" -lt 3 ] || [ "$py_major" -eq 3 -a "$py_minor" -lt 10 ]; then
    echo -e "${LIGHT_BLUE}It appears this instance does not meet the minimum Python version required for ERPNext 14 (Python3.10)... Not to worry, we will sort it out for you${NC}"
    sleep 3
    echo -e "${YELLOW}Installing Python 3.10+...${NC}"
    sleep 2

    sudo apt -qq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev -y && \
    wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz && \
    tar -xf Python-3.10.11.tgz && \
    cd Python-3.10.11 && \
    ./configure --prefix=/usr/local --enable-optimizations --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" && \
    make -j $(nproc) && \
    sudo make altinstall && \
    cd .. && \
    sudo rm -rf Python-3.10.11 && \
    sudo rm Python-3.10.11.tgz && \
    pip3.10 install --user --upgrade pip && \
    echo -e "${GREEN}Python3.10 installation successful!${NC}"
    sleep 2
fi
echo -e "${YELLOW}Installing additional Python packages and Redis Server${NC}"
sleep 2
sudo apt -qq install git python3-dev python3-setuptools python3-venv python3-pip python3-distutils redis-server -y
echo -e "${GREEN}Done!${NC}"
#... And mariadb with some extra needed applications.
echo -e "${YELLOW}Now installing MariaDB and other necessary packages...${NC}"
sleep 2
sudo apt -qq install mariadb-server mariadb-client xvfb libfontconfig xfonts-75dpi fontconfig libxrender1 -y
echo -e "${GREEN}MariaDB and other packages have been installed successfully.${NC}"
sleep 2

#Now we'll go through the required settings of the mysql_secure_installation...
echo -e ${YELLOW}"Now we'll go ahead to apply MariaDB security settings...${NC}"
sleep 2

sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
sudo mysql -u root -p$sqlpasswrd -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
sudo mysql -u root -p"$sqlpasswrd" -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -u root -p"$sqlpasswrd" -e "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -u root -p"$sqlpasswrd" -e "FLUSH PRIVILEGES;"

echo -e "${YELLOW}...And add some settings to /etc/mysql/my.cnf:${NC}"
sleep 2

sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF'

sudo service mysql restart

echo -e "${GREEN}MariaDB settings done!${NC}"

#Install NVM, Node, npm and yarn
echo -e ${YELLOW}"Now to install NVM, Node, npm and yarn${NC}"
sleep 1
echo -e "${RED}NOTE:${NC} ${LIGHT_BLUE}The NVM environment variables set is for this session only. Please restart your terminal after installation is complete to use Node.${NC}"
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

# Add environment variables to .profile
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.profile
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.profile
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.profile

# Source .profile to load the new environment variables in the current session
source ~/.profile

nvm install 16

sudo apt-get -qq install npm -y
sudo npm install -g yarn
echo -e "${GREEN}Package installation complete!${NC}"
sleep 2

# Now let's reactivate virtual environment
if [ "$DISTRO" == "Debian" ]; then
    python3.10 -m venv $USER && \
    source $USER/bin/activate
    nvm use 16
fi

#Install bench
echo -e "${YELLOW}Now let's install bench${NC}"
sleep 2
sudo pip3 install frappe-bench

#Initiate bench in frappe-bench folder, but get a supervisor can't restart bench error...
echo -e "${YELLOW}Initialising bench in frappe-bench folder.${NC}" 
echo -e "${LIGHT_BLUE}If you get a restart failed, don't worry, we will resolve that later.${NC}"
bench init frappe-bench --version version-14 --verbose --install-app erpnext --version version-14
echo -e "${GREEN}Bench installation complete!${NC}"
sleep 1

# Prompt user for site name
echo -e "${YELLOW}Preparing for Production installation. This could take a minute... or two so please be patient.${NC}"
read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN): " site_name
sleep 1
adminpasswrd=$(ask_twice "Enter the Administrator password" "true")
echo -e "\n"
sleep 2
# Install expect tool only if needed
echo $passwrd | sudo -S apt -qq install expect -y

echo -e "${YELLOW}Now setting up your site. Please wait...${NC}"
sleep 1
# Change directory to frappe-bench
cd frappe-bench && \

# Create new site using expect
export SITE_NAME=$site_name
export SQL_PASSWD=$sqlpasswrd
export ADMIN_PASSWD=$adminpasswrd

#Set Administrator password.
SECURE_MYSQL=$(expect -c "
set timeout 300
set sitename \$env(SITE_NAME)
set sqlpwd \$env(SQL_PASSWD)
set adminpwd \$env(ADMIN_PASSWD)
spawn bench new-site \$sitename --install-app erpnext
expect \"MySQL root password:\"
send \"\$sqlpwd\r\"
expect \"Set Administrator password:\"
sleep 20
send \"\$adminpwd\r\"
expect \"Re-enter Administrator password:\"
sleep 20
send \"\$adminpwd\r\"
expect eof
")
echo "$SECURE_MYSQL"

echo -e "${YELLOW}Installing packages and dependencies for Production...${NC}"
sleep 2
# Setup supervisor and nginx config
yes | sudo bench setup production $USER && \
echo -e "${YELLOW}Applying necessary permissions to supervisor...${NC}"
sleep 1
# Change ownership of supervisord.conf
sudo sed -i '6i chown='"$USER"':'"$USER"'' /etc/supervisor/supervisord.conf && \

# Restart supervisor
sudo service supervisor restart && \

# Setup production again to reflect the new site
yes | sudo bench setup production $USER && \

echo -e "${YELLOW}Enabling Scheduler...${NC}"
sleep 1
# Enable and resume the scheduler for the site
bench --site $site_name scheduler enable && \
bench --site $site_name scheduler resume && \

echo -e "${YELLOW}Restarting bench to apply all changes and optimizing environment pernissions.${NC}"
sleep 1

# Restart bench
bench restart && \

#Now to make sure the environment is fully setup
sudo chmod 755 /home/$(echo $USER)
sleep 3
printf "${GREEN}Production setup complete! "
printf '\xF0\x9F\x8E\x86'
printf "${NC}\n"
sleep 3

echo -e "${YELLOW}Would you like to install SSL? (yes/no)${NC}"

read -p "Response: " continue_ssl

continue_ssl=$(echo "$continue_ssl" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

case "$continue_ssl" in
    "yes" | "y")
        echo -e "${YELLOW}Make sure your domain name is pointed to the IP of this instance and is reachable before your proceed.${NC}"
        sleep 3
        # Prompt user for email
        read -p "Enter your email address: " email_address

        # Install Certbot
        echo -e "${YELLOW}Installing Certbot...${NC}"
        sleep 1
        sudo apt -qq install certbot python3-certbot-nginx -y

        # Obtain and Install the certificate
        echo -e "${YELLOW}Obtaining and installing SSL certificate...${NC}"
        sleep 2
        sudo certbot --nginx --non-interactive --agree-tos --email $email_address -d $site_name
        echo -e "${GREEN}SSL certificate installed successfully.${NC}"
        sleep 2
        ;;
    *)
        echo -e "${RED}Skipping SSL installation...${NC}"
        sleep 3
        ;;
esac

# Now let's reactivate virtual environment
if [ "$DISTRO" == "Debian" ]; then
    deactivate
fi

echo -e "${GREEN}--------------------------------------------------------------------------------"
echo -e "Congratulations! You have successfully installed ERPNext version 14."
echo -e "You can start using your new ERPNext installation by visiting:"
echo -e "https://$site_name (if you have enabled SSL and used a Fully Qualified Domain Name"
echo -e "during installation)"
echo -e "or"
echo -e "http://your_server_ip_address"
echo -e "Replace 'your_server_ip_address' with the actual IP address of your server."
echo -e "Remember to configure your ERPNext instance with the necessary information."
echo -e "Enjoy using ERPNext!"
echo -e "--------------------------------------------------------------------------------${NC}"