#!/bin/bash

# Check if Ansible is installed
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

# Check if Ansible installation is successful
if command -v ansible-playbook >/dev/null; then
    # Execute the playbook
    echo "Running Ansible playbook..."
    ansible-playbook main.yml
else
    echo "Failed to install Ansible. Cannot proceed with running the playbook."
    exit 1
fi

