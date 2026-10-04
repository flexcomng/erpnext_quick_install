# Unattended Install Script for ERPNext
Unattended script for ERPNext installation (Supports Versions 13, 14, 15, 16, and Develop).

This is a comprehensive, interactive script for installing ERPNext Versions 13, 14, 15, 16, and the develop branch. You can set up either development or production environments with enhanced features including intelligent additional apps installation, comprehensive logging, and smart branch detection.

## 🆕 What's New in This Version

### Enhanced Features
- **Develop Branch Support**: Added comprehensive warnings and support for the bleeding-edge develop branch
- **ERPNext v16 Support**: New version option with Python 3.14+ and Node.js 24 requirements
- **Intelligent Additional Apps Installation**: Automated discovery and installation of 50+ compatible Frappe apps
- **Smart Branch Detection**: Automatically detects and uses the best available branch for each app
- **Improved Error Handling**: Multiple installation strategies and graceful fallbacks
- **Better User Experience**: Clearer prompts, progress indicators, and informative messages

### Major Additions
- **Additional Apps Marketplace**: Browse and install from 50+ curated Frappe applications
- **Compatibility Checking**: Automatic validation for ERPNext v15/v16/develop (pyproject.toml requirements)
- **Branch Intelligence**: Frappe apps use appropriate version branches, third-party apps use default branches
- **Installation Strategies**: Multiple fallback methods for app installation (setup.py extraction, name transformations, directory scanning)

## 🔧 How To Use

### Before Installation

Make sure you install the latest package versions by updating system packages if you are running this script on a fresh Ubuntu machine.

```bash
sudo apt update && sudo apt -y upgrade
```
and then reboot your machine 

### ⚠️ Important!
Do not run this script as root as it will fail when setting up the site. If your VPS default user is root, create a non-root user by following these steps:

1. Create a new user (you can change frappeuser to your preferred user name):
```bash
sudo adduser frappeuser
Full Name []: frappeuser
Room Number []:
Work Phone []:
Home Phone []:
Other []:
Is the information correct? [Y]
```
2. Add the user to sudoers:
```bash
usermod -aG sudo frappeuser
```
3. Switch to created user:
```bash
su frappeuser
```
4. Ensure you're on created user's home directory:
```bash
cd /home/frappeuser
```
To manually add a user to the sudoers file, follow these steps:

1. Switch to Root User:
```
su root
```
2. Edit Sudoers File:
```
visudo
```
3. Add User Entry: Add the following line under the user privilege specification:
```
user ALL=(ALL:ALL) ALL
```
4. Save and Exit: Press CTRL+X, then Y, and Enter to save and exit.

Continue with the next steps below.

### Installation Steps

1. Clone the Repository:
```bash
git clone https://github.com/flexcomng/erpnext_quick_install.git
```
2. Navigate to the folder:
```bash
cd erpnext_quick_install
```
3. Make the script executable:
```bash
chmod +x erpnext_install.sh
```
4. Run the script:
```bash
source erpnext_install.sh
```

### Unattended Installation

Set `ERPNEXT_UNATTENDED=1` to run without prompts, for example from automation or a provisioning tool. Every prompt is then answered from an environment variable. Without `ERPNEXT_UNATTENDED`, the script stays interactive, and any variable you set simply pre-fills that answer. In unattended mode a missing required setting stops the script with a clear message instead of waiting for input.

| Variable | Required | Default (unattended) | Meaning |
|---|---|---|---|
| `ERPNEXT_VERSION` | yes | – | `13`, `14`, `15`, `16` or `develop` (develop also needs `ERPNEXT_DEVELOP_ACK=yes`) |
| `ERPNEXT_SITE_NAME` | yes | – | Site name (use a FQDN if you want SSL) |
| `ERPNEXT_DB_ROOT_PASSWORD_FILE` | yes* | – | File whose first line is the MariaDB root password |
| `ERPNEXT_ADMIN_PASSWORD_FILE` | yes* | – | File whose first line is the Administrator password |
| `ERPNEXT_BENCH_NAME` | no | `frappe-bench` | Bench folder name |
| `ERPNEXT_INSTALL_ERPNEXT` | no | `yes` | Install the ERPNext app |
| `ERPNEXT_PRODUCTION` | no | `yes` | Production setup (nginx and supervisor) |
| `ERPNEXT_SSL` | no | `no` | Request a Let's Encrypt certificate (needs `ERPNEXT_SSL_EMAIL`) |
| `ERPNEXT_SSL_EMAIL` | if SSL | – | Email address for Let's Encrypt |
| `ERPNEXT_UFW` | no | `0` | `1` enables ufw, allowing only SSH, HTTP and HTTPS |
| `ERPNEXT_ALLOW_EXISTING` | no | `no` | Continue even if an existing bench is detected |

\* `ERPNEXT_DB_ROOT_PASSWORD` and `ERPNEXT_ADMIN_PASSWORD` also work, but the `_FILE` forms keep passwords out of the environment and your shell history. The additional-apps marketplace is interactive, so unattended mode skips it.

Example:

```bash
umask 077
openssl rand -base64 24 > ~/.db-root.pw
openssl rand -base64 24 > ~/.admin.pw
ERPNEXT_UNATTENDED=1 ERPNEXT_VERSION=15 ERPNEXT_SITE_NAME=erp.example.com \
ERPNEXT_DB_ROOT_PASSWORD_FILE=~/.db-root.pw ERPNEXT_ADMIN_PASSWORD_FILE=~/.admin.pw \
ERPNEXT_SSL=yes ERPNEXT_SSL_EMAIL=ops@example.com ERPNEXT_UFW=1 \
bash erpnext_install.sh
```

### File permissions

nginx only needs to *traverse* your home directory to reach `sites/assets` and private files, so the script sets `chmod o+x` on `$HOME` (mode `711` after production setup) rather than making the whole home directory world-readable. `common_site_config.json` and the new site's `site_config.json` are set to `600`, because they hold database passwords and the encryption key, and only the bench user needs them.

## 🖥️ Compatibility

**Supported Operating Systems:**
- Ubuntu 24.04 LTS
- Ubuntu 23.04 LTS  
- Ubuntu 22.04 LTS
- Ubuntu 20.04 LTS
- Debian 12 (Bookworm)
- Debian 11 (Bullseye)
- Debian 10 (Buster)

**Version-Specific Requirements:**
- **ERPNext v16**: Ubuntu 22.04+ or Debian 12+ only, Python 3.14+, Node.js 24
- **ERPNext v15/Develop**: Ubuntu 22.04+ or Debian 12+ only, Python 3.10+, Node.js 18/20
- **ERPNext v13/v14**: Ubuntu 22.04 and below, Debian 11 and below, Python 3.10+, Node.js 16

## 🚨 Important Disclaimers

### Version Compatibility & Installation Conflicts

**⚠️ CRITICAL: Different ERPNext versions should NOT be installed on the same server!**

Installing multiple ERPNext versions (e.g., v16 + develop, or v14 + v15) on the same server can cause:
- **Redis port conflicts** (develop uses ports 11000, 12000, 13000 vs standard 6379)
- **Node.js version conflicts** (v13/v14 use Node 16, v15/develop use Node 18/20, v16 uses Node 24)
- **Supervisor configuration conflicts** (different service management approaches)
- **Database schema incompatibilities** (version-specific database changes)
- **Python dependency conflicts** (different package version requirements)
- **System instability and service failures**

**Recommended Approach:**
- **One ERPNext version per server/container**
- **Use separate servers** for production and development environments
- **Backup and completely remove** existing installations before installing different versions
- **Use Docker containers** for isolated testing of different versions

The script automatically detects existing installations and warns about potential conflicts.

### Develop Branch Warning
The **develop branch** contains bleeding-edge, experimental code that:
- Changes daily and may be unstable
- Can cause data corruption or system crashes  
- Is NOT suitable for production or important data
- Has limited community support

**Recommended for**: Experienced developers testing new features  
**Better alternatives**: Version 16 (stable) or Version 15 (proven)

### Additional Apps Installation
When installing additional Frappe apps, please note:
- App compatibility may vary between ERPNext versions
- Some apps might fail to install due to version mismatches or missing dependencies
- Third-party apps use their own versioning schemes
- Installation success is not guaranteed for all environments
- ERPNext v16: Apps not developed by Frappe are not tested yet; install at your own risk

## 📦 Additional Apps Feature

### What's Included
- **50+ Curated Apps**: Access to a comprehensive collection of Frappe applications
- **Official Frappe Apps**: HRMS, CRM, LMS, Insights, Builder, Drive, Helpdesk, and more
- **Third-Party Apps**: Community-developed applications for various business needs
- **Smart Selection**: Interactive dialog for easy app selection
- **Compatibility Checking**: Automatic validation for ERPNext v15/v16/develop requirements

### How It Works
1. **Repository Scanning**: Fetches app list from awesome-frappe repository
2. **Compatibility Validation**: Checks for pyproject.toml requirements (v15/v16/develop)
3. **Branch Detection**: Automatically selects the best available branch for each app
4. **Multiple Installation Strategies**: Falls back through different installation methods
5. **Comprehensive Reporting**: Detailed success/failure reporting with error details

### Supported App Categories
- **HR & Payroll**: HRMS, Employee management tools
- **Sales & CRM**: Customer relationship management, lead tracking
- **Learning & Education**: LMS, course management systems  
- **Project Management**: Task tracking, time management
- **E-commerce**: Online store integrations
- **Accounting & Finance**: Additional financial modules
- **Communication**: Chat, messaging, collaboration tools
- **And many more!**

## 🙏 Acknowledgments

### Special Thanks
**Gavin D'Souza (@gavindsouza)** - Creator and maintainer of [awesome-frappe](https://github.com/gavindsouza/awesome-frappe)

The additional apps feature is powered by the awesome-frappe repository, a comprehensive collection of Frappe applications and resources that is community-maintained and regularly updated. This curated list makes discovering quality Frappe apps much easier for the entire community.

**Repository**: https://github.com/gavindsouza/awesome-frappe

Thank you Gavin for your valuable contribution to the Frappe ecosystem! 🎉

## 📋 Changelog

### Version 2.1 (Latest)
**Major Features Added:**
- ✅ ERPNext v16 support (Python 3.14+, Node.js 24)
- ✅ Updated compatibility checks for v15/v16/develop

**User Experience:**
- 💬 Updated prompts and documentation for v16 selection

### Version 2.0
**Major Features Added:**
- ✨ Develop branch support with comprehensive warnings
- 🏪 Additional apps marketplace with 50+ applications
- 🧠 Intelligent branch detection for Frappe apps
- 🔄 Multiple installation strategies with fallbacks
- 🎯 Smart compatibility checking for v15/v16/develop
- 🖼️ Improved user interface with better prompts and progress indicators

**Technical Improvements:**
- 🔍 Git branch detection using `git ls-remote`
- 📝 Setup.py parsing for accurate app names
- 🏷️ Name transformation strategies for installation
- 📁 Directory scanning for app detection
- 🛡️ Enhanced error handling and recovery
- 📋 Comprehensive installation reporting

**User Experience:**
- 💬 Clearer installation prompts and confirmations
- ⚠️ Appropriate warnings for risky operations
- 🎨 Better visual formatting and colors
- 📈 Progress indicators during long operations
- 📄 Detailed success/failure summaries

### Version 1.0 (Original)
**Core Features:**
- ✅ ERPNext versions 13, 14, 15 support
- ✅ Production and development environment setup
- ✅ MariaDB configuration and security
- ✅ Node.js and Python environment management
- ✅ SSL certificate installation with Certbot
- ✅ Basic HRMS installation option

## 🛠️ Advanced Usage

### Manual App Installation
You can always install additional apps manually after the initial setup:
```bash
cd /path/to/frappe-bench
bench get-app <app-url>
bench --site <site-name> install-app <app-name>
```

### Troubleshooting Redis Issues
If you encounter Redis connection errors (Error 111 connecting to 127.0.0.1:11001):

**For ERPNext v15/v16:**
```bash
cd /path/to/frappe-bench
bench setup socketio
bench setup supervisor
bench setup redis
sudo supervisorctl reload
```

**For all versions:**
```bash
# Restart Redis service
sudo systemctl restart redis-server

# Restart all supervisor services
sudo supervisorctl restart all

# Check Redis status
sudo systemctl status redis-server
```

**Check Redis configuration:**
```bash
# Verify Redis is running on default port
redis-cli ping

# Check what ports Redis is using
sudo netstat -tlnp | grep redis
```

## 📚 Additional Resources

- **ERPNext Documentation**: https://docs.erpnext.com
- **Frappe Framework Documentation**: https://frappeframework.com/docs
- **Awesome Frappe**: https://github.com/gavindsouza/awesome-frappe
- **ERPNext GitHub**: https://github.com/frappe/erpnext
- **Frappe GitHub**: https://github.com/frappe/frappe

## 📄 License

This script is provided as-is for the ERPNext community. Please ensure you comply with the licenses of ERPNext, Frappe Framework, and any additional apps you install.

---

**Enjoy using ERPNext!** 🎉

For support and issues, please check the ERPNext community forum or GitHub issues.
