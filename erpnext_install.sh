#!/usr/bin/env bash

handle_error() {
    local line=$1
    local exit_code=$?
    echo "An error occurred on line $line with exit status $exit_code"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR
set -e

server_ip=$(hostname -I | awk '{print $1}')

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' 

SUPPORTED_DISTRIBUTIONS=("Ubuntu" "Debian")
SUPPORTED_VERSIONS=("24.04" "23.04" "22.04" "20.04" "12" "11" "10" "9" "8")

check_os() {
    local os_name=$(lsb_release -is)
    local os_version=$(lsb_release -rs)
    local os_supported=false
    local version_supported=false

    for i in "${SUPPORTED_DISTRIBUTIONS[@]}"; do
        if [[ "$i" = "$os_name" ]]; then
            os_supported=true
            break
        fi
    done

    for i in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$i" = "$os_version" ]]; then
            version_supported=true
            break
        fi
    done

    if [[ "$os_supported" = false ]] || [[ "$version_supported" = false ]]; then
        echo -e "${RED}This script is not compatible with your operating system or its version.${NC}"
        exit 1
    fi
}

check_os

OS="$(uname)"
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
            printf "${GREEN}Password confirmed${NC}\n" >&2
            echo "$val1"
            break
        else
            printf "${RED}Inputs do not match. Please try again${NC}\n" >&2
            echo -e "\n"
        fi
    done
}

extract_app_name_from_setup() {
    local setup_file="$1"
    local app_name=""
    
    if [[ -f "$setup_file" ]]; then
        app_name=$(grep -oE 'name\s*=\s*["\047][^"\047]+["\047]' "$setup_file" 2>/dev/null | head -1 | sed -E 's/.*name\s*=\s*["\047]([^"\047]+)["\047].*/\1/')
        
        if [[ -z "$app_name" ]]; then
            app_name=$(grep -oE 'name\s*=\s*["\047][^"\047]*["\047]' "$setup_file" 2>/dev/null | head -1 | sed -E 's/.*["\047]([^"\047]+)["\047].*/\1/')
        fi
        
        if [[ -z "$app_name" ]]; then
            app_name=$(awk '/setup\s*\(/,/\)/ { if (/name\s*=/) { gsub(/.*name\s*=\s*["\047]/, ""); gsub(/["\047].*/, ""); print; exit } }' "$setup_file" 2>/dev/null | head -1 | tr -d ' \t')
        fi
        
        if [[ -z "$app_name" ]]; then
            app_name=$(grep "name.*=" "$setup_file" 2>/dev/null | head -1 | sed -E 's/.*["\047]([^"\047]+)["\047].*/\1/' | tr -d ' \t')
        fi
        
        if [[ -z "$app_name" ]]; then
            local app_base_dir=$(dirname "$setup_file")
            for subdir in "$app_base_dir"/*/; do
                if [[ -d "$subdir" && -f "$subdir/__init__.py" ]]; then
                    local module_dir=$(basename "$subdir")
                    if [[ -n "$module_dir" && "$module_dir" != "." && "$module_dir" != "tests" && "$module_dir" != "docs" ]]; then
                        app_name="$module_dir"
                        break
                    fi
                fi
            done
        fi
    fi
    
    echo "$app_name"
}

check_existing_installations() {
    local existing_installations=()
    local installation_paths=()
    
    local search_paths=(
        "$HOME/frappe-bench"
        "/home/*/frappe-bench"
        "/opt/frappe-bench"
        "/var/www/frappe-bench"
    )
    
    echo -e "${YELLOW}Checking for existing ERPNext installations...${NC}"
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]] && [[ -f "$path/apps/frappe/frappe/__init__.py" ]]; then
            local version_info=""
            if [[ -f "$path/apps/frappe/frappe/__version__.py" ]]; then
                version_info=$(grep -o 'version.*=.*[0-9]' "$path/apps/frappe/frappe/__version__.py" 2>/dev/null || echo "unknown")
            fi
            
            local branch_info=""
            if [[ -d "$path/apps/frappe/.git" ]]; then
                branch_info=$(cd "$path/apps/frappe" && git branch --show-current 2>/dev/null || echo "unknown")
            fi
            
            existing_installations+=("$path")
            installation_paths+=("Path: $path | Version: $version_info | Branch: $branch_info")
        fi
    done
    
    if [[ ${#existing_installations[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}⚠️  EXISTING ERPNEXT INSTALLATION(S) DETECTED ⚠️${NC}"
        echo ""
        echo -e "${YELLOW}Found the following ERPNext installation(s):${NC}"
        for info in "${installation_paths[@]}"; do
            echo -e "${LIGHT_BLUE}• $info${NC}"
        done
        echo ""
        echo -e "${RED}WARNING: Installing different ERPNext versions on the same server can cause:${NC}"
        echo -e "${YELLOW}• Port conflicts (Redis, Node.js services)${NC}"
        echo -e "${YELLOW}• Dependency version conflicts${NC}"
        echo -e "${YELLOW}• Supervisor configuration conflicts${NC}"
        echo -e "${YELLOW}• Database schema incompatibilities${NC}"
        echo -e "${YELLOW}• System instability${NC}"
        echo ""
        echo -e "${LIGHT_BLUE}Recommended actions:${NC}"
        echo -e "${GREEN}1. Use the existing installation if it meets your needs${NC}"
        echo -e "${GREEN}2. Backup and remove existing installation before installing new version${NC}"
        echo -e "${GREEN}3. Use a fresh server/container for the new installation${NC}"
        echo -e "${GREEN}4. Use different users/paths if you must have multiple versions${NC}"
        echo ""
        
        read -p "Do you want to continue anyway? (yes/no): " conflict_confirm
        conflict_confirm=$(echo "$conflict_confirm" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$conflict_confirm" != "yes" && "$conflict_confirm" != "y" ]]; then
            echo -e "${GREEN}Installation cancelled. Good choice for system stability!${NC}"
            exit 0
        else
            echo -e "${YELLOW}Proceeding with installation despite existing installations...${NC}"
            echo -e "${RED}You've been warned about potential conflicts!${NC}"
        fi
    else
        echo -e "${GREEN}✓ No existing ERPNext installations found.${NC}"
    fi
}
detect_best_branch() {
    local repo_url="$1"
    local preferred_version="$2"
    
    local branches=$(git ls-remote --heads "$repo_url" 2>/dev/null | awk '{print $2}' | sed 's|refs/heads/||' | sort -V)
    
    if [[ -z "$branches" ]]; then
        echo ""
        return 1
    fi
    
    local branch_priorities=()
    
    case "$preferred_version" in
        "version-15"|"develop")
            branch_priorities=("version-15" "develop" "main" "master" "version-14" "version-13")
            ;;
        "version-14")
            branch_priorities=("version-14" "main" "master" "develop" "version-15" "version-13")
            ;;
        "version-13")
            branch_priorities=("version-13" "main" "master" "version-14" "develop" "version-15")
            ;;
        *)
            branch_priorities=("main" "master" "develop")
            ;;
    esac
    
    for priority_branch in "${branch_priorities[@]}"; do
        if echo "$branches" | grep -q "^$priority_branch$"; then
            echo "$priority_branch"
            return 0
        fi
    done
    
    echo "$branches" | head -1
    return 0
}

echo -e "${LIGHT_BLUE}Welcome to the ERPNext Installer...${NC}"
echo -e "\n"
sleep 3

echo -e "${YELLOW}Please enter the number of the corresponding ERPNext version you wish to install:${NC}"

versions=("Version 13" "Version 14" "Version 15" "Develop")
select version_choice in "${versions[@]}"; do
    case $REPLY in
        1) bench_version="version-13"; break;;
        2) bench_version="version-14"; break;;
        3) bench_version="version-15"; break;;
        4) bench_version="develop"; 
           echo ""
           echo -e "${RED}⚠️  WARNING: DEVELOP VERSION ⚠️${NC}"
           echo ""
           echo -e "${YELLOW}The develop branch contains bleeding-edge code that:${NC}"
           echo -e "${RED}• Changes daily and may be unstable${NC}"
           echo -e "${RED}• Can cause data corruption or system crashes${NC}"
           echo -e "${RED}• Is NOT suitable for production or important data${NC}"
           echo -e "${RED}• Has limited community support${NC}"
           echo ""
           echo -e "${GREEN}Recommended for: Experienced developers testing new features${NC}"
           echo -e "${GREEN}Better alternatives: Version 15 (stable) or Version 14 (proven)${NC}"
           echo ""
           read -p "Do you understand the risks and want to continue? (yes/no): " develop_confirm
           develop_confirm=$(echo "$develop_confirm" | tr '[:upper:]' '[:lower:]')
           
           if [[ "$develop_confirm" != "yes" && "$develop_confirm" != "y" ]]; then
               echo -e "${GREEN}Good choice! Please select a stable version.${NC}"
               continue
           else
               echo -e "${YELLOW}Proceeding with develop branch installation...${NC}"
           fi
           break;;
        *) echo -e "${RED}Invalid option. Please select a valid version.${NC}";;
    esac
done

echo -e "${GREEN}You have selected $version_choice for installation.${NC}"
echo -e "${LIGHT_BLUE}Do you wish to continue? (yes/no)${NC}"
read -p "Response: " continue_install
continue_install=$(echo "$continue_install" | tr '[:upper:]' '[:lower:]')

while [[ "$continue_install" != "yes" && "$continue_install" != "y" && "$continue_install" != "no" && "$continue_install" != "n" ]]; do
    echo -e "${RED}Invalid response. Please answer with 'yes' or 'no'.${NC}"
    echo -e "${LIGHT_BLUE}Do you wish to continue with the installation of $version_choice? (yes/no)${NC}"
    read -p "Response: " continue_install
    continue_install=$(echo "$continue_install" | tr '[:upper:]' '[:lower:]')
done

if [[ "$continue_install" == "no" || "$continue_install" == "n" ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 0
else
    echo -e "${GREEN}Proceeding with the installation of $version_choice.${NC}"
fi
sleep 2

check_existing_installations

#
# ─── OS COMPATIBILITY FOR VERSION-15 OR DEVELOP ────────────────────────────────────────
#
if [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
    if [[ "$(lsb_release -si)" != "Ubuntu" && "$(lsb_release -si)" != "Debian" ]]; then
        echo -e "${RED}Your Distro is not supported for Version 15/Develop.${NC}"
        exit 1
    elif [[ "$(lsb_release -si)" == "Ubuntu" && "$(lsb_release -rs)" < "22.04" ]]; then
        echo -e "${RED}Your Ubuntu version is below the minimum required to support Version 15/Develop.${NC}"
        exit 1
    elif [[ "$(lsb_release -si)" == "Debian" && "$(lsb_release -rs)" < "12" ]]; then
        echo -e "${RED}Your Debian version is below the minimum required to support Version 15/Develop.${NC}"
        exit 1
    fi
fi

#
# ─── OS COMPATIBILITY FOR OLDER VERSIONS (version-13, version-14) ───────────────────────
#
if [[ "$bench_version" != "version-15" && "$bench_version" != "develop" ]]; then
    if [[ "$(lsb_release -si)" != "Ubuntu" && "$(lsb_release -si)" != "Debian" ]]; then
        echo -e "${RED}Your Distro is not supported for $version_choice.${NC}"
        exit 1
    elif [[ "$(lsb_release -si)" == "Ubuntu" && "$(lsb_release -rs)" > "22.04" ]]; then
        echo -e "${RED}Your Ubuntu version is not supported for $version_choice.${NC}"
        echo -e "${YELLOW}ERPNext v13/v14 only support Ubuntu up to 22.04. Please use ERPNext v15 for Ubuntu 24.04.${NC}"
        exit 1
    elif [[ "$(lsb_release -si)" == "Debian" && "$(lsb_release -rs)" > "11" ]]; then
        echo -e "${YELLOW}Warning: Your Debian version is above the tested range for $version_choice, but we'll continue.${NC}"
        sleep 2
    fi
fi

check_os

cd "$(sudo -u $USER echo $HOME)"

#
# ─── SQL ROOT PASSWORD PROMPT ─────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Now let's set some important parameters...${NC}"
sleep 1
echo -e "${YELLOW}We will need your required SQL root password${NC}"
sleep 1
sqlpasswrd=$(ask_twice "What is your required SQL root password" "true")
echo -e "\n"
sleep 1

#
# ─── SYSTEM PACKAGE UPDATES ────────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Updating system packages...${NC}"
sleep 2
sudo apt update
sudo apt upgrade -y
echo -e "${GREEN}System packages updated.${NC}"
sleep 2

#
# ─── PRELIMINARY PACKAGE INSTALL ──────────────────────────────────────────────────────
#
echo -e "${YELLOW}Installing preliminary package requirements${NC}"
sleep 3
sudo apt install software-properties-common git curl whiptail -y

#
# ─── PYTHON AND REDIS INSTALL ───────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Installing python environment manager and other requirements...${NC}"
sleep 2

py_version=$(python3 --version 2>&1 | awk '{print $2}')
py_major=$(echo "$py_version" | cut -d '.' -f 1)
py_minor=$(echo "$py_version" | cut -d '.' -f 2)

if [[ -z "$py_version" ]] || [[ "$py_major" -lt 3 ]] || [[ "$py_major" -eq 3 && "$py_minor" -lt 10 ]]; then
    echo -e "${LIGHT_BLUE}It appears this instance does not meet the minimum Python version required for ERPNext 14 (Python3.10)...${NC}"
    sleep 2 
    echo -e "${YELLOW}Not to worry, we will sort it out for you${NC}"
    sleep 4
    echo -e "${YELLOW}Installing Python 3.10+...${NC}"
    sleep 2

    sudo apt -qq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
        libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev -y && \
    wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz && \
    tar -xf Python-3.10.11.tgz && \
    cd Python-3.10.11 && \
    ./configure --prefix=/usr/local --enable-optimizations --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" && \
    make -j "$(nproc)" && \
    sudo make altinstall && \
    cd .. && \
    sudo rm -rf Python-3.10.11 && \
    sudo rm Python-3.10.11.tgz && \
    pip3.10 install --user --upgrade pip && \
    echo -e "${GREEN}Python3.10 installation successful!${NC}"
    sleep 2
fi

echo -e "\n"
echo -e "${YELLOW}Installing additional Python packages and Redis Server${NC}"
sleep 2
sudo apt install git python3-dev python3-setuptools python3-venv python3-pip redis-server -y

#
# ─── WKHTMLTOPDF INSTALL ───────────────────────────────────────────────────────────────
#
arch=$(uname -m)
case $arch in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) echo -e "${RED}Unsupported architecture: $arch${NC}"; exit 1 ;;
esac

sudo apt install fontconfig libxrender1 xfonts-75dpi xfonts-base -y

wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_"$arch".deb && \
sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_"$arch".deb || true && \
sudo cp /usr/local/bin/wkhtmlto* /usr/bin/ && \
sudo chmod a+x /usr/bin/wk* && \
sudo rm wkhtmltox_0.12.6.1-2.jammy_"$arch".deb && \
sudo apt --fix-broken install -y && \
sudo apt install fontconfig xvfb libfontconfig xfonts-base xfonts-75dpi libxrender1 -y

echo -e "${GREEN}Done!${NC}"
sleep 1
echo -e "\n"

#
# ─── MARIADB + DEV LIBRARIES + PKG-CONFIG ─────────────────────────────────────────────
#
echo -e "${YELLOW}Now installing MariaDB and other necessary packages...${NC}"
sleep 2
sudo apt install mariadb-server mariadb-client -y

echo -e "${YELLOW}Installing MySQL/MariaDB development libraries and pkg-config...${NC}"
sleep 1
sudo apt install pkg-config default-libmysqlclient-dev -y

echo -e "${GREEN}MariaDB and development packages have been installed successfully.${NC}"
sleep 2

MARKER_FILE=~/.mysql_configured.marker
if [ ! -f "$MARKER_FILE" ]; then
    echo -e "${YELLOW}Now we'll go ahead to apply MariaDB security settings...${NC}"
    sleep 2

    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
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

    touch "$MARKER_FILE"
    echo -e "${GREEN}MariaDB settings done!${NC}"
    echo -e "\n"
    sleep 1
fi

#
# ─── NVM / NODE / YARN INSTALL ─────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Now to install NVM, Node, npm and yarn${NC}"
sleep 2

curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

nvm_init='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

grep -qxF 'export NVM_DIR="$HOME/.nvm"' ~/.profile 2>/dev/null || echo "$nvm_init" >> ~/.profile
grep -qxF 'export NVM_DIR="$HOME/.nvm"' ~/.bashrc 2>/dev/null || echo "$nvm_init" >> ~/.bashrc

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"


os_version=$(lsb_release -rs)
if [[ "$DISTRO" == "Ubuntu" && "$os_version" == "24.04" ]]; then
    nvm install 20
    nvm alias default 20
    node_version="20"
elif [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
    nvm install 18
    nvm alias default 18
    node_version="18"
else
    nvm install 16
    nvm alias default 16
    node_version="16"
fi

npm install -g yarn@1.22.19

echo -e "${GREEN}nvm and Node (v${node_version}) have been installed and aliased as default.${NC}"
echo -e "${GREEN}Yarn v$(yarn --version) (Classic) installed globally.${NC}"
sleep 2

if [[ -z "$py_version" ]] || [[ "$py_major" -lt 3 ]] || [[ "$py_major" -eq 3 && "$py_minor" -lt 10 ]]; then
    python3.10 -m venv "$USER"
    source "$USER/bin/activate"
    nvm use default
fi

#
# ─── BENCH INSTALL ───────────────────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Now let's install bench${NC}"
sleep 2

externally_managed_file=$(find /usr/lib/python3.*/EXTERNALLY-MANAGED 2>/dev/null || true)
if [[ -n "$externally_managed_file" ]]; then
    sudo python3 -m pip config --global set global.break-system-packages true
fi

sudo apt install python3-pip -y
sudo pip3 install frappe-bench

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use default

echo -e "${YELLOW}Initialising bench in frappe-bench folder.${NC}"
echo -e "${LIGHT_BLUE}If you get a restart failed, don't worry, we will resolve that later.${NC}"
bench init frappe-bench --version "$bench_version" --verbose
echo -e "${GREEN}Bench installation complete!${NC}"
sleep 1

#
# ─── NEW SITE CREATION ─────────────────────────────────────────────────────────────────
#
echo -e "${YELLOW}Preparing for Production installation. This could take a minute... or two so please be patient.${NC}"
read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN): " site_name
sleep 1
adminpasswrd=$(ask_twice "Enter the Administrator password" "true")
echo -e "\n"
sleep 2
echo -e "${YELLOW}Now setting up your site. This might take a few minutes. Please wait...${NC}"
sleep 1

cd frappe-bench && \
sudo chmod -R o+rx "$(echo $HOME)"

bench new-site "$site_name" \
  --db-root-username root \
  --db-root-password "$sqlpasswrd" \
  --admin-password "$adminpasswrd"

if [[ "$bench_version" == "develop" ]]; then
    echo -e "${YELLOW}Starting Redis instances for develop branch (queue, cache, and socketio)...${NC}"
    sleep 1
    redis-server --port 11000 --daemonize yes --bind 127.0.0.1
    redis-server --port 12000 --daemonize yes --bind 127.0.0.1
    redis-server --port 13000 --daemonize yes --bind 127.0.0.1
    echo -e "${GREEN}Redis instances started for develop branch.${NC}"
    sleep 1
fi

echo -e "${LIGHT_BLUE}Would you like to install ERPNext? (yes/no)${NC}"
read -p "Response: " erpnext_install
erpnext_install=$(echo "$erpnext_install" | tr '[:upper:]' '[:lower:]')

case "$erpnext_install" in
    "yes"|"y")
    sleep 2
    bench get-app erpnext --branch "$bench_version" && \
    bench --site "$site_name" install-app erpnext
    sleep 1
    ;;
esac

python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
playbook_file="/usr/local/lib/python${python_version}/dist-packages/bench/playbooks/roles/mariadb/tasks/main.yml"
sudo sed -i 's/- include: /- include_tasks: /g' "$playbook_file"

echo -e "${LIGHT_BLUE}Would you like to continue with production install? (yes/no)${NC}"
read -p "Response: " continue_prod
continue_prod=$(echo "$continue_prod" | tr '[:upper:]' '[:lower:]')

case "$continue_prod" in
    "yes"|"y")
        echo -e "${YELLOW}Installing packages and dependencies for Production...${NC}"
        sleep 2

        yes | sudo bench setup production "$USER" && \
        echo -e "${YELLOW}Applying necessary permissions to supervisor...${NC}"
        sleep 1

        FILE="/etc/supervisor/supervisord.conf"
        SEARCH_PATTERN="chown=$USER:$USER"

        if grep -q "$SEARCH_PATTERN" "$FILE"; then
            echo -e "${YELLOW}User ownership already exists for supervisord. Updating it...${NC}"
            sudo sed -i "/chown=.*/c $SEARCH_PATTERN" "$FILE"
        else
            echo -e "${YELLOW}User ownership does not exist for supervisor. Adding it...${NC}"
            sudo sed -i "5a $SEARCH_PATTERN" "$FILE"
        fi

        sudo service supervisor restart && \
        yes | sudo bench setup production "$USER" && \
        echo -e "${YELLOW}Enabling Scheduler...${NC}"
        sleep 1

        bench --site "$site_name" scheduler enable && \
        bench --site "$site_name" scheduler resume

        if [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
            echo -e "${YELLOW}Setting up Socketio, Redis and Supervisor for $bench_version...${NC}"
            sleep 1
            bench setup socketio
            yes | bench setup supervisor
            bench setup redis
            sudo supervisorctl reload
        fi

        echo -e "${YELLOW}Restarting bench to apply all changes and optimizing environment permissions.${NC}"
        sleep 1

        sudo chmod 755 "$(echo $HOME)"
        
        echo -e "${YELLOW}Configuring Redis services...${NC}"
        sudo systemctl restart redis-server
        sleep 2
        
        sudo supervisorctl restart all
        sleep 3

        printf "${GREEN}Production setup complete! "
        printf '\xF0\x9F\x8E\x86'
        printf "${NC}\n"
        sleep 3

        #
        # ─── ADDITIONAL APPS INSTALL SECTION ────────────────────────────────
        #
        echo -e "${LIGHT_BLUE}Would you like to install additional Frappe apps? (yes/no)${NC}"
        read -p "Response: " extra_apps_install
        extra_apps_install=$(echo "$extra_apps_install" | tr '[:upper:]' '[:lower:]')

        case "$extra_apps_install" in
            "yes"|"y")
                echo ""
                echo -e "${YELLOW}⚠️  Additional Apps Installation${NC}"
                echo -e "${LIGHT_BLUE}Note: App compatibility may vary. Some apps might fail to install${NC}"
                echo -e "${LIGHT_BLUE}due to version mismatches or missing dependencies.${NC}"
                echo ""
                echo -e "${GREEN}Apps courtesy of awesome-frappe by Gavin D'Souza (@gavindsouza)${NC}"
                echo -e "${GREEN}Repository: https://github.com/gavindsouza/awesome-frappe${NC}"
                echo ""
                read -p "Continue with app installation? (yes/no): " apps_confirm
                apps_confirm=$(echo "$apps_confirm" | tr '[:upper:]' '[:lower:]')
                
                if [[ "$apps_confirm" != "yes" && "$apps_confirm" != "y" ]]; then
                    echo -e "${GREEN}Apps installation cancelled.${NC}"
                else
                    echo -e "${GREEN}Proceeding with additional apps installation...${NC}"
                    echo ""
                    
                    echo -e "${YELLOW}Fetching available apps from awesome-frappe repository...${NC}"
                tmp_dir=$(mktemp -d)
                
                if ! git clone https://github.com/gavindsouza/awesome-frappe.git "$tmp_dir" --depth 1 2>/dev/null; then
                    echo -e "${RED}Failed to clone awesome-frappe repository. Skipping additional apps installation.${NC}"
                    rm -rf "$tmp_dir"
                else
                    if [[ ! -f "$tmp_dir/README.md" ]]; then
                        echo -e "${RED}README.md not found in awesome-frappe repository. Skipping additional apps installation.${NC}"
                        rm -rf "$tmp_dir"
                    else
                        mapfile -t raw_entries < <(
                            {
                                grep -oE '\[([^]]+)\]\(https://github\.com/[^)]*\)' "$tmp_dir/README.md" 2>/dev/null || true
                                grep -oE '\[([^]]+)\]\(https://frappecloud\.com/marketplace/[^)]*\)' "$tmp_dir/README.md" 2>/dev/null || true
                                grep -oE '\[([^]]+)\]\(https://frappe\.io/[^)]*\)' "$tmp_dir/README.md" 2>/dev/null || true
                                
                                echo "[Frappe HR](https://github.com/frappe/hrms.git)"
                                echo "[Frappe LMS](https://github.com/frappe/lms.git)"
                                echo "[Frappe CRM](https://github.com/frappe/crm.git)"
                                echo "[Frappe Helpdesk](https://github.com/frappe/helpdesk.git)"
                                echo "[Frappe Builder](https://github.com/frappe/builder.git)"
                                echo "[Frappe Drive](https://github.com/frappe/drive.git)"
                                echo "[Frappe Gameplan](https://github.com/frappe/gameplan.git)"
                            } | sort -u
                        )

                        if [ "${#raw_entries[@]}" -eq 0 ]; then
                            echo -e "${RED}No GitHub repository links found in awesome-frappe README. Skipping.${NC}"
                            rm -rf "$tmp_dir"
                        else
                            declare -a display_names=()
                            declare -a repo_names=()
                            declare -a url_array=()
                            
                            if [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
                                echo -e "${YELLOW}Checking app compatibility with $bench_version...${NC}"
                                echo -e "${LIGHT_BLUE}This may take a moment, please wait...${NC}"
                                
                                total_apps=${#raw_entries[@]}
                                current_app=0
                                compatible_count=0
                                
                                for entry in "${raw_entries[@]}"; do
                                    current_app=$((current_app + 1))
                                    
                                    echo -ne "\r${LIGHT_BLUE}Progress: $current_app/$total_apps apps checked...${NC}"
                                    
                                    display_name=$(echo "$entry" | sed -E 's/\[([^]]+)\]\(.*/\1/')
                                    
                                    url=$(echo "$entry" | sed -E 's/.*\(([^)]+)\).*/\1/')
                                    
                                    repo_url=""
                                    repo_name=""
                                    
                                    if [[ "$url" =~ ^https://github\.com/[^/]+/[^/]+/?$ ]]; then
                                        repo_url="$url"
                                        if [[ ! "$repo_url" =~ \.git$ ]]; then
                                            repo_url="${repo_url}.git"
                                        fi
                                        repo_name=$(basename "$repo_url" .git)
                                    elif [[ "$url" =~ ^https://frappecloud\.com/marketplace/ ]] || [[ "$url" =~ ^https://github\.com/frappe/ ]]; then
                                        case "$display_name" in
                                            "Frappe HR"|"HRMS")
                                                repo_url="https://github.com/frappe/hrms.git"
                                                repo_name="hrms"
                                                ;;
                                            "Frappe LMS")
                                                repo_url="https://github.com/frappe/lms.git"
                                                repo_name="lms"
                                                ;;
                                            "Frappe CRM")
                                                repo_url="https://github.com/frappe/crm.git"
                                                repo_name="crm"
                                                ;;
                                            "Frappe Helpdesk")
                                                repo_url="https://github.com/frappe/helpdesk.git"
                                                repo_name="helpdesk"
                                                ;;
                                            "Frappe Builder")
                                                repo_url="https://github.com/frappe/builder.git"
                                                repo_name="builder"
                                                ;;
                                            "Frappe Drive")
                                                repo_url="https://github.com/frappe/drive.git"
                                                repo_name="drive"
                                                ;;
                                            "Frappe Gameplan")
                                                repo_url="https://github.com/frappe/gameplan.git"
                                                repo_name="gameplan"
                                                ;;
                                            *)
                                                if [[ "$url" =~ ^https://github\.com/ ]]; then
                                                    repo_url="$url"
                                                    if [[ ! "$repo_url" =~ \.git$ ]]; then
                                                        repo_url="${repo_url}.git"
                                                    fi
                                                    repo_name=$(basename "$repo_url" .git)
                                                else
                                                    continue
                                                fi
                                                ;;
                                        esac
                                    else
                                        continue
                                    fi
                                    
                                    if [[ "$repo_name" == ".git" || "$repo_name" == "" ]]; then
                                        continue
                                    fi
                                    
                                    repo_check_dir=$(mktemp -d)
                                    
                                    if git clone "$repo_url" "$repo_check_dir" --depth 1 --quiet 2>/dev/null; then
                                        if [[ -f "$repo_check_dir/pyproject.toml" ]]; then
                                            display_names+=("$display_name")
                                            repo_names+=("$repo_name")
                                            url_array+=("$repo_url")
                                            compatible_count=$((compatible_count + 1))
                                        fi
                                    fi
                                    
                                    rm -rf "$repo_check_dir"
                                done
                                
                                echo -e "\r${GREEN}✓ Compatibility check complete: $compatible_count/$total_apps apps are compatible with $bench_version${NC}"
                                
                            else
                                echo -e "${YELLOW}Processing available apps for $bench_version...${NC}"
                                
                                for entry in "${raw_entries[@]}"; do
                                    display_name=$(echo "$entry" | sed -E 's/\[([^]]+)\]\(.*/\1/')
                                    
                                    url=$(echo "$entry" | sed -E 's/.*\(([^)]+)\).*/\1/')
                                    
                                    repo_url=""
                                    repo_name=""
                                    
                                    if [[ "$url" =~ ^https://github\.com/[^/]+/[^/]+/?$ ]]; then
                                        repo_url="$url"
                                        if [[ ! "$repo_url" =~ \.git$ ]]; then
                                            repo_url="${repo_url}.git"
                                        fi
                                        repo_name=$(basename "$repo_url" .git)
                                    elif [[ "$url" =~ ^https://frappecloud\.com/marketplace/ ]] || [[ "$url" =~ ^https://github\.com/frappe/ ]]; then
                                        case "$display_name" in
                                            "Frappe HR"|"HRMS")
                                                repo_url="https://github.com/frappe/hrms.git"
                                                repo_name="hrms"
                                                ;;
                                            "Frappe LMS")
                                                repo_url="https://github.com/frappe/lms.git"
                                                repo_name="lms"
                                                ;;
                                            "Frappe CRM")
                                                repo_url="https://github.com/frappe/crm.git"
                                                repo_name="crm"
                                                ;;
                                            "Frappe Helpdesk")
                                                repo_url="https://github.com/frappe/helpdesk.git"
                                                repo_name="helpdesk"
                                                ;;
                                            "Frappe Builder")
                                                repo_url="https://github.com/frappe/builder.git"
                                                repo_name="builder"
                                                ;;
                                            "Frappe Drive")
                                                repo_url="https://github.com/frappe/drive.git"
                                                repo_name="drive"
                                                ;;
                                            "Frappe Gameplan")
                                                repo_url="https://github.com/frappe/gameplan.git"
                                                repo_name="gameplan"
                                                ;;
                                            *)
                                                if [[ "$url" =~ ^https://github\.com/ ]]; then
                                                    repo_url="$url"
                                                    if [[ ! "$repo_url" =~ \.git$ ]]; then
                                                        repo_url="${repo_url}.git"
                                                    fi
                                                    repo_name=$(basename "$repo_url" .git)
                                                else
                                                    continue
                                                fi
                                                ;;
                                        esac
                                    else
                                        continue
                                    fi
                                    
                                    if [[ "$repo_name" == ".git" || "$repo_name" == "" ]]; then
                                        continue
                                    fi
                                    
                                    display_names+=("$display_name")
                                    repo_names+=("$repo_name")
                                    url_array+=("$repo_url")
                                done
                                
                                echo -e "${GREEN}✓ Found ${#display_names[@]} apps available for $bench_version${NC}"
                            fi

                            declare -a unique_display_names=()
                            declare -a unique_repo_names=()
                            declare -a unique_urls=()
                            declare -A seen_repos=()
                            
                            for i in "${!repo_names[@]}"; do
                                if [[ -z "${seen_repos[${repo_names[$i]}]}" ]]; then
                                    seen_repos["${repo_names[$i]}"]=1
                                    unique_display_names+=("${display_names[$i]}")
                                    unique_repo_names+=("${repo_names[$i]}")
                                    unique_urls+=("${url_array[$i]}")
                                fi
                            done

                            declare -a sorted_indices=()
                            readarray -t sorted_indices < <(
                                for i in "${!unique_display_names[@]}"; do
                                    echo "$i ${unique_display_names[$i]}"
                                done | sort -k2 | cut -d' ' -f1
                            )

                            declare -a final_display_names=()
                            declare -a final_repo_names=()
                            declare -a final_urls=()
                            
                            for i in "${sorted_indices[@]}"; do
                                final_display_names+=("${unique_display_names[$i]}")
                                final_repo_names+=("${unique_repo_names[$i]}")
                                final_urls+=("${unique_urls[$i]}")
                            done

                            display_names=("${final_display_names[@]}")
                            repo_names=("${final_repo_names[@]}")
                            url_array=("${final_urls[@]}")

                            if [ "${#display_names[@]}" -eq 0 ]; then
                                if [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
                                    echo -e "${RED}No apps with pyproject.toml found that are compatible with $bench_version.${NC}"
                                    echo -e "${YELLOW}ERPNext v15/develop requires apps to have pyproject.toml files.${NC}"
                                else
                                    echo -e "${RED}No valid Frappe apps found in awesome-frappe README.${NC}"
                                fi
                                rm -rf "$tmp_dir"
                            else
                                if [[ "$bench_version" == "version-15" || "$bench_version" == "develop" ]]; then
                                    echo -e "${GREEN}Found ${#display_names[@]} compatible apps with pyproject.toml for $bench_version.${NC}"
                                else
                                    echo -e "${GREEN}Found ${#display_names[@]} available apps for $bench_version.${NC}"
                                fi

                                terminal_height=$(tput lines 2>/dev/null || echo 24)
                                terminal_width=$(tput cols 2>/dev/null || echo 80)
                                
                                max_dialog_height=$((terminal_height - 4))
                                max_dialog_width=$((terminal_width - 10))
                                
                                max_display_len=0
                                for name in "${display_names[@]}"; do
                                    if (( ${#name} > 50 )); then
                                        name="${name:0:47}..."
                                    fi
                                    if (( ${#name} > max_display_len )); then
                                        max_display_len=${#name}
                                    fi
                                done
                                
                                dialog_width=$((max_display_len + 25))
                                if (( dialog_width < 60 )); then
                                    dialog_width=60
                                elif (( dialog_width > max_dialog_width )); then
                                    dialog_width=$max_dialog_width
                                fi
                                
                                item_count=${#display_names[@]}
                                dialog_height=$((item_count + 8))
                                if (( dialog_height > max_dialog_height )); then
                                    dialog_height=$max_dialog_height
                                fi

                                OPTIONS=()
                                for i in "${!display_names[@]}"; do
                                    display_name="${display_names[$i]}"
                                    
                                    if (( ${#display_name} > 50 )); then
                                        display_name="${display_name:0:47}..."
                                    fi
                                    
                                    OPTIONS+=("$display_name" "" OFF)
                                done

                                CHOICES=$(whiptail --title "Additional Frappe Apps (${#display_names[@]} available)" \
                                    --checklist "Choose apps to install (Space=toggle, Enter=confirm):" \
                                    "$dialog_height" "$dialog_width" "$((dialog_height - 8))" \
                                    "${OPTIONS[@]}" 3>&1 1>&2 2>&3) || {
                                    echo -e "${RED}No apps selected or dialog cancelled. Skipping additional apps installation.${NC}"
                                    rm -rf "$tmp_dir"
                                }

                                if [ -z "$CHOICES" ]; then
                                    echo -e "${RED}No apps selected. Skipping additional apps installation.${NC}"
                                    rm -rf "$tmp_dir"
                                else
                                    eval "selected_display_names=($CHOICES)"

                                    echo -e "${GREEN}Selected ${#selected_display_names[@]} apps for installation.${NC}"

                                    installation_errors=()
                                    successful_installations=()
                                    
                                    for selected_display_name in "${selected_display_names[@]}"; do
                                        selected_repo=""
                                        selected_url=""
                                        
                                        for idx in "${!display_names[@]}"; do
                                            if [[ "${display_names[$idx]}" == "$selected_display_name" ]]; then
                                                selected_repo="${repo_names[$idx]}"
                                                selected_url="${url_array[$idx]}"
                                                break
                                            fi
                                        done

                                        if [[ -z "$selected_url" ]]; then
                                            echo -e "${RED}Could not find URL for \"$selected_display_name\". Skipping.${NC}"
                                            installation_errors+=("$selected_display_name: URL not found")
                                            continue
                                        fi

                                        echo -e "${YELLOW}Installing \"$selected_display_name\" ($selected_repo)...${NC}"
                                        echo -e "${LIGHT_BLUE}Repository: $selected_url${NC}"

                                        echo -e "${YELLOW}Step 1/2: Downloading app...${NC}"
                                        
                                        download_success=false
                                        
                                        if bench get-app "$selected_url" --branch "$bench_version" --skip-assets 2>/tmp/bench_error_$.log; then
                                            download_success=true
                                        else
                                            echo -e "${YELLOW}⚠ Branch '$bench_version' not found, trying default branch...${NC}"
                                            if bench get-app "$selected_url" --skip-assets 2>/tmp/bench_error_$.log; then
                                                download_success=true
                                            fi
                                        fi
                                        
                                        if [ "$download_success" = true ]; then
                                            echo -e "${GREEN}✓ Successfully downloaded \"$selected_display_name\".${NC}"
                                            
                                            echo -e "${YELLOW}Step 2/2: Installing to site...${NC}"
                                            app_installed=false
                                            
                                            app_dir="apps/$selected_repo"
                                            setup_py_path="$app_dir/setup.py"
                                            
                                            if [[ -f "$setup_py_path" ]]; then
                                                extracted_app_name=$(extract_app_name_from_setup "$setup_py_path")
                                                
                                                if [[ -n "$extracted_app_name" ]]; then
                                                    echo -e "${LIGHT_BLUE}Found app name in setup.py: \"$extracted_app_name\"${NC}"
                                                    if bench --site "$site_name" install-app "$extracted_app_name" 2>/dev/null; then
                                                        echo -e "${GREEN}✓ Successfully installed using setup.py name.${NC}"
                                                        successful_installations+=("$selected_display_name")
                                                        app_installed=true
                                                    else
                                                        echo -e "${YELLOW}⚠ Setup.py name failed, trying alternatives...${NC}"
                                                    fi
                                                else
                                                    echo -e "${YELLOW}⚠ Could not extract name from setup.py, trying alternatives...${NC}"
                                                fi
                                            fi
                                            
                                            if [[ "$app_installed" == false ]]; then
                                                echo -e "${LIGHT_BLUE}Trying repo name: \"$selected_repo\"${NC}"
                                                if bench --site "$site_name" install-app "$selected_repo" 2>/dev/null; then
                                                    echo -e "${GREEN}✓ Successfully installed using repo name.${NC}"
                                                    successful_installations+=("$selected_display_name")
                                                    app_installed=true
                                                fi
                                            fi
                                            
                                            if [[ "$app_installed" == false ]]; then
                                                transformed_name=$(echo "$selected_repo" | sed -E 's/^(frappe[-_]?|erpnext[-_]?)//' | tr '-' '_' | tr '[:upper:]' '[:lower:]')
                                                
                                                if [[ "$transformed_name" != "$selected_repo" ]]; then
                                                    echo -e "${LIGHT_BLUE}Trying transformed name: \"$transformed_name\"${NC}"
                                                    if bench --site "$site_name" install-app "$transformed_name" 2>/dev/null; then
                                                        echo -e "${GREEN}✓ Successfully installed using transformed name.${NC}"
                                                        successful_installations+=("$selected_display_name")
                                                        app_installed=true
                                                    fi
                                                fi
                                            fi
                                            
                                            if [[ "$app_installed" == false ]]; then
                                                lowercase_name=$(echo "$selected_repo" | tr '[:upper:]' '[:lower:]')
                                                if [[ "$lowercase_name" != "$selected_repo" ]]; then
                                                    echo -e "${LIGHT_BLUE}Trying lowercase: \"$lowercase_name\"${NC}"
                                                    if bench --site "$site_name" install-app "$lowercase_name" 2>/dev/null; then
                                                        echo -e "${GREEN}✓ Successfully installed using lowercase name.${NC}"
                                                        successful_installations+=("$selected_display_name")
                                                        app_installed=true
                                                    fi
                                                fi
                                            fi
                                            
                                            if [[ "$app_installed" == false && -d "$app_dir" ]]; then
                                                for subdir in "$app_dir"/*/; do
                                                    if [[ -d "$subdir" && -f "$subdir/__init__.py" ]]; then
                                                        potential_app_name=$(basename "$subdir")
                                                        if [[ "$potential_app_name" != "tests" && "$potential_app_name" != "docs" && "$potential_app_name" != "__pycache__" ]]; then
                                                            echo -e "${LIGHT_BLUE}Trying directory name: \"$potential_app_name\"${NC}"
                                                            if bench --site "$site_name" install-app "$potential_app_name" 2>/dev/null; then
                                                                echo -e "${GREEN}✓ Successfully installed using directory name.${NC}"
                                                                successful_installations+=("$selected_display_name")
                                                                app_installed=true
                                                                break
                                                            fi
                                                        fi
                                                    fi
                                                done
                                            fi
                                            
                                            if [[ "$app_installed" == false ]]; then
                                                echo -e "${RED}✗ Failed to install \"$selected_display_name\" after trying all strategies.${NC}"
                                                echo -e "${YELLOW}This app may have compatibility issues with ERPNext $bench_version or missing dependencies.${NC}"
                                                installation_errors+=("$selected_display_name: Installation failed (compatibility/dependency issues)")
                                            fi
                                            
                                            rm -f /tmp/bench_error_$.log
                                        else
                                            if [[ -d "apps/$selected_repo" ]]; then
                                                echo -e "${YELLOW}⚠ App was cloned but failed during pip install phase.${NC}"
                                                echo -e "${RED}✗ \"$selected_display_name\" has dependency/compatibility issues with ERPNext $bench_version.${NC}"
                                                
                                                if [[ -f /tmp/bench_error_$.log ]]; then
                                                    echo -e "${LIGHT_BLUE}Error details:${NC}"
                                                    tail -3 /tmp/bench_error_$.log | grep -E "(ERROR|Failed|returned non-zero)" || echo "Check app requirements and compatibility."
                                                fi
                                                
                                                installation_errors+=("$selected_display_name: Dependency/compatibility issues")
                                            else
                                                echo -e "${RED}✗ Failed to clone \"$selected_display_name\" from repository.${NC}"
                                                installation_errors+=("$selected_display_name: Git clone failed")
                                            fi
                                            
                                            rm -f /tmp/bench_error_$.log
                                        fi
                                        
                                        echo -e "\n${LIGHT_BLUE}────────────────────────────────────────${NC}\n"
                                    done

                                    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
                                    echo -e "${GREEN}║           Installation Summary       ║${NC}"
                                    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
                                    
                                    if [ "${#successful_installations[@]}" -gt 0 ]; then
                                        echo -e "${GREEN}✓ Successfully installed ${#successful_installations[@]} apps:${NC}"
                                        for app in "${successful_installations[@]}"; do
                                            echo -e "  ${GREEN}✓${NC} $app"
                                        done
                                        echo ""
                                    fi
                                    
                                    if [ "${#installation_errors[@]}" -gt 0 ]; then
                                        echo -e "${RED}✗ Failed to install ${#installation_errors[@]} apps:${NC}"
                                        for error in "${installation_errors[@]}"; do
                                            echo -e "  ${RED}✗${NC} $error"
                                        done
                                        echo ""
                                        echo -e "${YELLOW}Note: Some apps may not be compatible with ERPNext $bench_version${NC}"
                                        echo -e "${YELLOW}or may require specific dependencies that are not installed.${NC}"
                                    fi

                                    rm -rf "$tmp_dir"
                                    
                                    if [ "${#successful_installations[@]}" -gt 0 ]; then
                                        echo -e "${YELLOW}Restarting services to apply changes...${NC}"
                                        sudo supervisorctl restart all 2>/dev/null || true
                                        echo -e "${GREEN}Services restarted successfully.${NC}"
                                    fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
                ;;
            *)
                echo -e "${RED}Skipping additional apps installation.${NC}"
                ;;
        esac

        #
        # ─── SSL SECTION ────────────────────────────────────────────────────────────────
        #
        echo -e "${YELLOW}Would you like to install SSL? (yes/no)${NC}"
        read -p "Response: " continue_ssl
        continue_ssl=$(echo "$continue_ssl" | tr '[:upper:]' '[:lower:]')

        case "$continue_ssl" in
            "yes"|"y")
                echo -e "${YELLOW}Make sure your domain name is pointed to the IP of this instance and is reachable before you proceed.${NC}"
                sleep 3

                if ! command -v certbot >/dev/null 2>&1; then
                    read -p "Enter your email address: " email_address

                    echo -e "${YELLOW}Installing Certbot...${NC}"
                    sleep 1
                    if [ "$DISTRO" == "Debian" ]; then
                        echo -e "${YELLOW}Fixing openssl package on Debian...${NC}"
                        sleep 4
                        sudo pip3 uninstall cryptography -y
                        yes | sudo pip3 install pyopenssl==22.0.0 cryptography==36.0.0
                        echo -e "${GREEN}Package fixed${NC}"
                        sleep 2
                    fi

                    sudo apt install snapd -y && \
                    sudo snap install core && \
                    sudo snap refresh core && \
                    sudo snap install --classic certbot && \
                    sudo ln -s /snap/bin/certbot /usr/bin/certbot

                    echo -e "${GREEN}Certbot installed successfully.${NC}"
                else
                    echo -e "${GREEN}Certbot is already installed. Skipping installation.${NC}"
                    sleep 1
                    read -p "Enter your email address: " email_address
                fi

                echo -e "${YELLOW}Obtaining and installing SSL certificate...${NC}"
                sleep 2
                sudo certbot --nginx --non-interactive --agree-tos --email "$email_address" -d "$site_name"
                echo -e "${GREEN}SSL certificate installed successfully.${NC}"
                sleep 2
                ;;
            *)
                echo -e "${RED}Skipping SSL installation...${NC}"
                ;;
        esac

        if [[ -z "$py_version" ]] || [[ "$py_major" -lt 3 ]] || [[ "$py_major" -eq 3 && "$py_minor" -lt 10 ]]; then
            deactivate
        fi

        echo -e "${GREEN}--------------------------------------------------------------------------------"
        echo -e "Congratulations! You have successfully installed ERPNext $version_choice."
        echo -e "You can start using your new ERPNext installation by visiting https://$site_name"
        echo -e "(if you have enabled SSL and used a Fully Qualified Domain Name"
        echo -e "during installation) or http://$server_ip to begin."
        echo -e "Install additional apps as required. Visit https://docs.erpnext.com for Documentation."
        echo -e "Enjoy using ERPNext!"
        echo -e "--------------------------------------------------------------------------------${NC}"
        ;;
    *)

        echo -e "${YELLOW}Getting your site ready for development...${NC}"
        sleep 2
        source ~/.profile
        if [[ "$bench_version" == "version-15" ]]; then
            nvm alias default 18
        else
            nvm alias default 16
        fi
        bench use "$site_name"
        bench build
        echo -e "${GREEN}Done!${NC}"
        sleep 5

        echo -e "${GREEN}-----------------------------------------------------------------------------------------------"
        echo -e "Congratulations! You have successfully installed Frappe and ERPNext $version_choice Development Environment."
        echo -e "Start your instance by running bench start to start your server and visiting http://$server_ip:8000"
        echo -e "Install additional apps as required. Visit https://frappeframework.com for Developer Documentation."
        echo -e "Enjoy development with Frappe!"
        echo -e "-----------------------------------------------------------------------------------------------${NC}"
        ;;
esac