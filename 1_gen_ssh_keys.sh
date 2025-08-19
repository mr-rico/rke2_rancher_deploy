#!/bin/bash
#
#
###############################################################################
# Script Name : 1_gen_ssh_keys.sh
# Description : Establish SSH connectivity and distribute host files
# Usage       : ./1_gen_ssh_keys.sh or called from ./0_rke2_deploy.sh
# Author      : Rico Randall
# Created     : 2025-06-16
# Last Updated: 2025-07-13
# Version     : 1.09
# License     : MIT
# Notes       : Ensure all nodes have network connectivity.
#               Requires sudo privileges.
###############################################################################

source ./vars.sh

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[1;31mThis script requires root privileges. Re-running the script with sudo...\033[0m"
    exec sudo "$0" "$@"  # Re-run the script with sudo
else
# Error checking function
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31mError occurred during: $1\033[0m" >&2
        exit 1
    fi
}

# Generate SSH keys if they do not exist
gen_keys() {
  echo -e "\n\033[0;32mGenerating ssh keys for remote connections\033[0m"
  if [ ! -f "${SSH_KEY}" ]; then
    echo "SSH key not found. Generating one..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N ""
  else
    echo "SSH key already exists."
  fi
}

# Install package to enable automated authentication
if ! command -v sshpass &> /dev/null; then
  echo -e "\033[0;33msshpass is not installed. Installing now.\033[0m"
  rpm -ivh "${WORKING_DIR}/sshpass-1.09-4.el9.x86_64.rpm"
    # You can install it here or exit
else
  echo -e "\033[0;33msshpass is installed.\033[0m"
fi

# Take user's password for automation of ssh key exchange
while true; do
  echo -e "\n\033[0;32mProvide the password for ${USER}: \033[0m"
  read -s -p "Enter password: " NODE_SSH_PASS
  echo
  read -s -p "Confirm password: " CONFIRM_PASS
  echo
  if [ "${NODE_SSH_PASS}" = "${CONFIRM_PASS}" ]; then
    echo "\033[0;32mPassword confirmed.\033[0m"
    break
  else
    echo -e "\033[0;31mPasswords do not match. Try again.\033[0m"
  fi
done

# Copy the SSH public key over to nodes. This will be done twice once with the IPs and then again with the hostnames.
copy_keys() {
  echo -e "\n\033[0;32mCopying ssh keys over to remote servers\033[0m"
  for HOST in "$@"; do
    echo "Copying SSH key to ${REMOTE_USER}@${HOST}..."
    sshpass -p "${NODE_SSH_PASS}" ssh-copy-id -i "${SSH_KEY}.pub" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_USER}@${HOST}"
    echo "Verifying SSH access to ${HOST}..."
    ssh -i "${SSH_KEY}" "${REMOTE_USER}@${HOST}" 'hostname'
  done
}

# Create host file and distribute it to all nodes
host_file() {
  mkdir -p ${FILE_STORE}
  echo -e "\n\033[0;32mCreating hosts file entries...\033[0m"
  cat <<EOF | sudo tee "${FILE_STORE}/hosts" >/dev/null
127.0.0.1	localhost	localhost.localdomain

EOF

  for HOST in "$@}"; do
    echo "Creating hosts entry for: ${HOST}..."
    cat <<EOF>> "${FILE_STORE}/hosts"
${HOST}  $(ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_USER}@${HOST}" 'hostname -s')  $(ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${REMOTE_USER}@${HOST}" 'hostname')

EOF
    cat "${FILE_STORE}/hosts"
  done

  echo "Distributing hosts file to other nodes..."
  for HOST in "$@"; do
    echo "Sending host file to: ${HOST}..."
    scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${FILE_STORE}/hosts" "${REMOTE_USER}@${HOST}:/etc/hosts"
  done

}

main() {
  gen_keys "${ALL_IPS[@]}"
  copy_keys "${ALL_IPS[@]}"
  host_file "${ALL_IPS[@]}"
  copy_keys "${RKE2_NODES[@]}"
}

main "$@"

fi
