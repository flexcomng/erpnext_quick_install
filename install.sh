#!/bin/bash

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
