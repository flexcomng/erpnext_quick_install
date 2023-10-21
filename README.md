# Unattended Install Script for ERPNext
Unattended script for ERPNext installation (Supports Versions 13, 14 and 15).

This is a no-interactive script for installing ERPNext Versions 13, 14 and 15. You can set up either development or production with very minimal interaction.

# How To:
To use this script, follow these steps:

# Before Installation

Make sure you install the latest package versions by updating system packages if you are running this script on a fresh Ubuntu machine.

```
sudo apt update && sudo -y apt upgrade
```
and then reboot your machine 

# Installation:

1. Clone the Repo:
```
git clone https://github.com/flexcomng/erpnext_quick_install.git
```
2. navigate to the folder:
```
cd erpnext_quick_install
```
3. Make the script executable
```
sudo chmod +x erpnext_install.sh
```
4. Run the script:
```
source erpnext_install.sh
```
# Compatibility

Ubuntu 22.04 LTS,
Ubuntu 20.04 LTS

Debian 10 (Buster),
Debian 11 (Bulls Eye)

# NOTE:

Version 15 Compatibility is set to Ubuntu 22.04 LTS and above only. Other Distros or lower Ubuntu versions not supported for version 15 installation.
Visit https://github.com/gavindsouza/awesome-frappe to learn about other apps you can install.

